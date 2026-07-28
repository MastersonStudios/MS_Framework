local PlatformRegisterKeyMapping = RegisterKeyMapping
local RegisterKeyMapping = type(PlatformRegisterKeyMapping) == 'function'
    and PlatformRegisterKeyMapping
    or function(...) return exports.MSCore:RegisterKeyMappingCompat(...) end

local SellerEntities = {}
local SellerLoading = {}
local SellerFailures = {}
local PendingEntities = {}
local ActiveEntities = {}
local NearestStable = nil
local MenuOpen = false
local LastPromptStable = false

local TASK_START_SCENARIO = 0x524B54361229154F
local UPDATE_PED_VARIATION = 0x283978A15512B2FE
local APPLY_SHOP_ITEM_TO_PED = 0xD3A7B003ED343FD9

local function distance(coords, point)
    local dx = coords.x - (tonumber(point.x) or 0.0)
    local dy = coords.y - (tonumber(point.y) or 0.0)
    local dz = coords.z - (tonumber(point.z) or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelValid(hash) then return nil end

    RequestModel(hash, false)
    local expires = GetGameTimer() + MSStablesConfig.ModelLoadTimeout
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function deleteEntitySafe(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if NetworkGetEntityIsNetworked(entity) then
        NetworkRequestControlOfEntity(entity)
        local expires = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(entity) and GetGameTimer() < expires do
            NetworkRequestControlOfEntity(entity)
            Wait(0)
        end
    end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

local function deleteSeller(stableId)
    deleteEntitySafe(SellerEntities[stableId])
    SellerEntities[stableId] = nil
end

local function spawnSeller(stableId, stable)
    if SellerEntities[stableId] or SellerLoading[stableId] or SellerFailures[stableId] then return end
    SellerLoading[stableId] = true

    CreateThread(function()
        local seller = stable.seller
        local hash = loadModel(seller.model)
        if not hash then
            SellerLoading[stableId] = nil
            SellerFailures[stableId] = true
            return print(('[MS_Stables] Verkäufermodell "%s" konnte nicht geladen werden.'):format(seller.model))
        end

        local ped = CreatePed(
            hash,
            seller.x,
            seller.y,
            seller.z,
            seller.heading or 0.0,
            false,
            false,
            false,
            false
        )
        SetModelAsNoLongerNeeded(hash)
        if not DoesEntityExist(ped) then
            SellerLoading[stableId] = nil
            SellerFailures[stableId] = true
            return
        end

        Citizen.InvokeNative(UPDATE_PED_VARIATION, ped, true)
        SetEntityAsMissionEntity(ped, true, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        FreezeEntityPosition(ped, true)
        if seller.scenario and seller.scenario ~= '' then
            Citizen.InvokeNative(
                TASK_START_SCENARIO,
                ped,
                GetHashKey(seller.scenario),
                -1,
                true,
                false,
                false,
                1.0,
                false
            )
        end

        SellerEntities[stableId] = ped
        SellerLoading[stableId] = nil
    end)
end

local function setMenuVisible(visible)
    MenuOpen = visible == true
    SetNuiFocus(MenuOpen, MenuOpen)
    if not MenuOpen then SendNUIMessage({ action = 'close' }) end
end

local function closeMenu(notifyServer)
    if not MenuOpen then return end
    setMenuVisible(false)
    if notifyServer ~= false then TriggerServerEvent('ms_stables:server:close') end
end

local function openNearestStable()
    if MenuOpen then return closeMenu(true) end
    if not NearestStable then
        return TriggerEvent('mscore:client:notify', 'Du bist bei keinem Stallverkäufer.')
    end
    TriggerServerEvent('ms_stables:server:open', NearestStable)
end

RegisterCommand(MSStablesConfig.Command, openNearestStable, false)
RegisterCommand('+ms_stables_interact', function()
    if not MenuOpen and NearestStable then
        TriggerServerEvent('ms_stables:server:open', NearestStable)
    end
end, false)
RegisterCommand('-ms_stables_interact', function() end, false)
RegisterKeyMapping(
    '+ms_stables_interact',
    'Stall benutzen',
    'keyboard',
    MSStablesConfig.InteractionKey
)

RegisterNetEvent('ms_stables:client:open', function(data)
    if type(data) ~= 'table' then return end
    MenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('ms_stables:client:refresh', function(data)
    if MenuOpen and type(data) == 'table' then
        SendNUIMessage({ action = 'refresh', data = data })
    end
end)

RegisterNetEvent('ms_stables:client:result', function(data)
    SendNUIMessage({
        action = 'result',
        success = data and data.success == true,
        message = data and data.message or 'Aktion verarbeitet.'
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu(true)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    if MenuOpen then TriggerServerEvent('ms_stables:server:refresh') end
    cb({ ok = true })
end)

RegisterNUICallback('purchaseHorse', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_stables:server:purchaseHorse', data.horseKey, data.name)
    cb({ ok = true })
end)

RegisterNUICallback('purchaseEquipment', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_stables:server:purchaseEquipment', data.horseId, data.equipmentKey)
    cb({ ok = true })
end)

RegisterNUICallback('purchaseCoat', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_stables:server:purchaseCoat', data.horseId, data.coatKey)
    cb({ ok = true })
end)

RegisterNUICallback('purchaseWagon', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_stables:server:purchaseWagon', data.wagonKey)
    cb({ ok = true })
end)

RegisterNUICallback('spawnAsset', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_stables:server:spawnAsset', data.kind, data.assetId)
    cb({ ok = true })
end)

RegisterNUICallback('dismissAsset', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent('ms_stables:server:dismissAsset', data.kind)
    cb({ ok = true })
end)

local function reportSpawnFailure(token, entity)
    if entity then deleteEntitySafe(entity) end
    PendingEntities[token] = nil
    TriggerServerEvent('ms_stables:server:spawnFailed', token)
end

RegisterNetEvent('ms_stables:client:createAsset', function(data)
    if type(data) ~= 'table' or type(data.token) ~= 'string'
        or type(data.model) ~= 'string' or type(data.spawn) ~= 'table' then return end

    CreateThread(function()
        local hash = loadModel(data.model)
        if not hash then return reportSpawnFailure(data.token) end

        local spawn = data.spawn
        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        local entity
        if data.kind == 'horse' then
            entity = CreatePed(
                hash,
                spawn.x,
                spawn.y,
                spawn.z,
                spawn.heading or 0.0,
                true,
                true,
                false,
                false
            )
        elseif data.kind == 'wagon' then
            entity = CreateVehicle(
                hash,
                spawn.x,
                spawn.y,
                spawn.z,
                spawn.heading or 0.0,
                true,
                true,
                false,
                false
            )
        end
        SetModelAsNoLongerNeeded(hash)

        if not entity or entity == 0 or not DoesEntityExist(entity) then
            return reportSpawnFailure(data.token, entity)
        end

        SetEntityAsMissionEntity(entity, true, false)
        SetEntityVisible(entity, true)
        SetEntityHeading(entity, spawn.heading or 0.0)
        if data.kind == 'horse' then
            Citizen.InvokeNative(UPDATE_PED_VARIATION, entity, true)
            SetBlockingOfNonTemporaryEvents(entity, true)
            local maxHealth = math.max(MSStablesConfig.BaseHorseHealth, tonumber(data.maxHealth) or 0)
            SetEntityMaxHealth(entity, maxHealth)
            SetEntityHealth(entity, maxHealth)
            for _, componentHash in ipairs(data.components or {}) do
                if tonumber(componentHash) then
                    Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, entity, tonumber(componentHash), true, true, true)
                end
            end
            Citizen.InvokeNative(UPDATE_PED_VARIATION, entity, true)
        end

        local netId = NetworkGetNetworkIdFromEntity(entity)
        if not netId or netId == 0 then return reportSpawnFailure(data.token, entity) end
        SetNetworkIdCanMigrate(netId, true)
        PendingEntities[data.token] = entity
        TriggerServerEvent('ms_stables:server:registerAsset', data.token, netId)

        SetTimeout(MSStablesConfig.ModelLoadTimeout + 6000, function()
            if PendingEntities[data.token] then reportSpawnFailure(data.token, PendingEntities[data.token]) end
        end)
    end)
end)

RegisterNetEvent('ms_stables:client:assetRegistered', function(token, netId)
    local entity = PendingEntities[token]
    PendingEntities[token] = nil
    if entity and DoesEntityExist(entity) then ActiveEntities[tonumber(netId)] = entity end
end)

RegisterNetEvent('ms_stables:client:deleteAsset', function(netId)
    netId = tonumber(netId)
    local entity = netId and ActiveEntities[netId]
    if (not entity or not DoesEntityExist(entity)) and netId and NetworkDoesEntityExistWithNetworkId(netId) then
        entity = NetworkGetEntityFromNetworkId(netId)
    end
    deleteEntitySafe(entity)
    if netId then ActiveEntities[netId] = nil end
end)

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for stableId, stable in pairs(MSStablesConfig.Stables) do
            local sellerDistance = distance(coords, stable.seller)
            if sellerDistance <= MSStablesConfig.SellerStreamDistance then
                spawnSeller(stableId, stable)
            elseif sellerDistance > MSStablesConfig.SellerDespawnDistance then
                deleteSeller(stableId)
                SellerFailures[stableId] = nil
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        if MenuOpen then
            NearestStable = nil
            if LastPromptStable ~= false then
                SendNUIMessage({ action = 'prompt', visible = false })
                LastPromptStable = false
            end
            Wait(250)
        else
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for stableId, stable in pairs(MSStablesConfig.Stables) do
                local currentDistance = distance(coords, stable.seller)
                if currentDistance <= MSStablesConfig.InteractionDistance
                    and (not nearestDistance or currentDistance < nearestDistance) then
                    nearest = stableId
                    nearestDistance = currentDistance
                end
            end
            NearestStable = nearest
            if LastPromptStable ~= nearest then
                SendNUIMessage({
                    action = 'prompt',
                    visible = nearest ~= nil,
                    key = MSStablesConfig.InteractionKey,
                    label = nearest and MSStablesConfig.Stables[nearest].label or nil
                })
                LastPromptStable = nearest or false
            end
            Wait(nearest and 100 or 350)
        end
    end
end)

RegisterNetEvent('mscore:client:prepareLogout', function()
    closeMenu(false)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    for stableId in pairs(SellerEntities) do deleteSeller(stableId) end
    for _, entity in pairs(PendingEntities) do deleteEntitySafe(entity) end
    for _, entity in pairs(ActiveEntities) do deleteEntitySafe(entity) end
end)
