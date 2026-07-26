local Config = MSRestrictedAreasConfig
local Geometry = MSRestrictedAreasGeometry
local PlayerStates = {}
local LastStateRequests = {}

local function debugLog(message, ...)
    if Config.Debug ~= true then return end
    print(('[MS_RestrictedAreas] ' .. message):format(...))
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function hasBypass(playerSource)
    local permission = tostring(Config.BypassAce or '')
    return permission ~= '' and IsPlayerAceAllowed(tostring(playerSource), permission)
end

local function jobRuleAllows(rule, grade)
    grade = math.floor(tonumber(grade) or 0)
    if rule == true then return true end
    if type(rule) == 'number' then return grade >= math.floor(rule) end
    if type(rule) ~= 'table' then return false end

    local minimum = math.floor(tonumber(rule.MinGrade) or 0)
    local maximum = tonumber(rule.MaxGrade)
    return grade >= minimum and (not maximum or grade <= math.floor(maximum))
end

local function isAuthorized(playerSource, player, zone)
    if not player or not zone then return false end
    if hasBypass(playerSource) then return true end
    if tostring(zone.Mode or 'jobs'):lower() == 'locked' then return false end

    local allowedJobs = type(zone.AllowedJobs) == 'table' and zone.AllowedJobs or {}
    return jobRuleAllows(allowedJobs[player.job], player.jobGrade)
end

local function payloadFor(zone, authorized)
    if not zone then return nil end
    return {
        id = zone.Id,
        label = zone.Label or zone.Id,
        mode = tostring(zone.Mode or 'jobs'):lower(),
        authorized = authorized == true,
        deniedMessage = zone.DeniedMessage,
        lockedMessage = zone.LockedMessage
    }
end

local function statesMatch(first, second)
    if not first or not second then return first == second end
    return first.id == second.id
        and first.authorized == second.authorized
        and first.mode == second.mode
end

local function setPlayerState(playerSource, state)
    local old = PlayerStates[playerSource]
    if statesMatch(old, state) then return end
    PlayerStates[playerSource] = state
    TriggerClientEvent('ms_restrictedareas:client:zoneState', playerSource, state)

    if state then
        debugLog(
            'Spieler %d betritt %s (Modus=%s, erlaubt=%s).',
            playerSource,
            state.id,
            state.mode,
            tostring(state.authorized)
        )
    elseif old then
        debugLog('Spieler %d verlässt %s.', playerSource, old.id)
    end
end

function RefreshPlayerArea(playerSource)
    playerSource = tonumber(playerSource)
    local player = playerSource and getPlayer(playerSource)
    if not player then
        if playerSource then setPlayerState(playerSource, nil) end
        return nil
    end

    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then
        setPlayerState(playerSource, nil)
        return nil
    end

    local zone = Geometry.FindZone(GetEntityCoords(ped))
    local state = zone and payloadFor(zone, isAuthorized(playerSource, player, zone)) or nil
    setPlayerState(playerSource, state)
    return state
end

function GetPlayerArea(playerSource)
    playerSource = tonumber(playerSource)
    local state = playerSource and PlayerStates[playerSource]
    if not state then return nil end
    return {
        id = state.id,
        label = state.label,
        mode = state.mode,
        authorized = state.authorized
    }
end

function IsPlayerAreaAuthorized(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource or not getPlayer(playerSource) then return false end
    local state = RefreshPlayerArea(playerSource)
    return not state or state.authorized == true
end

RegisterNetEvent('ms_restrictedareas:server:requestState', function()
    local playerSource = source
    local now = GetGameTimer()
    if LastStateRequests[playerSource] and now - LastStateRequests[playerSource] < 1000 then return end
    LastStateRequests[playerSource] = now
    RefreshPlayerArea(playerSource)
end)

AddEventHandler('mscore:server:playerLoaded', function(playerSource)
    SetTimeout(500, function()
        if getPlayer(playerSource) then RefreshPlayerArea(playerSource) end
    end)
end)

AddEventHandler('mscore:server:jobChanged', function(playerSource)
    RefreshPlayerArea(playerSource)
end)

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    playerSource = tonumber(playerSource)
    if playerSource then
        PlayerStates[playerSource] = nil
        LastStateRequests[playerSource] = nil
        TriggerClientEvent('ms_restrictedareas:client:zoneState', playerSource, nil)
    end
end)

AddEventHandler('playerDropped', function()
    PlayerStates[source] = nil
    LastStateRequests[source] = nil
end)

CreateThread(function()
    Wait(1000)
    while true do
        for playerSource in pairs(exports.MSCore:GetPlayers()) do
            RefreshPlayerArea(playerSource)
        end
        Wait(math.max(250, math.floor(tonumber(Config.ServerCheckIntervalMs) or 750)))
    end
end)

CreateThread(function()
    local enabled, locked = 0, 0
    local identifiers = {}
    for index, zone in ipairs(Config.Zones or {}) do
        if zone.Enabled == true then
            enabled = enabled + 1
            local id = type(zone.Id) == 'string' and zone.Id or ''
            if id == '' then
                print(('[MS_RestrictedAreas] WARNUNG: Gebiet %d besitzt keine gültige Id.'):format(index))
            elseif identifiers[id] then
                print(('[MS_RestrictedAreas] WARNUNG: Doppelte Gebiets-Id %s.'):format(id))
            end
            identifiers[id] = true
            if tostring(zone.Mode or 'jobs'):lower() == 'locked' then locked = locked + 1 end
        end
    end
    print(('[MS_RestrictedAreas] %d aktive Gebiete geladen, davon %d komplett gesperrt.'):format(
        enabled,
        locked
    ))
end)

exports('GetPlayerArea', GetPlayerArea)
exports('IsPlayerAreaAuthorized', IsPlayerAreaAuthorized)
exports('RefreshPlayerArea', RefreshPlayerArea)
