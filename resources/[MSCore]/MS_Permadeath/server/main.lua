local Config = MSPermadeathConfig
local DatabaseReady = false
local SourceCharacters = {}
local PendingFinales = {}
local FinalCharacters = {}
local ProcessingCharacters = {}
local LastDeathReports = {}
local FinaleSequence = 0

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function integer(value, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.floor(value)
end

local function notify(playerSource, message)
    playerSource = tonumber(playerSource) or 0
    if playerSource == 0 then
        print(('[MS_Permadeath] %s'):format(message))
        return
    end
    TriggerClientEvent('mscore:client:notify', playerSource, message)
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function hasAdminPermission(playerSource)
    playerSource = tonumber(playerSource) or 0
    return playerSource == 0
        or IsPlayerAceAllowed(playerSource, Config.AdminAce)
        or IsPlayerAceAllowed(playerSource, 'mscore.admin')
end

local function thresholdReached(risk)
    local threshold = clamp(integer(Config.ThresholdPercent, 60), 0, 100)
    if Config.TriggerAtOrAbove == true then return risk >= threshold end
    return risk > threshold
end

local function ensureState(characterId)
    if not DatabaseReady or not characterId then return false end
    MySQL.insert.await([[
        INSERT IGNORE INTO ms_permadeath_states (character_id)
        VALUES (?)
    ]], { characterId })
    return true
end

local function getState(characterId)
    if not ensureState(characterId) then return nil end
    return MySQL.single.await([[
        SELECT character_id, risk_percent, recorded_deaths, last_increase,
               last_cause, death_active, pending_finale, permadead, last_death_at,
               UNIX_TIMESTAMP(last_death_at) AS last_death_unix,
               permadeath_at
        FROM ms_permadeath_states
        WHERE character_id = ?
    ]], { characterId })
end

local function riskPayload(row)
    if not row then return nil end
    return {
        characterId = tonumber(row.character_id),
        risk = clamp(integer(row.risk_percent, 0), 0, 100),
        deaths = math.max(0, integer(row.recorded_deaths, 0)),
        lastIncrease = clamp(integer(row.last_increase, 0), 0, 100),
        pending = tonumber(row.pending_finale) == 1,
        permadead = tonumber(row.permadead) == 1,
        threshold = clamp(integer(Config.ThresholdPercent, 60), 0, 100)
    }
end

local function finaleToken(playerSource, characterId)
    FinaleSequence = FinaleSequence + 1
    if FinaleSequence > 2147483647 then FinaleSequence = 1 end
    return ('%d:%d:%d:%d:%d'):format(
        tonumber(playerSource),
        tonumber(characterId),
        os.time(),
        FinaleSequence,
        math.random(100000, 999999)
    )
end

local function finishPermanentDeath(playerSource, characterId, reason)
    characterId = tonumber(characterId)
    playerSource = tonumber(playerSource)
    if not characterId then return false end

    local success = MySQL.transaction.await({
        {
            query = [[
                UPDATE ms_permadeath_states
                SET pending_finale = 0,
                    permadead = 1,
                    permadeath_at = COALESCE(permadeath_at, CURRENT_TIMESTAMP),
                    updated_at = CURRENT_TIMESTAMP
                WHERE character_id = ?
            ]],
            values = { characterId }
        },
        {
            query = [[
                UPDATE mscore_characters
                SET is_deleted = 1
                WHERE id = ?
            ]],
            values = { characterId }
        }
    })

    if not success then
        print(('[MS_Permadeath] Finalisierung für Charakter %d fehlgeschlagen.'):format(characterId))
        return false
    end

    FinalCharacters[characterId] = true
    if playerSource and PendingFinales[playerSource]
        and PendingFinales[playerSource].characterId == characterId
    then
        PendingFinales[playerSource] = nil
    end

    TriggerEvent('ms_permadeath:server:characterPermanentlyDead', {
        source = playerSource,
        characterId = characterId,
        reason = tostring(reason or 'finale')
    })

    if not playerSource then
        print(('[MS_Permadeath] Charakter %d wurde permanent gesperrt (%s).'):format(
            characterId,
            tostring(reason or 'finale')
        ))
        return true
    end

    local player = getPlayer(playerSource)
    if not player or tonumber(player.characterId) ~= characterId then return true end

    TriggerClientEvent('ms_permadeath:client:finalized', playerSource)
    SetTimeout(700, function()
        local current = getPlayer(playerSource)
        if current and tonumber(current.characterId) == characterId then
            exports.MSCore:LogoutPlayer(playerSource)
        end
    end)
    return true
end

local function beginFinale(playerSource, characterId, state)
    playerSource = tonumber(playerSource)
    characterId = tonumber(characterId)
    if not playerSource or not characterId or not GetPlayerName(playerSource) then return false end

    local current = getPlayer(playerSource)
    if not current or tonumber(current.characterId) ~= characterId then return false end
    if PendingFinales[playerSource] then return true end

    local token = finaleToken(playerSource, characterId)
    PendingFinales[playerSource] = {
        token = token,
        characterId = characterId
    }
    FinalCharacters[characterId] = true

    TriggerClientEvent('ms_permadeath:client:startFinale', playerSource, {
        token = token,
        characterId = characterId,
        characterName = current:getName(),
        risk = clamp(integer(state and state.risk_percent, 100), 0, 100),
        increase = clamp(integer(state and state.last_increase, 0), 0, 100),
        threshold = clamp(integer(Config.ThresholdPercent, 60), 0, 100),
        test = false
    })

    local timeout = math.max(10000, integer(Config.Finale.ServerTimeoutMs, 90000))
    SetTimeout(timeout, function()
        local pending = PendingFinales[playerSource]
        if pending and pending.token == token and pending.characterId == characterId then
            finishPermanentDeath(playerSource, characterId, 'timeout')
        end
    end)
    return true
end

local function serverPedIsDead(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return false end
    local health = integer(GetEntityHealth(ped), 200)
    return health <= integer(Config.ServerDeathHealth, 0)
end

local function sanitizeCause(value)
    value = tostring(value or 'unknown'):lower():gsub('[^%w_%-]', '')
    if value == '' then value = 'unknown' end
    return value:sub(1, 32)
end

local function recordDeath(playerSource, rawCause)
    if Config.Enabled ~= true or not DatabaseReady then return end
    playerSource = tonumber(playerSource)
    local player = playerSource and getPlayer(playerSource)
    if not player or not serverPedIsDead(playerSource) then return end

    local characterId = tonumber(player.characterId)
    if not characterId or FinalCharacters[characterId] or ProcessingCharacters[characterId] then return end

    local now = os.time()
    local cooldown = math.max(1, integer(Config.DeathReportCooldownSeconds, 20))
    if LastDeathReports[characterId] and now - LastDeathReports[characterId] < cooldown then return end

    ProcessingCharacters[characterId] = true
    local ok, err = pcall(function()
        local row = getState(characterId)
        if not row then return end
        if tonumber(row.permadead) == 1 then
            FinalCharacters[characterId] = true
            return
        end
        if tonumber(row.pending_finale) == 1 then
            FinalCharacters[characterId] = true
            beginFinale(playerSource, characterId, row)
            return
        end
        if tonumber(row.death_active) == 1 then return end
        local persistedDeath = tonumber(row.last_death_unix)
        if persistedDeath and now - persistedDeath < cooldown then
            LastDeathReports[characterId] = persistedDeath
            return
        end

        local minimum = clamp(integer(Config.IncreaseMin, 1), 0, 100)
        local maximum = clamp(integer(Config.IncreaseMax, 3), minimum, 100)
        local increase = math.random(minimum, maximum)
        local oldRisk = clamp(integer(row.risk_percent, 0), 0, 100)
        local newRisk = clamp(oldRisk + increase, 0, 100)
        local cause = sanitizeCause(rawCause)
        local final = thresholdReached(newRisk)
        local success

        if final then
            success = MySQL.transaction.await({
                {
                    query = [[
                        UPDATE ms_permadeath_states
                        SET risk_percent = ?,
                            recorded_deaths = recorded_deaths + 1,
                            last_increase = ?,
                            last_cause = ?,
                            last_death_at = CURRENT_TIMESTAMP,
                            death_active = 1,
                            pending_finale = 1,
                            updated_at = CURRENT_TIMESTAMP
                        WHERE character_id = ? AND permadead = 0 AND pending_finale = 0
                    ]],
                    values = { newRisk, increase, cause, characterId }
                },
                {
                    query = [[
                        UPDATE mscore_characters
                        SET is_deleted = 1
                        WHERE id = ? AND is_deleted = 0
                    ]],
                    values = { characterId }
                }
            })
        else
            success = MySQL.update.await([[
                UPDATE ms_permadeath_states
                SET risk_percent = ?,
                    recorded_deaths = recorded_deaths + 1,
                    last_increase = ?,
                    last_cause = ?,
                    last_death_at = CURRENT_TIMESTAMP,
                    death_active = 1,
                    updated_at = CURRENT_TIMESTAMP
                WHERE character_id = ? AND permadead = 0 AND pending_finale = 0
            ]], { newRisk, increase, cause, characterId }) == 1
        end

        if not success then
            notify(playerSource, 'Das Todesrisiko konnte nicht gespeichert werden.')
            return
        end

        LastDeathReports[characterId] = now
        row.risk_percent = newRisk
        row.last_increase = increase
        row.recorded_deaths = integer(row.recorded_deaths, 0) + 1

        if final then
            row.pending_finale = 1
            FinalCharacters[characterId] = true
            print(('[MS_Permadeath] %s (%d) überschreitet mit %d %% den Schwellwert.'):format(
                player:getName(),
                characterId,
                newRisk
            ))
            beginFinale(playerSource, characterId, row)
        else
            TriggerClientEvent('ms_permadeath:client:riskUpdated', playerSource, {
                risk = newRisk,
                increase = increase,
                threshold = clamp(integer(Config.ThresholdPercent, 60), 0, 100)
            })
        end
    end)
    ProcessingCharacters[characterId] = nil

    if not ok then
        print(('[MS_Permadeath] Todesverarbeitung für Charakter %d fehlgeschlagen: %s'):format(
            characterId,
            tostring(err)
        ))
    end
end

RegisterNetEvent('ms_permadeath:server:reportDeath', function(cause)
    recordDeath(source, cause)
end)

RegisterNetEvent('ms_permadeath:server:reportAlive', function()
    local playerSource = tonumber(source)
    local player = getPlayer(playerSource)
    if not player or serverPedIsDead(playerSource) or IsFinalDeath(playerSource) then return end

    ensureState(player.characterId)
    MySQL.update.await([[
        UPDATE ms_permadeath_states
        SET death_active = 0, updated_at = CURRENT_TIMESTAMP
        WHERE character_id = ? AND pending_finale = 0 AND permadead = 0
    ]], { player.characterId })
    LastDeathReports[player.characterId] = nil
end)

RegisterNetEvent('ms_permadeath:server:finaleComplete', function(token)
    local playerSource = source
    local pending = PendingFinales[playerSource]
    if not pending or type(token) ~= 'string' or pending.token ~= token then return end

    local player = getPlayer(playerSource)
    if not player or tonumber(player.characterId) ~= pending.characterId then return end
    finishPermanentDeath(playerSource, pending.characterId, 'client_complete')
end)

function IsFinalDeath(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource then return false end
    local pending = PendingFinales[playerSource]
    if pending then return true end
    local player = getPlayer(playerSource)
    return player and FinalCharacters[tonumber(player.characterId)] == true or false
end

function GetRisk(playerSource)
    local player = getPlayer(tonumber(playerSource))
    if not player or not DatabaseReady then return nil end
    return riskPayload(getState(player.characterId))
end

exports('IsFinalDeath', IsFinalDeath)
exports('GetRisk', GetRisk)

local function activeTarget(requester, rawTarget)
    local target = tonumber(rawTarget)
    if not target and requester ~= 0 then target = requester end
    local player = target and getPlayer(target)
    if not player then return nil, nil, 'Kein aktiver Charakter für diese Server-ID.' end
    return target, player
end

RegisterCommand(Config.PlayerRiskCommand or 'deathrisk', function(playerSource)
    if playerSource == 0 then return notify(0, 'Dieser Befehl ist nur ingame verfügbar.') end
    local state = GetRisk(playerSource)
    if not state then return notify(playerSource, 'Das Todesrisiko ist noch nicht verfügbar.') end
    notify(playerSource, ('Permanentes Todesrisiko: %d %% | bestätigte Tode: %d | Schwellwert: %d %%'):format(
        state.risk,
        state.deaths,
        state.threshold
    ))
end, false)

RegisterCommand(Config.AdminCommand or 'permadeath', function(playerSource, args)
    if not hasAdminPermission(playerSource) then
        return notify(playerSource, 'Keine Berechtigung.')
    end

    local action = tostring(args[1] or 'status'):lower()
    if action == 'status' then
        local target, player, targetError = activeTarget(playerSource, args[2])
        if not target then return notify(playerSource, targetError) end
        local state = riskPayload(getState(player.characterId))
        if not state then return notify(playerSource, 'Status konnte nicht geladen werden.') end
        return notify(playerSource, ('%s (%d): Risiko %d %%, Tode %d, letzter Anstieg %d %%, Finale %s'):format(
            player:getName(),
            target,
            state.risk,
            state.deaths,
            state.lastIncrease,
            state.pending and 'ausstehend' or (state.permadead and 'abgeschlossen' or 'nein')
        ))
    end

    if action == 'set' then
        local target, player, targetError = activeTarget(playerSource, args[2])
        if not target then return notify(playerSource, targetError) end
        if IsFinalDeath(target) then return notify(playerSource, 'Der permanente Tod wurde bereits ausgelöst.') end
        local risk = tonumber(args[3])
        if not risk or risk < 0 or risk > 100 or risk % 1 ~= 0 then
            return notify(playerSource, 'Verwendung: permadeath set <Server-ID> <0-100>')
        end
        ensureState(player.characterId)
        MySQL.update.await([[
            UPDATE ms_permadeath_states
            SET risk_percent = ?, updated_at = CURRENT_TIMESTAMP
            WHERE character_id = ? AND permadead = 0 AND pending_finale = 0
        ]], { risk, player.characterId })
        return notify(playerSource, ('Risiko von %s auf %d %% gesetzt. Die Prüfung erfolgt beim nächsten Tod.'):format(
            player:getName(),
            risk
        ))
    end

    if action == 'reset' then
        local target, player, targetError = activeTarget(playerSource, args[2])
        if not target then return notify(playerSource, targetError) end
        if IsFinalDeath(target) then return notify(playerSource, 'Ein ausgelöster permanenter Tod kann ingame nicht zurückgesetzt werden.') end
        ensureState(player.characterId)
        MySQL.update.await([[
            UPDATE ms_permadeath_states
            SET risk_percent = 0,
                recorded_deaths = 0,
                last_increase = 0,
                last_cause = NULL,
                death_active = 0,
                last_death_at = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE character_id = ? AND permadead = 0 AND pending_finale = 0
        ]], { player.characterId })
        LastDeathReports[player.characterId] = nil
        return notify(playerSource, ('Todesrisiko von %s wurde zurückgesetzt.'):format(player:getName()))
    end

    if action == 'testscene' then
        local target, player, targetError = activeTarget(playerSource, args[2])
        if not target then return notify(playerSource, targetError) end
        TriggerClientEvent('ms_permadeath:client:startFinale', target, {
            characterId = player.characterId,
            characterName = player:getName(),
            risk = clamp(integer(Config.ThresholdPercent, 60) + 1, 0, 100),
            increase = 1,
            threshold = clamp(integer(Config.ThresholdPercent, 60), 0, 100),
            test = true
        })
        return notify(playerSource, ('Testszene für %s gestartet; es werden keine Daten geändert.'):format(
            player:getName()
        ))
    end

    notify(playerSource, 'Verwendung: permadeath <status|set|reset|testscene> [Server-ID] [Prozent]')
end, false)

local function loadCharacterState(playerSource, player)
    if not DatabaseReady or not player then return end
    playerSource = tonumber(playerSource)
    local characterId = tonumber(player.characterId)
    if not playerSource or not characterId then return end

    SourceCharacters[playerSource] = characterId
    local row = getState(characterId)
    if not row then return end
    if tonumber(row.permadead) == 1 then
        FinalCharacters[characterId] = true
        finishPermanentDeath(playerSource, characterId, 'state_recovery')
    elseif tonumber(row.pending_finale) == 1 then
        FinalCharacters[characterId] = true
        MySQL.update.await('UPDATE mscore_characters SET is_deleted = 1 WHERE id = ?', { characterId })
        beginFinale(playerSource, characterId, row)
    end
end

AddEventHandler('mscore:server:playerLoaded', function(playerSource, player)
    CreateThread(function()
        local attempts = 0
        while not DatabaseReady and attempts < 50 do
            attempts = attempts + 1
            Wait(100)
        end
        loadCharacterState(playerSource, player)
    end)
end)

AddEventHandler('mscore:server:playerUnloaded', function(playerSource, player)
    playerSource = tonumber(playerSource)
    local characterId = player and tonumber(player.characterId) or SourceCharacters[playerSource]
    local pending = playerSource and PendingFinales[playerSource]
    if pending and pending.characterId == characterId then
        PendingFinales[playerSource] = nil
        TriggerClientEvent('ms_permadeath:client:finalized', playerSource)
        CreateThread(function()
            finishPermanentDeath(nil, characterId, 'character_unloaded')
        end)
    end
    if playerSource then SourceCharacters[playerSource] = nil end
end)

AddEventHandler('playerDropped', function()
    local playerSource = tonumber(source)
    local pending = PendingFinales[playerSource]
    if pending then
        PendingFinales[playerSource] = nil
        CreateThread(function()
            finishPermanentDeath(nil, pending.characterId, 'disconnect')
        end)
    end
    SourceCharacters[playerSource] = nil
end)

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_permadeath_states (
            character_id BIGINT UNSIGNED NOT NULL,
            risk_percent TINYINT UNSIGNED NOT NULL DEFAULT 0,
            recorded_deaths INT UNSIGNED NOT NULL DEFAULT 0,
            last_increase TINYINT UNSIGNED NOT NULL DEFAULT 0,
            last_cause VARCHAR(32) NULL,
            death_active TINYINT(1) NOT NULL DEFAULT 0,
            pending_finale TINYINT(1) NOT NULL DEFAULT 0,
            permadead TINYINT(1) NOT NULL DEFAULT 0,
            last_death_at TIMESTAMP NULL DEFAULT NULL,
            permadeath_at TIMESTAMP NULL DEFAULT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (character_id),
            KEY idx_ms_permadeath_pending (pending_finale, permadead),
            CONSTRAINT fk_ms_permadeath_character
                FOREIGN KEY (character_id) REFERENCES mscore_characters (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    DatabaseReady = true

    for playerSource, player in pairs(exports.MSCore:GetPlayers()) do
        loadCharacterState(tonumber(playerSource), player)
    end
    print('[MS_Permadeath] Datenbank und Todeswahrscheinlichkeit bereit.')
end)
