local Sessions = {}
local LastActions = {}
local BusyPlayers = {}
local Ready = false

local function numberDigits()
    return math.max(4, math.min(9, math.floor(tonumber(MSTelegramsConfig.NumberDigits) or 6)))
end

local function subjectLimit()
    return math.max(1, math.min(64, math.floor(
        tonumber(MSTelegramsConfig.MaxSubjectLength) or 64
    )))
end

local function bodyLimit()
    return math.max(1, math.min(60000, math.floor(
        tonumber(MSTelegramsConfig.MaxBodyLength) or 1200
    )))
end

local function sendCost()
    return math.max(0, math.floor(tonumber(MSTelegramsConfig.SendCost) or 0))
end

local function debugLog(message, ...)
    if not MSTelegramsConfig.Debug then return end
    print(('[MS_Telegrams] ' .. message):format(...))
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function stationById(stationId)
    return type(stationId) == 'string' and MSTelegramsConfig.Stations[stationId] or nil
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

local function currentStation(playerSource)
    local stationId = Sessions[playerSource]
    local station = stationById(stationId)
    if not station
        or distanceTo(playerSource, station.clerk) > MSTelegramsConfig.ServerInteractionDistance then
        Sessions[playerSource] = nil
        return nil, nil
    end
    return stationId, station
end

local function onCooldown(playerSource, action)
    local key = ('%d:%s'):format(playerSource, action)
    local now = GetGameTimer()
    local last = LastActions[key]
    if last and now - last < MSTelegramsConfig.ActionCooldown then return true end
    LastActions[key] = now
    return false
end

local function trim(value)
    return value:match('^%s*(.-)%s*$')
end

local function cleanSubject(value)
    if type(value) ~= 'string' then return nil end
    value = trim(value:gsub('[%c]', ' '):gsub('%s+', ' '))
    if value == '' then value = 'Ohne Betreff' end
    if #value > subjectLimit() then return nil end
    return value
end

local function cleanBody(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('\r\n', '\n'):gsub('\r', '\n')
    value = value:gsub('[%z\1-\9\11\12\14-\31\127]', '')
    value = trim(value)
    if value == '' or #value > bodyLimit() then return nil end
    return value
end

local function normalizeNumber(value)
    if type(value) ~= 'string' and type(value) ~= 'number' then return nil end
    local number = tostring(value):gsub('[%s%-]', '')
    local digits = numberDigits()
    if #number ~= digits or not number:match('^%d+$') then return nil end
    return number
end

local function accountNumber(characterId)
    return MySQL.scalar.await(
        'SELECT telegram_number FROM ms_telegram_accounts WHERE character_id = ?',
        { characterId }
    )
end

local function ensureAccount(player)
    if not player then return nil end
    local existing = accountNumber(player.characterId)
    if existing then return tostring(existing) end

    local digits = numberDigits()
    local minimum = 10 ^ (digits - 1)
    local maximum = (10 ^ digits) - 1

    for _ = 1, 30 do
        local candidate = tostring(math.random(minimum, maximum))
        local success, affected = pcall(MySQL.update.await, [[
            INSERT IGNORE INTO ms_telegram_accounts (character_id, telegram_number)
            VALUES (?, ?)
        ]], { player.characterId, candidate })

        if success and affected == 1 then
            debugLog('Nummer %s an Charakter %d vergeben.', candidate, player.characterId)
            return candidate
        end

        existing = accountNumber(player.characterId)
        if existing then return tostring(existing) end
    end

    print(('[MS_Telegrams] Für Charakter %d konnte keine eindeutige Nummer erzeugt werden.'):format(
        player.characterId
    ))
    return nil
end

local function mapMessage(row)
    return {
        id = tonumber(row.id),
        senderNumber = tostring(row.sender_number),
        senderName = row.sender_name,
        recipientNumber = tostring(row.recipient_number),
        recipientName = row.recipient_name,
        subject = row.subject,
        body = row.body,
        sentAt = row.sent_at,
        readAt = row.read_at,
        unread = row.read_at == nil
    }
end

local function messagesFor(characterId, folder)
    local isInbox = folder == 'inbox'
    local ownerColumn = isInbox and 'recipient_character_id' or 'sender_character_id'
    local deletedColumn = isInbox and 'deleted_by_recipient' or 'deleted_by_sender'
    local limit = math.max(1, math.min(250, math.floor(
        tonumber(MSTelegramsConfig.MaxMessagesPerFolder) or 100
    )))
    local rows = MySQL.query.await(([[
        SELECT id, sender_number, sender_name, recipient_number, recipient_name,
               subject, body, sent_at, read_at
        FROM ms_telegrams
        WHERE %s = ? AND %s = 0
        ORDER BY sent_at DESC, id DESC
        LIMIT %d
    ]]):format(ownerColumn, deletedColumn, limit), { characterId })

    local messages = {}
    for _, row in ipairs(rows or {}) do messages[#messages + 1] = mapMessage(row) end
    return messages
end

local function menuPayload(playerSource, stationId)
    local player = getPlayer(playerSource)
    local station = stationById(stationId)
    if not player or not station then return nil end
    local number = ensureAccount(player)
    if not number then return nil end

    local unread = tonumber(MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM ms_telegrams
        WHERE recipient_character_id = ? AND read_at IS NULL AND deleted_by_recipient = 0
    ]], { player.characterId })) or 0

    return {
        station = { id = stationId, label = station.label },
        account = {
            number = number,
            name = player:getName(),
            balance = tonumber(player.money[MSTelegramsConfig.Account]) or 0,
            moneyAccount = MSTelegramsConfig.Account
        },
        inbox = messagesFor(player.characterId, 'inbox'),
        sent = messagesFor(player.characterId, 'sent'),
        unread = unread,
        settings = {
            sendCost = sendCost(),
            currency = MSTelegramsConfig.CurrencyLabel,
            numberDigits = numberDigits(),
            maxSubjectLength = subjectLimit(),
            maxBodyLength = bodyLimit()
        }
    }
end

local function refresh(playerSource)
    local stationId = Sessions[playerSource]
    local payload = stationId and menuPayload(playerSource, stationId)
    if payload then TriggerClientEvent('ms_telegrams:client:refresh', playerSource, payload) end
end

local function result(playerSource, success, message, shouldRefresh)
    TriggerClientEvent('ms_telegrams:client:result', playerSource, {
        success = success == true,
        message = message
    })
    if shouldRefresh then refresh(playerSource) end
end

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_telegram_accounts (
            character_id BIGINT UNSIGNED NOT NULL,
            telegram_number VARCHAR(16) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (character_id),
            UNIQUE KEY uq_ms_telegram_accounts_number (telegram_number),
            CONSTRAINT fk_ms_telegram_accounts_character
                FOREIGN KEY (character_id) REFERENCES mscore_characters (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_telegrams (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            sender_character_id BIGINT UNSIGNED NOT NULL,
            sender_number VARCHAR(16) NOT NULL,
            sender_name VARCHAR(80) NOT NULL,
            recipient_character_id BIGINT UNSIGNED NOT NULL,
            recipient_number VARCHAR(16) NOT NULL,
            recipient_name VARCHAR(80) NOT NULL,
            subject VARCHAR(64) NOT NULL,
            body TEXT NOT NULL,
            sent_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            read_at TIMESTAMP NULL DEFAULT NULL,
            deleted_by_sender TINYINT(1) NOT NULL DEFAULT 0,
            deleted_by_recipient TINYINT(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (id),
            KEY idx_ms_telegrams_sender (sender_character_id, sent_at),
            KEY idx_ms_telegrams_recipient (recipient_character_id, sent_at),
            KEY idx_ms_telegrams_unread (recipient_character_id, read_at),
            CONSTRAINT fk_ms_telegrams_sender
                FOREIGN KEY (sender_character_id) REFERENCES mscore_characters (id) ON DELETE CASCADE,
            CONSTRAINT fk_ms_telegrams_recipient
                FOREIGN KEY (recipient_character_id) REFERENCES mscore_characters (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

RegisterNetEvent('ms_telegrams:server:open', function(stationId)
    local playerSource = source
    local station = stationById(stationId)
    if not Ready or not getPlayer(playerSource) or not station then return end
    if distanceTo(playerSource, station.clerk) > MSTelegramsConfig.ServerInteractionDistance then return end

    Sessions[playerSource] = stationId
    local payload = menuPayload(playerSource, stationId)
    if payload then
        TriggerClientEvent('ms_telegrams:client:open', playerSource, payload)
    else
        Sessions[playerSource] = nil
        TriggerClientEvent(
            'mscore:client:notify',
            playerSource,
            'Das Telegrammkonto konnte nicht geladen werden.'
        )
    end
end)

RegisterNetEvent('ms_telegrams:server:close', function()
    Sessions[source] = nil
end)

RegisterNetEvent('ms_telegrams:server:refresh', function()
    if onCooldown(source, 'refresh') or not currentStation(source) then return end
    refresh(source)
end)

RegisterNetEvent('ms_telegrams:server:send', function(rawNumber, rawSubject, rawBody)
    local playerSource = source
    if BusyPlayers[playerSource] or onCooldown(playerSource, 'send') then
        return result(playerSource, false, 'Bitte warte einen Moment.')
    end
    if not currentStation(playerSource) then return end

    local player = getPlayer(playerSource)
    local recipientNumber = normalizeNumber(rawNumber)
    local subject = cleanSubject(rawSubject)
    local body = cleanBody(rawBody)
    if not player or not recipientNumber then
        return result(playerSource, false, 'Die Telegrammnummer ist ungültig.')
    end
    if not subject then
        return result(playerSource, false, 'Der Betreff ist zu lang.')
    end
    if not body then
        return result(playerSource, false, 'Der Nachrichtentext ist leer oder zu lang.')
    end

    BusyPlayers[playerSource] = true
    local transaction = {
        player = player,
        price = 0,
        charged = false,
        insertId = nil,
        completed = false
    }
    local success, err = xpcall(function()
        local senderNumber = ensureAccount(player)
        if not senderNumber then
            return result(playerSource, false, 'Deine Telegrammnummer konnte nicht geladen werden.')
        end
        if senderNumber == recipientNumber then
            return result(playerSource, false, 'Du kannst dir nicht selbst schreiben.')
        end

        local recipient = MySQL.single.await([[
            SELECT accounts.character_id, characters.firstname, characters.lastname
            FROM ms_telegram_accounts AS accounts
            INNER JOIN mscore_characters AS characters ON characters.id = accounts.character_id
            WHERE accounts.telegram_number = ? AND characters.is_deleted = 0
        ]], { recipientNumber })
        if not recipient then
            return result(playerSource, false, 'Diese Telegrammnummer ist nicht vergeben.')
        end

        local price = sendCost()
        if price > 0 and not player:removeMoney(
            MSTelegramsConfig.Account,
            price,
            'telegram_send'
        ) then
            return result(playerSource, false, 'Dein Guthaben reicht für den Versand nicht aus.')
        end

        transaction.price = price
        transaction.charged = price > 0
        local recipientName = ('%s %s'):format(recipient.firstname, recipient.lastname)
        local insertSuccess, insertId = pcall(MySQL.insert.await, [[
            INSERT INTO ms_telegrams
                (sender_character_id, sender_number, sender_name,
                 recipient_character_id, recipient_number, recipient_name, subject, body)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            player.characterId,
            senderNumber,
            player:getName(),
            tonumber(recipient.character_id),
            recipientNumber,
            recipientName,
            subject,
            body
        })

        if not insertSuccess or not insertId then
            if transaction.charged then
                player:addMoney(MSTelegramsConfig.Account, price, 'telegram_refund')
                transaction.charged = false
                player:save()
            end
            return result(playerSource, false, 'Das Telegramm konnte nicht gespeichert werden.')
        end

        transaction.insertId = insertId
        if transaction.charged then player:save() end
        transaction.charged = false
        transaction.completed = true
        local onlineRecipient = exports.MSCore:GetPlayerFromCharacterId(
            tonumber(recipient.character_id)
        )
        if onlineRecipient then
            TriggerClientEvent('ms_telegrams:client:newTelegram', onlineRecipient.source, {
                senderName = player:getName(),
                senderNumber = senderNumber,
                subject = subject
            })
        end

        TriggerEvent(
            'ms_telegrams:server:sent',
            playerSource,
            tonumber(recipient.character_id),
            insertId
        )
        result(playerSource, true, ('Telegramm an %s versendet.'):format(recipientNumber), true)
        debugLog(
            'Charakter %d versendete Telegramm %d an Charakter %d.',
            player.characterId,
            insertId,
            tonumber(recipient.character_id)
        )
    end, debug.traceback)

    BusyPlayers[playerSource] = nil
    if not success then
        if not transaction.completed and transaction.insertId then
            local deleteSuccess, deleteError = pcall(MySQL.update.await, [[
                DELETE FROM ms_telegrams
                WHERE id = ? AND sender_character_id = ?
            ]], { transaction.insertId, transaction.player.characterId })
            if not deleteSuccess then
                print(('[MS_Telegrams] Rücknahme von Telegramm %d fehlgeschlagen: %s'):format(
                    transaction.insertId,
                    tostring(deleteError)
                ))
            end
        end
        if transaction.charged then
            local refundSuccess, refundError = pcall(function()
                transaction.player:addMoney(
                    MSTelegramsConfig.Account,
                    transaction.price,
                    'telegram_refund'
                )
                transaction.charged = false
                transaction.player:save()
            end)
            if not refundSuccess then
                print(('[MS_Telegrams] Rückerstattung für %d fehlgeschlagen: %s'):format(
                    playerSource,
                    tostring(refundError)
                ))
            end
        end
        print(('[MS_Telegrams] Versand von %d fehlgeschlagen: %s'):format(
            playerSource,
            tostring(err)
        ))
        if transaction.completed then
            result(playerSource, true, 'Das Telegramm wurde versendet.', true)
        else
            result(playerSource, false, 'Das Telegramm konnte nicht verarbeitet werden.')
        end
    end
end)

RegisterNetEvent('ms_telegrams:server:read', function(messageId)
    local playerSource = source
    if onCooldown(playerSource, 'read') or not currentStation(playerSource) then return end
    local player = getPlayer(playerSource)
    messageId = math.floor(tonumber(messageId) or 0)
    if not player or messageId < 1 then return end

    local affected = MySQL.update.await([[
        UPDATE ms_telegrams
        SET read_at = COALESCE(read_at, CURRENT_TIMESTAMP)
        WHERE id = ? AND recipient_character_id = ? AND deleted_by_recipient = 0
    ]], { messageId, player.characterId })
    if affected == 1 then refresh(playerSource) end
end)

RegisterNetEvent('ms_telegrams:server:delete', function(messageId, folder)
    local playerSource = source
    if onCooldown(playerSource, 'delete') or not currentStation(playerSource) then return end
    local player = getPlayer(playerSource)
    messageId = math.floor(tonumber(messageId) or 0)
    if not player or messageId < 1 or (folder ~= 'inbox' and folder ~= 'sent') then return end

    local sql
    if folder == 'inbox' then
        sql = [[
            UPDATE ms_telegrams
            SET deleted_by_recipient = 1
            WHERE id = ? AND recipient_character_id = ? AND deleted_by_recipient = 0
        ]]
    else
        sql = [[
            UPDATE ms_telegrams
            SET deleted_by_sender = 1
            WHERE id = ? AND sender_character_id = ? AND deleted_by_sender = 0
        ]]
    end

    local affected = MySQL.update.await(sql, { messageId, player.characterId })
    if affected == 1 then
        result(playerSource, true, 'Telegramm aus diesem Ordner entfernt.', true)
    else
        result(playerSource, false, 'Telegramm nicht gefunden.')
    end
end)

AddEventHandler('mscore:server:playerLoaded', function(playerSource, player)
    if not Ready or not player then return end
    CreateThread(function()
        local success, number = pcall(ensureAccount, player)
        if not success or not number then return end
        local unread = tonumber(MySQL.scalar.await([[
            SELECT COUNT(*) FROM ms_telegrams
            WHERE recipient_character_id = ? AND read_at IS NULL AND deleted_by_recipient = 0
        ]], { player.characterId })) or 0
        if unread > 0 then
            TriggerClientEvent(
                'mscore:client:notify',
                playerSource,
                ('Du hast %d ungelesene Telegramme.'):format(unread)
            )
        end
    end)
end)

local function clearPlayerState(playerSource)
    Sessions[playerSource] = nil
    BusyPlayers[playerSource] = nil
    for key in pairs(LastActions) do
        if key:match(('^%d+:'):format(playerSource)) then LastActions[key] = nil end
    end
end

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    clearPlayerState(playerSource)
end)

AddEventHandler('playerDropped', function()
    clearPlayerState(source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        local success, err = pcall(createTables)
        if not success then
            return print(('[MS_Telegrams] Tabellen konnten nicht erstellt werden: %s'):format(
                tostring(err)
            ))
        end
        Ready = true
        for _, player in pairs(exports.MSCore:GetPlayers()) do
            pcall(ensureAccount, player)
        end
        print('[MS_Telegrams] Telegrammkonten und Nachrichten geladen.')
    end)
end)

function GetTelegramNumber(characterId)
    if not Ready then return nil end
    characterId = tonumber(characterId)
    if not characterId then return nil end
    local number = accountNumber(characterId)
    return number and tostring(number) or nil
end

exports('GetTelegramNumber', GetTelegramNumber)
