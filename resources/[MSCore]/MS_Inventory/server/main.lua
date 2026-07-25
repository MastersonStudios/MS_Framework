local OpenInventories = {}
local LastActions = {}
local BusyPlayers = {}
local RefreshScheduled = {}

local function debugLog(message, ...)
    if not MSInventoryConfig.Debug then return end
    print(('[MS_Inventory] ' .. message):format(...))
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function outfitSlots()
    local slots = {}
    for _, slot in ipairs(MSInventoryConfig.OutfitSlots or {}) do
        slots[slot.key] = slot
    end
    return slots
end

local OutfitSlots = outfitSlots()

local function getOutfit(player)
    if type(player.metadata.outfit) ~= 'table' then player.metadata.outfit = {} end
    return player.metadata.outfit
end

local function onCooldown(playerSource, action)
    local key = ('%d:%s'):format(playerSource, action)
    local now = GetGameTimer()
    local last = LastActions[key]
    if last and now - last < MSInventoryConfig.ActionCooldown then return true end
    LastActions[key] = now
    return false
end

local function actionAmount(value)
    value = tonumber(value)
    if not value or value % 1 ~= 0 or value < 1 or value > MSInventoryConfig.MaxActionAmount then return nil end
    return value
end

local function distanceBetween(firstSource, secondSource)
    local firstPed = GetPlayerPed(firstSource)
    local secondPed = GetPlayerPed(secondSource)
    if not firstPed or firstPed == 0 or not secondPed or secondPed == 0 then return math.huge end
    local first = GetEntityCoords(firstPed)
    local second = GetEntityCoords(secondPed)
    local dx, dy, dz = first.x - second.x, first.y - second.y, first.z - second.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function itemView(item, amount)
    return {
        name = item.name,
        label = item.label,
        description = item.description,
        category = item.category,
        rarity = item.rarity,
        amount = tonumber(amount) or 0,
        maxStack = tonumber(item.maxStack) or 1,
        weight = tonumber(item.weight) or 0,
        usable = item.usable == true,
        consumable = item.consumable == true,
        unique = item.unique == true,
        tradable = item.tradable == true,
        image = item.image,
        prop = item.prop,
        metadata = item.metadata or {}
    }
end

local function nearbyPlayers(playerSource)
    local rows = {}
    for _, value in ipairs(GetPlayers()) do
        local targetSource = tonumber(value)
        local target = targetSource and targetSource ~= playerSource and getPlayer(targetSource)
        if target and distanceBetween(playerSource, targetSource) <= MSInventoryConfig.GiveDistance then
            rows[#rows + 1] = {
                source = targetSource,
                name = target.getName and target:getName() or GetPlayerName(targetSource) or ('Spieler %d'):format(targetSource)
            }
        end
    end
    table.sort(rows, function(left, right) return left.source < right.source end)
    return rows
end

local function inventoryPayload(playerSource)
    local player = getPlayer(playerSource)
    if not player then return nil end

    local items = {}
    for itemName, amount in pairs(player:getInventory()) do
        local item = exports.MSCore:GetItem(itemName)
        amount = math.max(0, math.floor(tonumber(amount) or 0))
        if item and amount > 0 then items[#items + 1] = itemView(item, amount) end
    end
    table.sort(items, function(left, right)
        if left.label == right.label then return left.name < right.name end
        return left.label < right.label
    end)

    local equipped = {}
    for slotKey, itemName in pairs(getOutfit(player)) do
        local item = OutfitSlots[slotKey] and exports.MSCore:GetItem(itemName)
        if item then
            equipped[slotKey] = itemView(item, 1)
        end
    end

    local slots = {}
    for _, slot in ipairs(MSInventoryConfig.OutfitSlots or {}) do
        slots[#slots + 1] = {
            key = slot.key,
            label = slot.label,
            icon = slot.icon
        }
    end

    return {
        player = {
            source = playerSource,
            name = player.getName and player:getName() or GetPlayerName(playerSource) or 'Spieler'
        },
        items = items,
        outfit = equipped,
        outfitSlots = slots,
        nearbyPlayers = nearbyPlayers(playerSource),
        usage = player:getInventoryUsage(),
        limits = exports.MSCore:GetInventoryLimits(),
        allowDiscard = MSInventoryConfig.AllowDiscard == true,
        maxActionAmount = MSInventoryConfig.MaxActionAmount
    }
end

local function sendPayload(playerSource, eventName)
    local payload = inventoryPayload(playerSource)
    if payload then TriggerClientEvent(eventName or 'ms_inventory:client:refresh', playerSource, payload) end
end

local function scheduleRefresh(playerSource)
    if not OpenInventories[playerSource] or RefreshScheduled[playerSource] then return end
    RefreshScheduled[playerSource] = true
    SetTimeout(75, function()
        RefreshScheduled[playerSource] = nil
        if OpenInventories[playerSource] then sendPayload(playerSource) end
    end)
end

local function result(playerSource, success, message)
    TriggerClientEvent('ms_inventory:client:result', playerSource, {
        success = success == true,
        message = message
    })
    scheduleRefresh(playerSource)
end

local function pushOutfit(playerSource, player)
    player = player or getPlayer(playerSource)
    if not player then return end

    local components = {}
    for slotKey, itemName in pairs(getOutfit(player)) do
        local item = OutfitSlots[slotKey] and exports.MSCore:GetItem(itemName)
        local componentHash = item and item.metadata and tonumber(item.metadata.componentHash)
        local itemSex = item and item.metadata and item.metadata.sex
        if componentHash and (not itemSex or itemSex == 'unisex' or itemSex == player.sex) then
            components[#components + 1] = {
                slot = slotKey,
                item = itemName,
                componentHash = componentHash,
                sex = (itemSex == 'male' or itemSex == 'female') and itemSex or player.sex
            }
        end
    end
    TriggerClientEvent('ms_inventory:client:applyOutfit', playerSource, components)
end

local function runAction(playerSource, action, callback)
    if not OpenInventories[playerSource] then return end
    if BusyPlayers[playerSource] or onCooldown(playerSource, action) then
        return result(playerSource, false, 'Bitte warte einen Moment.')
    end
    BusyPlayers[playerSource] = true
    local success, err = xpcall(callback, debug.traceback)
    BusyPlayers[playerSource] = nil
    if not success then
        print(('[MS_Inventory] Aktion %s von %d fehlgeschlagen: %s'):format(action, playerSource, tostring(err)))
        result(playerSource, false, 'Die Inventaraktion konnte nicht verarbeitet werden.')
    end
end

RegisterNetEvent('ms_inventory:server:open', function()
    local playerSource = source
    if not getPlayer(playerSource) then return end
    OpenInventories[playerSource] = true
    sendPayload(playerSource, 'ms_inventory:client:open')
end)

RegisterNetEvent('ms_inventory:server:close', function()
    OpenInventories[source] = nil
end)

RegisterNetEvent('ms_inventory:server:refresh', function()
    if OpenInventories[source] and not onCooldown(source, 'refresh') then sendPayload(source) end
end)

RegisterNetEvent('ms_inventory:server:give', function(itemName, amount, targetSource)
    local playerSource = source
    runAction(playerSource, 'give', function()
        local player = getPlayer(playerSource)
        local target = getPlayer(tonumber(targetSource))
        local item = type(itemName) == 'string' and exports.MSCore:GetItem(itemName)
        amount = actionAmount(amount)
        targetSource = tonumber(targetSource)
        if not player or not target or not item or not amount or targetSource == playerSource then
            return result(playerSource, false, 'Übergabeziel oder Item ist ungültig.')
        end
        if not item.tradable then return result(playerSource, false, 'Dieses Item kann nicht übergeben werden.') end
        if distanceBetween(playerSource, targetSource) > MSInventoryConfig.GiveDistance then
            return result(playerSource, false, 'Der andere Spieler ist nicht nah genug.')
        end
        if (tonumber(player:getInventory()[itemName]) or 0) < amount then
            return result(playerSource, false, 'Du besitzt nicht genügend davon.')
        end
        if not target:canCarryItem(itemName, amount) then
            return result(playerSource, false, 'Das Zielinventar hat nicht genügend Platz.')
        end

        if not player:removeItem(itemName, amount, 'inventory_give') then
            return result(playerSource, false, 'Das Item konnte nicht übergeben werden.')
        end
        if not target:addItem(itemName, amount, ('inventory_received:%d'):format(playerSource)) then
            player:addItem(itemName, amount, 'inventory_give_rollback')
            return result(playerSource, false, 'Die Übergabe wurde zurückgesetzt.')
        end

        player:save()
        target:save()
        TriggerClientEvent('mscore:client:notify', targetSource, ('%dx %s von %s erhalten.'):format(
            amount,
            item.label,
            player.getName and player:getName() or GetPlayerName(playerSource) or 'Spieler'
        ))
        result(playerSource, true, ('%dx %s übergeben.'):format(amount, item.label))
        debugLog('%d gave %dx %s to %d', playerSource, amount, itemName, targetSource)
    end)
end)

RegisterNetEvent('ms_inventory:server:discard', function(itemName, amount)
    local playerSource = source
    runAction(playerSource, 'discard', function()
        if not MSInventoryConfig.AllowDiscard then
            return result(playerSource, false, 'Wegwerfen ist deaktiviert.')
        end
        local player = getPlayer(playerSource)
        local item = type(itemName) == 'string' and exports.MSCore:GetItem(itemName)
        amount = actionAmount(amount)
        if not player or not item or not amount then return result(playerSource, false, 'Item ist ungültig.') end
        if not player:removeItem(itemName, amount, 'inventory_discard') then
            return result(playerSource, false, 'Du besitzt nicht genügend davon.')
        end
        player:save()
        result(playerSource, true, ('%dx %s weggeworfen.'):format(amount, item.label))
        debugLog('%d discarded %dx %s', playerSource, amount, itemName)
    end)
end)

RegisterNetEvent('ms_inventory:server:use', function(itemName)
    local playerSource = source
    runAction(playerSource, 'use', function()
        local player = getPlayer(playerSource)
        local item = type(itemName) == 'string' and exports.MSCore:GetItem(itemName)
        if not player or not item or not item.usable then
            return result(playerSource, false, 'Dieses Item kann nicht benutzt werden.')
        end
        if (tonumber(player:getInventory()[itemName]) or 0) < 1 then
            return result(playerSource, false, 'Du besitzt dieses Item nicht.')
        end

        if item.consumable and not player:removeItem(itemName, 1, 'inventory_use') then
            return result(playerSource, false, 'Das Item konnte nicht benutzt werden.')
        end

        local effect = MSInventoryConfig.UseEffects[itemName] or {}
        for key, delta in pairs(type(effect.metadata) == 'table' and effect.metadata or {}) do
            local current = tonumber(player.metadata[key]) or 0
            player:setMetadata(key, math.max(0, math.min(100, current + (tonumber(delta) or 0))))
        end
        local healthDelta = tonumber(effect.health)
        if healthDelta then
            local health = math.max(0, math.min(200, (tonumber(player.metadata.health) or 100) + healthDelta))
            player:setMetadata('health', health)
            TriggerClientEvent('ms_inventory:client:useEffect', playerSource, { health = healthDelta })
        end

        player:save()
        TriggerEvent('ms_inventory:server:itemUsed', playerSource, itemName, item)
        TriggerClientEvent('ms_inventory:client:itemUsed', playerSource, itemName)
        result(playerSource, true, effect.message or ('%s benutzt.'):format(item.label))
    end)
end)

RegisterNetEvent('ms_inventory:server:equip', function(itemName, slotKey)
    local playerSource = source
    runAction(playerSource, 'equip', function()
        local player = getPlayer(playerSource)
        local item = type(itemName) == 'string' and exports.MSCore:GetItem(itemName)
        slotKey = type(slotKey) == 'string' and slotKey or nil
        local itemSlot = item and item.metadata and item.metadata.clothingSlot
        local itemSex = item and item.metadata and item.metadata.sex
        if not player or not item or not OutfitSlots[slotKey] or itemSlot ~= slotKey then
            return result(playerSource, false, 'Dieses Kleidungsstück passt nicht in den Slot.')
        end
        if itemSex and itemSex ~= 'unisex' and itemSex ~= player.sex then
            return result(playerSource, false, 'Dieses Kleidungsstück passt nicht zu deinem Charaktermodell.')
        end
        if (tonumber(player:getInventory()[itemName]) or 0) < 1 then
            return result(playerSource, false, 'Das Kleidungsstück befindet sich nicht im Inventar.')
        end

        local outfit = getOutfit(player)
        local previousItem = outfit[slotKey]
        if previousItem == itemName then return result(playerSource, false, 'Dieses Item ist bereits ausgerüstet.') end

        if not player:removeItem(itemName, 1, 'outfit_equip') then
            return result(playerSource, false, 'Das Kleidungsstück konnte nicht ausgerüstet werden.')
        end
        if previousItem and not player:addItem(previousItem, 1, 'outfit_swap') then
            player:addItem(itemName, 1, 'outfit_equip_rollback')
            return result(playerSource, false, 'Für das bisherige Kleidungsstück ist kein Platz.')
        end

        outfit[slotKey] = itemName
        player:setMetadata('outfit', outfit)
        player:save()
        pushOutfit(playerSource, player)
        TriggerEvent('ms_inventory:server:outfitChanged', playerSource, slotKey, itemName, previousItem)
        result(playerSource, true, ('%s ausgerüstet.'):format(item.label))
    end)
end)

RegisterNetEvent('ms_inventory:server:unequip', function(slotKey)
    local playerSource = source
    runAction(playerSource, 'unequip', function()
        local player = getPlayer(playerSource)
        slotKey = type(slotKey) == 'string' and slotKey or nil
        if not player or not OutfitSlots[slotKey] then return result(playerSource, false, 'Outfit-Slot ist ungültig.') end

        local outfit = getOutfit(player)
        local itemName = outfit[slotKey]
        local item = itemName and exports.MSCore:GetItem(itemName)
        if not item then return result(playerSource, false, 'Dieser Outfit-Slot ist leer.') end
        if not player:addItem(itemName, 1, 'outfit_unequip') then
            return result(playerSource, false, 'Dein Inventar hat keinen Platz für das Kleidungsstück.')
        end

        outfit[slotKey] = nil
        player:setMetadata('outfit', outfit)
        player:save()
        pushOutfit(playerSource, player)
        TriggerEvent('ms_inventory:server:outfitChanged', playerSource, slotKey, nil, itemName)
        result(playerSource, true, ('%s abgelegt.'):format(item.label))
    end)
end)

RegisterNetEvent('ms_inventory:server:requestOutfit', function()
    pushOutfit(source)
end)

AddEventHandler('mscore:server:itemChanged', function(playerSource)
    scheduleRefresh(playerSource)
end)

AddEventHandler('mscore:server:itemCatalogUpdated', function()
    for playerSource in pairs(OpenInventories) do scheduleRefresh(playerSource) end
end)

AddEventHandler('mscore:server:playerLoaded', function(playerSource, player)
    local characterId = player and player.characterId
    SetTimeout(1000, function()
        local current = getPlayer(playerSource)
        if current and current.characterId == characterId then pushOutfit(playerSource, current) end
    end)
end)

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    OpenInventories[playerSource] = nil
    BusyPlayers[playerSource] = nil
    RefreshScheduled[playerSource] = nil
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    OpenInventories[playerSource] = nil
    BusyPlayers[playerSource] = nil
    RefreshScheduled[playerSource] = nil
    for key in pairs(LastActions) do
        if key:match(('^%d+:'):format(playerSource)) then LastActions[key] = nil end
    end
end)

function OpenInventory(playerSource)
    playerSource = tonumber(playerSource)
    if not playerSource or not getPlayer(playerSource) then return false end
    OpenInventories[playerSource] = true
    sendPayload(playerSource, 'ms_inventory:client:open')
    return true
end

exports('OpenInventory', OpenInventory)

exports('GetOutfit', function(playerSource)
    local player = getPlayer(playerSource)
    if not player then return {} end
    local copy = {}
    for slotKey, itemName in pairs(getOutfit(player)) do copy[slotKey] = itemName end
    return copy
end)
