local SyncedPlayers = {}
local Revision = 0

local function normalizeState(state)
    if type(state) ~= 'table' then return nil end

    local playerSource = tonumber(state.source)
    local characterId = tonumber(state.characterId)
    if not playerSource or playerSource < 1 or not characterId then return nil end

    return {
        source = playerSource,
        characterId = characterId,
        firstname = tostring(state.firstname or ''),
        lastname = tostring(state.lastname or ''),
        name = tostring(state.name or ''),
        sex = tostring(state.sex or ''),
        job = tostring(state.job or 'unemployed'),
        jobGrade = tonumber(state.jobGrade) or 0,
        routingBucket = tonumber(state.routingBucket) or 0,
        loaded = state.loaded == true
    }
end

local function upsertState(state, revision)
    state = normalizeState(state)
    if not state then return end
    revision = tonumber(revision)
    if revision and revision < Revision then return end

    Revision = math.max(Revision, revision or Revision)
    SyncedPlayers[state.source] = state
    TriggerEvent('frontier_playersync:client:updated', state.source, state)
end

RegisterNetEvent('frontier_playersync:client:snapshot', function(snapshot, revision)
    if type(snapshot) ~= 'table' then return end
    revision = tonumber(revision)
    if revision and revision < Revision then return end

    local replacement = {}
    for _, state in ipairs(snapshot) do
        state = normalizeState(state)
        if state then replacement[state.source] = state end
    end

    SyncedPlayers = replacement
    Revision = revision or Revision
    TriggerEvent('frontier_playersync:client:snapshotUpdated', Revision)
end)

RegisterNetEvent('frontier_playersync:client:upsert', upsertState)

RegisterNetEvent('frontier_playersync:client:remove', function(playerSource, revision)
    playerSource = tonumber(playerSource)
    if not playerSource then return end
    revision = tonumber(revision)
    if revision and revision < Revision then return end

    Revision = math.max(Revision, revision or Revision)
    SyncedPlayers[playerSource] = nil
    TriggerEvent('frontier_playersync:client:removed', playerSource)
end)

AddStateBagChangeHandler(PlayerSyncConfig.StateBagKey, nil, function(bagName, _, value)
    if type(bagName) ~= 'string' then return end

    local bagPlayerSource = tonumber(bagName:match('^player:(%d+)$'))
    if not bagPlayerSource then return end

    if value == false then
        if SyncedPlayers[bagPlayerSource] then
            SyncedPlayers[bagPlayerSource] = nil
            TriggerEvent('frontier_playersync:client:removed', bagPlayerSource)
        end
        return
    end

    if type(value) ~= 'table' then return end
    local state = {}
    for key, entry in pairs(value) do state[key] = entry end
    state.source = bagPlayerSource
    upsertState(state)
end)

local function copyState(state)
    if not state then return nil end
    return {
        source = state.source,
        characterId = state.characterId,
        firstname = state.firstname,
        lastname = state.lastname,
        name = state.name,
        sex = state.sex,
        job = state.job,
        jobGrade = state.jobGrade,
        routingBucket = state.routingBucket,
        loaded = state.loaded
    }
end

local function getPlayerState(playerSource)
    return copyState(SyncedPlayers[tonumber(playerSource)])
end

local function getPlayers()
    local players = {}
    for _, state in pairs(SyncedPlayers) do
        players[#players + 1] = copyState(state)
    end
    table.sort(players, function(left, right) return left.source < right.source end)
    return players
end

local function getNearbyPlayers(radius, includeSelf)
    radius = tonumber(radius) or PlayerSyncConfig.NearbyRadius
    radius = math.max(0.0, radius)

    local localPlayerId = PlayerId()
    local localCoords = GetEntityCoords(PlayerPedId())
    local nearby = {}

    for _, playerId in ipairs(GetActivePlayers()) do
        if includeSelf == true or playerId ~= localPlayerId then
            local playerSource = GetPlayerServerId(playerId)
            local state = SyncedPlayers[playerSource]
            local ped = GetPlayerPed(playerId)

            if state and ped ~= 0 and DoesEntityExist(ped) then
                local coords = GetEntityCoords(ped)
                local distance = #(localCoords - coords)
                if distance <= radius then
                    local entry = copyState(state)
                    entry.playerId = playerId
                    entry.ped = ped
                    entry.coords = {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z
                    }
                    entry.distance = distance
                    nearby[#nearby + 1] = entry
                end
            end
        end
    end

    table.sort(nearby, function(left, right) return left.distance < right.distance end)
    return nearby
end

exports('GetPlayerState', getPlayerState)
exports('GetPlayers', getPlayers)
exports('GetNearbyPlayers', getNearbyPlayers)
exports('GetSyncedPlayerCount', function()
    local count = 0
    for _ in pairs(SyncedPlayers) do count = count + 1 end
    return count
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    TriggerServerEvent('frontier_playersync:server:requestSnapshot')
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerServerEvent('frontier_playersync:server:requestSnapshot')
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SyncedPlayers = {}
    Revision = 0
end)
