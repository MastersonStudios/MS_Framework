local Objects = {}
local UndoStacks = {}
local LastMutation = {}
local Ready = false

local function notify(source, message)
    if source == 0 then
        print(('[Frontier Mapeditor] %s'):format(message))
        return
    end
    TriggerClientEvent('frontier:client:notify', source, message)
end

local function hasPermission(source)
    return source == 0 or IsPlayerAceAllowed(source, MapEditorConfig.Permission)
end

local function getLicense(source)
    for _, value in ipairs(GetPlayerIdentifiers(source)) do
        if value:sub(1, 8) == 'license:' then return value end
    end
end

local function numberIsFinite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

local function normalizeRotation(value)
    value = value % 360.0
    if value < 0 then value = value + 360.0 end
    return value
end

local CatalogModels = {}
for _, item in ipairs(MapEditorConfig.ObjectCatalog) do
    CatalogModels[item.model:lower()] = true
end

local function validateData(data)
    if type(data) ~= 'table' or type(data.model) ~= 'string' then
        return nil, 'Ungültige Objektdaten.'
    end

    local model = data.model:lower()
    if #model < 2 or #model > 100 or not model:match('^[%w_]+$') then
        return nil, 'Ungültiger Modellname.'
    end
    if not MapEditorConfig.AllowCustomModels and not CatalogModels[model] then
        return nil, 'Dieses Modell ist nicht im Objektkatalog.'
    end

    local values = {
        tonumber(data.x), tonumber(data.y), tonumber(data.z),
        tonumber(data.rotX) or 0.0, tonumber(data.rotY) or 0.0, tonumber(data.rotZ) or 0.0
    }
    for _, value in ipairs(values) do
        if not numberIsFinite(value) then return nil, 'Ungültige Koordinaten.' end
    end
    if math.abs(values[1]) > 10000 or math.abs(values[2]) > 10000 or math.abs(values[3]) > 2000 then
        return nil, 'Koordinaten außerhalb des erlaubten Bereichs.'
    end

    return {
        model = model,
        x = values[1],
        y = values[2],
        z = values[3],
        rotX = normalizeRotation(values[4]),
        rotY = normalizeRotation(values[5]),
        rotZ = normalizeRotation(values[6]),
        collision = data.collision ~= false,
        frozen = data.frozen ~= false
    }
end

local function isNearPlayer(source, data)
    if source == 0 then return true end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local dx, dy, dz = coords.x - data.x, coords.y - data.y, coords.z - data.z
    return (dx * dx + dy * dy + dz * dz) <= (MapEditorConfig.MaxEditDistance ^ 2)
end

local function canMutate(source)
    if not hasPermission(source) then
        notify(source, 'Keine Berechtigung für den Mapeditor.')
        return false
    end
    local now = GetGameTimer()
    if source ~= 0 and LastMutation[source] and now - LastMutation[source] < MapEditorConfig.SaveCooldown then
        return false
    end
    LastMutation[source] = now
    return true
end

local function cloneObject(object)
    local copy = {}
    for key, value in pairs(object) do copy[key] = value end
    return copy
end

local function pushUndo(source, action)
    if source == 0 then return end
    UndoStacks[source] = UndoStacks[source] or {}
    table.insert(UndoStacks[source], action)
    while #UndoStacks[source] > 20 do table.remove(UndoStacks[source], 1) end
end

local function rowToObject(row)
    return {
        id = tonumber(row.id),
        model = row.model,
        x = tonumber(row.x),
        y = tonumber(row.y),
        z = tonumber(row.z),
        rotX = tonumber(row.rot_x),
        rotY = tonumber(row.rot_y),
        rotZ = tonumber(row.rot_z),
        collision = row.collision_enabled == true or tonumber(row.collision_enabled) == 1,
        frozen = row.frozen == true or tonumber(row.frozen) == 1
    }
end

local function insertObject(data, createdBy)
    local id = MySQL.insert.await([[
        INSERT INTO frontier_map_objects
            (model, x, y, z, rot_x, rot_y, rot_z, collision_enabled, frozen, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.model, data.x, data.y, data.z, data.rotX, data.rotY, data.rotZ,
        data.collision and 1 or 0, data.frozen and 1 or 0, createdBy
    })
    data.id = id
    Objects[id] = data
    return id
end

local function updateObject(data)
    MySQL.update.await([[
        UPDATE frontier_map_objects
        SET model = ?, x = ?, y = ?, z = ?, rot_x = ?, rot_y = ?, rot_z = ?,
            collision_enabled = ?, frozen = ?
        WHERE id = ?
    ]], {
        data.model, data.x, data.y, data.z, data.rotX, data.rotY, data.rotZ,
        data.collision and 1 or 0, data.frozen and 1 or 0, data.id
    })
    Objects[data.id] = data
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS frontier_map_objects (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            model VARCHAR(100) NOT NULL,
            x DOUBLE NOT NULL,
            y DOUBLE NOT NULL,
            z DOUBLE NOT NULL,
            rot_x DOUBLE NOT NULL DEFAULT 0,
            rot_y DOUBLE NOT NULL DEFAULT 0,
            rot_z DOUBLE NOT NULL DEFAULT 0,
            collision_enabled TINYINT(1) NOT NULL DEFAULT 1,
            frozen TINYINT(1) NOT NULL DEFAULT 1,
            created_by VARCHAR(64) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_frontier_map_objects_position (x, y)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    for _, row in ipairs(MySQL.query.await('SELECT * FROM frontier_map_objects ORDER BY id') or {}) do
        local object = rowToObject(row)
        Objects[object.id] = object
    end
    Ready = true
    print(('[Frontier Mapeditor] %d Objekte geladen.'):format(#(MySQL.query.await('SELECT id FROM frontier_map_objects') or {})))
end)

RegisterNetEvent('frontier_mapeditor:server:requestSync', function()
    local source = source
    while not Ready do Wait(50) end
    TriggerClientEvent('frontier_mapeditor:client:sync', source, Objects)
end)

RegisterNetEvent('frontier_mapeditor:server:create', function(rawData)
    local source = source
    if not canMutate(source) then return end
    if MySQL.scalar.await('SELECT COUNT(*) FROM frontier_map_objects') >= MapEditorConfig.MaxObjects then
        return notify(source, 'Das Objektlimit wurde erreicht.')
    end
    local data, err = validateData(rawData)
    if not data then return notify(source, err) end
    if not isNearPlayer(source, data) then return notify(source, 'Das Objekt ist zu weit entfernt.') end

    local id = insertObject(data, getLicense(source))
    pushUndo(source, { type = 'create', id = id })
    TriggerClientEvent('frontier_mapeditor:client:upsert', -1, data)
    notify(source, ('Objekt #%d gespeichert.'):format(id))
end)

RegisterNetEvent('frontier_mapeditor:server:update', function(id, rawData)
    local source = source
    id = tonumber(id)
    if not canMutate(source) or not id or not Objects[id] then return end
    local data, err = validateData(rawData)
    if not data then return notify(source, err) end
    if not isNearPlayer(source, data) then return notify(source, 'Das Objekt ist zu weit entfernt.') end

    pushUndo(source, { type = 'update', object = cloneObject(Objects[id]) })
    data.id = id
    updateObject(data)
    TriggerClientEvent('frontier_mapeditor:client:upsert', -1, data)
    notify(source, ('Objekt #%d aktualisiert.'):format(id))
end)

RegisterNetEvent('frontier_mapeditor:server:delete', function(id)
    local source = source
    id = tonumber(id)
    local object = id and Objects[id]
    if not canMutate(source) or not object then return end
    if not isNearPlayer(source, object) then return notify(source, 'Das Objekt ist zu weit entfernt.') end

    pushUndo(source, { type = 'delete', object = cloneObject(object) })
    MySQL.update.await('DELETE FROM frontier_map_objects WHERE id = ?', { id })
    Objects[id] = nil
    TriggerClientEvent('frontier_mapeditor:client:remove', -1, id)
    notify(source, ('Objekt #%d gelöscht.'):format(id))
end)

RegisterCommand('mapeditor', function(source, args)
    if source == 0 then return notify(source, 'Dieser Command ist nur ingame verfügbar.') end
    if not hasPermission(source) then return notify(source, 'Keine Berechtigung für den Mapeditor.') end
    TriggerClientEvent('frontier_mapeditor:client:create', source, args[1])
end, false)

RegisterCommand('mapedit', function(source, args)
    if source == 0 or not hasPermission(source) then return notify(source, 'Keine Berechtigung für den Mapeditor.') end
    TriggerClientEvent('frontier_mapeditor:client:edit', source, tonumber(args[1]))
end, false)

RegisterCommand('mapdelete', function(source, args)
    if source == 0 or not hasPermission(source) then return notify(source, 'Keine Berechtigung für den Mapeditor.') end
    TriggerClientEvent('frontier_mapeditor:client:deleteNearest', source, tonumber(args[1]))
end, false)

RegisterCommand('mapobjects', function(source)
    if source == 0 or not hasPermission(source) then return notify(source, 'Keine Berechtigung für den Mapeditor.') end
    TriggerClientEvent('frontier_mapeditor:client:listNearby', source)
end, false)

RegisterCommand('mapcatalog', function(source)
    if source == 0 or not hasPermission(source) then return notify(source, 'Keine Berechtigung für den Mapeditor.') end
    local parts = {}
    for _, item in ipairs(MapEditorConfig.ObjectCatalog) do
        parts[#parts + 1] = ('%s (%s)'):format(item.label, item.model)
    end
    notify(source, table.concat(parts, ', '))
end, false)

RegisterCommand('mapundo', function(source)
    if source == 0 or not canMutate(source) then return end
    local stack = UndoStacks[source]
    local action = stack and table.remove(stack)
    if not action then return notify(source, 'Keine Änderung zum Rückgängigmachen.') end

    if action.type == 'create' then
        MySQL.update.await('DELETE FROM frontier_map_objects WHERE id = ?', { action.id })
        Objects[action.id] = nil
        TriggerClientEvent('frontier_mapeditor:client:remove', -1, action.id)
    elseif action.type == 'update' then
        updateObject(action.object)
        TriggerClientEvent('frontier_mapeditor:client:upsert', -1, action.object)
    elseif action.type == 'delete' then
        local restored = cloneObject(action.object)
        restored.id = nil
        local id = insertObject(restored, getLicense(source))
        TriggerClientEvent('frontier_mapeditor:client:upsert', -1, restored)
        notify(source, ('Gelöschtes Objekt wurde als #%d wiederhergestellt.'):format(id))
        return
    end
    notify(source, 'Letzte Änderung rückgängig gemacht.')
end, false)

AddEventHandler('playerDropped', function()
    LastMutation[source] = nil
    UndoStacks[source] = nil
end)
