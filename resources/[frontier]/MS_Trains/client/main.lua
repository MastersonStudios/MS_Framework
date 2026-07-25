local NpcEntities = {}
local NpcLoading = {}
local NpcFailures = {}
local NearestStation = nil
local LastPromptStation = false
local MenuOpen = false
local ActiveTrain = nil
local Accelerating = false
local Braking = false

local TASK_START_SCENARIO = 0x524B54361229154F
local UPDATE_PED_VARIATION = 0x283978A15512B2FE
local GET_NUM_CARS_FROM_TRAIN_CONFIG = 0x635423D55CA84FC8
local GET_TRAIN_MODEL_FROM_CONFIG = 0x8DF5F6A19F99F0D5
local IS_POSITION_VALID_FOR_TRAIN = 0xF05DFAF1ADFEF2CD
local CREATE_MISSION_TRAIN = 0xC239DBD9A57D2A71
local DELETE_MISSION_TRAIN = 0x0D3630FB07E8B570
local SET_TRAIN_SPEED = 0xDFBA6BBFF7CCAFBB
local SET_TRAIN_MAX_SPEED = 0x9F29999DFDF2AEB8
local SET_TRAIN_CRUISE_SPEED = 0x01021EB2E96B793C
local SET_TRAIN_REVERSE_ENABLED = 0x06A09A6E0C6D2A84

local function debugLog(message, ...)
    if not MSTrainsConfig.Debug then return end
    print(('[MS_Trains] ' .. message):format(...))
end

local function notify(message)
    TriggerEvent('frontier:client:notify', message)
end

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
    local expiresAt = GetGameTimer() + MSTrainsConfig.ModelLoadTimeout
    while not HasModelLoaded(hash) and GetGameTimer() < expiresAt do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function deleteEntitySafe(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if NetworkGetEntityIsNetworked(entity) then
        NetworkRequestControlOfEntity(entity)
        local expiresAt = GetGameTimer() + 1500
        while not NetworkHasControlOfEntity(entity) and GetGameTimer() < expiresAt do
            NetworkRequestControlOfEntity(entity)
            Wait(0)
        end
    end
    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

local function deleteNpc(stationId)
    deleteEntitySafe(NpcEntities[stationId])
    NpcEntities[stationId] = nil
end

local function spawnNpc(stationId, station)
    if NpcEntities[stationId] or NpcLoading[stationId] or NpcFailures[stationId] then return end
    NpcLoading[stationId] = true

    CreateThread(function()
        local npc = station.npc
        local hash = loadModel(npc.model)
        if not hash then
            NpcLoading[stationId] = nil
            NpcFailures[stationId] = true
            return print(('[MS_Trains] NPC-Modell "%s" konnte nicht geladen werden.'):format(
                tostring(npc.model)
            ))
        end

        local ped = CreatePed(
            hash,
            npc.x,
            npc.y,
            npc.z,
            npc.heading or 0.0,
            false,
            false,
            false,
            false
        )
        SetModelAsNoLongerNeeded(hash)
        if not DoesEntityExist(ped) then
            NpcLoading[stationId] = nil
            NpcFailures[stationId] = true
            return
        end

        Citizen.InvokeNative(UPDATE_PED_VARIATION, ped, true)
        SetEntityAsMissionEntity(ped, true, false)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        FreezeEntityPosition(ped, true)
        if npc.scenario and npc.scenario ~= '' then
            Citizen.InvokeNative(
                TASK_START_SCENARIO,
                ped,
                GetHashKey(npc.scenario),
                -1,
                true,
                false,
                false,
                1.0,
                false
            )
        end

        NpcEntities[stationId] = ped
        NpcLoading[stationId] = nil
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
    if notifyServer ~= false then TriggerServerEvent('ms_trains:server:close') end
end

local function conflictingUiIsOpen()
    local checks = {
        { resource = 'MS_Inventory', export = 'IsUiOpen' },
        { resource = 'MS_ClothingShop', export = 'IsShopOpen' },
        { resource = 'MS_Telegrams', export = 'IsTelegramOpen' }
    }
    for _, check in ipairs(checks) do
        if GetResourceState(check.resource) == 'started' then
            local success, open = pcall(function()
                return exports[check.resource][check.export]()
            end)
            if success and open == true then return true end
        end
    end
    return false
end

local function openNearestStation()
    if MenuOpen then return closeMenu(true) end
    if conflictingUiIsOpen() then return notify('Schließe zuerst das andere Menü.') end
    if not NearestStation then return notify('Du bist bei keinem Zugpersonal.') end
    TriggerServerEvent('ms_trains:server:open', NearestStation)
end

local function trainModels(configHash)
    local models = {}
    local count = Citizen.InvokeNative(
        GET_NUM_CARS_FROM_TRAIN_CONFIG,
        configHash,
        Citizen.ResultAsInteger()
    )
    count = tonumber(count) or 0
    if count < 1 or count > 64 then return nil end

    for index = 0, count - 1 do
        local model = Citizen.InvokeNative(
            GET_TRAIN_MODEL_FROM_CONFIG,
            configHash,
            index,
            Citizen.ResultAsInteger()
        )
        if not model or model == 0 or not IsModelValid(model) then
            for _, loaded in ipairs(models) do SetModelAsNoLongerNeeded(loaded) end
            return nil
        end
        RequestModel(model, false)
        models[#models + 1] = model
    end

    local expiresAt = GetGameTimer() + MSTrainsConfig.ModelLoadTimeout
    while GetGameTimer() < expiresAt do
        local loaded = true
        for _, model in ipairs(models) do
            if not HasModelLoaded(model) then
                RequestModel(model, false)
                loaded = false
            end
        end
        if loaded then return models end
        Wait(0)
    end

    for _, model in ipairs(models) do SetModelAsNoLongerNeeded(model) end
    return nil
end

local function releaseModels(models)
    for _, model in ipairs(models or {}) do SetModelAsNoLongerNeeded(model) end
end

local function spawnIsClear(spawn)
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle)
            and distance(GetEntityCoords(vehicle), spawn) <= MSTrainsConfig.SpawnClearance then
            return false
        end
    end
    return true
end

local function applyTrainSpeed(trainState, immediate)
    if not trainState or not DoesEntityExist(trainState.entity) then return end
    local signedSpeed = trainState.targetSpeed * trainState.direction
    Citizen.InvokeNative(SET_TRAIN_CRUISE_SPEED, trainState.entity, signedSpeed)
    if immediate then Citizen.InvokeNative(SET_TRAIN_SPEED, trainState.entity, signedSpeed) end
end

local function setDrivingHud(visible, driver)
    if not ActiveTrain then
        return SendNUIMessage({ action = 'driving', visible = false })
    end
    SendNUIMessage({
        action = 'driving',
        visible = visible == true,
        driver = driver == true,
        train = ActiveTrain.label,
        station = ActiveTrain.stationLabel,
        speed = math.floor(ActiveTrain.targetSpeed * 3.6 + 0.5),
        direction = ActiveTrain.direction > 0 and 'Vorwärts' or 'Rückwärts',
        maxSpeed = math.floor(ActiveTrain.maxSpeed * 3.6 + 0.5)
    })
end

local function deleteActiveTrain(report)
    local active = ActiveTrain
    if not active then return end
    ActiveTrain = nil
    Accelerating = false
    Braking = false
    SendNUIMessage({ action = 'driving', visible = false })

    if DoesEntityExist(active.entity) then
        Citizen.InvokeNative(SET_TRAIN_CRUISE_SPEED, active.entity, 0.0)
        Citizen.InvokeNative(SET_TRAIN_SPEED, active.entity, 0.0)
        if NetworkGetEntityIsNetworked(active.entity) then
            NetworkRequestControlOfEntity(active.entity)
            local expiresAt = GetGameTimer() + 1500
            while not NetworkHasControlOfEntity(active.entity) and GetGameTimer() < expiresAt do
                NetworkRequestControlOfEntity(active.entity)
                Wait(0)
            end
        end
        SetEntityAsMissionEntity(active.entity, true, true)
        pcall(function()
            Citizen.InvokeNative(
                DELETE_MISSION_TRAIN,
                Citizen.PointerValueIntInitialized(active.entity)
            )
        end)
        if DoesEntityExist(active.entity) then DeleteEntity(active.entity) end
    end

    if report == true then
        TriggerServerEvent('ms_trains:server:returned', active.token)
    end
end

local function reportSpawnFailure(token, message, entity, models)
    releaseModels(models)
    if entity and DoesEntityExist(entity) then deleteEntitySafe(entity) end
    TriggerServerEvent('ms_trains:server:spawnFailed', token, message)
end

RegisterCommand(MSTrainsConfig.Command, openNearestStation, false)
RegisterCommand(MSTrainsConfig.ReturnCommand, function()
    TriggerServerEvent('ms_trains:server:return')
end, false)

RegisterCommand('+ms_trains_interact', function()
    if not MenuOpen and NearestStation and not conflictingUiIsOpen() then
        TriggerServerEvent('ms_trains:server:open', NearestStation)
    end
end, false)
RegisterCommand('-ms_trains_interact', function() end, false)
RegisterKeyMapping(
    '+ms_trains_interact',
    'Zugpersonal ansprechen',
    'keyboard',
    MSTrainsConfig.InteractionKey
)

RegisterCommand('+ms_trains_accelerate', function() Accelerating = true end, false)
RegisterCommand('-ms_trains_accelerate', function() Accelerating = false end, false)
RegisterKeyMapping(
    '+ms_trains_accelerate',
    'Zug: Geschwindigkeit erhöhen',
    'keyboard',
    MSTrainsConfig.AccelerateKey
)

RegisterCommand('+ms_trains_brake', function() Braking = true end, false)
RegisterCommand('-ms_trains_brake', function() Braking = false end, false)
RegisterKeyMapping(
    '+ms_trains_brake',
    'Zug: Bremsen',
    'keyboard',
    MSTrainsConfig.BrakeKey
)

RegisterCommand('ms_trains_reverse', function()
    if not ActiveTrain or not DoesEntityExist(ActiveTrain.entity) then return end
    if GetPedInVehicleSeat(ActiveTrain.entity, -1) ~= PlayerPedId() then return end
    if ActiveTrain.targetSpeed > 0.05 or GetEntitySpeed(ActiveTrain.entity) > 0.75 then
        return notify('Halte den Zug zuerst vollständig an.')
    end
    ActiveTrain.direction = ActiveTrain.direction * -1
    applyTrainSpeed(ActiveTrain, true)
    setDrivingHud(true, true)
end, false)
RegisterKeyMapping(
    'ms_trains_reverse',
    'Zug: Fahrtrichtung wechseln',
    'keyboard',
    MSTrainsConfig.ReverseKey
)

RegisterCommand('ms_trains_emergency', function()
    if not ActiveTrain or not DoesEntityExist(ActiveTrain.entity) then return end
    if GetPedInVehicleSeat(ActiveTrain.entity, -1) ~= PlayerPedId() then return end
    ActiveTrain.targetSpeed = 0.0
    applyTrainSpeed(ActiveTrain, true)
    setDrivingHud(true, true)
end, false)
RegisterKeyMapping(
    'ms_trains_emergency',
    'Zug: Notbremse',
    'keyboard',
    MSTrainsConfig.EmergencyBrakeKey
)

RegisterNetEvent('ms_trains:client:open', function(data)
    if type(data) ~= 'table' or MenuOpen then return end
    if conflictingUiIsOpen() then
        TriggerServerEvent('ms_trains:server:close')
        return notify('Schließe zuerst das andere Menü.')
    end
    MenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end)

RegisterNetEvent('ms_trains:client:result', function(data)
    local message = data and data.message or 'Aktion verarbeitet.'
    if MenuOpen then
        SendNUIMessage({
            action = 'result',
            success = data and data.success == true,
            message = message
        })
    else
        notify(message)
    end
end)

RegisterNetEvent('ms_trains:client:create', function(data)
    if type(data) ~= 'table' or type(data.token) ~= 'string' then return end
    closeMenu(false)

    CreateThread(function()
        local station = MSTrainsConfig.Stations[data.stationId]
        local trainConfig = MSTrainsConfig.Trains[data.trainId]
        if not station or not trainConfig or ActiveTrain then
            return reportSpawnFailure(data.token, 'Ungültige Zuganforderung.')
        end
        local maxSpeed = math.max(0.1, math.min(30.0, tonumber(trainConfig.maxSpeed) or 10.0))
        local reverseMaxSpeed = math.max(
            0.1,
            math.min(maxSpeed, tonumber(trainConfig.reverseMaxSpeed) or maxSpeed)
        )
        local acceleration = math.max(0.1, tonumber(trainConfig.acceleration) or 1.0)
        local braking = math.max(0.1, tonumber(trainConfig.braking) or 2.0)

        local spawn = station.spawn
        local direction = data.direction == true
        if not spawnIsClear(spawn) then
            return reportSpawnFailure(
                data.token,
                'Das Gleis am Bahnhof ist blockiert. Entferne zuerst andere Fahrzeuge.'
            )
        end

        local models = trainModels(trainConfig.configHash)
        if not models then
            return reportSpawnFailure(
                data.token,
                'Die Wagenmodelle dieses Zuges konnten nicht geladen werden.'
            )
        end

        local validPosition = Citizen.InvokeNative(
            IS_POSITION_VALID_FOR_TRAIN,
            trainConfig.configHash,
            spawn.x,
            spawn.y,
            spawn.z,
            direction,
            false,
            Citizen.ResultAsInteger()
        )
        if validPosition == 0 or validPosition == false then
            return reportSpawnFailure(
                data.token,
                'Der konfigurierte Spawnpunkt liegt für diesen Zug nicht auf einem gültigen Gleis.',
                nil,
                models
            )
        end

        RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
        local train = Citizen.InvokeNative(
            CREATE_MISSION_TRAIN,
            trainConfig.configHash,
            spawn.x,
            spawn.y,
            spawn.z,
            direction,
            trainConfig.passengers == true,
            true,
            false,
            Citizen.ResultAsInteger()
        )
        releaseModels(models)
        if not train or train == 0 or not DoesEntityExist(train) then
            return reportSpawnFailure(data.token, 'RedM konnte den Zug nicht erzeugen.', train)
        end

        SetEntityAsMissionEntity(train, true, false)
        Citizen.InvokeNative(SET_TRAIN_REVERSE_ENABLED, train, true)
        Citizen.InvokeNative(SET_TRAIN_MAX_SPEED, train, maxSpeed)
        Citizen.InvokeNative(SET_TRAIN_SPEED, train, 0.0)
        Citizen.InvokeNative(SET_TRAIN_CRUISE_SPEED, train, 0.0)

        if not NetworkGetEntityIsNetworked(train) then NetworkRegisterEntityAsNetworked(train) end
        local networkExpiresAt = GetGameTimer() + 3000
        while not NetworkGetEntityIsNetworked(train) and GetGameTimer() < networkExpiresAt do
            NetworkRegisterEntityAsNetworked(train)
            Wait(0)
        end
        if not NetworkGetEntityIsNetworked(train) then
            return reportSpawnFailure(
                data.token,
                'Der Zug konnte nicht für andere Spieler synchronisiert werden.',
                train
            )
        end

        local networkId = NetworkGetNetworkIdFromEntity(train)
        if not networkId or networkId <= 0 then
            return reportSpawnFailure(
                data.token,
                'Für den Zug konnte keine gültige Netzwerk-ID erstellt werden.',
                train
            )
        end
        SetNetworkIdCanMigrate(networkId, true)
        ActiveTrain = {
            entity = train,
            token = data.token,
            networkId = networkId,
            stationId = data.stationId,
            stationLabel = station.label,
            trainId = data.trainId,
            label = trainConfig.label,
            targetSpeed = 0.0,
            direction = 1,
            maxSpeed = maxSpeed,
            reverseMaxSpeed = reverseMaxSpeed,
            acceleration = acceleration,
            braking = braking,
            wasDriver = false
        }

        TaskWarpPedIntoVehicle(PlayerPedId(), train, -1)
        TriggerServerEvent('ms_trains:server:spawned', data.token, networkId)
        notify(('Dein %s steht bereit. W beschleunigt, S bremst.'):format(trainConfig.label))
        debugLog('Zug %s an %s mit Netzwerk-ID %d erzeugt.',
            data.trainId, data.stationId, networkId)
    end)
end)

RegisterNetEvent('ms_trains:client:delete', function(token)
    if not ActiveTrain or ActiveTrain.token ~= token then return end
    closeMenu(true)
    deleteActiveTrain(true)
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu(true)
    cb({ ok = true })
end)

RegisterNUICallback('spawn', function(data, cb)
    if not MenuOpen or type(data) ~= 'table' or type(data.trainId) ~= 'string' then
        return cb({ ok = false })
    end
    TriggerServerEvent('ms_trains:server:spawn', data.trainId, data.direction == true)
    cb({ ok = true })
end)

RegisterNUICallback('returnTrain', function(_, cb)
    TriggerServerEvent('ms_trains:server:return')
    cb({ ok = true })
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for stationId, station in pairs(MSTrainsConfig.Stations) do
            local npcDistance = distance(coords, station.npc)
            if npcDistance <= MSTrainsConfig.NpcStreamDistance then
                spawnNpc(stationId, station)
            elseif npcDistance > MSTrainsConfig.NpcDespawnDistance then
                deleteNpc(stationId)
                NpcFailures[stationId] = nil
            end
        end
        Wait(1000)
    end
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    while true do
        if MenuOpen then
            NearestStation = nil
            if LastPromptStation ~= false then
                SendNUIMessage({ action = 'prompt', visible = false })
                LastPromptStation = false
            end
            Wait(250)
        else
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, nearestDistance
            for stationId, station in pairs(MSTrainsConfig.Stations) do
                local currentDistance = distance(coords, station.npc)
                if currentDistance <= MSTrainsConfig.InteractionDistance
                    and (not nearestDistance or currentDistance < nearestDistance) then
                    nearest = stationId
                    nearestDistance = currentDistance
                end
            end
            NearestStation = nearest
            if LastPromptStation ~= nearest then
                LastPromptStation = nearest or false
                SendNUIMessage({
                    action = 'prompt',
                    visible = nearest ~= nil,
                    key = MSTrainsConfig.InteractionKey,
                    label = nearest and MSTrainsConfig.Stations[nearest].label or nil
                })
            end
            Wait(nearest and 100 or 350)
        end
    end
end)

CreateThread(function()
    while true do
        if not ActiveTrain then
            Wait(500)
        elseif not DoesEntityExist(ActiveTrain.entity) then
            local token = ActiveTrain.token
            ActiveTrain = nil
            SendNUIMessage({ action = 'driving', visible = false })
            TriggerServerEvent('ms_trains:server:lost', token)
            notify('Dein Zug ist nicht mehr verfügbar.')
            Wait(500)
        else
            local isDriver = GetPedInVehicleSeat(ActiveTrain.entity, -1) == PlayerPedId()
            if isDriver then
                local seconds = MSTrainsConfig.ControlInterval / 1000.0
                if Accelerating then
                    local limit = ActiveTrain.direction > 0
                        and ActiveTrain.maxSpeed
                        or ActiveTrain.reverseMaxSpeed
                    ActiveTrain.targetSpeed = math.min(
                        limit,
                        ActiveTrain.targetSpeed + ActiveTrain.acceleration * seconds
                    )
                elseif Braking then
                    ActiveTrain.targetSpeed = math.max(
                        0.0,
                        ActiveTrain.targetSpeed - ActiveTrain.braking * seconds
                    )
                end
                applyTrainSpeed(ActiveTrain, Accelerating or Braking)
                setDrivingHud(true, true)
            elseif ActiveTrain.wasDriver then
                ActiveTrain.targetSpeed = 0.0
                applyTrainSpeed(ActiveTrain, true)
                setDrivingHud(true, false)
            else
                setDrivingHud(true, false)
            end
            ActiveTrain.wasDriver = isDriver
            Wait(MSTrainsConfig.ControlInterval)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if ActiveTrain then deleteActiveTrain(false) end
    for stationId in pairs(NpcEntities) do deleteNpc(stationId) end
end)

function GetActiveTrain()
    if not ActiveTrain then return nil end
    return {
        entity = ActiveTrain.entity,
        networkId = ActiveTrain.networkId,
        stationId = ActiveTrain.stationId,
        trainId = ActiveTrain.trainId,
        speed = ActiveTrain.targetSpeed,
        direction = ActiveTrain.direction
    }
end

function IsTrainMenuOpen()
    return MenuOpen
end
