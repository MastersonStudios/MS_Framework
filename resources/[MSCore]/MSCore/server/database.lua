MSDatabase = MSDatabase or {
    ready = false,
    error = nil
}

local readyPromise = promise.new()

local migrations = {
    [[
        CREATE TABLE IF NOT EXISTS `mscore_accounts` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `license` VARCHAR(80) NOT NULL,
            `group_name` VARCHAR(40) NOT NULL DEFAULT 'user',
            `max_characters` SMALLINT UNSIGNED NOT NULL DEFAULT 3,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `last_seen_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uq_mscore_accounts_license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `mscore_characters` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `account_id` BIGINT UNSIGNED NOT NULL,
            `firstname` VARCHAR(32) NOT NULL,
            `lastname` VARCHAR(32) NOT NULL,
            `date_of_birth` DATE NULL,
            `sex` ENUM('male', 'female') NOT NULL DEFAULT 'male',
            `group_name` VARCHAR(40) NOT NULL DEFAULT 'user',
            `job_name` VARCHAR(64) NOT NULL DEFAULT 'unemployed',
            `job_grade` INT NOT NULL DEFAULT 0,
            `job_label` VARCHAR(80) NOT NULL DEFAULT 'Arbeitslos',
            `money` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
            `gold` DECIMAL(15,2) NOT NULL DEFAULT 0.00,
            `xp` INT UNSIGNED NOT NULL DEFAULT 0,
            `health` INT UNSIGNED NOT NULL DEFAULT 500,
            `stamina` INT UNSIGNED NOT NULL DEFAULT 100,
            `is_dead` TINYINT(1) NOT NULL DEFAULT 0,
            `coords` LONGTEXT NOT NULL,
            `metadata` LONGTEXT NOT NULL,
            `is_deleted` TINYINT(1) NOT NULL DEFAULT 0,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `last_played_at` TIMESTAMP NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_mscore_characters_account` (`account_id`, `is_deleted`),
            CONSTRAINT `fk_mscore_characters_account`
                FOREIGN KEY (`account_id`) REFERENCES `mscore_accounts` (`id`)
                ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
}

function MSDatabase.AwaitReady()
    if MSDatabase.ready then return true end
    if MSDatabase.error then return false, MSDatabase.error end
    Citizen.Await(readyPromise)
    return MSDatabase.ready, MSDatabase.error
end

local function finish(success, errorMessage)
    MSDatabase.ready = success == true
    MSDatabase.error = success and nil or tostring(errorMessage or 'Unbekannter Datenbankfehler')
    readyPromise:resolve(MSDatabase.ready)
end

MySQL.ready(function()
    local ok, errorMessage = xpcall(function()
        if Config.Database and Config.Database.AutoMigrate ~= false then
            for index, statement in ipairs(migrations) do
                MySQL.query.await(statement)
                if Config.Debug then
                    print(('[MSCore] Datenbankmigration %d/%d abgeschlossen.'):format(index, #migrations))
                end
            end
        end
    end, debug.traceback)

    finish(ok, errorMessage)
    if ok then
        print(('[MSCore] Datenbank bereit (Version %s).'):format(Config.Version))
    else
        print(('[MSCore] Datenbankinitialisierung fehlgeschlagen:\n%s'):format(tostring(errorMessage)))
    end
end)
