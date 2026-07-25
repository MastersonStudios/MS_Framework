local ClerkEntities = {}
local ClerkLoading = {}
local ClerkFailures = {}
local NearestStation = nil
local LastPromptStation = false
local TelegramOpen = false

local TASK_START_SCENARIO = 0x524B54361229154F
local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE

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
    local expires = GetGameTimer() + MSTelegramsConfig.ModelLoadTimeout
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function deleteEntitySafe(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

local function deleteClerk(stationId)
    deleteEntitySafe(ClerkEntities[stationId])
    ClerkEntities[stationId] = nil
end

local function spawnClerk(stationId, station)
    if ClerkEntities[stationId] or ClerkLoading[stationId] or ClerkFailures[stationId] then return end
    ClerkLoading[stationId] = true

    CreateThread(function()
        local clerk = station.clerk
        local hash = loadModel(clerk.model)
        if not hash then
            ClerkLoading[stationId] = nil
            ClerkFailures[stationId] = true
            return print(('[MS_Telegrams] NPC-Modell "%s" konnte nicht geladen werden.'):format(
                tostring(clerk.model)
            ))
        end

        local ped = CreatePed(
            hash,
            clerk.x,
            clerk.y,
            clerk.z,
            clerk.heading or 0.0,
            false,
            false,
            false,
            false
        )
        SetModelAsNoLongerNeeded(hash)
        if not DoesEntityExist(ped) then
            ClerkLoading[stationId] = nil
            ClerkFailures[stationId] = true
            return
        end

        Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
        SetEntityAsMissionEntity(ped, true, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        FreezeEntityPosition(ped, true)
        if clerk.scenario and clerk.scenario ~= '' then
            Citizen.InvokeNative(
                TASK_START_SCENARIO,
                ped,
                GetHashKey(clerk.scenario),
                -1,
                true,
                false,
                false,
                1.0,
                false
            )
        end

        ClerkEntities[stationId] = ped
        ClerkLoading[stationId] = nil
    end)
end

local function inventoryIsOpen()
    if GetResourceState('MS_Inventory') ~= 'started' then return false end
    local success, open = pcall(function() return exports.MS_Inventory:IsUiOpen() end)
    return success and open == true
end

local function clothingShopIsOpen()
    if GetResourceState('MS_ClothingShop') ~= 'started' then return false end
    local success, open = pcall(function() return exports.MS_ClothingShop:IsShopOpen() end)
    return success and open == true
end

local function conflictingUiIsOpen()
    return inventoryIsOpen() or clothingShopIsOpen()
end

local function closeTelegram(notifyServer)
    if not TelegramOpen then return end
    TelegramOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if notifyServer ~= false then TriggerServerEvent('ms_telegrams:server:close') end
end

local function openNearestStation()
    if TelegramOpen then return closeTelegram(true) end
    if conflictingUiIsOpen() then
        return TriggerEvent('frontier:client:notify', 'Schließe zuerst das andere Menü.')
    end
    if not NearestStation then
        return TriggerEvent('frontier:client:notify', 'Du bist bei keinem Telegrafenamt.')
    end
    TriggerServerEvent('ms_telegrams:server:open', NearestStation)
end

RegisterCommand(MSTelegramsConfig.Command, openNearestStation, false)
RegisterCommand('+ms_telegrams_interact', function()
    if not TelegramOpen and NearestStation and not conflictingUiIsOpen() then
        TriggerServerEvent('ms_telegrams:server:open', NearestStation)
    end
end, false)
RegisterCommand('-ms_telegrams_interact', function() end, false)
RegisterKeyMapping(
    '+ms_telegrams_interact',
    'Telegrafenamt benutzen',
    'keyboard',
    MSTelegramsConfig.InteractionKey
)

function IsTelegramOpen()
    return TelegramOpen
end

exports('IsTelegramOpen', IsTelegramOpen)

RegisterNetEvent('ms_telegrams:client:open', function(data)
    if type(data) ~= 'table' or TelegramOpen then return end
    if conflictingUiIsOpen() then
        TriggerServerEvent('ms_telegrams:server:close')
        return TriggerEvent('frontier:client:notify', 'Schließe zuerst das andere Menü.')
    end
    TelegramOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('ms_telegrams:client:refresh', function(data)
    if TelegramOpen and type(data) == 'table' then
        SendNUIMessage({ action = 'refresh', data = data })
    end
end)

RegisterNetEvent('ms_telegrams:client:result', function(data)
    if TelegramOpen then
        SendNUIMessage({
            action = 'result',
            success = data and data.success == true,
            message = data and data.message or 'Aktion verarbeitet.'
        })
    elseif data and data.message then
        TriggerEvent('frontier:client:notify', data.message)
    end
end)

RegisterNetEvent('ms_telegrams:client:newTelegram', function(data)
    local sender = data and data.senderName or 'Unbekannt'
    local number = data and data.senderNumber or '------'
    TriggerEvent(
        'frontier:client:notify',
        ('Neues Telegramm von %s (%s).'):format(sender, number)
    )
    if TelegramOpen then TriggerServerEvent('ms_telegrams:server:refresh') end
end)

RegisterNUICallback('close', function(_, cb)
    closeTelegram(true)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    if TelegramOpen then TriggerServerEvent('ms_telegrams:server:refresh') end
    cb({ ok = true })
end)

RegisterNUICallback('send', function(data, cb)
    if not TelegramOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    TriggerServerEvent(
        'ms_telegrams:server:send',
        data.recipientNumber,
        data.subject,
        data.body
    )
    cb({ ok = true })
end)

RegisterNUICallback('read', function(data, cb)
    if TelegramOpen and type(data) == 'table' then
        TriggerServerEvent('ms_telegrams:server:read', data.messageId)
    end
    cb({ ok = true })
end)

RegisterNUICallback('delete', function(data, cb)
    if TelegramOpen and type(data) == 'table' then
        TriggerServerEvent(
            'ms_telegrams:server:delete',
            data.messageId,
            data.folder
        )
    end
    cb({ ok = true })
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for stationId, station in pairs(MSTelegramsConfig.Stations) do
            local clerkDistance = distance(coords, station.clerk)
            if clerkDistance <= MSTelegramsConfig.ClerkStreamDistance then
                spawnClerk(stationId, station)
            elseif clerkDistance > MSTelegramsConfig.ClerkDespawnDistance then
                deleteClerk(stationId)
                ClerkFailures[stationId] = nil
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    while true do
        if TelegramOpen then
            NearestStation = nil
            if LastPromptStation ~= false then
                SendNUIMessage({ action = 'prompt', visible = false })
                LastPromptStation = false
            end
            Wait(250)
        else
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for stationId, station in pairs(MSTelegramsConfig.Stations) do
                local currentDistance = distance(coords, station.clerk)
                if currentDistance <= MSTelegramsConfig.InteractionDistance
                    and (not nearestDistance or currentDistance < nearestDistance) then
                    nearest = stationId
                    nearestDistance = currentDistance
                end
            end
            NearestStation = nearest
            if LastPromptStation ~= nearest then
                SendNUIMessage({
                    action = 'prompt',
                    visible = nearest ~= nil,
                    key = MSTelegramsConfig.InteractionKey,
                    label = nearest and MSTelegramsConfig.Stations[nearest].label or nil
                })
                LastPromptStation = nearest or false
            end
            Wait(nearest and 100 or 350)
        end
    end
end)

RegisterNetEvent('frontier:client:prepareLogout', function()
    closeTelegram(false)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    for stationId in pairs(ClerkEntities) do deleteClerk(stationId) end
end)
