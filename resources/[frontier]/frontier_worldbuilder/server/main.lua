local Npcs = {}
local Storages = {}
local Doors = {}
local InventoryLocks = {}
local LastActions = {}
local Ready = false

local function notify(source, message)
    if source == 0 then
        print(('[Frontier World Builder] %s'):format(message))
        return
    end
    TriggerClientEvent('frontier:client:notify', source, message)
end

local function isBuilder(source)
    return source == 0 or IsPlayerAceAllowed(source, WorldBuilderConfig.Permission)
end

local function audit(source, action, detail)
    print(('[Frontier World Builder] %s (%d) | %s | %s'):format(
        source == 0 and 'Konsole' or (GetPlayerName(source) or 'Unbekannt'),
        source,
        action,
        detail or '-'
    ))
end

local function onCooldown(source, action, duration)
    local key = ('%d:%s'):format(source, action)
    local now = GetGameTimer()
    if LastActions[key] and now - LastActions[key] < duration then return true end
    LastActions[key] = now
    return false
end

local function getLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == 'license:' then return identifier end
    end
end

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function cleanText(value, maximum)
    if type(value) ~= 'string' then return end
    value = value:gsub('[%c]', ' '):match('^%s*(.-)%s*$')
    if #value < 2 or #value > maximum then return end
    return value
end

local function cleanJob(value)
    if value == nil or value == '' then return nil end
    if type(value) ~= 'string' then return end
    value = value:lower():match('^%s*(.-)%s*$')
    if #value > 32 or not value:match('^[%w_]+$') then return end
    return value
end

local function normalizeHeading(value)
    value = tonumber(value) or 0.0
    value = value % 360.0
    return value < 0 and value + 360.0 or value
end

local function coordinates(data)
    if type(data) ~= 'table' then return end
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not finite(x) or not finite(y) or not finite(z) then return end
    if math.abs(x) > 10000.0 or math.abs(y) > 10000.0 or z < -500.0 or z > 2000.0 then return end
    return x, y, z
end

local function distanceTo(source, data)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return math.huge end
    local coords = GetEntityCoords(ped)
    local dx, dy, dz = coords.x - data.x, coords.y - data.y, coords.z - data.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function mapCount(items)
    local count = 0
    for _ in pairs(items) do count = count + 1 end
    return count
end

local function sortedRows(items)
    local rows = {}
    for _, item in pairs(items) do rows[#rows + 1] = item end
    table.sort(rows, function(a, b) return a.id < b.id end)
    return rows
end

local function definitions()
    return {
        npcs = Npcs,
        storages = Storages,
        doors = Doors
    }
end

local function builderPayload()
    return {
        npcs = sortedRows(Npcs),
        storages = sortedRows(Storages),
        doors = sortedRows(Doors)
    }
end

local function syncAll()
    TriggerClientEvent('frontier_worldbuilder:client:sync', -1, definitions())
end

local function refreshBuilder(source)
    if isBuilder(source) then
        TriggerClientEvent('frontier_worldbuilder:client:builderData', source, builderPayload())
    end
end

local function result(source, success, message)
    TriggerClientEvent('frontier_worldbuilder:client:result', source, {
        success = success == true,
        message = message
    })
    if isBuilder(source) then refreshBuilder(source) end
end

local function rowToNpc(row)
    return {
        id = tonumber(row.id),
        label = row.label,
        model = row.model,
        scenario = row.scenario or '',
        x = tonumber(row.x),
        y = tonumber(row.y),
        z = tonumber(row.z),
        heading = tonumber(row.heading) or 0.0
    }
end

local function rowToStorage(row)
    return {
        id = tonumber(row.id),
        label = row.label,
        type = row.storage_type,
        capacity = tonumber(row.capacity),
        accessJob = row.access_job,
        x = tonumber(row.x),
        y = tonumber(row.y),
        z = tonumber(row.z),
        heading = tonumber(row.heading) or 0.0,
        radius = tonumber(row.interact_radius) or WorldBuilderConfig.DefaultStorageRadius
    }
end

local function rowToDoor(row)
    return {
        id = tonumber(row.id),
        label = row.label,
        modelHash = tonumber(row.model_hash),
        x = tonumber(row.x),
        y = tonumber(row.y),
        z = tonumber(row.z),
        heading = tonumber(row.heading) or 0.0,
        locked = row.locked == true or tonumber(row.locked) == 1,
        accessJob = row.access_job,
        radius = tonumber(row.interact_radius) or 2.0
    }
end

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS frontier_world_npcs (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            label VARCHAR(64) NOT NULL,
            model VARCHAR(100) NOT NULL,
            scenario VARCHAR(100) NULL,
            x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
            heading DOUBLE NOT NULL DEFAULT 0,
            created_by VARCHAR(64) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_frontier_world_npcs_position (x, y)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS frontier_storages (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            label VARCHAR(64) NOT NULL,
            storage_type ENUM('global','private') NOT NULL DEFAULT 'global',
            capacity INT UNSIGNED NOT NULL DEFAULT 100,
            access_job VARCHAR(32) NULL,
            x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
            heading DOUBLE NOT NULL DEFAULT 0,
            interact_radius DOUBLE NOT NULL DEFAULT 2,
            created_by VARCHAR(64) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_frontier_storages_position (x, y)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS frontier_storage_inventories (
            storage_id BIGINT UNSIGNED NOT NULL,
            owner_key VARCHAR(64) NOT NULL,
            items LONGTEXT NOT NULL,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (storage_id, owner_key),
            CONSTRAINT fk_frontier_storage_inventory_storage
                FOREIGN KEY (storage_id) REFERENCES frontier_storages (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS frontier_doors (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            label VARCHAR(64) NOT NULL,
            model_hash BIGINT NOT NULL,
            x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
            heading DOUBLE NOT NULL DEFAULT 0,
            locked TINYINT(1) NOT NULL DEFAULT 1,
            access_job VARCHAR(32) NULL,
            interact_radius DOUBLE NOT NULL DEFAULT 2,
            created_by VARCHAR(64) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_frontier_doors_position (x, y)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

MySQL.ready(function()
    createTables()
    for _, row in ipairs(MySQL.query.await('SELECT * FROM frontier_world_npcs ORDER BY id') or {}) do
        local npc = rowToNpc(row)
        Npcs[npc.id] = npc
    end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM frontier_storages ORDER BY id') or {}) do
        local storage = rowToStorage(row)
        Storages[storage.id] = storage
    end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM frontier_doors ORDER BY id') or {}) do
        local door = rowToDoor(row)
        Doors[door.id] = door
    end
    Ready = true
    print(('[Frontier World Builder] %d NPCs, %d Lager und %d Türen geladen.'):format(
        mapCount(Npcs), mapCount(Storages), mapCount(Doors)
    ))
end)

local function waitUntilReady()
    while not Ready do Wait(50) end
end

RegisterNetEvent('frontier_worldbuilder:server:requestSync', function()
    local source = source
    waitUntilReady()
    TriggerClientEvent('frontier_worldbuilder:client:sync', source, definitions())
end)

RegisterNetEvent('frontier_worldbuilder:server:openBuilder', function()
    local source = source
    if not isBuilder(source) then return notify(source, 'Keine Berechtigung für den World Builder.') end
    waitUntilReady()
    TriggerClientEvent('frontier_worldbuilder:client:openBuilder', source, builderPayload())
end)

RegisterNetEvent('frontier_worldbuilder:server:create', function(kind, data)
    local source = source
    if not isBuilder(source) or type(kind) ~= 'string' or type(data) ~= 'table' then return end
    if onCooldown(source, 'create', 500) then return end
    waitUntilReady()

    local label = cleanText(data.label, 64)
    local x, y, z = coordinates(data)
    if not label or not x or distanceTo(source, { x = x, y = y, z = z }) > WorldBuilderConfig.MaxPlacementDistance then
        return result(source, false, 'Bezeichnung oder Position ungültig beziehungsweise zu weit entfernt.')
    end

    if kind == 'npc' then
        if mapCount(Npcs) >= WorldBuilderConfig.MaxDefinitionsPerType then
            return result(source, false, 'Das NPC-Limit wurde erreicht.')
        end
        local model = type(data.model) == 'string' and data.model:lower()
        local scenario = type(data.scenario) == 'string' and data.scenario:upper() or ''
        if not model or #model < 2 or #model > 100 or not model:match('^[%w_]+$') then
            return result(source, false, 'NPC-Modell ungültig.')
        end
        if #scenario > 100 or (scenario ~= '' and not scenario:match('^[%w_]+$')) then
            return result(source, false, 'NPC-Szenario ungültig.')
        end
        local npc = {
            label = label,
            model = model,
            scenario = scenario,
            x = x, y = y, z = z,
            heading = normalizeHeading(data.heading)
        }
        npc.id = MySQL.insert.await([[
            INSERT INTO frontier_world_npcs
                (label, model, scenario, x, y, z, heading, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            npc.label, npc.model, npc.scenario ~= '' and npc.scenario or nil,
            npc.x, npc.y, npc.z, npc.heading, getLicense(source)
        })
        Npcs[npc.id] = npc
        syncAll()
        audit(source, 'NPC erstellt', ('#%d %s (%s)'):format(npc.id, npc.label, npc.model))
        return result(source, true, ('NPC #%d erstellt.'):format(npc.id))
    end

    if kind == 'storage' then
        if mapCount(Storages) >= WorldBuilderConfig.MaxDefinitionsPerType then
            return result(source, false, 'Das Lager-Limit wurde erreicht.')
        end
        local storageType = data.type == 'private' and 'private' or data.type == 'global' and 'global'
        local capacity = tonumber(data.capacity)
        local accessJob = cleanJob(data.accessJob)
        local radius = tonumber(data.radius) or WorldBuilderConfig.DefaultStorageRadius
        if not storageType or not capacity or capacity % 1 ~= 0 or capacity < 1
            or capacity > WorldBuilderConfig.MaxStorageCapacity or radius < 1.0 or radius > 5.0 then
            return result(source, false, 'Lagertyp, Kapazität oder Radius ungültig.')
        end
        if data.accessJob and data.accessJob ~= '' and not accessJob then
            return result(source, false, 'Job-Zugriff ungültig.')
        end
        local storage = {
            label = label,
            type = storageType,
            capacity = capacity,
            accessJob = accessJob,
            x = x, y = y, z = z,
            heading = normalizeHeading(data.heading),
            radius = radius
        }
        storage.id = MySQL.insert.await([[
            INSERT INTO frontier_storages
                (label, storage_type, capacity, access_job, x, y, z, heading, interact_radius, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            storage.label, storage.type, storage.capacity, storage.accessJob,
            storage.x, storage.y, storage.z, storage.heading, storage.radius, getLicense(source)
        })
        Storages[storage.id] = storage
        syncAll()
        audit(source, 'Lager erstellt', ('#%d %s (%s)'):format(storage.id, storage.label, storage.type))
        return result(source, true, ('Lager #%d erstellt.'):format(storage.id))
    end

    if kind == 'door' then
        if mapCount(Doors) >= WorldBuilderConfig.MaxDefinitionsPerType then
            return result(source, false, 'Das Tür-Limit wurde erreicht.')
        end
        local modelHash = tonumber(data.modelHash)
        local accessJob = cleanJob(data.accessJob)
        local radius = tonumber(data.radius) or 2.0
        if not modelHash or modelHash % 1 ~= 0 or math.abs(modelHash) > 4294967295
            or radius < 1.0 or radius > 5.0 then
            return result(source, false, 'Türmodell oder Radius ungültig.')
        end
        if data.accessJob and data.accessJob ~= '' and not accessJob then
            return result(source, false, 'Job-Zugriff ungültig.')
        end
        local door = {
            label = label,
            modelHash = modelHash,
            x = x, y = y, z = z,
            heading = normalizeHeading(data.heading),
            locked = data.locked ~= false,
            accessJob = accessJob,
            radius = radius
        }
        door.id = MySQL.insert.await([[
            INSERT INTO frontier_doors
                (label, model_hash, x, y, z, heading, locked, access_job, interact_radius, created_by)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            door.label, door.modelHash, door.x, door.y, door.z, door.heading,
            door.locked and 1 or 0, door.accessJob, door.radius, getLicense(source)
        })
        Doors[door.id] = door
        syncAll()
        audit(source, 'Tür erstellt', ('#%d %s (%s)'):format(door.id, door.label, door.modelHash))
        return result(source, true, ('Tür #%d erstellt.'):format(door.id))
    end

    result(source, false, 'Unbekannter Definitionstyp.')
end)

RegisterNetEvent('frontier_worldbuilder:server:delete', function(kind, id)
    local source = source
    if not isBuilder(source) then return end
    if onCooldown(source, 'delete', 500) then return end
    id = tonumber(id)
    local definitionsByKind = {
        npc = { items = Npcs, tableName = 'frontier_world_npcs' },
        storage = { items = Storages, tableName = 'frontier_storages' },
        door = { items = Doors, tableName = 'frontier_doors' }
    }
    local definition = definitionsByKind[kind]
    if not id or not definition or not definition.items[id] then
        return result(source, false, 'Eintrag nicht gefunden.')
    end
    MySQL.update.await(('DELETE FROM %s WHERE id = ?'):format(definition.tableName), { id })
    definition.items[id] = nil
    syncAll()
    audit(source, 'Eintrag gelöscht', ('%s #%d'):format(kind, id))
    result(source, true, ('Eintrag #%d gelöscht.'):format(id))
end)

local function canAccess(player, accessJob, source)
    return isBuilder(source) or not accessJob or player.job == accessJob
end

local function storageOwner(storage, player)
    return storage.type == 'global' and 'global' or ('character:%d'):format(player.characterId)
end

local function loadInventory(storageId, ownerKey)
    local encoded = MySQL.scalar.await(
        'SELECT items FROM frontier_storage_inventories WHERE storage_id = ? AND owner_key = ?',
        { storageId, ownerKey }
    )
    if not encoded then
        MySQL.update.await(
            'INSERT IGNORE INTO frontier_storage_inventories (storage_id, owner_key, items) VALUES (?, ?, ?)',
            { storageId, ownerKey, '{}' }
        )
        return {}
    end
    local inventory = json.decode(encoded)
    return type(inventory) == 'table' and inventory or {}
end

local function saveInventory(storageId, ownerKey, inventory)
    MySQL.update.await(
        'UPDATE frontier_storage_inventories SET items = ? WHERE storage_id = ? AND owner_key = ?',
        { json.encode(inventory), storageId, ownerKey }
    )
end

local function catalogMap()
    local items = {}
    for _, item in ipairs(exports.frontier_core:GetItemCatalog()) do items[item.name] = item end
    return items
end

local function inventoryTotal(inventory)
    local total = 0
    for _, amount in pairs(inventory) do total = total + math.max(tonumber(amount) or 0, 0) end
    return total
end

local function storageView(source, storage, player, ownerKey, inventory)
    local rows = {}
    local playerInventory = player:getInventory()
    for _, item in ipairs(exports.frontier_core:GetItemCatalog()) do
        rows[#rows + 1] = {
            name = item.name,
            label = item.label,
            description = item.description,
            maxStack = item.maxStack,
            playerAmount = tonumber(playerInventory[item.name]) or 0,
            storageAmount = tonumber(inventory[item.name]) or 0
        }
    end
    TriggerClientEvent('frontier_worldbuilder:client:openStorage', source, {
        id = storage.id,
        label = storage.label,
        type = storage.type,
        capacity = storage.capacity,
        used = inventoryTotal(inventory),
        ownerKey = ownerKey,
        items = rows
    })
end

local function openStorage(source, storageId)
    local storage = Storages[tonumber(storageId)]
    local player = exports.frontier_core:GetPlayer(source)
    if not storage or not player then return end
    if distanceTo(source, storage) > storage.radius + 1.5 then
        return notify(source, 'Du bist zu weit vom Lager entfernt.')
    end
    if not canAccess(player, storage.accessJob, source) then
        return notify(source, 'Du hast keinen Zugriff auf dieses Lager.')
    end
    local ownerKey = storageOwner(storage, player)
    storageView(source, storage, player, ownerKey, loadInventory(storage.id, ownerKey))
end

RegisterNetEvent('frontier_worldbuilder:server:openStorage', function(storageId)
    if onCooldown(source, 'open_storage', 300) then return end
    openStorage(source, storageId)
end)

RegisterNetEvent('frontier_worldbuilder:server:transfer', function(storageId, direction, itemName, rawAmount)
    local source = source
    if onCooldown(source, 'transfer', 200) then return end
    local storage = Storages[tonumber(storageId)]
    local player = exports.frontier_core:GetPlayer(source)
    local amount = tonumber(rawAmount)
    if not storage or not player or (direction ~= 'deposit' and direction ~= 'withdraw')
        or type(itemName) ~= 'string' or not amount or amount % 1 ~= 0
        or amount < 1 or amount > WorldBuilderConfig.TransferLimit then
        return TriggerClientEvent('frontier_worldbuilder:client:result', source, {
            success = false,
            message = 'Transferdaten ungültig.'
        })
    end
    if distanceTo(source, storage) > storage.radius + 1.5 or not canAccess(player, storage.accessJob, source) then
        return notify(source, 'Lagerzugriff nicht möglich.')
    end

    local catalog = catalogMap()
    if not catalog[itemName] then return notify(source, 'Unbekanntes Item.') end
    local ownerKey = storageOwner(storage, player)
    local lockKey = ('%d:%s'):format(storage.id, ownerKey)
    if InventoryLocks[lockKey] then return notify(source, 'Dieses Lager wird gerade verwendet.') end
    InventoryLocks[lockKey] = true

    local inventory = loadInventory(storage.id, ownerKey)
    local success, message
    if direction == 'deposit' then
        if inventoryTotal(inventory) + amount > storage.capacity then
            message = 'Das Lager hat nicht genügend freie Kapazität.'
        elseif player:removeItem(itemName, amount, 'storage_deposit') then
            inventory[itemName] = (tonumber(inventory[itemName]) or 0) + amount
            saveInventory(storage.id, ownerKey, inventory)
            player:save()
            success, message = true, ('%dx %s eingelagert.'):format(amount, catalog[itemName].label)
        else
            message = 'Du besitzt nicht genügend Items.'
        end
    else
        local stored = tonumber(inventory[itemName]) or 0
        if stored < amount then
            message = 'Im Lager sind nicht genügend Items.'
        elseif player:addItem(itemName, amount, 'storage_withdraw') then
            local remaining = stored - amount
            inventory[itemName] = remaining > 0 and remaining or nil
            saveInventory(storage.id, ownerKey, inventory)
            player:save()
            success, message = true, ('%dx %s entnommen.'):format(amount, catalog[itemName].label)
        else
            message = 'Dein Inventar kann diese Menge nicht aufnehmen.'
        end
    end
    InventoryLocks[lockKey] = nil

    TriggerClientEvent('frontier_worldbuilder:client:result', source, {
        success = success == true,
        message = message
    })
    storageView(source, storage, player, ownerKey, inventory)
end)

local function toggleDoor(source, doorId, requireNearby)
    if onCooldown(source, 'door', 500) then return end
    local door = Doors[tonumber(doorId)]
    local player = exports.frontier_core:GetPlayer(source)
    if not door or not player then return end
    if requireNearby and distanceTo(source, door) > door.radius + 1.5 then
        return notify(source, 'Du bist zu weit von der Tür entfernt.')
    end
    if not canAccess(player, door.accessJob, source) then
        return notify(source, 'Du hast keinen Schlüssel für diese Tür.')
    end
    door.locked = not door.locked
    MySQL.update.await('UPDATE frontier_doors SET locked = ? WHERE id = ?', { door.locked and 1 or 0, door.id })
    TriggerClientEvent('frontier_worldbuilder:client:updateDoor', -1, door)
    notify(source, door.locked and 'Tür abgeschlossen.' or 'Tür aufgeschlossen.')
    if isBuilder(source) then
        audit(source, door.locked and 'Tür abgeschlossen' or 'Tür aufgeschlossen', ('#%d %s'):format(door.id, door.label))
        refreshBuilder(source)
    end
end

RegisterNetEvent('frontier_worldbuilder:server:interactDoor', function(doorId)
    toggleDoor(source, doorId, true)
end)

RegisterNetEvent('frontier_worldbuilder:server:builderToggleDoor', function(doorId)
    local source = source
    if not isBuilder(source) then return end
    toggleDoor(source, doorId, false)
end)

AddEventHandler('frontier:server:playerLoaded', function(source)
    SetTimeout(1200, function()
        if GetPlayerName(source) then
            TriggerClientEvent('frontier_worldbuilder:client:sync', source, definitions())
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local prefix = ('%d:'):format(source)
    for key in pairs(LastActions) do
        if key:sub(1, #prefix) == prefix then LastActions[key] = nil end
    end
end)
