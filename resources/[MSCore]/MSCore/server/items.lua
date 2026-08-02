local Items = {}
local ItemsReady = false
local ItemsInitializationError
local Rarities = {
    common = true,
    uncommon = true,
    rare = true,
    epic = true,
    legendary = true
}

local function trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or nil
end

local function cleanText(value, maximum, optional)
    if value == nil or value == '' then return optional and '' or nil end
    value = trim(value)
    if not value then return end
    value = value:gsub('[%c]', ' ')
    if (not optional and #value < 2) or #value > maximum then return end
    return value
end

local function decodeMetadata(value)
    if type(value) == 'table' then return value end
    if value == nil or value == '' then return {} end
    if type(value) ~= 'string' or #value > 4000 then return end
    local success, decoded = pcall(json.decode, value)
    if not success or type(decoded) ~= 'table' then return end
    return decoded
end

local function boolean(value)
    return value == true or value == 1 or value == '1'
end

local function rowToItem(row)
    return {
        name = row.name,
        label = row.label,
        description = row.description or '',
        category = row.category,
        rarity = row.rarity,
        maxStack = tonumber(row.max_stack) or Config.MaxItemStack,
        weight = tonumber(row.weight) or 0,
        usable = boolean(row.usable),
        consumable = boolean(row.consumable),
        unique = boolean(row.unique_item),
        tradable = boolean(row.tradable),
        prop = row.prop_model or '',
        image = row.image or '',
        metadata = decodeMetadata(row.metadata) or {},
        protected = boolean(row.is_system),
        createdAt = row.created_at
    }
end

local function createTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS mscore_items (
            name VARCHAR(64) NOT NULL,
            label VARCHAR(64) NOT NULL,
            description VARCHAR(255) NULL,
            category VARCHAR(32) NOT NULL DEFAULT 'general',
            rarity ENUM('common','uncommon','rare','epic','legendary') NOT NULL DEFAULT 'common',
            max_stack INT UNSIGNED NOT NULL DEFAULT 1,
            weight INT UNSIGNED NOT NULL DEFAULT 0,
            usable TINYINT(1) NOT NULL DEFAULT 0,
            consumable TINYINT(1) NOT NULL DEFAULT 0,
            unique_item TINYINT(1) NOT NULL DEFAULT 0,
            tradable TINYINT(1) NOT NULL DEFAULT 1,
            prop_model VARCHAR(100) NULL,
            image VARCHAR(255) NULL,
            metadata LONGTEXT NULL,
            is_system TINYINT(1) NOT NULL DEFAULT 0,
            created_by VARCHAR(100) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (name),
            KEY idx_mscore_items_category (category)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

local function seedConfigItems()
    for name, item in pairs(Config.Items or {}) do
        MySQL.update.await([[
            INSERT IGNORE INTO mscore_items
                (name, label, description, category, rarity, max_stack, weight,
                 usable, consumable, unique_item, tradable, prop_model, image,
                 metadata, is_system, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 'config')
        ]], {
            name,
            item.label,
            item.description,
            item.category or 'general',
            item.rarity or 'common',
            item.unique and 1 or (item.maxStack or Config.MaxItemStack),
            math.max(tonumber(item.weight) or 0, 0),
            item.usable and 1 or 0,
            item.consumable and 1 or 0,
            item.unique and 1 or 0,
            item.tradable == false and 0 or 1,
            item.prop,
            item.image,
            json.encode(item.metadata or {})
        })
    end
end

local function loadItems()
    Items = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM mscore_items ORDER BY label') or {}) do
        local item = rowToItem(row)
        Items[item.name] = item
    end
    ItemsReady = true
end

MySQL.ready(function()
    local success, initError = xpcall(function()
        createTable()
        seedConfigItems()
        loadItems()
        print(('[MSCore] %d Datenbank-Items geladen.'):format((function()
            local count = 0
            for _ in pairs(Items) do count = count + 1 end
            return count
        end)()))
    end, function(errorMessage)
        if type(debug) == 'table' and type(debug.traceback) == 'function' then
            return debug.traceback(tostring(errorMessage), 2)
        end
        return tostring(errorMessage)
    end)
    if not success then
        ItemsInitializationError = tostring(initError)
        print(('[MSCore] Item-Datenbankinitialisierung fehlgeschlagen:\n%s'):format(
            ItemsInitializationError
        ))
    end
end)

local function waitForItems()
    local deadline = GetGameTimer() + 10000
    while not ItemsReady and not ItemsInitializationError and GetGameTimer() < deadline do Wait(25) end
    if ItemsReady then return true end
    return false, ItemsInitializationError
        and 'Die Item-Datenbank konnte nicht initialisiert werden.'
        or 'Die Item-Datenbank ist noch nicht bereit.'
end

function MSCore.GetItemDefinition(name)
    return type(name) == 'string' and Items[name] or nil
end

function GetItem(name)
    return MSCore.GetItemDefinition(name)
end

function GetItemCatalog()
    local catalog = {}
    for _, item in pairs(Items) do
        catalog[#catalog + 1] = item
    end
    table.sort(catalog, function(a, b)
        if a.label == b.label then return a.name < b.name end
        return a.label < b.label
    end)
    return catalog
end

local function validateItem(data)
    if type(data) ~= 'table' then return nil, 'Itemdaten fehlen.' end
    local name = type(data.name) == 'string' and data.name:lower():match('^%s*(.-)%s*$')
    local label = cleanText(data.label, 64)
    local description = cleanText(data.description, 255, true)
    local category = type(data.category) == 'string' and data.category:lower():match('^%s*(.-)%s*$')
    local rarity = type(data.rarity) == 'string' and data.rarity:lower()
    local maxStack = tonumber(data.maxStack)
    local weight = tonumber(data.weight)
    local prop = cleanText(data.prop, 100, true)
    local image = cleanText(data.image, 255, true)
    local metadata = decodeMetadata(data.metadata)
    local metadataEncoded = metadata and json.encode(metadata)

    if not name or #name < 2 or #name > 64 or not name:match('^[a-z0-9_]+$') then
        return nil, 'Der technische Name darf nur Kleinbuchstaben, Zahlen und Unterstriche enthalten.'
    end
    if not label or description == nil then return nil, 'Bezeichnung oder Beschreibung ungültig.' end
    if not category or #category < 2 or #category > 32 or not category:match('^[a-z0-9_-]+$') then
        return nil, 'Kategorie ungültig.'
    end
    if not Rarities[rarity] then return nil, 'Seltenheit ungültig.' end
    if not maxStack or maxStack % 1 ~= 0 or maxStack < 1 or maxStack > 10000 then
        return nil, 'Stack-Limit muss zwischen 1 und 10000 liegen.'
    end
    if not weight or weight % 1 ~= 0 or weight < 0 or weight > 1000000 then
        return nil, 'Gewicht muss zwischen 0 und 1000000 Gramm liegen.'
    end
    if prop ~= '' and not prop:lower():match('^[a-z0-9_]+$') then
        return nil, 'Prop-Modell ungültig.'
    end
    if image == nil or not metadataEncoded or #metadataEncoded > 4000 then
        return nil, 'Bildpfad oder Standard-Metadaten ungültig beziehungsweise zu groß.'
    end

    local unique = data.unique == true
    return {
        name = name,
        label = label,
        description = description,
        category = category,
        rarity = rarity,
        maxStack = unique and 1 or maxStack,
        weight = weight,
        usable = data.usable == true,
        consumable = data.consumable == true,
        unique = unique,
        tradable = data.tradable ~= false,
        prop = prop:lower(),
        image = image,
        metadata = metadata,
        protected = false
    }
end

function CreateItem(data, createdBy)
    local ready, readyError = waitForItems()
    if not ready then return false, readyError end
    local item, validationError = validateItem(data)
    if not item then return false, validationError end
    if Items[item.name] then return false, 'Ein Item mit diesem technischen Namen existiert bereits.' end

    local inserted = MySQL.insert.await([[
        INSERT INTO mscore_items
            (name, label, description, category, rarity, max_stack, weight,
             usable, consumable, unique_item, tradable, prop_model, image,
             metadata, is_system, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
    ]], {
        item.name,
        item.label,
        item.description ~= '' and item.description or nil,
        item.category,
        item.rarity,
        item.maxStack,
        item.weight,
        item.usable and 1 or 0,
        item.consumable and 1 or 0,
        item.unique and 1 or 0,
        item.tradable and 1 or 0,
        item.prop ~= '' and item.prop or nil,
        item.image ~= '' and item.image or nil,
        json.encode(item.metadata),
        createdBy
    })
    if not inserted then return false, 'Item konnte nicht in die Datenbank geschrieben werden.' end
    Items[item.name] = item
    TriggerEvent('mscore:server:itemCatalogUpdated', GetItemCatalog())
    return true, item
end

local function scalarSafe(query, parameters)
    local success, value = pcall(function()
        return MySQL.scalar.await(query, parameters)
    end)
    return success and tonumber(value) or 0
end

local function itemUsage(name)
    for _, player in pairs(MSCore.GetPlayers and MSCore.GetPlayers() or {}) do
        if (tonumber(player:getInventory()[name]) or 0) > 0 then
            return 'Das Item befindet sich noch in einem aktiven Spielerinventar.'
        end
    end

    local pattern = ('%%"%s"%%'):format(name)
    if scalarSafe('SELECT COUNT(*) FROM mscore_characters WHERE metadata LIKE ?', { pattern }) > 0 then
        return 'Das Item befindet sich noch in einem gespeicherten Spielerinventar.'
    end
    if scalarSafe('SELECT COUNT(*) FROM mscore_storage_inventories WHERE items LIKE ?', { pattern }) > 0 then
        return 'Das Item befindet sich noch in einem Storage.'
    end
    if scalarSafe('SELECT COUNT(*) FROM mscore_crafting_recipes WHERE output_item = ? OR ingredients LIKE ?', {
        name, pattern
    }) > 0 then
        return 'Das Item wird noch in einem Crafting-Rezept verwendet.'
    end
end

function DeleteItem(name)
    local ready, readyError = waitForItems()
    if not ready then return false, readyError end
    name = type(name) == 'string' and name:lower()
    local item = name and Items[name]
    if not item then return false, 'Item nicht gefunden.' end
    if item.protected then return false, 'Systemitems aus der Core-Konfiguration können nicht gelöscht werden.' end
    local usageError = itemUsage(name)
    if usageError then return false, usageError end

    local affected = MySQL.update.await('DELETE FROM mscore_items WHERE name = ? AND is_system = 0', { name })
    if affected ~= 1 then return false, 'Item konnte nicht gelöscht werden.' end
    Items[name] = nil
    TriggerEvent('mscore:server:itemCatalogUpdated', GetItemCatalog())
    return true, item
end

exports('GetItem', GetItem)
exports('GetItemCatalog', GetItemCatalog)
exports('CreateItem', CreateItem)
exports('DeleteItem', DeleteItem)
