local Config = MSMedicConfig
local Settings = type(Config.Unconscious) == 'table' and Config.Unconscious or {}
local ActiveUnconscious = {}
local Sequence = 0
local LastEmergencyRequests = {}
local METADATA_KEY = 'medicUnconscious'

local function debugLog(message, ...)
    if Config.Debug ~= true then return end
    print(('[MS_Medic:Unconscious] ' .. message):format(...))
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function notify(playerSource, message)
    TriggerClientEvent('mscore:client:notify', playerSource, message)
end

local function isMedic(playerSource)
    local player = getPlayer(playerSource)
    if not player then return false end
    local minimumGrade = type(Config.MedicJobs) == 'table' and Config.MedicJobs[player.job]
    return minimumGrade ~= nil
        and (tonumber(player.jobGrade) or 0) >= (tonumber(minimumGrade) or 0)
end

local function isFinalDeath(playerSource)
    if GetResourceState('MS_Permadeath') ~= 'started' then return false end
    local success, blocked = pcall(function()
        return exports.MS_Permadeath:IsFinalDeath(playerSource)
    end)
    return success and blocked == true
end

local function playerCoords(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    if not coords then return nil end
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = GetEntityHeading(ped)
    }
end

local function playerIsDead(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return false end
    return (type(IsEntityDead) == 'function' and IsEntityDead(ped))
        or (tonumber(GetEntityHealth(ped)) or 0) <= 0
end

local function serializableCoords(coords)
    if not coords then return nil end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end
    return {
        x = x,
        y = y,
        z = z,
        w = tonumber(coords.w) or tonumber(coords.heading) or 0.0
    }
end

local function statePayload(state, forceDead)
    return {
        incidentId = state.incidentId,
        startedAt = state.startedAt,
        deadlineAt = state.deadlineAt,
        remainingSeconds = math.max(0, state.deadlineAt - os.time()),
        emergencyCalled = state.emergencyCalled == true,
        forceDead = forceDead == true
    }
end

local function persistentState(state)
    return {
        incidentId = state.incidentId,
        startedAt = state.startedAt,
        deadlineAt = state.deadlineAt,
        emergencyCalled = state.emergencyCalled == true,
        coords = serializableCoords(state.coords)
    }
end

local function saveState(player, state)
    player:setMetadata(METADATA_KEY, persistentState(state))
    player:setMetadata('health', 0)
    player:save()
end

local function emergencyPayload(state)
    local patient = getPlayer(state.playerSource)
    return {
        incidentId = state.incidentId,
        patientSource = state.playerSource,
        patientName = patient and patient:getName() or 'Unbekannter Patient',
        coords = serializableCoords(state.coords),
        radius = math.max(1.0, tonumber(Settings.EmergencyRadius) or 15.0),
        remainingSeconds = math.max(0, state.deadlineAt - os.time())
    }
end

local function forEachMedic(callback)
    for playerSource in pairs(exports.MSCore:GetPlayers()) do
        playerSource = tonumber(playerSource)
        if playerSource and isMedic(playerSource) then callback(playerSource) end
    end
end

local function broadcastEmergency(state)
    local payload = emergencyPayload(state)
    if not payload.coords then return end
    forEachMedic(function(medicSource)
        TriggerClientEvent('ms_medic:client:emergencyCall', medicSource, payload)
        notify(
            medicSource,
            ('Notruf von %s (ID %d). Der Einsatz wurde auf der Karte markiert.'):format(
                payload.patientName,
                payload.patientSource
            )
        )
    end)
end

local function broadcastResolved(state, reason)
    if not state or state.emergencyCalled ~= true then return end
    forEachMedic(function(medicSource)
        TriggerClientEvent(
            'ms_medic:client:emergencyResolved',
            medicSource,
            state.incidentId,
            tostring(reason or 'resolved')
        )
    end)
end

local function removeState(playerSource, reason, clearMetadata, tellClient)
    playerSource = tonumber(playerSource)
    local state = playerSource and ActiveUnconscious[playerSource]
    if not state then return false end

    ActiveUnconscious[playerSource] = nil
    LastEmergencyRequests[playerSource] = nil
    broadcastResolved(state, reason)

    local player = getPlayer(playerSource)
    if clearMetadata == true and player then
        player:setMetadata(METADATA_KEY, nil)
        player:save()
    end
    if tellClient ~= false and player then
        TriggerClientEvent('ms_medic:client:unconsciousStop', playerSource, {
            reason = tostring(reason or 'resolved')
        })
    end
    return true
end

local function nearestCity(coords)
    local selected
    local selectedDistance = math.huge
    for _, city in ipairs(type(Settings.RespawnCities) == 'table' and Settings.RespawnCities or {}) do
        local destination = serializableCoords(city.coords)
        if destination then
            local dx = destination.x - coords.x
            local dy = destination.y - coords.y
            local distance = dx * dx + dy * dy
            if distance < selectedDistance then
                selectedDistance = distance
                selected = {
                    label = tostring(city.label or 'Nächste Stadt'),
                    coords = destination
                }
            end
        end
    end
    return selected
end

local function jailDestination(playerSource)
    if Settings.RespectJail ~= true or GetResourceState('MS_Jail') ~= 'started' then return nil end
    local success, state = pcall(function()
        return exports.MS_Jail:GetJailState(playerSource)
    end)
    if not success or type(state) ~= 'table' or not state.cell then return nil end
    local coords = serializableCoords(state.cell)
    return coords and { label = 'Sisika', coords = coords } or nil
end

local function wakeDestination(playerSource, state)
    local jailed = jailDestination(playerSource)
    if jailed then return jailed end
    local origin = serializableCoords(state.coords) or playerCoords(playerSource)
    return origin and nearestCity(origin) or nil
end

local function autoWake(playerSource, state)
    local player = getPlayer(playerSource)
    if not player or ActiveUnconscious[playerSource] ~= state then return false end
    if isFinalDeath(playerSource) then
        return removeState(playerSource, 'permadeath', true, true)
    end

    local destination = wakeDestination(playerSource, state)
    if not destination then
        state.deadlineAt = os.time() + 30
        saveState(player, state)
        return false
    end

    local health = math.max(1, math.min(
        200,
        math.floor(tonumber(Settings.WakeHealth) or 100)
    ))
    ActiveUnconscious[playerSource] = nil
    LastEmergencyRequests[playerSource] = nil
    broadcastResolved(state, 'automatic_wake')

    player:setMetadata(METADATA_KEY, nil)
    player:setMetadata('health', health)
    player:save(destination.coords)
    TriggerClientEvent('ms_medic:client:autoWake', playerSource, {
        coords = destination.coords,
        city = destination.label,
        health = health
    })
    TriggerEvent('MS_Medic:server:autoWake', {
        playerSource = playerSource,
        characterId = player.characterId,
        city = destination.label,
        coords = destination.coords,
        emergencyCalled = state.emergencyCalled == true
    })
    debugLog('%s (%d) wacht automatisch in %s auf.', player:getName(), playerSource, destination.label)
    return true
end

local function activateState(playerSource, player, state, forceDead)
    state.playerSource = playerSource
    state.characterId = player.characterId
    state.coords = serializableCoords(state.coords)
        or playerCoords(playerSource)
        or serializableCoords(player.coords)
    state.startedAt = math.floor(tonumber(state.startedAt) or os.time())
    state.deadlineAt = math.floor(tonumber(state.deadlineAt) or os.time())
    state.emergencyCalled = state.emergencyCalled == true
    state.incidentId = tostring(state.incidentId or '')
    if state.incidentId == '' then
        Sequence = Sequence + 1
        state.incidentId = ('%d:%d:%d'):format(player.characterId, state.startedAt, Sequence)
    end
    state.graceUntil = os.time() + 4
    state.nextSyncAt = os.time() + math.max(
        5,
        math.floor(tonumber(Settings.SyncIntervalSeconds) or 30)
    )
    ActiveUnconscious[playerSource] = state
    TriggerClientEvent(
        'ms_medic:client:unconsciousStart',
        playerSource,
        statePayload(state, forceDead)
    )
    if state.emergencyCalled then broadcastEmergency(state) end
    return state
end

local function restoreStoredState(playerSource, player)
    if not player or ActiveUnconscious[playerSource] then return false end
    local stored = player.metadata and player.metadata[METADATA_KEY]
    if type(stored) ~= 'table' then return false end

    local state = activateState(playerSource, player, {
        incidentId = stored.incidentId,
        startedAt = stored.startedAt,
        deadlineAt = stored.deadlineAt,
        emergencyCalled = stored.emergencyCalled,
        coords = stored.coords
    }, true)
    if state.deadlineAt <= os.time() then autoWake(playerSource, state) end
    return true
end

local function beginUnconscious(playerSource)
    local player = getPlayer(playerSource)
    if Settings.Enabled ~= true or not player then return end
    if ActiveUnconscious[playerSource] then
        return TriggerClientEvent(
            'ms_medic:client:unconsciousStart',
            playerSource,
            statePayload(ActiveUnconscious[playerSource], false)
        )
    end
    if restoreStoredState(playerSource, player) then return end
    if not playerIsDead(playerSource) or isFinalDeath(playerSource) then
        return TriggerClientEvent('ms_medic:client:unconsciousStop', playerSource, {
            reason = isFinalDeath(playerSource) and 'permadeath' or 'not_dead'
        })
    end

    Sequence = Sequence + 1
    if Sequence > 2147483647 then Sequence = 1 end
    local startedAt = os.time()
    local state = {
        playerSource = playerSource,
        characterId = player.characterId,
        incidentId = ('%d:%d:%d'):format(player.characterId, startedAt, Sequence),
        startedAt = startedAt,
        deadlineAt = startedAt + math.max(
            60,
            math.floor(tonumber(Settings.InitialSeconds) or 600)
        ),
        emergencyCalled = false,
        coords = playerCoords(playerSource)
    }
    saveState(player, state)
    activateState(playerSource, player, state, false)
end

RegisterNetEvent('ms_medic:server:reportUnconscious', function()
    local playerSource = source
    SetTimeout(math.max(0, math.floor(tonumber(Settings.DetectionDelayMs) or 1500)), function()
        if getPlayer(playerSource) then beginUnconscious(playerSource) end
    end)
end)

RegisterNetEvent('ms_medic:server:emergencyCall', function()
    local playerSource = source
    local state = ActiveUnconscious[playerSource]
    local player = getPlayer(playerSource)
    if not state or not player or state.emergencyCalled == true then return end

    local nowMs = GetGameTimer()
    if LastEmergencyRequests[playerSource]
        and nowMs - LastEmergencyRequests[playerSource] < 1000
    then
        return
    end
    LastEmergencyRequests[playerSource] = nowMs
    if not playerIsDead(playerSource) or isFinalDeath(playerSource) then return end

    state.emergencyCalled = true
    state.deadlineAt = os.time() + math.max(
        60,
        math.floor(tonumber(Settings.EmergencySeconds) or 1200)
    )
    state.coords = playerCoords(playerSource) or state.coords
    state.nextSyncAt = os.time() + math.max(
        5,
        math.floor(tonumber(Settings.SyncIntervalSeconds) or 30)
    )
    saveState(player, state)
    TriggerClientEvent('ms_medic:client:unconsciousUpdate', playerSource, statePayload(state, false))
    notify(playerSource, 'Dein Notruf wurde an alle Medics übermittelt.')
    broadcastEmergency(state)
    TriggerEvent('MS_Medic:server:emergencyCalled', emergencyPayload(state))
end)

RegisterNetEvent('ms_medic:server:reportConscious', function()
    local playerSource = source
    if ActiveUnconscious[playerSource] and not playerIsDead(playerSource) then
        removeState(playerSource, 'conscious', true, true)
    end
end)

AddEventHandler('MS_Medic:server:playerRevived', function(playerSource, reason)
    removeState(tonumber(playerSource), tostring(reason or 'revived'), true, true)
end)

local function syncCallsToMedic(medicSource)
    if not isMedic(medicSource) then
        return TriggerClientEvent('ms_medic:client:clearEmergencyCalls', medicSource)
    end
    for _, state in pairs(ActiveUnconscious) do
        if state.emergencyCalled == true then
            TriggerClientEvent('ms_medic:client:emergencyCall', medicSource, emergencyPayload(state))
        end
    end
end

AddEventHandler('mscore:server:playerLoaded', function(playerSource, player)
    SetTimeout(1000, function()
        local current = getPlayer(playerSource)
        if not current or current.characterId ~= player.characterId then return end
        if not isFinalDeath(playerSource) then restoreStoredState(playerSource, current) end
        syncCallsToMedic(playerSource)
    end)
end)

AddEventHandler('mscore:server:jobChanged', function(playerSource)
    syncCallsToMedic(tonumber(playerSource))
end)

local function disconnectPlayer(playerSource)
    playerSource = tonumber(playerSource)
    local state = playerSource and ActiveUnconscious[playerSource]
    if not state then return end
    ActiveUnconscious[playerSource] = nil
    LastEmergencyRequests[playerSource] = nil
    broadcastResolved(state, 'offline')
end

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    disconnectPlayer(playerSource)
end)

AddEventHandler('playerDropped', function()
    disconnectPlayer(source)
end)

CreateThread(function()
    while true do
        Wait(math.max(250, math.floor(tonumber(Settings.ServerCheckIntervalMs) or 1000)))
        local now = os.time()
        local sources = {}
        for playerSource in pairs(ActiveUnconscious) do sources[#sources + 1] = playerSource end

        for _, playerSource in ipairs(sources) do
            local state = ActiveUnconscious[playerSource]
            local player = state and getPlayer(playerSource)
            if state and not player then
                disconnectPlayer(playerSource)
            elseif state and isFinalDeath(playerSource) then
                removeState(playerSource, 'permadeath', true, true)
            elseif state and now >= state.deadlineAt then
                autoWake(playerSource, state)
            elseif state and now > (state.graceUntil or 0) and not playerIsDead(playerSource) then
                removeState(playerSource, 'conscious', true, true)
            elseif state and now >= (state.nextSyncAt or 0) then
                state.nextSyncAt = now + math.max(
                    5,
                    math.floor(tonumber(Settings.SyncIntervalSeconds) or 30)
                )
                TriggerClientEvent(
                    'ms_medic:client:unconsciousUpdate',
                    playerSource,
                    statePayload(state, false)
                )
            end
        end
    end
end)

function GetUnconsciousState(playerSource)
    playerSource = tonumber(playerSource)
    local state = playerSource and ActiveUnconscious[playerSource]
    return state and statePayload(state, false) or nil
end

function IsUnconscious(playerSource)
    return GetUnconsciousState(playerSource) ~= nil
end

exports('GetUnconsciousState', GetUnconsciousState)
exports('IsUnconscious', IsUnconscious)
