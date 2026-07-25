local Sessions = {}
local PendingSpawns = {}
local ActiveTrains = {}
local LastActions = {}
local StationReservations = {}

local function debugLog(message, ...)
    if not MSTrainsConfig.Debug then return end
    print(('[MS_Trains] ' .. message):format(...))
end

local function notify(playerSource, message)
    TriggerClientEvent('ms_trains:client:result', playerSource, {
        success = false,
        message = message
    })
end

local function hasActiveCharacter(playerSource)
    local success, player = pcall(function()
        return exports.MSCore:GetPlayer(playerSource)
    end)
    return success and player ~= nil
end

local function stationById(stationId)
    return type(stationId) == 'string' and MSTrainsConfig.Stations[stationId] or nil
end

local function trainById(trainId)
    return type(trainId) == 'string' and MSTrainsConfig.Trains[trainId] or nil
end

local function tableContains(values, needle)
    if type(values) ~= 'table' then return false end
    for _, value in ipairs(values) do
        if value == needle then return true end
    end
    return false
end

local function distanceTo(playerSource, point)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 or type(point) ~= 'table' then return math.huge end
    local coords = GetEntityCoords(ped)
    local dx = coords.x - (tonumber(point.x) or 0.0)
    local dy = coords.y - (tonumber(point.y) or 0.0)
    local dz = coords.z - (tonumber(point.z) or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function distanceBetween(coords, point)
    local dx = coords.x - (tonumber(point.x) or 0.0)
    local dy = coords.y - (tonumber(point.y) or 0.0)
    local dz = coords.z - (tonumber(point.z) or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function onCooldown(playerSource, action, duration)
    local key = ('%d:%s'):format(playerSource, action)
    local now = GetGameTimer()
    local previous = LastActions[key]
    if previous and now - previous < duration then return true end
    LastActions[key] = now
    return false
end

local function activeCount()
    local count = 0
    for _ in pairs(ActiveTrains) do count = count + 1 end
    return count
end

local function pendingCount()
    local count = 0
    for _ in pairs(PendingSpawns) do count = count + 1 end
    return count
end

local function clearStationReservation(stationId, token)
    local reservation = StationReservations[stationId]
    if reservation and reservation.token == token then StationReservations[stationId] = nil end
end

local function publicActive(playerSource)
    local active = ActiveTrains[playerSource]
    if not active then return nil end
    local station = stationById(active.stationId)
    local train = trainById(active.trainId)
    return {
        stationId = active.stationId,
        stationLabel = station and station.label or active.stationId,
        trainId = active.trainId,
        trainLabel = train and train.label or active.trainId,
        networkId = active.networkId,
        spawnedAt = active.spawnedAt
    }
end

local function trainCatalog(station)
    local rows = {}
    for _, trainId in ipairs(station.trains or {}) do
        local train = trainById(trainId)
        if train then
            rows[#rows + 1] = {
                id = trainId,
                label = train.label,
                description = train.description,
                maxSpeed = train.maxSpeed
            }
        end
    end
    return rows
end

local function menuPayload(playerSource, stationId, station)
    return {
        station = {
            id = stationId,
            label = station.label,
            region = station.region,
            defaultDirection = station.spawn.direction == true
        },
        trains = trainCatalog(station),
        active = publicActive(playerSource),
        settings = {
            returnCommand = MSTrainsConfig.ReturnCommand,
            maxActiveTrains = MSTrainsConfig.MaxActiveTrains,
            activeTrains = activeCount()
        }
    }
end

local function currentStation(playerSource)
    local stationId = Sessions[playerSource]
    local station = stationById(stationId)
    if not station
        or distanceTo(playerSource, station.npc) > MSTrainsConfig.ServerInteractionDistance then
        Sessions[playerSource] = nil
        return nil, nil
    end
    return stationId, station
end

local function deleteNetworkEntity(networkId)
    networkId = tonumber(networkId)
    if not networkId or networkId <= 0 then return end
    local success, entity = pcall(NetworkGetEntityFromNetworkId, networkId)
    if not success or not entity or entity == 0 then return end
    if DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function clearPlayer(playerSource, deleteEntity)
    local active = ActiveTrains[playerSource]
    local pending = PendingSpawns[playerSource]
    if deleteEntity and active then deleteNetworkEntity(active.networkId) end
    if pending then clearStationReservation(pending.stationId, pending.token) end
    for stationId, reservation in pairs(StationReservations) do
        if reservation.playerSource == playerSource then StationReservations[stationId] = nil end
    end
    Sessions[playerSource] = nil
    PendingSpawns[playerSource] = nil
    ActiveTrains[playerSource] = nil
    for key in pairs(LastActions) do
        if key:sub(1, #tostring(playerSource) + 1) == tostring(playerSource) .. ':' then
            LastActions[key] = nil
        end
    end
end

RegisterNetEvent('ms_trains:server:open', function(stationId)
    local playerSource = source
    if onCooldown(playerSource, 'open', MSTrainsConfig.ActionCooldown) then return end
    if not hasActiveCharacter(playerSource) then
        return notify(playerSource, 'Lade zuerst einen Charakter.')
    end

    local station = stationById(stationId)
    if not station
        or distanceTo(playerSource, station.npc) > MSTrainsConfig.ServerInteractionDistance then
        return notify(playerSource, 'Du bist bei keinem Zugpersonal.')
    end

    Sessions[playerSource] = stationId
    TriggerClientEvent(
        'ms_trains:client:open',
        playerSource,
        menuPayload(playerSource, stationId, station)
    )
end)

RegisterNetEvent('ms_trains:server:close', function()
    Sessions[source] = nil
end)

RegisterNetEvent('ms_trains:server:spawn', function(trainId, direction)
    local playerSource = source
    if onCooldown(playerSource, 'spawn_request', MSTrainsConfig.ActionCooldown) then return end

    local stationId, station = currentStation(playerSource)
    local train = trainById(trainId)
    if not station then return notify(playerSource, 'Der Bahnhof ist nicht mehr in Reichweite.') end
    if not train or not tableContains(station.trains, trainId) then
        return notify(playerSource, 'Dieser Zug ist an dem Bahnhof nicht verfügbar.')
    end
    if ActiveTrains[playerSource] or PendingSpawns[playerSource] then
        return notify(playerSource, 'Du hast bereits einen aktiven oder angeforderten Zug.')
    end
    if activeCount() + pendingCount() >= MSTrainsConfig.MaxActiveTrains then
        return notify(playerSource, 'Zurzeit können keine weiteren Züge bereitgestellt werden.')
    end
    local reservation = StationReservations[stationId]
    if reservation and reservation.expiresAt > GetGameTimer() then
        return notify(playerSource, 'Am Bahnhof wird gerade ein anderer Zug bereitgestellt.')
    end
    StationReservations[stationId] = nil
    if onCooldown(playerSource, 'spawn', MSTrainsConfig.SpawnCooldown) then
        return notify(playerSource, 'Bitte warte vor der nächsten Zuganforderung.')
    end

    local token = ('%d:%d:%d'):format(
        playerSource,
        GetGameTimer(),
        math.random(100000, 999999)
    )
    PendingSpawns[playerSource] = {
        token = token,
        stationId = stationId,
        trainId = trainId,
        direction = direction == true,
        expiresAt = GetGameTimer() + MSTrainsConfig.SpawnTimeout
    }
    StationReservations[stationId] = {
        playerSource = playerSource,
        token = token,
        expiresAt = GetGameTimer() + MSTrainsConfig.SpawnTimeout
    }
    Sessions[playerSource] = nil

    TriggerClientEvent('ms_trains:client:create', playerSource, {
        token = token,
        stationId = stationId,
        trainId = trainId,
        direction = direction == true
    })

    SetTimeout(MSTrainsConfig.SpawnTimeout + 1000, function()
        local pending = PendingSpawns[playerSource]
        if pending and pending.token == token and pending.expiresAt <= GetGameTimer() then
            clearStationReservation(pending.stationId, token)
            PendingSpawns[playerSource] = nil
            notify(playerSource, 'Die Zuganforderung ist abgelaufen.')
        end
    end)
end)

RegisterNetEvent('ms_trains:server:spawned', function(token, networkId)
    local playerSource = source
    local pending = PendingSpawns[playerSource]
    networkId = tonumber(networkId)
    if not pending or pending.token ~= token or pending.expiresAt < GetGameTimer() then return end
    if not networkId or networkId <= 0 then
        clearStationReservation(pending.stationId, token)
        PendingSpawns[playerSource] = nil
        return notify(playerSource, 'Der Zug konnte nicht synchronisiert werden.')
    end

    ActiveTrains[playerSource] = {
        token = token,
        stationId = pending.stationId,
        trainId = pending.trainId,
        direction = pending.direction,
        networkId = math.floor(networkId),
        spawnedAt = os.time()
    }
    PendingSpawns[playerSource] = nil
    debugLog('Spieler %d hat Zug %s mit Netzwerk-ID %d erzeugt.',
        playerSource, ActiveTrains[playerSource].trainId, networkId)

    SetTimeout(5000, function()
        clearStationReservation(ActiveTrains[playerSource]
            and ActiveTrains[playerSource].stationId or pending.stationId, token)
    end)

    SetTimeout(3500, function()
        local active = ActiveTrains[playerSource]
        if not active or active.token ~= token then return end

        local success, entity = pcall(NetworkGetEntityFromNetworkId, active.networkId)
        if not success or not entity or entity == 0 or not DoesEntityExist(entity) then
            ActiveTrains[playerSource] = nil
            TriggerClientEvent('ms_trains:client:delete', playerSource, token)
            return notify(playerSource, 'Die Serversynchronisierung des Zuges ist fehlgeschlagen.')
        end

        local station = stationById(active.stationId)
        local owner = NetworkGetEntityOwner(entity)
        local entityType = GetEntityType(entity)
        if owner ~= playerSource
            or entityType ~= 2
            or not station
            or distanceBetween(GetEntityCoords(entity), station.spawn) > 250.0 then
            deleteNetworkEntity(active.networkId)
            ActiveTrains[playerSource] = nil
            TriggerClientEvent('ms_trains:client:delete', playerSource, token)
            notify(playerSource, 'Die Zuganforderung hat die serverseitige Prüfung nicht bestanden.')
        end
    end)
end)

RegisterNetEvent('ms_trains:server:spawnFailed', function(token, reason)
    local playerSource = source
    local pending = PendingSpawns[playerSource]
    if not pending or pending.token ~= token then return end
    clearStationReservation(pending.stationId, token)
    PendingSpawns[playerSource] = nil
    TriggerClientEvent('ms_trains:client:result', playerSource, {
        success = false,
        message = type(reason) == 'string' and reason or 'Der Zug konnte nicht bereitgestellt werden.'
    })
end)

RegisterNetEvent('ms_trains:server:return', function()
    local playerSource = source
    if onCooldown(playerSource, 'return', MSTrainsConfig.ActionCooldown) then return end
    local active = ActiveTrains[playerSource]
    if not active then return notify(playerSource, 'Du hast keinen aktiven Zug.') end
    TriggerClientEvent('ms_trains:client:delete', playerSource, active.token)
end)

RegisterNetEvent('ms_trains:server:returned', function(token)
    local playerSource = source
    local active = ActiveTrains[playerSource]
    if not active or active.token ~= token then return end
    deleteNetworkEntity(active.networkId)
    ActiveTrains[playerSource] = nil
    TriggerClientEvent('ms_trains:client:result', playerSource, {
        success = true,
        message = 'Der Zug wurde zurückgegeben.'
    })
end)

RegisterNetEvent('ms_trains:server:lost', function(token)
    local playerSource = source
    local active = ActiveTrains[playerSource]
    if active and active.token == token then ActiveTrains[playerSource] = nil end
end)

AddEventHandler('playerDropped', function()
    clearPlayer(source, true)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for playerSource in pairs(ActiveTrains) do clearPlayer(playerSource, true) end
end)

function GetActiveTrain(playerSource)
    return publicActive(tonumber(playerSource))
end
