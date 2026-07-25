local MenuOpen = false
local NoClip = false
local Frozen = false
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

local function setMenuOpen(open)
    MenuOpen = open == true
    SetNuiFocus(MenuOpen, MenuOpen)
    if not MenuOpen then SendNUIMessage({ action = 'close' }) end
end

local function isOnGuarma(coords)
    local bounds = AdminMenuConfig.GuarmaBounds
    return coords.x >= bounds.minX and coords.x <= bounds.maxX
        and coords.y >= bounds.minY and coords.y <= bounds.maxY
end

local function teleport(coords)
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    setMenuOpen(false)
    TriggerEvent('frontier:client:beforeTeleport')
    local ped = PlayerPedId()
    DoScreenFadeOut(350)
    while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, tonumber(coords.w) or 0.0)
    FreezeEntityPosition(ped, true)
    Wait(800)
    FreezeEntityPosition(ped, Frozen)
    TriggerEvent('frontier_guarma:client:setIslandMode', isOnGuarma({ x = x, y = y }))
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
    TriggerEvent('frontier:client:notify', NoClip and 'Noclip aktiviert.' or 'Noclip deaktiviert.')
end

local function guarmaOnboardingActive()
    if GetResourceState('frontier_guarma_onboarding') ~= 'started' then return false end
    local success, active = pcall(function()
        return exports.frontier_guarma_onboarding:IsOnboardingActive()
    end)
    return success and active == true
end

RegisterCommand(AdminMenuConfig.Command, function()
    if MenuOpen then
        setMenuOpen(false)
        TriggerServerEvent('frontier_adminmenu:server:close')
    else
        TriggerServerEvent('frontier_adminmenu:server:open')
    end
end, false)

RegisterKeyMapping(
    AdminMenuConfig.Command,
    'Frontier Adminmenü öffnen',
    'keyboard',
    AdminMenuConfig.DefaultKey
)

RegisterNetEvent('frontier_adminmenu:client:open', function(data)
    setMenuOpen(true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('frontier_adminmenu:client:refresh', function(data)
    if MenuOpen then SendNUIMessage({ action = 'refresh', data = data }) end
end)

RegisterNetEvent('frontier_adminmenu:client:result', function(data)
    SendNUIMessage({
        action = 'result',
        success = data and data.success == true,
        message = data and data.message or 'Aktion verarbeitet.'
    })
end)

RegisterNetEvent('frontier_adminmenu:client:forceClose', function()
    setMenuOpen(false)
end)

RegisterNetEvent('frontier_adminmenu:client:applyWeather', function(data)
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
end)

RegisterNetEvent('frontier_adminmenu:client:teleport', teleport)

RegisterNetEvent('frontier_adminmenu:client:restorePlayer', function(revive)
    local ped = PlayerPedId()
    if revive then
        Citizen.InvokeNative(RESURRECT_PED, ped)
        ClearPedTasksImmediately(ped)
    end
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('frontier_adminmenu:client:setFrozen', function(enabled)
    Frozen = enabled == true
    FreezeEntityPosition(PlayerPedId(), Frozen)
    TriggerEvent('frontier:client:notify', Frozen and 'Du wurdest von einem Admin eingefroren.' or 'Du kannst dich wieder bewegen.')
end)

RegisterNetEvent('frontier_adminmenu:client:toggleNoclip', function()
    setNoclip(not NoClip)
end)

RegisterNUICallback('close', function(_, cb)
    setMenuOpen(false)
    TriggerServerEvent('frontier_adminmenu:server:close')
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent('frontier_adminmenu:server:refresh')
    cb({ ok = true })
end)

RegisterNUICallback('execute', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' or type(data.action) ~= 'string' then
        return cb({ ok = false })
    end
    TriggerServerEvent('frontier_adminmenu:server:execute', data.action, data.data or {})
    cb({ ok = true })
end)

local function bindNoclip(name, key, field)
    RegisterCommand('+' .. name, function()
        if NoClip then NoclipInput[field] = true end
    end, false)
    RegisterCommand('-' .. name, function()
        NoclipInput[field] = false
    end, false)
    RegisterKeyMapping('+' .. name, 'Admin Noclip: ' .. field, 'keyboard', key)
end

bindNoclip('frontier_admin_forward', 'W', 'forward')
bindNoclip('frontier_admin_back', 'S', 'back')
bindNoclip('frontier_admin_left', 'A', 'left')
bindNoclip('frontier_admin_right', 'D', 'right')
bindNoclip('frontier_admin_up', 'SPACE', 'up')
bindNoclip('frontier_admin_down', 'LCONTROL', 'down')
bindNoclip('frontier_admin_fast', 'LSHIFT', 'fast')

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
            if NoclipInput.right then
                x, y = x + right.x * speed, y + right.y * speed
            end
            if NoclipInput.left then
                x, y = x - right.x * speed, y - right.y * speed
            end
            if NoclipInput.up then z = z + speed end
            if NoclipInput.down then z = z - speed end

            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
            SetEntityCoordsNoOffset(ped, x, y, z, true, true, true)
            SetEntityHeading(ped, rotation.z)
        end
    end
end)

RegisterNetEvent('frontier:client:prepareLogout', function()
    if MenuOpen then
        setMenuOpen(false)
        TriggerServerEvent('frontier_adminmenu:server:close')
    end
    if NoClip then setNoclip(false) end
    Frozen = false
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    setMenuOpen(false)
    if NoClip then setNoclip(false) end
    Frozen = false
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityInvincible(PlayerPedId(), false)
    SetEntityCollision(PlayerPedId(), true, true)
end)
