local FrozenPlayers = {}
local OpenMenus = {}
local AdminGrants = {}
local CraftingRecipes = {}
local CraftingPoints = {}
local CraftingLocks = {}
local LastActions = {}
local CurrentWeather = AdminMenuConfig.DefaultWeather
local CurrentTransition = AdminMenuConfig.DefaultTransition
local Ready = false

local function notify(source, message)
    if source == 0 then
        print(('[Frontier ACP] %s'):format(message))
        return
    end
    TriggerClientEvent('frontier:client:notify', source, message)
end

local function audit(source, action, target, detail)
    print(('[Frontier ACP] %s (%d) | %s | Ziel: %s | %s'):format(
        source == 0 and 'Konsole' or (GetPlayerName(source) or 'Unbekannt'),
        source,
        action,
        target and tostring(target) or '-',
        detail or '-'
    ))
end

local function getLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == 'license:' then return identifier end
    end
end

local function isRoot(source)
    return source == 0
        or IsPlayerAceAllowed(source, AdminMenuConfig.Permission)
        or IsPlayerAceAllowed(source, 'frontier.admin')
end

local function knownPermission(permission)
    if type(permission) ~= 'string' then return false end
    for _, definition in ipairs(AdminMenuConfig.Permissions) do
        if definition.id == permission then return true end
    end
    return false
end

local function hasPermission(source, permission)
    source = tonumber(source)
    if not source or not knownPermission(permission) then return false end
    if isRoot(source) then return true end
    local grant = AdminGrants[getLicense(source)]
    return grant ~= nil
        and type(grant.permissions) == 'table'
        and grant.permissions.access == true
        and grant.permissions[permission] == true
end

local function isAdmin(source)
    return hasPermission(source, 'access')
end

exports('HasPermission', hasPermission)

local function decodeTable(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end
    local success, decoded = pcall(json.decode, value)
    return success and type(decoded) == 'table' and decoded or {}
end

local function finite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function cleanText(value, maximum, optional)
    if value == nil or value == '' then return optional and '' or nil end
    if type(value) ~= 'string' then return end
    value = value:gsub('[%c]', ' '):match('^%s*(.-)%s*$')
    if (not optional and #value < 2) or #value > maximum then return end
    return value
end

local function cleanJob(value)
    if value == nil or value == '' then return nil end
    if type(value) ~= 'string' then return end
    value = value:lower():match('^%s*(.-)%s*$')
    if #value > 32 or not value:match('^[%w_]+$') then return end
    return value
end

local function positiveInteger(value, maximum)
    value = tonumber(value)
    if not value or value % 1 ~= 0 or value < 1 or value > maximum then return end
    return value
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

local function onCooldown(source, action, duration)
    local key = ('%d:%s'):format(source, action)
    local now = GetGameTimer()
    if LastActions[key] and now - LastActions[key] < duration then return true end
    LastActions[key] = now
    return false
end

local function weatherById(weatherId)
    if type(weatherId) ~= 'string' then return end
    for _, weather in ipairs(AdminMenuConfig.Weathers) do
        if weather.id == weatherId then return weather end
    end
end

local function weatherRows()
    local rows = {}
    for _, weather in ipairs(AdminMenuConfig.Weathers) do
        rows[#rows + 1] = {
            id = weather.id,
            label = weather.label,
            description = weather.description
        }
    end
    return rows
end

local function playerCoordinates(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = GetEntityHeading(ped)
    }
end

local function inventoryCount(player)
    local count = 0
    local inventory = player.metadata and player.metadata.inventory
    if type(inventory) ~= 'table' then return count end
    for _, amount in pairs(inventory) do
        count = count + math.max(tonumber(amount) or 0, 0)
    end
    return count
end

local function playerRows(includePermissions)
    local rows = {}
    for source, player in pairs(exports.frontier_core:GetPlayers()) do
        source = tonumber(source)
        if source and GetPlayerName(source) then
            local ped = GetPlayerPed(source)
            local health = ped and ped ~= 0 and GetEntityHealth(ped) or 0
            local identifier = getLicense(source)
            local grant = identifier and AdminGrants[identifier]
            local row = {
                source = source,
                serverName = GetPlayerName(source),
                characterName = player:getName(),
                characterId = player.characterId,
                job = player.job,
                jobGrade = player.jobGrade,
                cash = player.money.cash,
                bank = player.money.bank,
                ping = GetPlayerPing(source),
                health = health,
                frozen = FrozenPlayers[source] == true,
                itemCount = inventoryCount(player)
            }
            if includePermissions then
                row.acpGranted = grant ~= nil
                row.permissions = grant and grant.permissions or {}
                row.aceRoot = isRoot(source)
            end
            rows[#rows + 1] = row
        end
    end
    table.sort(rows, function(a, b) return a.source < b.source end)
    return rows
end

local function sourceForIdentifier(identifier)
    for _, value in ipairs(GetPlayers()) do
        local source = tonumber(value)
        if source and getLicense(source) == identifier then return source end
    end
end

local function adminRows()
    local rows = {}
    for identifier, grant in pairs(AdminGrants) do
        rows[#rows + 1] = {
            identifier = identifier,
            displayName = grant.displayName,
            permissions = grant.permissions,
            assignedBy = grant.assignedBy,
            source = sourceForIdentifier(identifier)
        }
    end
    table.sort(rows, function(a, b)
        return (a.displayName or a.identifier):lower() < (b.displayName or b.identifier):lower()
    end)
    return rows
end

local function permissionState(source)
    local permissions = {}
    for _, definition in ipairs(AdminMenuConfig.Permissions) do
        permissions[definition.id] = hasPermission(source, definition.id)
    end
    return permissions
end

local function rowToRecipe(row)
    return {
        id = tonumber(row.id),
        label = row.label,
        description = row.description or '',
        outputItem = row.output_item,
        outputAmount = tonumber(row.output_amount) or 1,
        ingredients = decodeTable(row.ingredients),
        duration = tonumber(row.duration_ms) or 1000,
        active = row.active == true or tonumber(row.active) == 1
    }
end

local function rowToPoint(row)
    local recipeIds = {}
    for _, id in ipairs(decodeTable(row.recipe_ids)) do
        id = tonumber(id)
        if id then recipeIds[#recipeIds + 1] = id end
    end
    return {
        id = tonumber(row.id),
        label = row.label,
        x = tonumber(row.x),
        y = tonumber(row.y),
        z = tonumber(row.z),
        heading = tonumber(row.heading) or 0.0,
        radius = tonumber(row.interact_radius) or AdminMenuConfig.DefaultCraftingRadius,
        accessJob = row.access_job,
        recipeIds = recipeIds,
        active = row.active == true or tonumber(row.active) == 1
    }
end

local function craftingSyncPayload()
    local points = {}
    for _, point in pairs(CraftingPoints) do
        if point.active then
            points[#points + 1] = {
                id = point.id,
                label = point.label,
                x = point.x,
                y = point.y,
                z = point.z,
                radius = point.radius,
                accessJob = point.accessJob
            }
        end
    end
    table.sort(points, function(a, b) return a.id < b.id end)
    return points
end

local function syncCraftingPoints(target)
    TriggerClientEvent('frontier_adminmenu:client:craftingSync', target or -1, craftingSyncPayload())
end

local function itemCatalogMap()
    local items = {}
    for _, item in ipairs(exports.frontier_core:GetItemCatalog()) do
        items[item.name] = item
    end
    return items
end

local function worldBuilderData(source)
    if not hasPermission(source, 'world') or GetResourceState('frontier_worldbuilder') ~= 'started' then
        return nil
    end
    local success, data = pcall(function()
        return exports.frontier_worldbuilder:GetAcpData(source)
    end)
    return success and data or nil
end

local function payload(source)
    local permissions = permissionState(source)
    return {
        selfId = source,
        players = playerRows(permissions.rights),
        items = exports.frontier_core:GetItemCatalog(),
        weathers = weatherRows(),
        currentWeather = CurrentWeather,
        currentTransition = CurrentTransition,
        permissions = permissions,
        permissionDefinitions = AdminMenuConfig.Permissions,
        root = isRoot(source),
        admins = permissions.rights and adminRows() or {},
        crafting = permissions.crafting and {
            recipes = sortedRows(CraftingRecipes),
            points = sortedRows(CraftingPoints)
        } or nil,
        worldBuilder = worldBuilderData(source),
        limits = {
            money = AdminMenuConfig.MaxMoneyGrant,
            items = AdminMenuConfig.MaxItemGrant,
            weatherTransition = AdminMenuConfig.MaxWeatherTransition,
            craftingAmount = AdminMenuConfig.MaxCraftingAmount,
            craftingIngredients = AdminMenuConfig.MaxCraftingIngredients,
            craftingDuration = AdminMenuConfig.MaxCraftingDuration
        }
    }
end

local function refresh(source)
    if source ~= 0 and OpenMenus[source] and isAdmin(source) then
        TriggerClientEvent('frontier_adminmenu:client:refresh', source, payload(source))
    end
end

local function refreshAllMenus()
    for source in pairs(OpenMenus) do refresh(source) end
end

local function result(source, success, message)
    TriggerClientEvent('frontier_adminmenu:client:result', source, {
        success = success == true,
        message = message
    })
    refresh(source)
end

local function activeTarget(data)
    local target = type(data) == 'table' and tonumber(data.target)
    local player = target and exports.frontier_core:GetPlayer(target)
    if not target or not player or not GetPlayerName(target) then return end
    return target, player
end

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS frontier_admin_permissions (
            identifier VARCHAR(100) NOT NULL,
            display_name VARCHAR(80) NOT NULL,
            permissions LONGTEXT NOT NULL,
            assigned_by VARCHAR(100) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (identifier)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS frontier_crafting_recipes (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            label VARCHAR(64) NOT NULL,
            description VARCHAR(255) NULL,
            output_item VARCHAR(64) NOT NULL,
            output_amount INT UNSIGNED NOT NULL DEFAULT 1,
            ingredients LONGTEXT NOT NULL,
            duration_ms INT UNSIGNED NOT NULL DEFAULT 1000,
            active TINYINT(1) NOT NULL DEFAULT 1,
            created_by VARCHAR(100) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS frontier_crafting_points (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            label VARCHAR(64) NOT NULL,
            x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL,
            heading DOUBLE NOT NULL DEFAULT 0,
            interact_radius DOUBLE NOT NULL DEFAULT 2,
            access_job VARCHAR(32) NULL,
            recipe_ids LONGTEXT NOT NULL,
            active TINYINT(1) NOT NULL DEFAULT 1,
            created_by VARCHAR(100) NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_frontier_crafting_points_position (x, y)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

MySQL.ready(function()
    createTables()
    for _, row in ipairs(MySQL.query.await('SELECT * FROM frontier_admin_permissions') or {}) do
        AdminGrants[row.identifier] = {
            displayName = row.display_name,
            permissions = decodeTable(row.permissions),
            assignedBy = row.assigned_by
        }
    end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM frontier_crafting_recipes ORDER BY id') or {}) do
        local recipe = rowToRecipe(row)
        CraftingRecipes[recipe.id] = recipe
    end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM frontier_crafting_points ORDER BY id') or {}) do
        local point = rowToPoint(row)
        CraftingPoints[point.id] = point
    end
    Ready = true
    syncCraftingPoints()
    print(('[Frontier ACP] %d Rechteprofile, %d Rezepte und %d Crafting-Punkte geladen.'):format(
        mapCount(AdminGrants),
        mapCount(CraftingRecipes),
        mapCount(CraftingPoints)
    ))
end)

local function setPermissions(source, data)
    if not hasPermission(source, 'rights') then
        return result(source, false, 'Keine Berechtigung für die Rechteverwaltung.')
    end
    local target = tonumber(data.target)
    if not target or not GetPlayerName(target) then
        return result(source, false, 'Der Spieler muss online sein.')
    end
    if isRoot(target) then
        return result(source, false, 'ACE-Rootrechte werden ausschließlich in der server.cfg verwaltet.')
    end
    if target == source and not isRoot(source) then
        return result(source, false, 'Du kannst dein eigenes Rechteprofil nicht verändern.')
    end
    local identifier = getLicense(target)
    if not identifier then return result(source, false, 'Keine Rockstar-Lizenz gefunden.') end

    local selected = type(data.permissions) == 'table' and data.permissions or {}
    local permissions, count = {}, 0
    for _, definition in ipairs(AdminMenuConfig.Permissions) do
        if selected[definition.id] == true then
            permissions[definition.id] = true
            count = count + 1
        end
    end
    if count == 0 then
        AdminGrants[identifier] = nil
        MySQL.update.await('DELETE FROM frontier_admin_permissions WHERE identifier = ?', { identifier })
        OpenMenus[target] = nil
        TriggerClientEvent('frontier_adminmenu:client:forceClose', target)
        TriggerClientEvent('frontier:client:notify', target, 'Deine ACP-Rechte wurden entzogen.')
        audit(source, 'ACP-Rechte entzogen', target)
        refreshAllMenus()
        return result(source, true, 'ACP-Rechte vollständig entzogen.')
    end

    permissions.access = true
    local assignedBy = getLicense(source) or 'console'
    local displayName = GetPlayerName(target) or identifier
    MySQL.update.await([[
        INSERT INTO frontier_admin_permissions
            (identifier, display_name, permissions, assigned_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            display_name = VALUES(display_name),
            permissions = VALUES(permissions),
            assigned_by = VALUES(assigned_by)
    ]], { identifier, displayName, json.encode(permissions), assignedBy })
    AdminGrants[identifier] = {
        displayName = displayName,
        permissions = permissions,
        assignedBy = assignedBy
    }
    audit(source, 'ACP-Rechte gespeichert', target, json.encode(permissions))
    refreshAllMenus()
    TriggerClientEvent('frontier:client:notify', target, 'Deine ACP-Rechte wurden aktualisiert.')
    return result(source, true, ('Rechte für %s gespeichert.'):format(displayName))
end

local function revokePermissions(source, data)
    if not hasPermission(source, 'rights') then
        return result(source, false, 'Keine Berechtigung für die Rechteverwaltung.')
    end
    local identifier = type(data.identifier) == 'string' and data.identifier
    if not identifier or not AdminGrants[identifier] then
        return result(source, false, 'Rechteprofil nicht gefunden.')
    end
    if identifier == getLicense(source) and not isRoot(source) then
        return result(source, false, 'Du kannst dein eigenes Rechteprofil nicht entfernen.')
    end
    local target = sourceForIdentifier(identifier)
    if target and isRoot(target) then
        return result(source, false, 'ACE-Rootrechte werden ausschließlich in der server.cfg verwaltet.')
    end
    local displayName = AdminGrants[identifier].displayName or identifier
    MySQL.update.await('DELETE FROM frontier_admin_permissions WHERE identifier = ?', { identifier })
    AdminGrants[identifier] = nil
    audit(source, 'ACP-Rechte entzogen', target, displayName)
    if target then
        TriggerClientEvent('frontier:client:notify', target, 'Deine ACP-Rechte wurden entzogen.')
        if not isAdmin(target) then TriggerClientEvent('frontier_adminmenu:client:forceClose', target) end
    end
    refreshAllMenus()
    return result(source, true, ('Rechteprofil %s entfernt.'):format(displayName))
end

local function cleanIngredients(rawIngredients, outputItem)
    if type(rawIngredients) ~= 'table' or #rawIngredients < 1
        or #rawIngredients > AdminMenuConfig.MaxCraftingIngredients then return end
    local catalog = itemCatalogMap()
    if not catalog[outputItem] then return end
    local totals = {}
    for _, ingredient in ipairs(rawIngredients) do
        local item = type(ingredient) == 'table' and ingredient.item
        local amount = type(ingredient) == 'table'
            and positiveInteger(ingredient.amount, AdminMenuConfig.MaxCraftingAmount)
        if type(item) ~= 'string' or not catalog[item] or not amount then return end
        totals[item] = (totals[item] or 0) + amount
        if totals[item] > AdminMenuConfig.MaxCraftingAmount then return end
    end
    local ingredients = {}
    for item, amount in pairs(totals) do
        ingredients[#ingredients + 1] = { item = item, amount = amount }
    end
    table.sort(ingredients, function(a, b) return a.item < b.item end)
    return ingredients
end

local function createRecipe(source, data)
    if not hasPermission(source, 'crafting') then
        return result(source, false, 'Keine Berechtigung für Crafting.')
    end
    if mapCount(CraftingRecipes) >= AdminMenuConfig.MaxCraftingDefinitions then
        return result(source, false, 'Das Rezeptlimit wurde erreicht.')
    end
    local label = cleanText(data.label, 64)
    local description = cleanText(data.description, 255, true)
    local outputItem = type(data.outputItem) == 'string' and data.outputItem
    local outputAmount = positiveInteger(data.outputAmount, AdminMenuConfig.MaxCraftingAmount)
    local duration = positiveInteger(data.duration, AdminMenuConfig.MaxCraftingDuration)
    local ingredients = cleanIngredients(data.ingredients, outputItem)
    if not label or description == nil or not outputAmount or not duration or not ingredients then
        return result(source, false, 'Rezeptdaten ungültig.')
    end

    local recipe = {
        label = label,
        description = description,
        outputItem = outputItem,
        outputAmount = outputAmount,
        ingredients = ingredients,
        duration = duration,
        active = true
    }
    recipe.id = MySQL.insert.await([[
        INSERT INTO frontier_crafting_recipes
            (label, description, output_item, output_amount, ingredients, duration_ms, active, created_by)
        VALUES (?, ?, ?, ?, ?, ?, 1, ?)
    ]], {
        recipe.label,
        recipe.description ~= '' and recipe.description or nil,
        recipe.outputItem,
        recipe.outputAmount,
        json.encode(recipe.ingredients),
        recipe.duration,
        getLicense(source)
    })
    CraftingRecipes[recipe.id] = recipe
    audit(source, 'Crafting-Rezept erstellt', recipe.id, recipe.label)
    refreshAllMenus()
    return result(source, true, ('Rezept #%d erstellt.'):format(recipe.id))
end

local function deleteRecipe(source, data)
    if not hasPermission(source, 'crafting') then
        return result(source, false, 'Keine Berechtigung für Crafting.')
    end
    local id = tonumber(data.id)
    if not id or not CraftingRecipes[id] then return result(source, false, 'Rezept nicht gefunden.') end
    MySQL.update.await('DELETE FROM frontier_crafting_recipes WHERE id = ?', { id })
    CraftingRecipes[id] = nil
    for _, point in pairs(CraftingPoints) do
        local recipeIds, changed = {}, false
        for _, recipeId in ipairs(point.recipeIds) do
            if recipeId == id then
                changed = true
            else
                recipeIds[#recipeIds + 1] = recipeId
            end
        end
        if changed then
            point.recipeIds = recipeIds
            MySQL.update.await(
                'UPDATE frontier_crafting_points SET recipe_ids = ? WHERE id = ?',
                { json.encode(recipeIds), point.id }
            )
        end
    end
    audit(source, 'Crafting-Rezept gelöscht', id)
    refreshAllMenus()
    return result(source, true, ('Rezept #%d gelöscht.'):format(id))
end

local function createCraftingPoint(source, data)
    if not hasPermission(source, 'crafting') then
        return result(source, false, 'Keine Berechtigung für Crafting.')
    end
    if mapCount(CraftingPoints) >= AdminMenuConfig.MaxCraftingDefinitions then
        return result(source, false, 'Das Crafting-Punkt-Limit wurde erreicht.')
    end
    local label = cleanText(data.label, 64)
    local x, y, z = coordinates(data)
    local radius = tonumber(data.radius) or AdminMenuConfig.DefaultCraftingRadius
    local accessJob = cleanJob(data.accessJob)
    if not label or not x or radius < 1.0 or radius > 5.0
        or distanceTo(source, { x = x, y = y, z = z }) > AdminMenuConfig.MaxPlacementDistance then
        return result(source, false, 'Bezeichnung, Position oder Radius ungültig.')
    end
    if data.accessJob and data.accessJob ~= '' and not accessJob then
        return result(source, false, 'Job-Zugriff ungültig.')
    end
    if type(data.recipeIds) ~= 'table' or #data.recipeIds < 1 then
        return result(source, false, 'Wähle mindestens ein Rezept aus.')
    end
    local seen, recipeIds = {}, {}
    for _, rawId in ipairs(data.recipeIds) do
        local id = tonumber(rawId)
        if not id or not CraftingRecipes[id] then
            return result(source, false, 'Ein ausgewähltes Rezept existiert nicht.')
        end
        if not seen[id] then
            seen[id] = true
            recipeIds[#recipeIds + 1] = id
        end
    end
    table.sort(recipeIds)
    local point = {
        label = label,
        x = x, y = y, z = z,
        heading = tonumber(data.heading) or 0.0,
        radius = radius,
        accessJob = accessJob,
        recipeIds = recipeIds,
        active = true
    }
    point.id = MySQL.insert.await([[
        INSERT INTO frontier_crafting_points
            (label, x, y, z, heading, interact_radius, access_job, recipe_ids, active, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
    ]], {
        point.label, point.x, point.y, point.z, point.heading,
        point.radius, point.accessJob, json.encode(point.recipeIds), getLicense(source)
    })
    CraftingPoints[point.id] = point
    syncCraftingPoints()
    audit(source, 'Crafting-Punkt erstellt', point.id, point.label)
    refreshAllMenus()
    return result(source, true, ('Crafting-Punkt #%d erstellt.'):format(point.id))
end

local function deleteCraftingPoint(source, data)
    if not hasPermission(source, 'crafting') then
        return result(source, false, 'Keine Berechtigung für Crafting.')
    end
    local id = tonumber(data.id)
    if not id or not CraftingPoints[id] then
        return result(source, false, 'Crafting-Punkt nicht gefunden.')
    end
    MySQL.update.await('DELETE FROM frontier_crafting_points WHERE id = ?', { id })
    CraftingPoints[id] = nil
    syncCraftingPoints()
    audit(source, 'Crafting-Punkt gelöscht', id)
    refreshAllMenus()
    return result(source, true, ('Crafting-Punkt #%d gelöscht.'):format(id))
end

RegisterNetEvent('frontier_adminmenu:server:open', function()
    local source = source
    if not Ready then return notify(source, 'Das ACP wird noch initialisiert.') end
    if not isAdmin(source) then return notify(source, 'Keine Berechtigung für das ACP.') end
    OpenMenus[source] = true
    TriggerClientEvent('frontier_adminmenu:client:open', source, payload(source))
end)

RegisterNetEvent('frontier_adminmenu:server:close', function()
    OpenMenus[source] = nil
end)

RegisterNetEvent('frontier_adminmenu:server:refresh', function()
    local source = source
    if not Ready or not isAdmin(source) then return end
    OpenMenus[source] = true
    refresh(source)
end)

RegisterNetEvent('frontier_adminmenu:server:execute', function(action, data)
    local source = source
    if not Ready or not isAdmin(source) then
        OpenMenus[source] = nil
        TriggerClientEvent('frontier_adminmenu:client:forceClose', source)
        return notify(source, 'Deine ACP-Berechtigung ist nicht aktiv.')
    end
    if type(action) ~= 'string' or onCooldown(source, action, 150) then return end
    data = type(data) == 'table' and data or {}

    if action == 'setPermissions' then return setPermissions(source, data) end
    if action == 'revokePermissions' then return revokePermissions(source, data) end
    if action == 'createRecipe' then return createRecipe(source, data) end
    if action == 'deleteRecipe' then return deleteRecipe(source, data) end
    if action == 'createCraftingPoint' then return createCraftingPoint(source, data) end
    if action == 'deleteCraftingPoint' then return deleteCraftingPoint(source, data) end

    if action == 'setWeather' then
        if not hasPermission(source, 'weather') then
            return result(source, false, 'Keine Berechtigung für Wetteränderungen.')
        end
        local weather = weatherById(data.weather)
        local transition = tonumber(data.transition)
        if not weather or not transition then return result(source, false, 'Wetterauswahl ungültig.') end
        transition = math.max(0.0, math.min(transition, AdminMenuConfig.MaxWeatherTransition))
        CurrentWeather, CurrentTransition = weather.id, transition
        TriggerClientEvent('frontier_adminmenu:client:applyWeather', -1, {
            id = weather.id,
            hash = weather.hash,
            transition = transition
        })
        audit(source, 'Wetter', nil, ('%s / %.1fs'):format(weather.label, transition))
        refreshAllMenus()
        return result(source, true, ('Wetter auf %s gesetzt.'):format(weather.label))
    end

    if action == 'teleportCoords' then
        if not hasPermission(source, 'players') then
            return result(source, false, 'Keine Berechtigung für Teleports.')
        end
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        local heading = tonumber(data.w) or 0.0
        if not x or not y or not z
            or math.abs(x) > 10000.0 or math.abs(y) > 10000.0
            or z < -500.0 or z > 2000.0 then
            return result(source, false, 'Koordinaten ungültig.')
        end
        TriggerClientEvent('frontier_adminmenu:client:teleport', source, {
            x = x, y = y, z = z, w = heading
        })
        audit(source, 'Koordinaten-Teleport', source, ('%.2f, %.2f, %.2f'):format(x, y, z))
        return result(source, true, 'Teleport ausgeführt.')
    end

    if action == 'noclip' then
        if not hasPermission(source, 'players') then
            return result(source, false, 'Keine Berechtigung für Noclip.')
        end
        TriggerClientEvent('frontier_adminmenu:client:toggleNoclip', source)
        audit(source, 'Noclip umgeschaltet', source)
        return
    end

    local target, player = activeTarget(data)
    if not target then return result(source, false, 'Spieler nicht gefunden.') end

    if action == 'giveMoney' or action == 'giveItem' then
        if not hasPermission(source, 'economy') then
            return result(source, false, 'Keine Berechtigung für die Wirtschaft.')
        end
        if action == 'giveMoney' then
            local amount = positiveInteger(data.amount, AdminMenuConfig.MaxMoneyGrant)
            local account = data.account == 'bank' and 'bank' or data.account == 'cash' and 'cash'
            if not amount or not account then return result(source, false, 'Konto oder Betrag ungültig.') end
            if not player:addMoney(account, amount, ('admin:%d'):format(source)) then
                return result(source, false, 'Geld konnte nicht hinzugefügt werden.')
            end
            player:save()
            notify(target, ('$%d wurden deinem %s gutgeschrieben.'):format(
                amount,
                account == 'cash' and 'Bargeld' or 'Bankkonto'
            ))
            audit(source, 'Geld hinzugefügt', target, ('%s $%d'):format(account, amount))
            return result(source, true, ('$%d erfolgreich gutgeschrieben.'):format(amount))
        end

        local amount = positiveInteger(data.amount, AdminMenuConfig.MaxItemGrant)
        local itemName = type(data.item) == 'string' and data.item
        if not amount or not itemName then return result(source, false, 'Item oder Anzahl ungültig.') end
        if not player:addItem(itemName, amount, ('admin:%d'):format(source)) then
            return result(source, false, 'Item unbekannt oder Stack-Limit überschritten.')
        end
        player:save()
        local itemLabel = itemName
        for _, item in ipairs(exports.frontier_core:GetItemCatalog()) do
            if item.name == itemName then itemLabel = item.label break end
        end
        notify(target, ('%dx %s wurde deinem Inventar hinzugefügt.'):format(amount, itemLabel))
        audit(source, 'Item hinzugefügt', target, ('%s x%d'):format(itemName, amount))
        return result(source, true, ('%dx %s vergeben.'):format(amount, itemLabel))
    end

    if not hasPermission(source, 'players') then
        return result(source, false, 'Keine Berechtigung für die Spielerverwaltung.')
    end

    if action == 'heal' or action == 'revive' then
        TriggerClientEvent('frontier_adminmenu:client:restorePlayer', target, action == 'revive')
        player:setMetadata('health', 200)
        player:save()
        notify(target, action == 'revive' and 'Du wurdest von einem Admin wiederbelebt.' or 'Du wurdest von einem Admin geheilt.')
        audit(source, action == 'revive' and 'Wiederbelebt' or 'Geheilt', target)
        return result(source, true, action == 'revive' and 'Spieler wiederbelebt.' or 'Spieler geheilt.')
    end

    if action == 'goto' then
        local coords = playerCoordinates(target)
        if not coords then return result(source, false, 'Spielerposition nicht verfügbar.') end
        TriggerClientEvent('frontier_adminmenu:client:teleport', source, coords)
        audit(source, 'Goto', target)
        return result(source, true, 'Zum Spieler teleportiert.')
    end

    if action == 'bring' then
        local coords = playerCoordinates(source)
        if not coords then return result(source, false, 'Adminposition nicht verfügbar.') end
        TriggerClientEvent('frontier_adminmenu:client:teleport', target, coords)
        notify(target, 'Du wurdest von einem Admin teleportiert.')
        audit(source, 'Bring', target)
        return result(source, true, 'Spieler zu dir teleportiert.')
    end

    if action == 'freeze' then
        FrozenPlayers[target] = not FrozenPlayers[target]
        TriggerClientEvent('frontier_adminmenu:client:setFrozen', target, FrozenPlayers[target])
        audit(source, FrozenPlayers[target] and 'Eingefroren' or 'Freigegeben', target)
        return result(source, true, FrozenPlayers[target] and 'Spieler eingefroren.' or 'Spieler freigegeben.')
    end

    if action == 'kick' then
        if target == source then return result(source, false, 'Du kannst dich nicht selbst kicken.') end
        local reason = tostring(data.reason or ''):gsub('[\r\n]', ' '):sub(1, AdminMenuConfig.MaxKickReasonLength)
        if reason:match('^%s*$') then reason = 'Von der Administration vom Server entfernt.' end
        audit(source, 'Kick', target, reason)
        DropPlayer(target, reason)
        refreshAllMenus()
        return result(source, true, 'Spieler vom Server entfernt.')
    end

    result(source, false, 'Unbekannte Adminaktion.')
end)

local function pointAllowsRecipe(point, recipeId)
    for _, id in ipairs(point and point.recipeIds or {}) do
        if id == recipeId then return true end
    end
    return false
end

local function canUsePoint(source, player, point)
    return point
        and point.active
        and distanceTo(source, point) <= point.radius + 1.5
        and (not point.accessJob or player.job == point.accessJob or hasPermission(source, 'crafting'))
end

local function craftingView(source, point, player)
    local catalog = itemCatalogMap()
    local inventory = player:getInventory()
    local recipes = {}
    for _, recipeId in ipairs(point.recipeIds) do
        local recipe = CraftingRecipes[recipeId]
        if recipe and recipe.active and catalog[recipe.outputItem] then
            local ingredients = {}
            for _, ingredient in ipairs(recipe.ingredients) do
                local item = catalog[ingredient.item]
                if item then
                    ingredients[#ingredients + 1] = {
                        item = ingredient.item,
                        label = item.label,
                        amount = ingredient.amount,
                        have = tonumber(inventory[ingredient.item]) or 0
                    }
                end
            end
            recipes[#recipes + 1] = {
                id = recipe.id,
                label = recipe.label,
                description = recipe.description,
                outputItem = recipe.outputItem,
                outputLabel = catalog[recipe.outputItem].label,
                outputAmount = recipe.outputAmount,
                ingredients = ingredients,
                duration = recipe.duration
            }
        end
    end
    TriggerClientEvent('frontier_adminmenu:client:openCrafting', source, {
        point = { id = point.id, label = point.label },
        recipes = recipes
    })
end

RegisterNetEvent('frontier_adminmenu:server:openCrafting', function(pointId)
    local source = source
    if not Ready or onCooldown(source, 'open_crafting', 300) then return end
    local point = CraftingPoints[tonumber(pointId)]
    local player = exports.frontier_core:GetPlayer(source)
    if not player or not canUsePoint(source, player, point) then
        return notify(source, 'Du kannst diesen Crafting-Punkt nicht benutzen.')
    end
    craftingView(source, point, player)
end)

local function craftFailure(source, point, player, message)
    CraftingLocks[source] = nil
    TriggerClientEvent('frontier_adminmenu:client:craftResult', source, {
        success = false,
        message = message
    })
    if point and player and canUsePoint(source, player, point) then craftingView(source, point, player) end
end

RegisterNetEvent('frontier_adminmenu:server:craft', function(pointId, recipeId)
    local source = source
    if not Ready or CraftingLocks[source] then return end
    local point = CraftingPoints[tonumber(pointId)]
    local recipe = CraftingRecipes[tonumber(recipeId)]
    local player = exports.frontier_core:GetPlayer(source)
    if not player or not recipe or not recipe.active or not pointAllowsRecipe(point or {}, recipe.id)
        or not canUsePoint(source, player, point) then
        return craftFailure(source, point, player, 'Rezept oder Crafting-Punkt ungültig.')
    end

    CraftingLocks[source] = true
    TriggerClientEvent('frontier_adminmenu:client:craftingBusy', source, {
        duration = recipe.duration,
        label = recipe.label
    })
    Wait(recipe.duration)

    point = CraftingPoints[point.id]
    recipe = CraftingRecipes[recipe.id]
    player = exports.frontier_core:GetPlayer(source)
    if not player or not point or not recipe or not recipe.active
        or not pointAllowsRecipe(point, recipe.id) or not canUsePoint(source, player, point) then
        return craftFailure(source, point, player, 'Crafting abgebrochen: Punkt, Rezept oder Entfernung ist nicht mehr gültig.')
    end

    local catalog = itemCatalogMap()
    local inventory = player:getInventory()
    local simulated = {}
    for itemName, amount in pairs(inventory) do simulated[itemName] = tonumber(amount) or 0 end
    for _, ingredient in ipairs(recipe.ingredients) do
        simulated[ingredient.item] = (simulated[ingredient.item] or 0) - ingredient.amount
        if simulated[ingredient.item] < 0 then
            return craftFailure(source, point, player, 'Dir fehlen benötigte Materialien.')
        end
    end
    local output = catalog[recipe.outputItem]
    if not output then return craftFailure(source, point, player, 'Das Ausgabe-Item existiert nicht mehr.') end
    simulated[recipe.outputItem] = (simulated[recipe.outputItem] or 0) + recipe.outputAmount
    if simulated[recipe.outputItem] > (tonumber(output.maxStack) or 100) then
        return craftFailure(source, point, player, 'Dein Inventar kann das Ergebnis nicht aufnehmen.')
    end

    local removed = {}
    for _, ingredient in ipairs(recipe.ingredients) do
        if not player:removeItem(ingredient.item, ingredient.amount, ('craft:%d'):format(recipe.id)) then
            for _, rollback in ipairs(removed) do
                player:addItem(rollback.item, rollback.amount, 'craft_rollback')
            end
            return craftFailure(source, point, player, 'Materialien konnten nicht verarbeitet werden.')
        end
        removed[#removed + 1] = ingredient
    end
    if not player:addItem(recipe.outputItem, recipe.outputAmount, ('craft:%d'):format(recipe.id)) then
        for _, rollback in ipairs(removed) do
            player:addItem(rollback.item, rollback.amount, 'craft_rollback')
        end
        return craftFailure(source, point, player, 'Ergebnis konnte nicht ins Inventar gelegt werden.')
    end

    player:save()
    CraftingLocks[source] = nil
    audit(source, 'Gegenstand hergestellt', recipe.id, ('%s x%d'):format(recipe.outputItem, recipe.outputAmount))
    TriggerClientEvent('frontier_adminmenu:client:craftResult', source, {
        success = true,
        message = ('%dx %s hergestellt.'):format(recipe.outputAmount, output.label)
    })
    craftingView(source, point, player)
end)

AddEventHandler('frontier:server:playerLoaded', function(source)
    SetTimeout(1200, function()
        if not GetPlayerName(source) then return end
        syncCraftingPoints(source)
        local weather = weatherById(CurrentWeather)
        if weather then
            TriggerClientEvent('frontier_adminmenu:client:applyWeather', source, {
                id = weather.id,
                hash = weather.hash,
                transition = CurrentTransition
            })
        end
    end)
    refreshAllMenus()
end)

AddEventHandler('frontier:server:onboardingCompleted', function(source)
    SetTimeout(2500, function()
        local weather = weatherById(CurrentWeather)
        if weather and GetPlayerName(source) then
            TriggerClientEvent('frontier_adminmenu:client:applyWeather', source, {
                id = weather.id,
                hash = weather.hash,
                transition = CurrentTransition
            })
        end
    end)
end)

AddEventHandler('frontier:server:playerUnloaded', function(source)
    FrozenPlayers[source] = nil
    CraftingLocks[source] = nil
    TriggerClientEvent('frontier_adminmenu:client:setFrozen', source, false)
    refreshAllMenus()
end)

AddEventHandler('playerDropped', function()
    FrozenPlayers[source] = nil
    OpenMenus[source] = nil
    CraftingLocks[source] = nil
    local prefix = ('%d:'):format(source)
    for key in pairs(LastActions) do
        if key:sub(1, #prefix) == prefix then LastActions[key] = nil end
    end
    refreshAllMenus()
end)

CreateThread(function()
    Wait(1500)
    local weather = weatherById(CurrentWeather)
    if not weather then return end
    TriggerClientEvent('frontier_adminmenu:client:applyWeather', -1, {
        id = weather.id,
        hash = weather.hash,
        transition = CurrentTransition
    })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for target in pairs(FrozenPlayers) do
        TriggerClientEvent('frontier_adminmenu:client:setFrozen', target, false)
    end
end)
