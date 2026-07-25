local Config = MSJailConfig
local ActiveJails = {}
local LastReturns = {}
local DatabaseReady = false

local function debugLog(message, ...)
    if Config.Debug ~= true then return end
    print(('[MS_Jail] ' .. message):format(...))
end

local function notify(playerSource, message)
    if playerSource == 0 then
        print(('[MS_Jail] %s'):format(message))
        return
    end
    TriggerClientEvent('frontier:client:notify', playerSource, message)
end

local function getPlayer(playerSource)
    return exports.frontier_core:GetPlayer(tonumber(playerSource))
end

local function isAdmin(playerSource)
    return playerSource == 0
        or IsPlayerAceAllowed(playerSource, tostring(Config.AdminAce or 'frontier.admin.jail'))
end

local function cleanReason(value)
    value = type(value) == 'string' and value or ''
    value = value:gsub('[%c]', ' '):match('^%s*(.-)%s*$') or ''
    local maximum = math.max(1, math.floor(tonumber(Config.MaximumReasonLength) or 180))
    if #value > maximum then value = value:sub(1, maximum) end
    if value == '' then value = tostring(Config.DefaultReason or 'Keine Begründung angegeben.') end
    return value
end

local function sentenceMinutes(value)
    value = tonumber(value)
    local minimum = math.max(1, math.floor(tonumber(Config.MinimumSentenceMinutes) or 1))
    local maximum = math.max(minimum, math.floor(tonumber(Config.MaximumSentenceMinutes) or 1440))
    if not value or value % 1 ~= 0 or value < minimum or value > maximum then return nil end
    return math.floor(value)
end

local function coordsPayload(coords)
    return {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0,
        w = tonumber(coords.w) or 0.0
    }
end

local function cellFor(characterId)
    local cells = type(Config.CellSpawns) == 'table' and Config.CellSpawns or {}
    if #cells < 1 then return nil end
    local index = ((math.max(1, math.floor(tonumber(characterId) or 1)) - 1) % #cells) + 1
    return cells[index], index
end

local function remainingSeconds(state)
    return math.max(0, math.floor((tonumber(state and state.releaseAt) or 0) - os.time()))
end

local function statePayload(state)
    if not state then return nil end
    return {
        characterId = state.characterId,
        reason = state.reason,
        jailedBy = state.jailedBy,
        startedAt = state.startedAt,
        releaseAt = state.releaseAt,
        remainingSeconds = remainingSeconds(state),
        cell = coordsPayload(state.cell),
        cellIndex = state.cellIndex
    }
end

local function createTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_jail_sentences (
            character_id BIGINT UNSIGNED NOT NULL,
            jailed_by VARCHAR(100) NOT NULL,
            reason VARCHAR(180) NOT NULL,
            started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            release_at TIMESTAMP NOT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (character_id),
            KEY idx_ms_jail_release (release_at),
            CONSTRAINT fk_ms_jail_character
                FOREIGN KEY (character_id) REFERENCES frontier_characters(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

local function deleteSentence(characterId)
    if not DatabaseReady then return false end
    MySQL.update.await('DELETE FROM ms_jail_sentences WHERE character_id = ?', {
        tonumber(characterId)
    })
    return true
end

local function persistSentence(state)
    if not DatabaseReady then return false end
    MySQL.update.await([[
        INSERT INTO ms_jail_sentences
            (character_id, jailed_by, reason, started_at, release_at)
        VALUES (?, ?, ?, FROM_UNIXTIME(?), FROM_UNIXTIME(?))
        ON DUPLICATE KEY UPDATE
            jailed_by = VALUES(jailed_by),
            reason = VALUES(reason),
            started_at = VALUES(started_at),
            release_at = VALUES(release_at),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        state.characterId,
        state.jailedBy,
        state.reason,
        state.startedAt,
        state.releaseAt
    })
    return true
end

local function actorLabel(actorSource)
    actorSource = tonumber(actorSource)
    if actorSource == 0 then return 'Konsole' end
    local actor = actorSource and getPlayer(actorSource)
    return actor and actor:getName()
        or (actorSource and GetPlayerName(actorSource))
        or 'System'
end

local function teleportAndSave(playerSource, player, coords, eventName, payload)
    local position = coordsPayload(coords)
    player:save(position)
    TriggerClientEvent(eventName, playerSource, payload, position)
end

local function releaseInternal(playerSource, releaseReason, actorSource)
    playerSource = tonumber(playerSource)
    local player = playerSource and getPlayer(playerSource)
    local state = playerSource and ActiveJails[playerSource]
    if not player or not state then return false, 'Spieler ist nicht inhaftiert.' end
    if not DatabaseReady then return false, 'Haftdatenbank ist noch nicht bereit.' end

    deleteSentence(state.characterId)
    ActiveJails[playerSource] = nil
    LastReturns[playerSource] = nil

    local reason = cleanReason(releaseReason or 'Haftzeit beendet.')
    local releaseCoords = Config.ReleaseCoords
    teleportAndSave(playerSource, player, releaseCoords, 'ms_jail:client:released', {
        reason = reason
    })

    notify(playerSource, reason)
    print(('[MS_Jail] %s entließ %s (%d), Charakter #%d. Grund: %s'):format(
        actorLabel(actorSource),
        player:getName(),
        playerSource,
        tonumber(state.characterId) or 0,
        reason
    ))
    TriggerEvent('ms_jail:server:released', playerSource, state.characterId, reason, actorSource)
    return true
end

local function jailInternal(playerSource, minutes, reason, actorSource)
    playerSource = tonumber(playerSource)
    minutes = sentenceMinutes(minutes)
    local player = playerSource and getPlayer(playerSource)
    if not player then return false, 'Spieler hat keinen aktiven Charakter.' end
    if not DatabaseReady then return false, 'Haftdatenbank ist noch nicht bereit.' end
    if not minutes then
        return false, ('Haftzeit muss zwischen %d und %d Minuten liegen.'):format(
            math.max(1, math.floor(tonumber(Config.MinimumSentenceMinutes) or 1)),
            math.max(1, math.floor(tonumber(Config.MaximumSentenceMinutes) or 1440))
        )
    end

    local cell, cellIndex = cellFor(player.characterId)
    if not cell then return false, 'Es ist keine Sisika-Zelle konfiguriert.' end
    local now = os.time()
    local state = {
        characterId = player.characterId,
        reason = cleanReason(reason),
        jailedBy = actorLabel(actorSource),
        startedAt = now,
        releaseAt = now + minutes * 60,
        cell = cell,
        cellIndex = cellIndex
    }

    persistSentence(state)
    ActiveJails[playerSource] = state
    LastReturns[playerSource] = nil
    teleportAndSave(
        playerSource,
        player,
        cell,
        'ms_jail:client:jailed',
        statePayload(state)
    )

    notify(playerSource, ('Du wurdest für %d Minuten nach Sisika gebracht.'):format(minutes))
    print(('[MS_Jail] %s inhaftierte %s (%d), Charakter #%d, für %d Minuten. Grund: %s'):format(
        state.jailedBy,
        player:getName(),
        playerSource,
        tonumber(player.characterId) or 0,
        minutes,
        state.reason
    ))
    TriggerEvent('ms_jail:server:jailed', playerSource, statePayload(state), actorSource)
    return true, statePayload(state)
end

local function loadSentence(playerSource, player)
    if not DatabaseReady then return false end
    playerSource = tonumber(playerSource)
    player = player or getPlayer(playerSource)
    if not playerSource or not player then return false end

    local row = MySQL.single.await([[
        SELECT jailed_by, reason,
               UNIX_TIMESTAMP(started_at) AS started_unix,
               UNIX_TIMESTAMP(release_at) AS release_unix
        FROM ms_jail_sentences
        WHERE character_id = ?
    ]], { player.characterId })

    if not row then
        ActiveJails[playerSource] = nil
        TriggerClientEvent('ms_jail:client:reset', playerSource)
        return false
    end

    local releaseAt = tonumber(row.release_unix) or 0
    if releaseAt <= os.time() then
        deleteSentence(player.characterId)
        ActiveJails[playerSource] = nil
        teleportAndSave(
            playerSource,
            player,
            Config.ReleaseCoords,
            'ms_jail:client:released',
            { reason = 'Deine Haftzeit ist während deiner Abwesenheit abgelaufen.' }
        )
        notify(playerSource, 'Deine Haftzeit ist während deiner Abwesenheit abgelaufen.')
        return false
    end

    local cell, cellIndex = cellFor(player.characterId)
    if not cell then return false end
    local state = {
        characterId = player.characterId,
        reason = cleanReason(row.reason),
        jailedBy = tostring(row.jailed_by or 'System'),
        startedAt = tonumber(row.started_unix) or os.time(),
        releaseAt = releaseAt,
        cell = cell,
        cellIndex = cellIndex
    }
    ActiveJails[playerSource] = state
    LastReturns[playerSource] = nil
    teleportAndSave(
        playerSource,
        player,
        cell,
        'ms_jail:client:jailed',
        statePayload(state)
    )
    debugLog('Haftstatus für %d / Charakter %d geladen.', playerSource, player.characterId)
    return true
end

function GetJailState(playerSource)
    playerSource = tonumber(playerSource)
    return playerSource and statePayload(ActiveJails[playerSource]) or nil
end

function IsJailed(playerSource)
    playerSource = tonumber(playerSource)
    local state = playerSource and ActiveJails[playerSource]
    return state ~= nil and remainingSeconds(state) > 0
end

function JailPlayer(playerSource, minutes, reason, actorSource)
    return jailInternal(playerSource, minutes, reason, actorSource)
end

function ReleasePlayer(playerSource, reason, actorSource)
    return releaseInternal(playerSource, reason, actorSource)
end

exports('GetJailState', GetJailState)
exports('IsJailed', IsJailed)
exports('JailPlayer', JailPlayer)
exports('ReleasePlayer', ReleasePlayer)

RegisterCommand(Config.JailCommand or 'jail', function(playerSource, args)
    if not isAdmin(playerSource) then return notify(playerSource, 'Keine Berechtigung.') end
    local targetSource = tonumber(args[1])
    local minutes = tonumber(args[2])
    local reason = table.concat(args, ' ', 3)
    if not targetSource or not minutes then
        return notify(playerSource, 'Verwendung: jail <Server-ID> <Minuten> [Grund]')
    end
    local success, result = jailInternal(targetSource, minutes, reason, playerSource)
    if not success then return notify(playerSource, result) end
    notify(playerSource, ('Spieler %d wurde in Sisika inhaftiert.'):format(targetSource))
end, false)

RegisterCommand(Config.UnjailCommand or 'unjail', function(playerSource, args)
    if not isAdmin(playerSource) then return notify(playerSource, 'Keine Berechtigung.') end
    local targetSource = tonumber(args[1])
    if not targetSource then
        return notify(playerSource, 'Verwendung: unjail <Server-ID> [Grund]')
    end
    local reason = table.concat(args, ' ', 2)
    if reason == '' then reason = 'Du wurdest vorzeitig aus Sisika entlassen.' end
    local success, message = releaseInternal(targetSource, reason, playerSource)
    if not success then return notify(playerSource, message) end
    notify(playerSource, ('Spieler %d wurde entlassen.'):format(targetSource))
end, false)

RegisterCommand(Config.StatusCommand or 'jailstatus', function(playerSource, args)
    local targetSource = tonumber(args[1])
    if playerSource == 0 and not targetSource then
        return notify(playerSource, 'Verwendung: jailstatus <Server-ID>')
    end
    if not targetSource then targetSource = playerSource end
    if targetSource ~= playerSource and not isAdmin(playerSource) then
        return notify(playerSource, 'Keine Berechtigung für den Haftstatus anderer Spieler.')
    end

    local state = ActiveJails[targetSource]
    if not state then return notify(playerSource, 'Keine aktive Inhaftierung.') end
    local seconds = remainingSeconds(state)
    local minutes = math.floor(seconds / 60)
    notify(playerSource, ('Sisika: %d:%02d Minuten verbleiben. Grund: %s'):format(
        minutes,
        seconds % 60,
        state.reason
    ))
end, false)

AddEventHandler('frontier:server:playerLoaded', function(playerSource, player)
    if DatabaseReady then
        loadSentence(playerSource, player)
    else
        SetTimeout(1000, function()
            if DatabaseReady then loadSentence(playerSource, getPlayer(playerSource)) end
        end)
    end
end)

local function clearSource(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource then return end
    ActiveJails[playerSource] = nil
    LastReturns[playerSource] = nil
end

AddEventHandler('frontier:server:playerUnloaded', clearSource)
AddEventHandler('playerDropped', function()
    clearSource(source)
end)

MySQL.ready(function()
    createTable()
    DatabaseReady = true
    for playerSource, player in pairs(exports.frontier_core:GetPlayers() or {}) do
        loadSentence(tonumber(playerSource), player)
    end
    print('[MS_Jail] Datenbank und persistente Haftverwaltung bereit.')
end)

CreateThread(function()
    while true do
        local boundary = type(Config.Boundary) == 'table' and Config.Boundary or {}
        Wait(math.max(500, math.floor(tonumber(boundary.CheckIntervalMs) or 2000)))
        local now = os.time()
        local gameTimer = GetGameTimer()

        for playerSource, state in pairs(ActiveJails) do
            local player = getPlayer(playerSource)
            if not player or player.characterId ~= state.characterId then
                clearSource(playerSource)
            elseif remainingSeconds(state) <= 0 then
                releaseInternal(playerSource, 'Deine Haftzeit ist beendet.', 0)
            else
                local ped = GetPlayerPed(playerSource)
                if ped and ped ~= 0 and boundary.Center then
                    local coords = GetEntityCoords(ped)
                    local dx = coords.x - boundary.Center.x
                    local dy = coords.y - boundary.Center.y
                    local dz = coords.z - boundary.Center.z
                    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
                    local radius = math.max(10.0, tonumber(boundary.Radius) or 260.0)
                    local cooldown = math.max(500, math.floor(
                        tonumber(boundary.ReturnCooldownMs) or 3500
                    ))
                    if distance > radius
                        and (not LastReturns[playerSource]
                            or gameTimer - LastReturns[playerSource] >= cooldown) then
                        LastReturns[playerSource] = gameTimer
                        TriggerClientEvent(
                            'ms_jail:client:returnToCell',
                            playerSource,
                            coordsPayload(state.cell),
                            statePayload(state)
                        )
                        notify(playerSource, 'Fluchtversuch verhindert. Du wurdest zurückgebracht.')
                    end
                end
            end
        end
    end
end)
