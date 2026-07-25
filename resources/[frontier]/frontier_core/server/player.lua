local Player = {}
Player.__index = Player

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
    instance.metadata = json.decode(row.metadata or '{}') or {}
    instance.coords = json.decode(row.coords or 'null')
    instance.dirty = false
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
    TriggerClientEvent('frontier:client:setPlayerData', self.source, self:getPublicData())
end

function Player:addMoney(account, amount, reason)
    if not self.money[account] or not Frontier.IsInteger(amount) then return false end
    self.money[account] = self.money[account] + amount
    self.dirty = true
    self:sync()
    TriggerEvent('frontier:server:moneyChanged', self.source, account, amount, reason or 'unknown')
    return true
end

function Player:removeMoney(account, amount, reason)
    if not self.money[account] or not Frontier.IsInteger(amount) then return false end
    if self.money[account] < amount then return false end
    self.money[account] = self.money[account] - amount
    self.dirty = true
    self:sync()
    TriggerEvent('frontier:server:moneyChanged', self.source, account, -amount, reason or 'unknown')
    return true
end

function Player:getInventory()
    if type(self.metadata.inventory) ~= 'table' then
        self.metadata.inventory = {}
    end
    return self.metadata.inventory
end

function Player:addItem(itemName, amount, reason)
    local item = type(itemName) == 'string' and Config.Items[itemName]
    if not item or not Frontier.IsInteger(amount) or amount < 1 then return false end

    local inventory = self:getInventory()
    local current = tonumber(inventory[itemName]) or 0
    local maxStack = tonumber(item.maxStack) or Config.MaxItemStack
    if current + amount > maxStack then return false end

    inventory[itemName] = current + amount
    self.dirty = true
    self:sync()
    TriggerEvent('frontier:server:itemChanged', self.source, itemName, amount, reason or 'unknown')
    return true
end

function Player:removeItem(itemName, amount, reason)
    local item = type(itemName) == 'string' and Config.Items[itemName]
    if not item or not Frontier.IsInteger(amount) or amount < 1 then return false end

    local inventory = self:getInventory()
    local current = tonumber(inventory[itemName]) or 0
    if current < amount then return false end

    local remaining = current - amount
    inventory[itemName] = remaining > 0 and remaining or nil
    self.dirty = true
    self:sync()
    TriggerEvent('frontier:server:itemChanged', self.source, itemName, -amount, reason or 'unknown')
    return true
end

function Player:setJob(job, grade)
    grade = tonumber(grade)
    if not Config.Jobs[job] or not grade or not Config.Jobs[job].grades[grade] then return false end
    self.job, self.jobGrade, self.dirty = job, grade, true
    self:sync()
    TriggerEvent('frontier:server:jobChanged', self.source, job, grade)
    return true
end

function Player:setMetadata(key, value)
    if type(key) ~= 'string' or #key > 64 then return false end
    self.metadata[key], self.dirty = value, true
    self:sync()
    return true
end

function Player:save(coords)
    if coords then self.coords = coords end
    MySQL.update.await([[
        UPDATE frontier_characters
        SET job = ?, job_grade = ?, group_name = ?, cash = ?, bank = ?,
            coords = ?, metadata = ?
        WHERE id = ?
    ]], {
        self.job, self.jobGrade, self.group, self.money.cash, self.money.bank,
        json.encode(self.coords), json.encode(self.metadata), self.characterId
    })
    self.dirty = false
end

Frontier.Player = Player
