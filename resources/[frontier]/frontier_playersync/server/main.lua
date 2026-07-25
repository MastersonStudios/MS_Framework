local SyncedPlayers = {}
local SnapshotCooldowns = {}
local Revision = 0

local function debugLog(message, ...)
    if not PlayerSyncConfig.Debug then return end
    print(('[frontier_playersync] ' .. message):format(...))
end

local function getCorePlayer(playerSource)
    return exports.frontier_core:GetPlayer(tonumber(playerSource))
end

local function makePublicState(playerSource, player)
    playerSource = tonumber(playerSource)
    if not playerSource or not player then return nil end

    local firstname = tostring(player.firstname or '')
    local lastname = tostring(player.lastname or '')
    local characterName = ('%s %s'):format(firstname, lastname)
    characterName = characterName:gsub('^%s+', ''):gsub('%s+$', '')

    return {
        source = playerSource,
        characterId = tonumber(player.characterId),
        firstname = firstname,
        lastname = lastname,
        name = characterName ~= '' and characterName or tostring(GetPlayerName(playerSource) or ''),
        sex = tostring(player.sex or ''),
        job = tostring(player.job or 'unemployed'),
        jobGrade = tonumber(player.jobGrade) or 0,
        routingBucket = GetPlayerRoutingBucket(playerSource),
        loaded = true
    }
end

local function statesEqual(left, right)
    if not left or not right then return false end

    return left.source == right.source
        and left.characterId == right.characterId
        and left.firstname == right.firstname
        and left.lastname == right.lastname
        and left.name == right.name
        and left.sex == right.sex
        and left.job == right.job
        and left.jobGrade == right.jobGrade
        and left.routingBucket == right.routingBucket
        and left.loaded == right.loaded
end

local function setReplicatedState(playerSource, value)
    local cfxPlayer = Player(playerSource)
    if not cfxPlayer or not cfxPlayer.state then return end
    cfxPlayer.state:set(PlayerSyncConfig.StateBagKey, value, true)
end

local function upsertPlayer(playerSource, player, force)
    playerSource = tonumber(playerSource)
    player = player or getCorePlayer(playerSource)
    if not playerSource or not player then return false end

    local publicState = makePublicState(playerSource, player)
    if not force and statesEqual(SyncedPlayers[playerSource], publicState) then return false end

    SyncedPlayers[playerSource] = publicState
    Revision = Revision + 1
    setReplicatedState(playerSource, publicState)
    TriggerClientEvent('frontier_playersync:client:upsert', -1, publicState, Revision)
    debugLog('updated player %d at revision %d', playerSource, Revision)
    return true
end

local function removePlayer(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource then return false end

    SnapshotCooldowns[playerSource] = nil
    if not SyncedPlayers[playerSource] then return false end

    SyncedPlayers[playerSource] = nil
    Revision = Revision + 1
    setReplicatedState(playerSource, false)
    TriggerClientEvent('frontier_playersync:client:remove', -1, playerSource, Revision)
    debugLog('removed player %d at revision %d', playerSource, Revision)
    return true
end

local function copyState(state)
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

local function getSnapshot()
    local snapshot = {}
    for _, state in pairs(SyncedPlayers) do
        snapshot[#snapshot + 1] = copyState(state)
    end
    table.sort(snapshot, function(left, right) return left.source < right.source end)
    return snapshot
end

local function sendSnapshot(target)
    TriggerClientEvent('frontier_playersync:client:snapshot', target, getSnapshot(), Revision)
end

RegisterNetEvent('frontier_playersync:server:requestSnapshot', function()
    local playerSource = source
    local now = GetGameTimer()
    local availableAt = SnapshotCooldowns[playerSource] or 0
    if now < availableAt then return end

    SnapshotCooldowns[playerSource] = now + PlayerSyncConfig.SnapshotRequestCooldown
    sendSnapshot(playerSource)
end)

AddEventHandler('frontier:server:playerLoaded', function(playerSource, player)
    upsertPlayer(playerSource, player, true)
    sendSnapshot(playerSource)
end)

AddEventHandler('frontier:server:playerUnloaded', function(playerSource)
    removePlayer(playerSource)
end)

AddEventHandler('frontier:server:jobChanged', function(playerSource)
    upsertPlayer(playerSource, nil, true)
end)

AddEventHandler('playerDropped', function()
    removePlayer(source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local configuredSlots = GetConvarInt('sv_maxclients', 48)
    if configuredSlots > PlayerSyncConfig.MaxPlayers then
        print(('[frontier_playersync] WARNING: sv_maxclients is %d, but this resource is configured for %d players.'):format(
            configuredSlots,
            PlayerSyncConfig.MaxPlayers
        ))
    end

    if GetConvar('sv_stateBagStrictMode', 'false') ~= 'true' then
        print('[frontier_playersync] WARNING: Set sv_stateBagStrictMode true to keep player state server-authoritative.')
    end

    CreateThread(function()
        Wait(500)
        for playerSource, player in pairs(exports.frontier_core:GetPlayers()) do
            upsertPlayer(playerSource, player, true)
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(math.max(500, tonumber(PlayerSyncConfig.ReconcileInterval) or 2000))

        local corePlayers = exports.frontier_core:GetPlayers()
        for playerSource, player in pairs(corePlayers) do
            upsertPlayer(playerSource, player, false)
        end

        local stale = {}
        for playerSource in pairs(SyncedPlayers) do
            if not corePlayers[playerSource] then
                stale[#stale + 1] = playerSource
            end
        end
        for _, playerSource in ipairs(stale) do
            removePlayer(playerSource)
        end
    end
end)

exports('GetPlayerState', function(playerSource)
    local state = SyncedPlayers[tonumber(playerSource)]
    return state and copyState(state) or nil
end)

exports('GetSnapshot', getSnapshot)

exports('GetSyncedPlayerCount', function()
    local count = 0
    for _ in pairs(SyncedPlayers) do count = count + 1 end
    return count
end)
