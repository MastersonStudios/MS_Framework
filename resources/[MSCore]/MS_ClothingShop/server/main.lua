local Sessions = {}
local BusyPlayers = {}
local LastActions = {}

local function debugLog(message, ...)
    if not MSClothingShopConfig.Debug then return end
    print(('[MS_ClothingShop] ' .. message):format(...))
end

local function getPlayer(playerSource)
    return exports.MSCore:GetPlayer(tonumber(playerSource))
end

local function shopById(shopId)
    return type(shopId) == 'string' and MSClothingShopConfig.Shops[shopId] or nil
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

local function onCooldown(playerSource, action)
    local key = ('%d:%s'):format(playerSource, action)
    local now = GetGameTimer()
    local last = LastActions[key]
    if last and now - last < MSClothingShopConfig.ActionCooldown then return true end
    LastActions[key] = now
    return false
end

local function currentShop(playerSource)
    local shopId = Sessions[playerSource]
    local shop = shopById(shopId)
    if not shop or distanceTo(playerSource, shop.seller) > MSClothingShopConfig.ServerInteractionDistance then
        Sessions[playerSource] = nil
        return nil, nil
    end
    return shopId, shop
end

local function configuredProduct(itemName)
    if type(itemName) ~= 'string' then return nil end
    for _, product in ipairs(MSClothingShopConfig.Products or {}) do
        if product.item == itemName then return product end
    end
end

local function productAllowedAtShop(shop, itemName)
    if type(shop.products) ~= 'table' then return true end
    for _, allowedItem in ipairs(shop.products) do
        if allowedItem == itemName then return true end
    end
    return false
end

local function productView(product, item)
    return {
        item = item.name,
        label = item.label,
        description = item.description,
        category = item.metadata.clothingSlot,
        rarity = item.rarity,
        weight = tonumber(item.weight) or 0,
        price = math.max(0, math.floor(tonumber(product.price) or 0)),
        order = math.floor(tonumber(product.order) or 0),
        componentHash = tonumber(item.metadata.componentHash),
        sex = item.metadata.sex
    }
end

local function productCatalog(player, shop)
    local products = {}
    for _, product in ipairs(MSClothingShopConfig.Products or {}) do
        local item = exports.MSCore:GetItem(product.item)
        local metadata = item and item.metadata
        local sex = metadata and metadata.sex
        if item and metadata and type(metadata.clothingSlot) == 'string'
            and tonumber(metadata.componentHash)
            and (not sex or sex == 'unisex' or sex == player.sex)
            and productAllowedAtShop(shop, product.item) then
            products[#products + 1] = productView(product, item)
        end
    end
    table.sort(products, function(left, right)
        if left.order == right.order then return left.label < right.label end
        return left.order < right.order
    end)
    return products
end

local function menuPayload(playerSource, shopId)
    local player = getPlayer(playerSource)
    local shop = player and shopById(shopId)
    if not player or not shop then return nil end

    local categories = {}
    for _, category in ipairs(MSClothingShopConfig.Categories or {}) do
        categories[#categories + 1] = {
            key = category.key,
            label = category.label
        }
    end

    return {
        shop = {
            id = shopId,
            label = shop.label
        },
        player = {
            name = player:getName(),
            sex = player.sex,
            balance = tonumber(player.money[MSClothingShopConfig.Account]) or 0
        },
        products = productCatalog(player, shop),
        categories = categories,
        account = MSClothingShopConfig.Account,
        currencyLabel = MSClothingShopConfig.CurrencyLabel,
        maxCartItems = MSClothingShopConfig.MaxCartItems
    }
end

local function refresh(playerSource)
    local shopId = Sessions[playerSource]
    local payload = shopId and menuPayload(playerSource, shopId)
    if payload then TriggerClientEvent('ms_clothingshop:client:refresh', playerSource, payload) end
end

local function result(playerSource, success, message, clearCart)
    TriggerClientEvent('ms_clothingshop:client:result', playerSource, {
        success = success == true,
        message = message,
        clearCart = clearCart == true
    })
    if success then refresh(playerSource) end
end

local function validateCart(player, shop, rawCart)
    if type(rawCart) ~= 'table' or #rawCart < 1 or #rawCart > MSClothingShopConfig.MaxCartItems then
        return nil, nil, 'Die Einkaufsliste ist leer oder zu groß.'
    end

    local selected, seen, total = {}, {}, 0
    for index = 1, #rawCart do
        local itemName = rawCart[index]
        local product = configuredProduct(itemName)
        local item = product and exports.MSCore:GetItem(itemName)
        local metadata = item and item.metadata
        local itemSex = metadata and metadata.sex
        if type(itemName) ~= 'string' or seen[itemName] or not product or not item
            or type(metadata) ~= 'table'
            or not productAllowedAtShop(shop, itemName)
            or type(metadata.clothingSlot) ~= 'string'
            or not tonumber(metadata.componentHash)
            or (itemSex and itemSex ~= 'unisex' and itemSex ~= player.sex) then
            return nil, nil, 'Die Einkaufsliste enthält einen ungültigen Artikel.'
        end

        local price = math.max(0, math.floor(tonumber(product.price) or 0))
        seen[itemName] = true
        total = total + price
        selected[#selected + 1] = {
            item = itemName,
            label = item.label,
            price = price
        }
    end

    local simulated = {}
    for itemName, amount in pairs(player:getInventory()) do
        simulated[itemName] = math.max(0, math.floor(tonumber(amount) or 0))
    end
    for _, product in ipairs(selected) do
        simulated[product.item] = (simulated[product.item] or 0) + 1
    end
    if not player:getInventoryUsage(simulated).hasCapacity then
        return nil, nil, 'Dein Inventar hat nicht genug Platz für die gesamte Einkaufsliste.'
    end
    return selected, total
end

RegisterNetEvent('ms_clothingshop:server:open', function(shopId)
    local playerSource = source
    local shop = shopById(shopId)
    if not getPlayer(playerSource) or not shop then return end
    if distanceTo(playerSource, shop.seller) > MSClothingShopConfig.ServerInteractionDistance then return end

    Sessions[playerSource] = shopId
    local payload = menuPayload(playerSource, shopId)
    if payload then TriggerClientEvent('ms_clothingshop:client:open', playerSource, payload) end
end)

RegisterNetEvent('ms_clothingshop:server:close', function()
    Sessions[source] = nil
end)

RegisterNetEvent('ms_clothingshop:server:refresh', function()
    if onCooldown(source, 'refresh') or not currentShop(source) then return end
    refresh(source)
end)

RegisterNetEvent('ms_clothingshop:server:purchase', function(rawCart)
    local playerSource = source
    if BusyPlayers[playerSource] or onCooldown(playerSource, 'purchase') then
        return result(playerSource, false, 'Bitte warte einen Moment.')
    end

    local _, shop = currentShop(playerSource)
    if not shop then return end
    BusyPlayers[playerSource] = true
    local transaction = {
        player = nil,
        total = 0,
        charged = false,
        added = {},
        completed = false
    }

    local function rollback()
        if not transaction.player or not transaction.charged then return end
        for _, itemName in ipairs(transaction.added) do
            transaction.player:removeItem(itemName, 1, 'clothing_cart_rollback')
        end
        transaction.player:addMoney(
            MSClothingShopConfig.Account,
            transaction.total,
            'clothing_cart_refund'
        )
        transaction.player:save()
        transaction.charged = false
        transaction.added = {}
    end

    local success, err = xpcall(function()
        local player = getPlayer(playerSource)
        if not player then return end
        transaction.player = player

        local selected, total, validationError = validateCart(player, shop, rawCart)
        if not selected then return result(playerSource, false, validationError) end
        if total < 1 then return result(playerSource, false, 'Der Gesamtpreis ist ungültig.') end
        if not player:removeMoney(MSClothingShopConfig.Account, total, 'clothing_cart_purchase') then
            return result(playerSource, false, 'Dein Guthaben reicht für diese Einkaufsliste nicht aus.')
        end
        transaction.total = total
        transaction.charged = true

        for _, product in ipairs(selected) do
            if not player:addItem(product.item, 1, 'clothing_cart_purchase') then
                rollback()
                return result(playerSource, false, 'Der Einkauf wurde vollständig zurückgesetzt.')
            end
            transaction.added[#transaction.added + 1] = product.item
        end

        player:save()
        transaction.charged = false
        transaction.completed = true
        TriggerEvent('ms_clothingshop:server:purchased', playerSource, selected, total)
        result(
            playerSource,
            true,
            ('%d Kleidungsstücke für %s%d gekauft.'):format(
                #selected,
                MSClothingShopConfig.CurrencyLabel,
                total
            ),
            true
        )
        debugLog('%d purchased %d items for %d', playerSource, #selected, total)
    end, debug.traceback)

    BusyPlayers[playerSource] = nil
    if not success then
        if not transaction.completed then
            local rollbackSuccess, rollbackError = pcall(rollback)
            if not rollbackSuccess then
                print(('[MS_ClothingShop] Rückabwicklung von %d fehlgeschlagen: %s'):format(
                    playerSource,
                    tostring(rollbackError)
                ))
            end
        end
        print(('[MS_ClothingShop] Einkauf von %d fehlgeschlagen: %s'):format(playerSource, tostring(err)))
        if transaction.completed then
            result(playerSource, true, 'Der Einkauf wurde abgeschlossen.', true)
        else
            result(playerSource, false, 'Der Einkauf konnte nicht verarbeitet werden.')
        end
    end
end)

AddEventHandler('mscore:server:itemCatalogUpdated', function()
    for playerSource in pairs(Sessions) do refresh(playerSource) end
end)

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    Sessions[playerSource] = nil
    BusyPlayers[playerSource] = nil
end)

AddEventHandler('playerDropped', function()
    local playerSource = source
    Sessions[playerSource] = nil
    BusyPlayers[playerSource] = nil
    for key in pairs(LastActions) do
        if key:match(('^%d+:'):format(playerSource)) then LastActions[key] = nil end
    end
end)
