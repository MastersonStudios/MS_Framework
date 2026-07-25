local Sessions = {}
local LastActions = {}
local PendingSpawns = {}
local ActiveAssets = {}
local Ready = false

local function debugLog(message, ...)
    if not MSStablesConfig.Debug then return end
    print(('[MS_Stables] ' .. message):format(...))
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function stableById(stableId)
    return type(stableId) == 'string' and MSStablesConfig.Stables[stableId] or nil
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

local function onCooldown(playerSource, action, duration)
    local key = ('%d:%s'):format(playerSource, action)
    local now = GetGameTimer()
    local last = LastActions[key]
    if last and now - last < duration then return true end
    LastActions[key] = now
    return false
end

local function cleanName(value)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):match('^%s*(.-)%s*$')
    if #value < 2 or #value > 32 then return nil end
    if not value:match("^[%w%säöüÄÖÜß%-%']+$") then return nil end
    return value
end

local function decodeTable(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local success, decoded = pcall(json.decode, value)
    return success and type(decoded) == 'table' and decoded or fallback
end

local function tableContains(values, needle)
    for _, value in ipairs(values) do
        if value == needle then return true end
    end
    return false
end

local function compatibleEquipment(equipment, horseKey)
    if type(equipment.breeds) ~= 'table' then return true end
    return tableContains(equipment.breeds, horseKey)
end

local function findCoat(horseKey, coatKey)
    local horse = MSStablesConfig.Horses[horseKey]
    if not horse then return nil end
    for _, coat in ipairs(horse.coats or {}) do
        if coat.key == coatKey then return coat end
    end
end

local function currentStable(playerSource)
    local stableId = Sessions[playerSource]
    local stable = stableById(stableId)
    if not stable or distanceTo(playerSource, stable.seller) > MSStablesConfig.ServerInteractionDistance then
        Sessions[playerSource] = nil
        return nil, nil
    end
    return stableId, stable
end

local function rowToHorse(row)
    return {
        id = tonumber(row.id),
        name = row.name,
        horseKey = row.horse_key,
        coatKey = row.coat_key,
        model = row.model,
        ownedEquipment = decodeTable(row.owned_equipment, {}),
        equipped = decodeTable(row.equipped, {}),
        ownedCoats = decodeTable(row.owned_coats, {}),
        purchasedAt = row.purchased_at
    }
end

local function rowToWagon(row)
    return {
        id = tonumber(row.id),
        wagonKey = row.wagon_key,
        label = row.label,
        model = row.model,
        purchasedAt = row.purchased_at
    }
end

local function ownedHorses(characterId)
    local rows = MySQL.query.await([[
        SELECT id, name, horse_key, coat_key, model, owned_equipment, equipped, owned_coats, purchased_at
        FROM ms_stable_horses
        WHERE character_id = ?
        ORDER BY purchased_at ASC, id ASC
    ]], { characterId })
    local horses = {}
    for _, row in ipairs(rows or {}) do horses[#horses + 1] = rowToHorse(row) end
    return horses
end

local function ownedWagons(characterId)
    local rows = MySQL.query.await([[
        SELECT id, wagon_key, label, model, purchased_at
        FROM ms_stable_wagons
        WHERE character_id = ?
        ORDER BY purchased_at ASC, id ASC
    ]], { characterId })
    local wagons = {}
    for _, row in ipairs(rows or {}) do wagons[#wagons + 1] = rowToWagon(row) end
    return wagons
end

local function sortedCatalog(config, mapper)
    local rows = {}
    for key, value in pairs(config) do rows[#rows + 1] = mapper(key, value) end
    table.sort(rows, function(left, right) return left.label < right.label end)
    return rows
end

local function horseCatalog()
    return sortedCatalog(MSStablesConfig.Horses, function(key, horse)
        local coats = {}
        for _, coat in ipairs(horse.coats or {}) do
            coats[#coats + 1] = {
                key = coat.key,
                label = coat.label,
                model = coat.model,
                price = tonumber(coat.price) or 0
            }
        end
        return {
            key = key,
            label = horse.label,
            description = horse.description,
            price = tonumber(horse.price) or 0,
            coats = coats
        }
    end)
end

local function equipmentCatalog()
    return sortedCatalog(MSStablesConfig.Equipment, function(key, equipment)
        return {
            key = key,
            label = equipment.label,
            description = equipment.description,
            category = equipment.category,
            categoryLabel = equipment.categoryLabel or equipment.category,
            price = tonumber(equipment.price) or 0,
            healthBonus = tonumber(equipment.healthBonus) or 0,
            breeds = equipment.breeds
        }
    end)
end

local function wagonCatalog()
    return sortedCatalog(MSStablesConfig.Wagons, function(key, wagon)
        return {
            key = key,
            label = wagon.label,
            description = wagon.description,
            model = wagon.model,
            price = tonumber(wagon.price) or 0
        }
    end)
end

local function activePayload(playerSource)
    local active = ActiveAssets[playerSource]
    if not active then return nil end
    if not active.entity or not DoesEntityExist(active.entity) then
        ActiveAssets[playerSource] = nil
        return nil
    end
    return {
        kind = active.kind,
        assetId = active.assetId,
        netId = active.netId
    }
end

local function menuPayload(playerSource, stableId)
    local player = getPlayer(playerSource)
    local stable = stableById(stableId)
    if not player or not stable then return nil end

    return {
        stable = { id = stableId, label = stable.label },
        account = MSStablesConfig.Account,
        currency = MSStablesConfig.CurrencyLabel,
        balance = tonumber(player.money[MSStablesConfig.Account]) or 0,
        horses = ownedHorses(player.characterId),
        wagons = ownedWagons(player.characterId),
        active = activePayload(playerSource),
        catalog = {
            horses = horseCatalog(),
            equipment = equipmentCatalog(),
            wagons = wagonCatalog()
        },
        limits = {
            horses = MSStablesConfig.MaxHorses,
            wagons = MSStablesConfig.MaxWagons
        }
    }
end

local function refresh(playerSource)
    local stableId = Sessions[playerSource]
    local payload = stableId and menuPayload(playerSource, stableId)
    if payload then TriggerClientEvent('ms_stables:client:refresh', playerSource, payload) end
end

local function result(playerSource, success, message, shouldRefresh)
    TriggerClientEvent('ms_stables:client:result', playerSource, {
        success = success == true,
        message = message
    })
    if shouldRefresh then refresh(playerSource) end
end

local function charge(player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return player:removeMoney(MSStablesConfig.Account, amount, reason)
end

local function refund(player, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount > 0 then player:addMoney(MSStablesConfig.Account, amount, reason) end
    player:save()
end

local function deleteActive(playerSource, expectedKind)
    local active = ActiveAssets[playerSource]
    if not active or (expectedKind and active.kind ~= expectedKind) then return false end

    ActiveAssets[playerSource] = nil
    if active.entity and DoesEntityExist(active.entity) then
        DeleteEntity(active.entity)
    end
    TriggerClientEvent('ms_stables:client:deleteAsset', playerSource, active.netId)
    return true
end

local function createTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_stable_horses (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            character_id BIGINT UNSIGNED NOT NULL,
            name VARCHAR(32) NOT NULL,
            horse_key VARCHAR(64) NOT NULL,
            coat_key VARCHAR(64) NOT NULL,
            model VARCHAR(100) NOT NULL,
            owned_equipment LONGTEXT NOT NULL,
            equipped LONGTEXT NOT NULL,
            owned_coats LONGTEXT NOT NULL,
            purchased_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_ms_stable_horses_character (character_id),
            CONSTRAINT fk_ms_stable_horses_character
                FOREIGN KEY (character_id) REFERENCES mscore_characters (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS ms_stable_wagons (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            character_id BIGINT UNSIGNED NOT NULL,
            wagon_key VARCHAR(64) NOT NULL,
            label VARCHAR(64) NOT NULL,
            model VARCHAR(100) NOT NULL,
            purchased_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_ms_stable_wagons_character (character_id),
            CONSTRAINT fk_ms_stable_wagons_character
                FOREIGN KEY (character_id) REFERENCES mscore_characters (id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end

RegisterNetEvent('ms_stables:server:open', function(stableId)
    local playerSource = source
    local stable = stableById(stableId)
    if not Ready or not getPlayer(playerSource) or not stable then return end
    if distanceTo(playerSource, stable.seller) > MSStablesConfig.ServerInteractionDistance then return end

    Sessions[playerSource] = stableId
    TriggerClientEvent('ms_stables:client:open', playerSource, menuPayload(playerSource, stableId))
end)

RegisterNetEvent('ms_stables:server:close', function()
    Sessions[source] = nil
end)

RegisterNetEvent('ms_stables:server:refresh', function()
    if onCooldown(source, 'refresh', MSStablesConfig.ActionCooldown) then return end
    if not currentStable(source) then return end
    refresh(source)
end)

RegisterNetEvent('ms_stables:server:purchaseHorse', function(horseKey, horseName)
    local playerSource = source
    if onCooldown(playerSource, 'purchaseHorse', MSStablesConfig.ActionCooldown) then return end
    if not currentStable(playerSource) then return end

    local player = getPlayer(playerSource)
    local horse = type(horseKey) == 'string' and MSStablesConfig.Horses[horseKey]
    horseName = cleanName(horseName)
    if not player or not horse or not horseName or not horse.coats or not horse.coats[1] then
        return result(playerSource, false, 'Pferd oder Name ist ungültig.')
    end

    local count = tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM ms_stable_horses WHERE character_id = ?',
        { player.characterId }
    )) or 0
    if count >= MSStablesConfig.MaxHorses then
        return result(playerSource, false, 'Du hast bereits die maximale Anzahl an Pferden.')
    end

    local price = math.floor(tonumber(horse.price) or 0)
    if not charge(player, price, 'stable_horse_purchase') then
        return result(playerSource, false, 'Dein Guthaben reicht für dieses Pferd nicht aus.')
    end

    local coat = horse.coats[1]
    local success, insertId = pcall(MySQL.insert.await, [[
        INSERT INTO ms_stable_horses
            (character_id, name, horse_key, coat_key, model, owned_equipment, equipped, owned_coats)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        player.characterId,
        horseName,
        horseKey,
        coat.key,
        coat.model,
        '[]',
        '{}',
        json.encode({ coat.key })
    })
    if not success or not insertId then
        refund(player, price, 'stable_horse_refund')
        return result(playerSource, false, 'Der Kauf konnte nicht gespeichert werden.')
    end

    player:save()
    result(playerSource, true, ('%s gehört jetzt dir.'):format(horseName), true)
end)

RegisterNetEvent('ms_stables:server:purchaseEquipment', function(horseId, equipmentKey)
    local playerSource = source
    if onCooldown(playerSource, 'equipment', MSStablesConfig.ActionCooldown) then return end
    if not currentStable(playerSource) then return end

    local player = getPlayer(playerSource)
    local equipment = type(equipmentKey) == 'string' and MSStablesConfig.Equipment[equipmentKey]
    horseId = tonumber(horseId)
    if not player or not equipment or not horseId then
        return result(playerSource, false, 'Ausrüstung oder Pferd ist ungültig.')
    end

    local row = MySQL.single.await([[
        SELECT id, horse_key, owned_equipment, equipped
        FROM ms_stable_horses
        WHERE id = ? AND character_id = ?
    ]], { horseId, player.characterId })
    if not row or not compatibleEquipment(equipment, row.horse_key) then
        return result(playerSource, false, 'Diese Ausrüstung passt nicht zu deinem Pferd.')
    end

    local owned = decodeTable(row.owned_equipment, {})
    local equipped = decodeTable(row.equipped, {})
    local alreadyOwned = tableContains(owned, equipmentKey)
    local price = alreadyOwned and 0 or math.floor(tonumber(equipment.price) or 0)
    if price > 0 and not charge(player, price, 'stable_equipment_purchase') then
        return result(playerSource, false, 'Dein Guthaben reicht für diese Ausrüstung nicht aus.')
    end

    if not alreadyOwned then owned[#owned + 1] = equipmentKey end
    equipped[equipment.category] = equipmentKey
    local success, affected = pcall(MySQL.update.await, [[
        UPDATE ms_stable_horses
        SET owned_equipment = ?, equipped = ?
        WHERE id = ? AND character_id = ?
    ]], { json.encode(owned), json.encode(equipped), horseId, player.characterId })
    if not success or affected ~= 1 then
        if price > 0 then refund(player, price, 'stable_equipment_refund') end
        return result(playerSource, false, 'Die Ausrüstung konnte nicht gespeichert werden.')
    end

    player:save()
    if ActiveAssets[playerSource] and ActiveAssets[playerSource].kind == 'horse'
        and ActiveAssets[playerSource].assetId == horseId then
        deleteActive(playerSource, 'horse')
    end
    result(
        playerSource,
        true,
        alreadyOwned and 'Ausrüstung angelegt. Hole dein Pferd erneut aus dem Stall.'
            or 'Ausrüstung gekauft und angelegt. Hole dein Pferd erneut aus dem Stall.',
        true
    )
end)

RegisterNetEvent('ms_stables:server:purchaseCoat', function(horseId, coatKey)
    local playerSource = source
    if onCooldown(playerSource, 'coat', MSStablesConfig.ActionCooldown) then return end
    if not currentStable(playerSource) then return end

    local player = getPlayer(playerSource)
    horseId = tonumber(horseId)
    local row = player and horseId and MySQL.single.await([[
        SELECT id, horse_key, owned_coats
        FROM ms_stable_horses
        WHERE id = ? AND character_id = ?
    ]], { horseId, player.characterId })
    local coat = row and findCoat(row.horse_key, coatKey)
    if not player or not row or not coat then
        return result(playerSource, false, 'Fellfarbe oder Pferd ist ungültig.')
    end

    local owned = decodeTable(row.owned_coats, {})
    local alreadyOwned = tableContains(owned, coat.key)
    local price = alreadyOwned and 0 or math.floor(tonumber(coat.price) or 0)
    if price > 0 and not charge(player, price, 'stable_coat_purchase') then
        return result(playerSource, false, 'Dein Guthaben reicht für diese Fellfarbe nicht aus.')
    end
    if not alreadyOwned then owned[#owned + 1] = coat.key end

    local success, affected = pcall(MySQL.update.await, [[
        UPDATE ms_stable_horses
        SET coat_key = ?, model = ?, owned_coats = ?
        WHERE id = ? AND character_id = ?
    ]], { coat.key, coat.model, json.encode(owned), horseId, player.characterId })
    if not success or affected ~= 1 then
        if price > 0 then refund(player, price, 'stable_coat_refund') end
        return result(playerSource, false, 'Die Fellfarbe konnte nicht gespeichert werden.')
    end

    player:save()
    if ActiveAssets[playerSource] and ActiveAssets[playerSource].kind == 'horse'
        and ActiveAssets[playerSource].assetId == horseId then
        deleteActive(playerSource, 'horse')
    end
    result(
        playerSource,
        true,
        alreadyOwned and 'Fellfarbe gewechselt. Hole dein Pferd erneut aus dem Stall.'
            or 'Fellfarbe gekauft. Hole dein Pferd erneut aus dem Stall.',
        true
    )
end)

RegisterNetEvent('ms_stables:server:purchaseWagon', function(wagonKey)
    local playerSource = source
    if onCooldown(playerSource, 'purchaseWagon', MSStablesConfig.ActionCooldown) then return end
    if not currentStable(playerSource) then return end

    local player = getPlayer(playerSource)
    local wagon = type(wagonKey) == 'string' and MSStablesConfig.Wagons[wagonKey]
    if not player or not wagon then return result(playerSource, false, 'Kutsche ist ungültig.') end

    local count = tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM ms_stable_wagons WHERE character_id = ?',
        { player.characterId }
    )) or 0
    if count >= MSStablesConfig.MaxWagons then
        return result(playerSource, false, 'Du hast bereits die maximale Anzahl an Kutschen.')
    end

    local price = math.floor(tonumber(wagon.price) or 0)
    if not charge(player, price, 'stable_wagon_purchase') then
        return result(playerSource, false, 'Dein Guthaben reicht für diese Kutsche nicht aus.')
    end

    local success, insertId = pcall(MySQL.insert.await, [[
        INSERT INTO ms_stable_wagons (character_id, wagon_key, label, model)
        VALUES (?, ?, ?, ?)
    ]], { player.characterId, wagonKey, wagon.label, wagon.model })
    if not success or not insertId then
        refund(player, price, 'stable_wagon_refund')
        return result(playerSource, false, 'Der Kutschenkauf konnte nicht gespeichert werden.')
    end

    player:save()
    result(playerSource, true, ('%s wurde gekauft.'):format(wagon.label), true)
end)

RegisterNetEvent('ms_stables:server:spawnAsset', function(kind, assetId)
    local playerSource = source
    if onCooldown(playerSource, 'spawn', MSStablesConfig.SpawnCooldown) then
        return result(playerSource, false, 'Bitte warte einen Moment.')
    end
    local stableId, stable = currentStable(playerSource)
    local player = getPlayer(playerSource)
    assetId = tonumber(assetId)
    if not stable or not player or not assetId or (kind ~= 'horse' and kind ~= 'wagon') then return end

    local asset
    if kind == 'horse' then
        local row = MySQL.single.await([[
            SELECT id, name, horse_key, coat_key, model, owned_equipment, equipped
            FROM ms_stable_horses
            WHERE id = ? AND character_id = ?
        ]], { assetId, player.characterId })
        if row then
            local equipped = decodeTable(row.equipped, {})
            local components = {}
            local healthBonus = 0
            for _, equipmentKey in pairs(equipped) do
                local equipment = MSStablesConfig.Equipment[equipmentKey]
                if equipment then
                    healthBonus = healthBonus + (tonumber(equipment.healthBonus) or 0)
                    if tonumber(equipment.componentHash) then
                        components[#components + 1] = tonumber(equipment.componentHash)
                    end
                end
            end
            asset = {
                id = tonumber(row.id),
                name = row.name,
                model = row.model,
                maxHealth = MSStablesConfig.BaseHorseHealth + healthBonus,
                components = components
            }
        end
    else
        local row = MySQL.single.await([[
            SELECT id, label, model
            FROM ms_stable_wagons
            WHERE id = ? AND character_id = ?
        ]], { assetId, player.characterId })
        if row then
            asset = { id = tonumber(row.id), name = row.label, model = row.model }
        end
    end
    if not asset then return result(playerSource, false, 'Dieses Stallobjekt gehört dir nicht.') end

    deleteActive(playerSource)
    PendingSpawns[playerSource] = nil

    local token = ('%d:%d:%d'):format(playerSource, GetGameTimer(), math.random(100000, 999999))
    local spawn = kind == 'horse' and stable.horseSpawn or stable.wagonSpawn
    PendingSpawns[playerSource] = {
        token = token,
        kind = kind,
        assetId = asset.id,
        modelHash = GetHashKey(asset.model),
        expires = GetGameTimer() + MSStablesConfig.ModelLoadTimeout + 5000
    }

    TriggerClientEvent('ms_stables:client:createAsset', playerSource, {
        token = token,
        kind = kind,
        assetId = asset.id,
        name = asset.name,
        model = asset.model,
        maxHealth = asset.maxHealth,
        components = asset.components,
        stableId = stableId,
        spawn = spawn
    })
end)

RegisterNetEvent('ms_stables:server:registerAsset', function(token, netId)
    local playerSource = source
    local pending = PendingSpawns[playerSource]
    netId = tonumber(netId)
    if not pending or pending.token ~= token or not netId
        or netId < 1 or netId > 65535 or netId % 1 ~= 0 or pending.registering then return end
    if GetGameTimer() > pending.expires then
        PendingSpawns[playerSource] = nil
        return result(playerSource, false, 'Der Spawn ist abgelaufen.')
    end
    pending.registering = true

    CreateThread(function()
        local entity = 0
        local expires = GetGameTimer() + 5000
        repeat
            entity = NetworkGetEntityFromNetworkId(netId)
            if entity == 0 or not DoesEntityExist(entity) then Wait(100) end
        until (entity ~= 0 and DoesEntityExist(entity)) or GetGameTimer() >= expires

        pending = PendingSpawns[playerSource]
        if not pending or pending.token ~= token then
            if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
            return
        end
        PendingSpawns[playerSource] = nil

        if entity == 0 or not DoesEntityExist(entity)
            or NetworkGetEntityOwner(entity) ~= playerSource
            or GetEntityModel(entity) ~= pending.modelHash then
            if entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
            return result(playerSource, false, 'Das Stallobjekt konnte nicht sicher registriert werden.')
        end

        local ownerPlayer = getPlayer(playerSource)
        if not ownerPlayer then
            DeleteEntity(entity)
            return result(playerSource, false, 'Der aktive Charakter wurde nicht gefunden.')
        end

        SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(playerSource))
        SetEntityOrphanMode(entity, 2)
        Entity(entity).state:set('msStables', {
            ownerCharacterId = ownerPlayer.characterId,
            kind = pending.kind,
            assetId = pending.assetId
        }, true)
        ActiveAssets[playerSource] = {
            kind = pending.kind,
            assetId = pending.assetId,
            entity = entity,
            netId = netId
        }
        TriggerClientEvent('ms_stables:client:assetRegistered', playerSource, token, netId)
        result(playerSource, true, pending.kind == 'horse' and 'Dein Pferd steht am Abholpunkt.'
            or 'Deine Kutsche steht am Abholpunkt.', true)
        debugLog('registered %s %d for player %d', pending.kind, pending.assetId, playerSource)
    end)
end)

RegisterNetEvent('ms_stables:server:spawnFailed', function(token)
    local pending = PendingSpawns[source]
    if not pending or pending.token ~= token then return end
    PendingSpawns[source] = nil
    result(source, false, 'Das Modell konnte nicht geladen oder erstellt werden.')
end)

RegisterNetEvent('ms_stables:server:dismissAsset', function(kind)
    local playerSource = source
    if onCooldown(playerSource, 'dismiss', MSStablesConfig.ActionCooldown) then return end
    if not currentStable(playerSource) then return end
    if kind ~= 'horse' and kind ~= 'wagon' then kind = nil end
    if not deleteActive(playerSource, kind) then
        return result(playerSource, false, 'Kein passendes Stallobjekt ist aktiv.')
    end
    result(playerSource, true, 'Das Stallobjekt wurde eingestellt.', true)
end)

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    Sessions[playerSource] = nil
    PendingSpawns[playerSource] = nil
    deleteActive(playerSource)
    for key in pairs(LastActions) do
        if key:match(('^%d+:'):format(playerSource)) then LastActions[key] = nil end
    end
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    Sessions[playerSource] = nil
    PendingSpawns[playerSource] = nil
    deleteActive(playerSource)
    for key in pairs(LastActions) do
        if key:match(('^%d+:'):format(playerSource)) then LastActions[key] = nil end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        local success, err = pcall(createTables)
        if not success then
            return print(('[MS_Stables] Tabellen konnten nicht erstellt werden: %s'):format(tostring(err)))
        end
        Ready = true
        print('[MS_Stables] Stalltabellen geladen.')
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for playerSource in pairs(ActiveAssets) do deleteActive(playerSource) end
end)

exports('GetOwnedHorses', function(playerSource)
    local player = getPlayer(playerSource)
    return player and ownedHorses(player.characterId) or {}
end)

exports('GetOwnedWagons', function(playerSource)
    local player = getPlayer(playerSource)
    return player and ownedWagons(player.characterId) or {}
end)

exports('GetActiveStableAsset', function(playerSource)
    return activePayload(tonumber(playerSource))
end)
