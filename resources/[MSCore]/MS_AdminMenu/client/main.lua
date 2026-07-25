local MenuOpen = false
local CraftingOpen = false
local NoClip = false
local GhostMode = false
local Frozen = false
local GhostPlayers = {}
local GhostEntities = {}
local CraftingPoints = {}
local NearestCraftingPoint = nil
local NoclipInput = {
    forward = false,
    back = false,
    left = false,
    right = false,
    up = false,
    down = false,
    fast = false
}

local SET_WEATHER_TYPE = 0x59174F1AFE095B5A
local RESURRECT_PED = 0x71BC8E838B9C6035

local function closeUi()
    MenuOpen = false
    CraftingOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openAcp(data)
    MenuOpen = true
    CraftingOpen = false
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
    SendNUIMessage({ action = 'noclipState', enabled = NoClip })
    SendNUIMessage({ action = 'ghostState', enabled = GhostMode })
end

local function distance(coords, point)
    local dx, dy, dz = coords.x - point.x, coords.y - point.y, coords.z - point.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function worldInteractionNearby()
    if GetResourceState('MS_WorldBuilder') ~= 'started' then return false end
    local success, nearby = pcall(function()
        return exports.MS_WorldBuilder:HasNearbyInteraction()
    end)
    return success and nearby == true
end

exports('IsUiOpen', function()
    return MenuOpen or CraftingOpen
end)

local function isOnGuarma(coords)
    local bounds = AdminMenuConfig.GuarmaBounds
    return coords.x >= bounds.minX and coords.x <= bounds.maxX
        and coords.y >= bounds.minY and coords.y <= bounds.maxY
end

local function teleport(coords)
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    closeUi()
    TriggerServerEvent('ms_adminmenu:server:close')
    TriggerEvent('mscore:client:beforeTeleport')
    local ped = PlayerPedId()
    DoScreenFadeOut(350)
    while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, tonumber(coords.w) or 0.0)
    FreezeEntityPosition(ped, true)
    Wait(800)
    FreezeEntityPosition(ped, Frozen)
    TriggerEvent('ms_guarma:client:setIslandMode', isOnGuarma({ x = x, y = y }))
    DoScreenFadeIn(500)
end

local function setNoclip(enabled)
    NoClip = enabled == true
    local ped = PlayerPedId()
    SetEntityInvincible(ped, NoClip)
    SetEntityCollision(ped, not NoClip, not NoClip)
    SetEntityVelocity(ped, 0.0, 0.0, 0.0)
    if not NoClip then
        for key in pairs(NoclipInput) do NoclipInput[key] = false end
    end
    SendNUIMessage({ action = 'noclipState', enabled = NoClip })
    TriggerEvent('mscore:client:notify', NoClip and 'Noclip aktiviert.' or 'Noclip deaktiviert.')
end

local function playerPedFromServerId(playerSource)
    if playerSource == GetPlayerServerId(PlayerId()) then return PlayerPedId() end
    local playerId = GetPlayerFromServerId(playerSource)
    if playerId == -1 or not NetworkIsPlayerActive(playerId) then return nil end
    local ped = GetPlayerPed(playerId)
    return ped and ped ~= 0 and ped or nil
end

local function restoreGhostEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    SetEntityVisible(entity, true, false)
    if ResetEntityAlpha then
        ResetEntityAlpha(entity)
    elseif SetEntityAlpha then
        SetEntityAlpha(entity, 255, false)
    end
    if SetPedCanBeTargetted then SetPedCanBeTargetted(entity, true) end
end

local function applyGhostVisual(playerSource)
    local ped = playerPedFromServerId(playerSource)
    if not ped then return end

    local previous = GhostEntities[playerSource]
    if previous and previous ~= ped then restoreGhostEntity(previous) end
    GhostEntities[playerSource] = ped

    SetEntityVisible(ped, false, false)
    if SetEntityAlpha then SetEntityAlpha(ped, 0, false) end
    if SetPedCanBeTargetted then SetPedCanBeTargetted(ped, false) end
    if playerSource == GetPlayerServerId(PlayerId())
        and NetworkSetEntityInvisibleToNetwork then
        NetworkSetEntityInvisibleToNetwork(ped, true)
    end
end

local function setGhostState(playerSource, enabled, notifySelf)
    playerSource = tonumber(playerSource)
    if not playerSource then return end
    enabled = enabled == true

    if enabled then
        GhostPlayers[playerSource] = true
        applyGhostVisual(playerSource)
    else
        local current = playerPedFromServerId(playerSource)
        restoreGhostEntity(GhostEntities[playerSource])
        if current ~= GhostEntities[playerSource] then restoreGhostEntity(current) end
        GhostPlayers[playerSource] = nil
        GhostEntities[playerSource] = nil
    end

    if playerSource == GetPlayerServerId(PlayerId()) then
        GhostMode = enabled
        local ped = PlayerPedId()
        if not enabled and NetworkSetEntityInvisibleToNetwork then
            NetworkSetEntityInvisibleToNetwork(ped, false)
        end
        SendNUIMessage({ action = 'ghostState', enabled = GhostMode })
        if notifySelf == true then
            TriggerEvent(
                'mscore:client:notify',
                GhostMode and 'Ghost Mode aktiviert.' or 'Ghost Mode deaktiviert.'
            )
        end
    end
end

local function applyGhostSnapshot(snapshot)
    local replacement = {}
    local removals = {}
    for _, rawSource in ipairs(type(snapshot) == 'table' and snapshot or {}) do
        local playerSource = tonumber(rawSource)
        if playerSource then replacement[playerSource] = true end
    end
    for playerSource in pairs(GhostPlayers) do
        if not replacement[playerSource] then removals[#removals + 1] = playerSource end
    end
    for _, playerSource in ipairs(removals) do
        setGhostState(playerSource, false, false)
    end
    for playerSource in pairs(replacement) do
        setGhostState(playerSource, true, false)
    end
end

local function guarmaOnboardingActive()
    if GetResourceState('MS_GuarmaOnboarding') ~= 'started' then return false end
    local success, active = pcall(function()
        return exports.MS_GuarmaOnboarding:IsOnboardingActive()
    end)
    return success and active == true
end

local function toggleAcp()
    if MenuOpen or CraftingOpen then
        closeUi()
        TriggerServerEvent('ms_adminmenu:server:close')
    else
        TriggerServerEvent('ms_adminmenu:server:open')
    end
end

RegisterCommand(AdminMenuConfig.Command, toggleAcp, false)
for _, alias in ipairs(AdminMenuConfig.CommandAliases or {}) do
    RegisterCommand(alias, toggleAcp, false)
end

RegisterKeyMapping(
    AdminMenuConfig.Command,
    'MSCore ACP öffnen',
    'keyboard',
    AdminMenuConfig.DefaultKey
)

RegisterNetEvent('ms_adminmenu:client:open', openAcp)

RegisterNetEvent('ms_adminmenu:client:refresh', function(data)
    if MenuOpen then SendNUIMessage({ action = 'refresh', data = data }) end
end)

RegisterNetEvent('ms_adminmenu:client:result', function(data)
    SendNUIMessage({
        action = 'result',
        success = data and data.success == true,
        message = data and data.message or 'Aktion verarbeitet.'
    })
end)

RegisterNetEvent('ms_adminmenu:client:externalResult', function(data)
    if not MenuOpen then return end
    SendNUIMessage({
        action = 'result',
        success = data and data.success == true,
        message = data and data.message or 'World-Builder-Aktion verarbeitet.'
    })
end)

RegisterNetEvent('ms_adminmenu:client:worldBuilderData', function(data)
    if MenuOpen then SendNUIMessage({ action = 'worldData', data = data }) end
end)

RegisterNetEvent('ms_adminmenu:client:forceClose', closeUi)

RegisterNetEvent('ms_adminmenu:client:applyWeather', function(data)
    if type(data) ~= 'table' or not tonumber(data.hash) then return end
    if guarmaOnboardingActive() then return end
    Citizen.InvokeNative(
        SET_WEATHER_TYPE,
        tonumber(data.hash),
        false,
        true,
        true,
        tonumber(data.transition) or AdminMenuConfig.DefaultTransition,
        false
    )
    TriggerEvent('mscore:client:weatherChanged', tostring(data.id or 'custom'), tonumber(data.hash))
end)

RegisterNetEvent('ms_adminmenu:client:teleport', teleport)

RegisterNetEvent('ms_adminmenu:client:restorePlayer', function(revive)
    local ped = PlayerPedId()
    if revive then
        Citizen.InvokeNative(RESURRECT_PED, ped)
        ClearPedTasksImmediately(ped)
    end
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('ms_adminmenu:client:setFrozen', function(enabled)
    Frozen = enabled == true
    FreezeEntityPosition(PlayerPedId(), Frozen)
    TriggerEvent(
        'mscore:client:notify',
        Frozen and 'Du wurdest von einem Admin eingefroren.' or 'Du kannst dich wieder bewegen.'
    )
end)

RegisterNetEvent('ms_adminmenu:client:toggleNoclip', function()
    setNoclip(not NoClip)
end)

RegisterNetEvent('ms_adminmenu:client:ghostSnapshot', applyGhostSnapshot)

RegisterNetEvent('ms_adminmenu:client:ghostChanged', function(playerSource, enabled)
    setGhostState(playerSource, enabled, playerSource == GetPlayerServerId(PlayerId()))
end)

RegisterNetEvent('ms_adminmenu:client:craftingSync', function(points)
    CraftingPoints = {}
    for _, point in ipairs(type(points) == 'table' and points or {}) do
        point.id = tonumber(point.id)
        if point.id then CraftingPoints[point.id] = point end
    end
end)

RegisterNetEvent('ms_adminmenu:client:openCrafting', function(data)
    if MenuOpen then TriggerServerEvent('ms_adminmenu:server:close') end
    MenuOpen = false
    CraftingOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCrafting', data = data })
end)

RegisterNetEvent('ms_adminmenu:client:craftingBusy', function(data)
    if CraftingOpen then SendNUIMessage({ action = 'craftingBusy', data = data }) end
end)

RegisterNetEvent('ms_adminmenu:client:craftResult', function(data)
    SendNUIMessage({
        action = 'craftResult',
        success = data and data.success == true,
        message = data and data.message or 'Crafting verarbeitet.'
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    TriggerServerEvent('ms_adminmenu:server:close')
    cb({ ok = true })
end)

RegisterNUICallback('closeCrafting', function(_, cb)
    closeUi()
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    if MenuOpen then TriggerServerEvent('ms_adminmenu:server:refresh') end
    cb({ ok = true })
end)

RegisterNUICallback('execute', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' or type(data.action) ~= 'string' then
        return cb({ ok = false })
    end
    TriggerServerEvent('ms_adminmenu:server:execute', data.action, data.data or {})
    cb({ ok = true })
end)

RegisterNUICallback('worldCreate', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' or type(data.kind) ~= 'string' then
        return cb({ ok = false })
    end
    TriggerServerEvent('ms_worldbuilder:server:create', data.kind, data.data or {})
    cb({ ok = true })
end)

RegisterNUICallback('worldDelete', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_worldbuilder:server:delete', data.kind, data.id)
    cb({ ok = true })
end)

RegisterNUICallback('worldToggleDoor', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_worldbuilder:server:builderToggleDoor', data.id)
    cb({ ok = true })
end)

RegisterNUICallback('capturePosition', function(data, cb)
    if not MenuOpen then return cb({ ok = false }) end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local radians = math.rad(heading)
    local offset = data and data.kind == 'npc' and 1.6 or 0.8
    cb({
        ok = true,
        coords = {
            x = coords.x - math.sin(radians) * offset,
            y = coords.y + math.cos(radians) * offset,
            z = coords.z,
            heading = heading
        }
    })
end)

local function cameraDirection(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local pitchScale = math.abs(math.cos(pitch))
    return vector3(-math.sin(yaw) * pitchScale, math.cos(yaw) * pitchScale, math.sin(pitch))
end

RegisterNUICallback('captureDoor', function(_, cb)
    if not MenuOpen then return cb({ ok = false }) end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'captureHint', visible = true })
    Wait(1500)

    local origin = GetGameplayCamCoord()
    local direction = cameraDirection(GetGameplayCamRot(2))
    local destination = origin + direction * 10.0
    local ray = StartShapeTestRay(
        origin.x, origin.y, origin.z,
        destination.x, destination.y, destination.z,
        16,
        PlayerPedId(),
        0
    )
    local status, hit, endCoords, surfaceNormal, entity
    local expires = GetGameTimer() + 1000
    repeat
        status, hit, endCoords, surfaceNormal, entity = GetShapeTestResult(ray)
        if status == 1 then Wait(0) end
    until status ~= 1 or GetGameTimer() >= expires

    SendNUIMessage({ action = 'captureHint', visible = false })
    if MenuOpen then SetNuiFocus(true, true) end
    if not hit or not entity or entity == 0 or GetEntityType(entity) ~= 3 then
        return cb({ ok = false, error = 'Kein Tür- oder Objektmodell anvisiert.' })
    end
    local coords = GetEntityCoords(entity)
    cb({
        ok = true,
        door = {
            modelHash = GetEntityModel(entity),
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = GetEntityHeading(entity)
        }
    })
end)

RegisterNUICallback('craft', function(data, cb)
    if not CraftingOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_adminmenu:server:craft', data.pointId, data.recipeId)
    cb({ ok = true })
end)

RegisterCommand('+mscore_crafting_interact', function()
    if MenuOpen or CraftingOpen or worldInteractionNearby() or not NearestCraftingPoint then return end
    TriggerServerEvent('ms_adminmenu:server:openCrafting', NearestCraftingPoint.id)
end, false)
RegisterCommand('-mscore_crafting_interact', function() end, false)
RegisterKeyMapping(
    '+mscore_crafting_interact',
    'Crafting-Punkt benutzen',
    'keyboard',
    AdminMenuConfig.CraftingInteractionKey
)

local function bindNoclip(name, key, field)
    RegisterCommand('+' .. name, function()
        if NoClip then NoclipInput[field] = true end
    end, false)
    RegisterCommand('-' .. name, function()
        NoclipInput[field] = false
    end, false)
    RegisterKeyMapping('+' .. name, 'Admin Noclip: ' .. field, 'keyboard', key)
end

bindNoclip('mscore_admin_forward', 'W', 'forward')
bindNoclip('mscore_admin_back', 'S', 'back')
bindNoclip('mscore_admin_left', 'A', 'left')
bindNoclip('mscore_admin_right', 'D', 'right')
bindNoclip('mscore_admin_up', 'SPACE', 'up')
bindNoclip('mscore_admin_down', 'LCONTROL', 'down')
bindNoclip('mscore_admin_fast', 'LSHIFT', 'fast')

CreateThread(function()
    while true do
        if not NoClip then
            Wait(350)
        else
            Wait(0)
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local rotation = GetGameplayCamRot(2)
            local yaw = math.rad(rotation.z)
            local pitch = math.rad(rotation.x)
            local cosPitch = math.abs(math.cos(pitch))
            local forward = vector3(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch))
            local right = vector3(math.cos(yaw), math.sin(yaw), 0.0)
            local speed = NoclipInput.fast and 1.4 or 0.38
            local x, y, z = coords.x, coords.y, coords.z

            if NoclipInput.forward then
                x, y, z = x + forward.x * speed, y + forward.y * speed, z + forward.z * speed
            end
            if NoclipInput.back then
                x, y, z = x - forward.x * speed, y - forward.y * speed, z - forward.z * speed
            end
            if NoclipInput.right then x, y = x + right.x * speed, y + right.y * speed end
            if NoclipInput.left then x, y = x - right.x * speed, y - right.y * speed end
            if NoclipInput.up then z = z + speed end
            if NoclipInput.down then z = z - speed end

            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
            SetEntityCoordsNoOffset(ped, x, y, z, true, true, true)
            SetEntityHeading(ped, rotation.z)
        end
    end
end)

CreateThread(function()
    Wait(500)
    TriggerServerEvent('ms_adminmenu:server:requestGhostSnapshot')
    while true do
        if next(GhostPlayers) == nil then
            Wait(500)
        else
            for playerSource in pairs(GhostPlayers) do applyGhostVisual(playerSource) end
            Wait(math.max(
                25,
                math.floor(tonumber(AdminMenuConfig.GhostRefreshIntervalMs) or 100)
            ))
        end
    end
end)

CreateThread(function()
    while true do
        if MenuOpen or CraftingOpen or worldInteractionNearby() then
            NearestCraftingPoint = nil
            SendNUIMessage({ action = 'craftPrompt', visible = false })
            Wait(300)
        else
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for _, point in pairs(CraftingPoints) do
                local currentDistance = distance(coords, point)
                if currentDistance <= point.radius and (not nearestDistance or currentDistance < nearestDistance) then
                    nearest = point
                    nearestDistance = currentDistance
                end
            end
            NearestCraftingPoint = nearest
            SendNUIMessage({
                action = 'craftPrompt',
                visible = nearest ~= nil,
                key = AdminMenuConfig.CraftingInteractionKey,
                label = nearest and nearest.label
            })
            Wait(nearest and 120 or 400)
        end
    end
end)

RegisterNetEvent('mscore:client:prepareLogout', function()
    if MenuOpen then TriggerServerEvent('ms_adminmenu:server:close') end
    closeUi()
    if NoClip then setNoclip(false) end
    setGhostState(GetPlayerServerId(PlayerId()), false, false)
    Frozen = false
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeUi()
    if NoClip then setNoclip(false) end
    local ghostSources = {}
    for playerSource in pairs(GhostPlayers) do
        ghostSources[#ghostSources + 1] = playerSource
    end
    for _, playerSource in ipairs(ghostSources) do
        setGhostState(playerSource, false, false)
    end
    Frozen = false
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityInvincible(PlayerPedId(), false)
    SetEntityCollision(PlayerPedId(), true, true)
end)
