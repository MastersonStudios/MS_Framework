local Sessions = {}
local LastActions = {}
local OperationLocks = {}
local AccountLocks = {}
local CompanyLocks = {}
local Ready = false

local function debugLog(message, ...)
    if not MSBankingConfig.Debug then return end
    print(('[MS_Banking] ' .. message):format(...))
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function bankerById(bankerId)
    return type(bankerId) == 'string' and MSBankingConfig.Bankers[bankerId] or nil
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

local function currentBanker(playerSource)
    local bankerId = Sessions[playerSource]
    local banker = bankerById(bankerId)
    if not banker
        or distanceTo(playerSource, banker.npc) > MSBankingConfig.ServerInteractionDistance then
        Sessions[playerSource] = nil
        return nil, nil
    end
    return bankerId, banker
end

local function onCooldown(playerSource, action)
    local key = ('%d:%s'):format(playerSource, action)
    local now = GetGameTimer()
    local last = LastActions[key]
    if last and now - last < MSBankingConfig.ActionCooldown then return true end
    LastActions[key] = now
    return false
end

local function validAmount(value)
    local amount = tonumber(value)
    if not amount or amount ~= math.floor(amount) then return nil end
    amount = math.floor(amount)
    if amount < 1 or amount > MSBankingConfig.MaxTransactionAmount then return nil end
    return amount
end

local function normalizeAccountNumber(value)
    if type(value) ~= 'string' then return nil end
    local normalized = value:upper():gsub('[^A-Z0-9]', '')
    if #normalized < 4 or #normalized > 24 then return nil end
    return normalized
end

local function generateAccountNumber(characterId)
    local prefix = tostring(MSBankingConfig.AccountPrefix or 'MS')
        :upper()
        :gsub('[^A-Z0-9]', '')
        :sub(1, 6)
    if prefix == '' then prefix = 'MS' end
    local digits = math.max(4, math.min(16, math.floor(
        tonumber(MSBankingConfig.AccountDigits) or 10
    )))
    return prefix .. (('%0' .. digits .. 'd'):format(characterId))
end

local function ensureAccount(player)
    if not player then return nil end
    local account = MySQL.single.await([[
        SELECT character_id, account_number, created_at
        FROM ms_bank_accounts
        WHERE character_id = ?
        LIMIT 1
    ]], { player.characterId })
    if account then return account end

    local accountNumber = generateAccountNumber(player.characterId)
    MySQL.insert.await([[
        INSERT IGNORE INTO ms_bank_accounts (character_id, account_number)
        VALUES (?, ?)
    ]], { player.characterId, accountNumber })

    return MySQL.single.await([[
        SELECT character_id, account_number, created_at
        FROM ms_bank_accounts
        WHERE character_id = ?
        LIMIT 1
    ]], { player.characterId })
end

local function transactionsFor(characterId)
    local limit = math.max(1, math.min(100, math.floor(
        tonumber(MSBankingConfig.TransactionHistoryLimit) or 25
    )))
    local rows = MySQL.query.await(([[
        SELECT id, transaction_type, amount, balance_after,
            counterparty_account, description, created_at
        FROM ms_bank_transactions
        WHERE account_character_id = ?
        ORDER BY id DESC
        LIMIT %d
    ]]):format(limit), { characterId }) or {}

    local transactions = {}
    for _, row in ipairs(rows) do
        transactions[#transactions + 1] = {
            id = tonumber(row.id),
            type = row.transaction_type,
            amount = tonumber(row.amount) or 0,
            balanceAfter = tonumber(row.balance_after) or 0,
            counterpartyAccount = row.counterparty_account,
            description = row.description,
            createdAt = row.created_at
        }
    end
    return transactions
end

local function recordTransaction(characterId, transactionType, amount, balanceAfter, counterparty, description)
    local success, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO ms_bank_transactions (
                account_character_id, transaction_type, amount, balance_after,
                counterparty_account, description
            )
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            characterId,
            transactionType,
            amount,
            balanceAfter,
            counterparty,
            description
        })
    end)
    if not success then
        print(('[MS_Banking] Buchungshistorie für Charakter %d fehlgeschlagen: %s'):format(
            characterId,
            tostring(err)
        ))
    end
    return success
end

local function companyConfigByJob(jobName)
    if type(jobName) ~= 'string' or jobName == '' then return nil end
    local config = MSBankingConfig.CompanyAccounts[jobName]
    if type(config) == 'table' then return config end

    local defaults = MSBankingConfig.CompanyAccountDefaults
    if type(defaults) ~= 'table' or defaults.enabled ~= true
        or (type(defaults.excludedJobs) == 'table' and defaults.excludedJobs[jobName]) then
        return nil
    end

    local label = jobName:gsub('_', ' ')
    label = label:gsub('^%l', string.upper)
    return {
        label = label,
        minDepositGrade = defaults.minDepositGrade,
        minWithdrawGrade = defaults.minWithdrawGrade
    }
end

local function companyConfigFor(player)
    if not player or type(player.job) ~= 'string' then return nil, nil end
    local config = companyConfigByJob(player.job)
    if not config then return nil, nil end
    return player.job, config
end

local function ensureCompanyAccount(jobName, config)
    if type(jobName) ~= 'string' or type(config) ~= 'table' then return nil end
    local label = tostring(config.label or jobName):sub(1, 64)
    MySQL.insert.await([[
        INSERT INTO ms_bank_company_accounts (job_name, label, balance)
        VALUES (?, ?, 0)
        ON DUPLICATE KEY UPDATE label = VALUES(label)
    ]], { jobName, label })
    return MySQL.single.await([[
        SELECT job_name, label, balance, created_at, updated_at
        FROM ms_bank_company_accounts
        WHERE job_name = ?
        LIMIT 1
    ]], { jobName })
end

local function companyTransactionsFor(jobName)
    local limit = math.max(1, math.min(100, math.floor(
        tonumber(MSBankingConfig.TransactionHistoryLimit) or 25
    )))
    local rows = MySQL.query.await(([[
        SELECT id, actor_character_id, actor_name, transaction_type,
            amount, balance_after, description, created_at
        FROM ms_bank_company_transactions
        WHERE company_job = ?
        ORDER BY id DESC
        LIMIT %d
    ]]):format(limit), { jobName }) or {}

    local transactions = {}
    for _, row in ipairs(rows) do
        transactions[#transactions + 1] = {
            id = tonumber(row.id),
            actorCharacterId = tonumber(row.actor_character_id),
            actorName = row.actor_name,
            type = row.transaction_type,
            amount = tonumber(row.amount) or 0,
            balanceAfter = tonumber(row.balance_after) or 0,
            description = row.description,
            createdAt = row.created_at
        }
    end
    return transactions
end

local function recordCompanyTransaction(jobName, player, transactionType, amount, balanceAfter, description)
    local success, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO ms_bank_company_transactions (
                company_job, actor_character_id, actor_name, transaction_type,
                amount, balance_after, description
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {
            jobName,
            player.characterId,
            player:getName(),
            transactionType,
            amount,
            balanceAfter,
            description
        })
    end)
    if not success then
        print(('[MS_Banking] Firmenbuchung für Job %s fehlgeschlagen: %s'):format(
            jobName,
            tostring(err)
        ))
    end
    return success
end

local function companyEnvelope(player)
    local jobName, config = companyConfigFor(player)
    if not jobName then return nil end
    local company = ensureCompanyAccount(jobName, config)
    if not company then return nil end

    local grade = math.floor(tonumber(player.jobGrade) or -1)
    local minDepositGrade = math.max(0, math.floor(tonumber(config.minDepositGrade) or 0))
    local minWithdrawGrade = math.max(0, math.floor(tonumber(config.minWithdrawGrade) or 0))
    return {
        job = jobName,
        label = company.label,
        balance = tonumber(company.balance) or 0,
        canDeposit = grade >= minDepositGrade,
        canWithdraw = grade >= minWithdrawGrade,
        minDepositGrade = minDepositGrade,
        minWithdrawGrade = minWithdrawGrade,
        transactions = companyTransactionsFor(jobName)
    }
end

local function accountEnvelope(playerSource, banker)
    local player = getPlayer(playerSource)
    local account = player and ensureAccount(player)
    if not player or not account then return nil end
    return {
        branch = banker.label,
        currency = MSBankingConfig.CurrencyLabel,
        maxTransactionAmount = MSBankingConfig.MaxTransactionAmount,
        account = {
            number = account.account_number,
            holder = player:getName(),
            cash = tonumber(player.money.cash) or 0,
            balance = tonumber(player.money.bank) or 0,
            createdAt = account.created_at
        },
        transactions = transactionsFor(player.characterId),
        company = companyEnvelope(player)
    }
end

local function result(playerSource, success, message)
    playerSource = tonumber(playerSource)
    if not playerSource then return end
    TriggerClientEvent('ms_banking:client:result', playerSource, {
        success = success == true,
        message = message
    })
end

local function refreshClient(playerSource)
    local _, banker = currentBanker(playerSource)
    if not banker then return false end
    local data = accountEnvelope(playerSource, banker)
    if not data then return false end
    TriggerClientEvent('ms_banking:client:refresh', playerSource, data)
    return true
end

local function runOperation(playerSource, action, handler)
    playerSource = tonumber(playerSource)
    if not playerSource or not Ready then
        return result(playerSource, false, 'Die Bank ist noch nicht verfügbar.')
    end
    local _, banker = currentBanker(playerSource)
    local player = getPlayer(playerSource)
    if not banker or not player then
        return result(playerSource, false, 'Du bist bei keinem erreichbaren Banker.')
    end
    if OperationLocks[playerSource] then
        return result(playerSource, false, 'Dein letzter Bankauftrag wird noch verarbeitet.')
    end
    if AccountLocks[player.characterId] then
        return result(playerSource, false, 'Dieses Konto verarbeitet bereits einen Bankauftrag.')
    end
    if onCooldown(playerSource, action) then
        return result(playerSource, false, 'Bitte warte kurz vor dem nächsten Bankauftrag.')
    end

    OperationLocks[playerSource] = true
    AccountLocks[player.characterId] = true
    local success, err = pcall(handler, player, banker)
    OperationLocks[playerSource] = nil
    AccountLocks[player.characterId] = nil
    if not success then
        print(('[MS_Banking] Fehler bei %s für Spieler %d: %s'):format(
            action,
            playerSource,
            tostring(err)
        ))
        result(playerSource, false, 'Der Bankauftrag konnte nicht verarbeitet werden.')
    end
end

local function runCompanyOperation(playerSource, action, permission, handler)
    runOperation(playerSource, action, function(player, banker)
        local jobName, config = companyConfigFor(player)
        if not jobName then
            return result(playerSource, false, 'Für deinen Job ist kein Firmenkonto eingerichtet.')
        end

        local requiredGrade = permission == 'withdraw'
            and math.max(0, math.floor(tonumber(config.minWithdrawGrade) or 0))
            or math.max(0, math.floor(tonumber(config.minDepositGrade) or 0))
        if (tonumber(player.jobGrade) or -1) < requiredGrade then
            return result(
                playerSource,
                false,
                ('Für diese Firmenbuchung wird mindestens Jobgrad %d benötigt.'):format(
                    requiredGrade
                )
            )
        end
        if CompanyLocks[jobName] then
            return result(playerSource, false, 'Das Firmenkonto verarbeitet bereits einen Auftrag.')
        end

        CompanyLocks[jobName] = true
        local success, err = pcall(handler, player, banker, jobName, config)
        CompanyLocks[jobName] = nil
        if not success then error(err) end
    end)
end

RegisterNetEvent('ms_banking:server:open', function(bankerId)
    local playerSource = source
    if not Ready then return result(playerSource, false, 'Die Bank wird noch vorbereitet.') end
    local banker = bankerById(bankerId)
    local player = getPlayer(playerSource)
    if not banker or not player
        or distanceTo(playerSource, banker.npc) > MSBankingConfig.ServerInteractionDistance then
        return result(playerSource, false, 'Du bist bei keinem erreichbaren Banker.')
    end

    Sessions[playerSource] = bankerId
    local data = accountEnvelope(playerSource, banker)
    if not data then
        Sessions[playerSource] = nil
        return result(playerSource, false, 'Dein Bankkonto konnte nicht geladen werden.')
    end
    TriggerClientEvent('ms_banking:client:open', playerSource, data)
end)

RegisterNetEvent('ms_banking:server:close', function()
    Sessions[source] = nil
end)

RegisterNetEvent('ms_banking:server:refresh', function()
    local playerSource = source
    if not Ready or not refreshClient(playerSource) then
        result(playerSource, false, 'Die Bankdaten konnten nicht aktualisiert werden.')
    end
end)

RegisterNetEvent('ms_banking:server:deposit', function(rawAmount)
    local playerSource = source
    runOperation(playerSource, 'deposit', function(player)
        local amount = validAmount(rawAmount)
        if not amount then
            return result(playerSource, false, 'Gib einen gültigen ganzzahligen Betrag ein.')
        end
        if not player:removeMoney('cash', amount, 'bank_deposit') then
            return result(playerSource, false, 'Du hast nicht genug Bargeld.')
        end
        if not player:addMoney('bank', amount, 'bank_deposit') then
            player:addMoney('cash', amount, 'bank_deposit_rollback')
            return result(playerSource, false, 'Die Einzahlung konnte nicht gebucht werden.')
        end

        player:save()
        recordTransaction(
            player.characterId,
            'deposit',
            amount,
            player.money.bank,
            nil,
            'Bargeld eingezahlt'
        )
        TriggerEvent('ms_banking:server:deposited', playerSource, player.characterId, amount)
        result(playerSource, true, ('$%d wurden eingezahlt.'):format(amount))
        refreshClient(playerSource)
    end)
end)

RegisterNetEvent('ms_banking:server:withdraw', function(rawAmount)
    local playerSource = source
    runOperation(playerSource, 'withdraw', function(player)
        local amount = validAmount(rawAmount)
        if not amount then
            return result(playerSource, false, 'Gib einen gültigen ganzzahligen Betrag ein.')
        end
        if not player:removeMoney('bank', amount, 'bank_withdrawal') then
            return result(playerSource, false, 'Dein Kontoguthaben reicht nicht aus.')
        end
        if not player:addMoney('cash', amount, 'bank_withdrawal') then
            player:addMoney('bank', amount, 'bank_withdrawal_rollback')
            return result(playerSource, false, 'Die Auszahlung konnte nicht gebucht werden.')
        end

        player:save()
        recordTransaction(
            player.characterId,
            'withdrawal',
            -amount,
            player.money.bank,
            nil,
            'Bargeld abgehoben'
        )
        TriggerEvent('ms_banking:server:withdrawn', playerSource, player.characterId, amount)
        result(playerSource, true, ('$%d wurden ausgezahlt.'):format(amount))
        refreshClient(playerSource)
    end)
end)

RegisterNetEvent('ms_banking:server:companyDeposit', function(rawAmount)
    local playerSource = source
    runCompanyOperation(playerSource, 'company_deposit', 'deposit', function(player, _, jobName, config)
        local amount = validAmount(rawAmount)
        if not amount then
            return result(playerSource, false, 'Gib einen gültigen ganzzahligen Betrag ein.')
        end
        if not ensureCompanyAccount(jobName, config) then
            return result(playerSource, false, 'Das Firmenkonto konnte nicht geladen werden.')
        end
        if not player:removeMoney('cash', amount, 'company_bank_deposit') then
            return result(playerSource, false, 'Du hast nicht genug Bargeld.')
        end

        local affected = MySQL.update.await([[
            UPDATE ms_bank_company_accounts
            SET balance = balance + ?
            WHERE job_name = ?
        ]], { amount, jobName })
        if tonumber(affected) ~= 1 then
            player:addMoney('cash', amount, 'company_bank_deposit_rollback')
            return result(playerSource, false, 'Die Firmeneinzahlung konnte nicht gebucht werden.')
        end

        local companyBalance = tonumber(MySQL.scalar.await(
            'SELECT balance FROM ms_bank_company_accounts WHERE job_name = ?',
            { jobName }
        )) or 0
        player:save()
        recordCompanyTransaction(
            jobName,
            player,
            'company_deposit',
            amount,
            companyBalance,
            ('Einzahlung von %s'):format(player:getName())
        )
        TriggerEvent(
            'ms_banking:server:companyDeposited',
            playerSource,
            player.characterId,
            jobName,
            amount
        )
        result(playerSource, true, ('$%d wurden auf %s eingezahlt.'):format(
            amount,
            config.label or jobName
        ))
        refreshClient(playerSource)
    end)
end)

RegisterNetEvent('ms_banking:server:companyWithdraw', function(rawAmount)
    local playerSource = source
    runCompanyOperation(playerSource, 'company_withdraw', 'withdraw', function(player, _, jobName, config)
        local amount = validAmount(rawAmount)
        if not amount then
            return result(playerSource, false, 'Gib einen gültigen ganzzahligen Betrag ein.')
        end
        if not ensureCompanyAccount(jobName, config) then
            return result(playerSource, false, 'Das Firmenkonto konnte nicht geladen werden.')
        end

        local affected = MySQL.update.await([[
            UPDATE ms_bank_company_accounts
            SET balance = balance - ?
            WHERE job_name = ? AND balance >= ?
        ]], { amount, jobName, amount })
        if tonumber(affected) ~= 1 then
            return result(playerSource, false, 'Das Firmenkonto besitzt nicht genug Guthaben.')
        end
        if not player:addMoney('cash', amount, 'company_bank_withdrawal') then
            MySQL.update.await([[
                UPDATE ms_bank_company_accounts
                SET balance = balance + ?
                WHERE job_name = ?
            ]], { amount, jobName })
            return result(playerSource, false, 'Die Firmenauszahlung konnte nicht gebucht werden.')
        end

        local companyBalance = tonumber(MySQL.scalar.await(
            'SELECT balance FROM ms_bank_company_accounts WHERE job_name = ?',
            { jobName }
        )) or 0
        player:save()
        recordCompanyTransaction(
            jobName,
            player,
            'company_withdrawal',
            -amount,
            companyBalance,
            ('Auszahlung an %s'):format(player:getName())
        )
        TriggerEvent(
            'ms_banking:server:companyWithdrawn',
            playerSource,
            player.characterId,
            jobName,
            amount
        )
        result(playerSource, true, ('$%d wurden von %s ausgezahlt.'):format(
            amount,
            config.label or jobName
        ))
        refreshClient(playerSource)
    end)
end)

RegisterNetEvent('ms_banking:server:transfer', function(rawAccountNumber, rawAmount)
    local playerSource = source
    runOperation(playerSource, 'transfer', function(player)
        local amount = validAmount(rawAmount)
        local targetNumber = normalizeAccountNumber(rawAccountNumber)
        if not amount then
            return result(playerSource, false, 'Gib einen gültigen ganzzahligen Betrag ein.')
        end
        if not targetNumber then
            return result(playerSource, false, 'Die Kontonummer ist ungültig.')
        end

        local senderAccount = ensureAccount(player)
        local targetAccount = MySQL.single.await([[
            SELECT character_id, account_number
            FROM ms_bank_accounts
            WHERE account_number = ?
            LIMIT 1
        ]], { targetNumber })
        if not senderAccount or not targetAccount then
            return result(playerSource, false, 'Das Empfängerkonto wurde nicht gefunden.')
        end

        local targetCharacterId = tonumber(targetAccount.character_id)
        if targetCharacterId == player.characterId then
            return result(playerSource, false, 'Du kannst nicht an dein eigenes Konto überweisen.')
        end
        if AccountLocks[targetCharacterId] then
            return result(playerSource, false, 'Das Empfängerkonto verarbeitet gerade einen Auftrag.')
        end
        if not player:removeMoney('bank', amount, 'bank_transfer_out') then
            return result(playerSource, false, 'Dein Kontoguthaben reicht nicht aus.')
        end

        AccountLocks[targetCharacterId] = true
        local creditCallOk, credited, targetPlayer, targetBalance = pcall(function()
            local recipient = exports.MSCore:GetPlayerFromCharacterId(targetCharacterId)
            if recipient then
                local recipientCredited = recipient:addMoney('bank', amount, 'bank_transfer_in')
                if recipientCredited then
                    recipient:save()
                    return true, recipient, recipient.money.bank
                end
                return false, recipient, nil
            end

            local affected = MySQL.update.await([[
                UPDATE mscore_characters
                SET bank = bank + ?
                WHERE id = ? AND is_deleted = 0
            ]], { amount, targetCharacterId })
            local recipientCredited = tonumber(affected) == 1
            local recipientBalance
            if recipientCredited then
                recipientBalance = tonumber(MySQL.scalar.await(
                    'SELECT bank FROM mscore_characters WHERE id = ?',
                    { targetCharacterId }
                )) or 0
            end
            return recipientCredited, nil, recipientBalance
        end)
        AccountLocks[targetCharacterId] = nil

        if not creditCallOk then
            player:addMoney('bank', amount, 'bank_transfer_rollback')
            error(credited)
        end

        if not credited then
            player:addMoney('bank', amount, 'bank_transfer_rollback')
            return result(playerSource, false, 'Die Überweisung konnte nicht zugestellt werden.')
        end

        player:save()
        recordTransaction(
            player.characterId,
            'transfer_out',
            -amount,
            player.money.bank,
            targetAccount.account_number,
            'Überweisung gesendet'
        )
        recordTransaction(
            targetCharacterId,
            'transfer_in',
            amount,
            targetBalance,
            senderAccount.account_number,
            'Überweisung erhalten'
        )
        TriggerEvent(
            'ms_banking:server:transferred',
            playerSource,
            player.characterId,
            targetCharacterId,
            amount
        )

        result(playerSource, true, ('$%d wurden an %s überwiesen.'):format(
            amount,
            targetAccount.account_number
        ))
        refreshClient(playerSource)
        if targetPlayer then
            TriggerClientEvent(
                'mscore:client:notify',
                targetPlayer.source,
                ('$%d wurden auf dein Konto überwiesen.'):format(amount)
            )
            if Sessions[targetPlayer.source] then refreshClient(targetPlayer.source) end
        end
    end)
end)

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource then return end
    Sessions[playerSource] = nil
    OperationLocks[playerSource] = nil
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    Sessions[playerSource] = nil
    OperationLocks[playerSource] = nil
    for key in pairs(LastActions) do
        if key:match(('^%d:'):format(playerSource)) then LastActions[key] = nil end
    end
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_bank_accounts (
            character_id BIGINT UNSIGNED NOT NULL,
            account_number VARCHAR(24) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (character_id),
            UNIQUE KEY uq_ms_bank_accounts_number (account_number),
            CONSTRAINT fk_ms_bank_accounts_character
                FOREIGN KEY (character_id) REFERENCES mscore_characters (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_bank_transactions (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            account_character_id BIGINT UNSIGNED NOT NULL,
            transaction_type VARCHAR(24) NOT NULL,
            amount INT NOT NULL,
            balance_after INT UNSIGNED NOT NULL,
            counterparty_account VARCHAR(24) NULL,
            description VARCHAR(100) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_ms_bank_transactions_account (account_character_id, id),
            CONSTRAINT fk_ms_bank_transactions_account
                FOREIGN KEY (account_character_id)
                REFERENCES ms_bank_accounts (character_id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_bank_company_accounts (
            job_name VARCHAR(32) NOT NULL,
            label VARCHAR(64) NOT NULL,
            balance BIGINT UNSIGNED NOT NULL DEFAULT 0,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (job_name)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_bank_company_transactions (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            company_job VARCHAR(32) NOT NULL,
            actor_character_id BIGINT UNSIGNED NOT NULL,
            actor_name VARCHAR(80) NOT NULL,
            transaction_type VARCHAR(32) NOT NULL,
            amount INT NOT NULL,
            balance_after BIGINT UNSIGNED NOT NULL,
            description VARCHAR(120) NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_ms_bank_company_transactions_job (company_job, id),
            CONSTRAINT fk_ms_bank_company_transactions_job
                FOREIGN KEY (company_job)
                REFERENCES ms_bank_company_accounts (job_name) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    for jobName, config in pairs(MSBankingConfig.CompanyAccounts) do
        ensureCompanyAccount(jobName, config)
    end

    Ready = true
    debugLog('Datenbanktabellen bereit.')
end)

function GetAccount(playerSource)
    if not Ready then return nil end
    local player = getPlayer(playerSource)
    local account = player and ensureAccount(player)
    if not player or not account then return nil end
    return {
        characterId = player.characterId,
        number = account.account_number,
        holder = player:getName(),
        balance = tonumber(player.money.bank) or 0
    }
end

exports('GetAccount', GetAccount)

function GetCompanyAccount(jobName)
    if not Ready or type(jobName) ~= 'string' then return nil end
    local config = companyConfigByJob(jobName)
    local company = config and ensureCompanyAccount(jobName, config) or nil
    if not company then return nil end
    return {
        job = company.job_name,
        label = company.label,
        balance = tonumber(company.balance) or 0,
        minDepositGrade = math.max(0, math.floor(tonumber(config.minDepositGrade) or 0)),
        minWithdrawGrade = math.max(0, math.floor(tonumber(config.minWithdrawGrade) or 0))
    }
end

exports('GetCompanyAccount', GetCompanyAccount)
