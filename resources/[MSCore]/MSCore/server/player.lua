local Player = {}
Player.__index = Player
local InventoryLockSequence = 0

local function decodeJson(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end

    local success, decoded = pcall(json.decode, value)
    return success and decoded ~= nil and decoded or fallback
end

local function bindPlayerMethods(instance)
    -- Cfx überträgt Tabellen zwischen Resources, aber nicht deren Metatabelle.
    -- Gebundene Funktionsreferenzen halten alle bestehenden player:method()-
    -- Aufrufe auf dem kanonischen MSCore-Spielerobjekt funktionsfähig.
    for methodName, method in pairs(Player) do
        if methodName ~= 'new' and type(method) == 'function' then
            local boundMethod = method
            instance[methodName] = function(_, ...)
                return boundMethod(instance, ...)
            end
        end
    end
end

function Player:new(source, row)
    local instance = setmetatable({}, self)
    instance.source = source
    instance.characterId = row.id
    instance.userId = row.user_id
    instance.firstname = row.firstname
    instance.lastname = row.lastname
    instance.dateOfBirth = row.date_of_birth
    instance.sex = row.sex
    instance.job = row.job
    instance.jobGrade = row.job_grade
    instance.group = row.group_name
    instance.money = { cash = row.cash, bank = row.bank }
    instance.metadata = decodeJson(row.metadata, {})
    if type(instance.metadata) ~= 'table' then instance.metadata = {} end
    instance.coords = decodeJson(row.coords, nil)
    instance.dirty = false
    instance.inventoryLock = nil
    instance.savePending = false
    bindPlayerMethods(instance)
    return instance
end

function Player:getName()
    return ('%s %s'):format(self.firstname, self.lastname)
end

function Player:getPublicData()
    return {
        source = self.source,
        characterId = self.characterId,
        firstname = self.firstname,
        lastname = self.lastname,
        name = self:getName(),
        dateOfBirth = self.dateOfBirth,
        sex = self.sex,
        job = self.job,
        jobGrade = self.jobGrade,
        group = self.group,
        money = self.money,
        metadata = self.metadata
    }
end

function Player:sync()
    TriggerClientEvent('mscore:client:setPlayerData', self.source, self:getPublicData())
end

function Player:addMoney(account, amount, reason)
    if not self.money[account] or not MSCore.IsInteger(amount) then return false end
    self.money[account] = self.money[account] + amount
    self.dirty = true
    self:sync()
    TriggerEvent('mscore:server:moneyChanged', self.source, account, amount, reason or 'unknown')
    return true
end

function Player:removeMoney(account, amount, reason)
    if not self.money[account] or not MSCore.IsInteger(amount) then return false end
    if self.money[account] < amount then return false end
    self.money[account] = self.money[account] - amount
    self.dirty = true
    self:sync()
    TriggerEvent('mscore:server:moneyChanged', self.source, account, -amount, reason or 'unknown')
    return true
end

function Player:getInventory()
    if type(self.metadata.inventory) ~= 'table' then
        self.metadata.inventory = {}
    end
    return self.metadata.inventory
end

function Player:getMetadataJson()
    return json.encode(self.metadata)
end

local function inventoryLimits()
    local config = type(Config.Inventory) == 'table' and Config.Inventory or {}
    return {
        slots = math.max(1, math.floor(tonumber(config.Slots) or 30)),
        maxWeight = math.max(0, math.floor(tonumber(config.MaxWeight) or 30000))
    }
end

function Player:getInventoryUsage(inventory)
    inventory = type(inventory) == 'table' and inventory or self:getInventory()
    local usage = { slots = 0, weight = 0, amount = 0 }

    for itemName, rawAmount in pairs(inventory) do
        local amount = math.max(0, math.floor(tonumber(rawAmount) or 0))
        local item = amount > 0 and MSCore.GetItemDefinition(itemName)
        if item then
            local maxStack = math.max(1, math.floor(
                tonumber(item.maxStack) or tonumber(Config.MaxItemStack) or 100
            ))
            usage.slots = usage.slots + math.ceil(amount / maxStack)
            usage.weight = usage.weight + amount * math.max(0, tonumber(item.weight) or 0)
            usage.amount = usage.amount + amount
        end
    end

    local limits = inventoryLimits()
    usage.maxSlots = limits.slots
    usage.maxWeight = limits.maxWeight
    usage.hasCapacity = usage.slots <= limits.slots and usage.weight <= limits.maxWeight
    return usage
end

function Player:canCarryItem(itemName, amount, inventory)
    local item = type(itemName) == 'string' and MSCore.GetItemDefinition(itemName)
    if not item or not MSCore.IsInteger(amount) or amount < 1 then return false end

    local simulated = {}
    for name, current in pairs(type(inventory) == 'table' and inventory or self:getInventory()) do
        simulated[name] = math.max(0, math.floor(tonumber(current) or 0))
    end
    simulated[itemName] = (simulated[itemName] or 0) + amount
    return self:getInventoryUsage(simulated).hasCapacity
end

function Player:acquireInventoryLock()
    if self.inventoryLock then return nil end
    InventoryLockSequence = InventoryLockSequence + 1
    if InventoryLockSequence > 2147483647 then InventoryLockSequence = 1 end
    local token = ('%d:%d:%d'):format(
        tonumber(self.characterId) or 0,
        os.time(),
        InventoryLockSequence
    )
    self.inventoryLock = token
    return token
end

function Player:releaseInventoryLock(token)
    if not self.inventoryLock or self.inventoryLock ~= token then return false end
    local pendingSave = self.savePending
    self.savePending = false

    if not pendingSave then
        self.inventoryLock = nil
        return true
    end

    local saveCallOk, saveResult = pcall(function()
        return self:save(nil, token)
    end)
    self.inventoryLock = nil
    if not saveCallOk then error(saveResult) end
    return saveResult == true
end

function Player:addItem(itemName, amount, reason, lockToken)
    if self.inventoryLock and self.inventoryLock ~= lockToken then return false end
    local item = type(itemName) == 'string' and MSCore.GetItemDefinition(itemName)
    if not item or not MSCore.IsInteger(amount) or amount < 1 then return false end
    if not self:canCarryItem(itemName, amount) then return false end

    local inventory = self:getInventory()
    local current = tonumber(inventory[itemName]) or 0

    inventory[itemName] = current + amount
    self.dirty = true
    self:sync()
    TriggerEvent('mscore:server:itemChanged', self.source, itemName, amount, reason or 'unknown')
    return true
end

function Player:removeItem(itemName, amount, reason, lockToken)
    if self.inventoryLock and self.inventoryLock ~= lockToken then return false end
    local item = type(itemName) == 'string' and MSCore.GetItemDefinition(itemName)
    if not item or not MSCore.IsInteger(amount) or amount < 1 then return false end

    local inventory = self:getInventory()
    local current = tonumber(inventory[itemName]) or 0
    if current < amount then return false end

    local remaining = current - amount
    inventory[itemName] = remaining > 0 and remaining or nil
    self.dirty = true
    self:sync()
    TriggerEvent('mscore:server:itemChanged', self.source, itemName, -amount, reason or 'unknown')
    return true
end

function Player:setJob(job, grade)
    grade = tonumber(grade)
    if not Config.Jobs[job] or not grade or not Config.Jobs[job].grades[grade] then return false end
    self.job, self.jobGrade, self.dirty = job, grade, true
    self:sync()
    TriggerEvent('mscore:server:jobChanged', self.source, job, grade)
    return true
end

function Player:setMetadata(key, value)
    if type(key) ~= 'string' or #key > 64 then return false end
    self.metadata[key], self.dirty = value, true
    self:sync()
    return true
end

function Player:setMetadataValues(values)
    if type(values) ~= 'table' then return false end

    local entries = {}
    for key, value in pairs(values) do
        if type(key) ~= 'string' or #key < 1 or #key > 64 then return false end
        entries[#entries + 1] = { key = key, value = value }
        if #entries > 64 then return false end
    end
    if #entries == 0 then return false end

    for _, entry in ipairs(entries) do
        self.metadata[entry.key] = entry.value
    end
    self.dirty = true
    self:sync()
    return true
end

function Player:save(coords, lockToken)
    if coords then self.coords = coords end
    if self.inventoryLock and self.inventoryLock ~= lockToken then
        self.savePending = true
        return false
    end

    local affected = MySQL.update.await([[
        UPDATE mscore_characters
        SET job = ?, job_grade = ?, group_name = ?, cash = ?, bank = ?,
            coords = ?, metadata = ?
        WHERE id = ?
    ]], {
        self.job, self.jobGrade, self.group, self.money.cash, self.money.bank,
        json.encode(self.coords), json.encode(self.metadata), self.characterId
    })
    if affected == nil then return false end
    self.dirty = false
    return true
end

MSCore.Player = Player

function GetInventoryLimits()
    return inventoryLimits()
end

exports('GetInventoryLimits', GetInventoryLimits)
