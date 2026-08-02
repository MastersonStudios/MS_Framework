MSCharacter = MSCharacter or {}
MSCharacter.__index = MSCharacter

local function defaultJob()
    local jobName = Config.DefaultCharacter.job
    local definition = Config.Jobs[jobName] or {}
    local grade = tonumber(Config.DefaultCharacter.jobGrade) or 0
    local gradeDefinition = type(definition.grades) == 'table' and definition.grades[grade] or {}
    return jobName, grade, tostring(gradeDefinition and gradeDefinition.label or definition.label or jobName)
end

local function normalizeCoords(value)
    value = MSUtils.SafeDecode(value, {})
    local fallback = Config.DefaultCharacter.spawn
    return {
        x = tonumber(value.x) or fallback.x,
        y = tonumber(value.y) or fallback.y,
        z = tonumber(value.z) or fallback.z,
        w = tonumber(value.w or value.heading) or fallback.w
    }
end

function MSCharacter.new(row, owner)
    assert(type(row) == 'table', 'Charakterdaten fehlen.')
    local self = setmetatable({}, MSCharacter)
    local jobName, jobGrade, jobLabel = defaultJob()

    self.owner = owner
    self.id = tonumber(row.id or row.characterId)
    self.accountId = tonumber(row.account_id or owner.accountId)
    self.firstname = tostring(row.firstname or '')
    self.lastname = tostring(row.lastname or '')
    self.dateOfBirth = row.date_of_birth and tostring(row.date_of_birth):sub(1, 10) or nil
    self.sex = row.sex == 'female' and 'female' or 'male'
    self.group = tostring(row.group_name or owner.group or Config.DefaultCharacter.group)
    self.job = tostring(row.job_name or jobName)
    self.jobGrade = tonumber(row.job_grade) or jobGrade
    self.jobLabel = tostring(row.job_label or jobLabel)
    self.money = MSUtils.RoundMoney(row.money or Config.DefaultCharacter.money)
    self.gold = MSUtils.RoundMoney(row.gold or Config.DefaultCharacter.gold)
    self.xp = math.max(0, math.floor(tonumber(row.xp) or Config.DefaultCharacter.xp))
    self.health = math.max(0, math.floor(tonumber(row.health) or Config.DefaultCharacter.health))
    self.stamina = math.max(0, math.floor(tonumber(row.stamina) or Config.DefaultCharacter.stamina))
    self.isDead = row.is_dead == true or tonumber(row.is_dead) == 1
    self.coords = normalizeCoords(row.coords)
    self.metadata = MSUtils.SafeDecode(row.metadata, {})
    self.dirty = false
    return self
end

function MSCharacter:GetId()
    return self.id
end

function MSCharacter:GetSource()
    return self.owner and self.owner.source or nil
end

function MSCharacter:MarkDirty()
    self.dirty = true
end

function MSCharacter:ToClientData()
    return {
        characterId = self.id,
        firstname = self.firstname,
        lastname = self.lastname,
        dateOfBirth = self.dateOfBirth,
        sex = self.sex,
        group = self.group,
        job = {
            name = self.job,
            grade = self.jobGrade,
            label = self.jobLabel
        },
        money = self.money,
        gold = self.gold,
        xp = self.xp,
        health = self.health,
        stamina = self.stamina,
        isDead = self.isDead,
        coords = MSUtils.Copy(self.coords),
        metadata = MSUtils.Copy(self.metadata)
    }
end

function MSCharacter:ToSelectionData()
    return {
        id = self.id,
        firstname = self.firstname,
        lastname = self.lastname,
        dateOfBirth = self.dateOfBirth,
        sex = self.sex,
        job = self.job,
        jobGrade = self.jobGrade,
        jobLabel = self.jobLabel,
        money = self.money,
        gold = self.gold,
        lastPlayedAt = self.lastPlayedAt,
        metadata = MSUtils.Copy(self.metadata)
    }
end

function MSCharacter:Sync()
    local source = self:GetSource()
    if not source or not GetPlayerName(source) then return end
    local data = self:ToClientData()
    self.owner:SyncState(data)
    TriggerClientEvent('mscore:client:setPlayerData', source, data)
end

local function validCurrency(currency)
    return currency == 'money' or currency == 'gold'
end

function MSCharacter:GetMoney(currency)
    if not validCurrency(currency) then return nil end
    return self[currency]
end

function MSCharacter:SetMoney(currency, amount, reason)
    if not validCurrency(currency) or not MSUtils.IsFiniteNumber(amount) then
        return false, 'Ungültige Währung oder Summe.'
    end
    local maximum = tonumber(Config.Limits.MaximumMoney) or 100000000
    amount = MSUtils.RoundMoney(amount)
    if amount < 0 or amount > maximum then return false, 'Summe außerhalb des erlaubten Bereichs.' end

    local previous = self[currency]
    self[currency] = amount
    self:MarkDirty()
    self:Sync()
    TriggerEvent('mscore:server:moneyChanged', self:GetSource(), currency, amount, previous, reason or 'set')
    return true, amount
end

function MSCharacter:AddMoney(currency, amount, reason)
    if not MSUtils.IsFiniteNumber(amount) or tonumber(amount) <= 0 then
        return false, 'Die Summe muss größer als null sein.'
    end
    return self:SetMoney(currency, (self:GetMoney(currency) or 0) + tonumber(amount), reason or 'add')
end

function MSCharacter:RemoveMoney(currency, amount, reason)
    if not MSUtils.IsFiniteNumber(amount) or tonumber(amount) <= 0 then
        return false, 'Die Summe muss größer als null sein.'
    end
    local current = self:GetMoney(currency)
    if current == nil then return false, 'Unbekannte Währung.' end
    if current < tonumber(amount) then return false, 'Nicht genügend Guthaben.' end
    return self:SetMoney(currency, current - tonumber(amount), reason or 'remove')
end

function MSCharacter:SetJob(jobName, grade, reason)
    jobName = tostring(jobName or ''):lower()
    grade = math.floor(tonumber(grade) or -1)
    local job = MSCore and MSCore.GetJob and MSCore.GetJob(jobName) or Config.Jobs[jobName]
    local gradeDefinition = job and type(job.grades) == 'table' and job.grades[grade] or nil
    if not job or not gradeDefinition then return false, 'Job oder Jobgrad ist nicht registriert.' end

    local previous = { name = self.job, grade = self.jobGrade, label = self.jobLabel }
    self.job = jobName
    self.jobGrade = grade
    self.jobLabel = tostring(gradeDefinition.label or job.label or jobName)
    self:MarkDirty()
    self:Sync()
    TriggerEvent('mscore:server:jobChanged', self:GetSource(), self.job, self.jobGrade, previous, reason)
    return true
end

function MSCharacter:SetGroup(groupName)
    groupName = MSUtils.Trim(tostring(groupName or '')):lower()
    if groupName == '' or #groupName > 40 or groupName:find('[^%w_%-]') then
        return false, 'Ungültige Gruppe.'
    end
    self.group = groupName
    self:MarkDirty()
    self:Sync()
    return true
end

function MSCharacter:SetMetadata(key, value)
    if type(key) ~= 'string' or key == '' or #key > 80 then return false, 'Ungültiger Metadaten-Schlüssel.' end
    local nextMetadata = MSUtils.Copy(self.metadata)
    nextMetadata[key] = value
    local encoded = MSUtils.SafeEncode(nextMetadata)
    if #encoded > (tonumber(Config.Limits.MetadataBytes) or 32768) then
        return false, 'Metadaten überschreiten das Größenlimit.'
    end
    self.metadata = nextMetadata
    self:MarkDirty()
    self:Sync()
    return true
end

function MSCharacter:GetMetadata(key)
    if key == nil then return MSUtils.Copy(self.metadata) end
    return MSUtils.Copy(self.metadata[key])
end

function MSCharacter:SetPosition(coords)
    if type(coords) ~= 'table' then return false end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z or math.abs(x) > 10000 or math.abs(y) > 10000 then return false end
    self.coords = {
        x = x,
        y = y,
        z = z,
        w = tonumber(coords.w or coords.heading) or 0.0
    }
    self:MarkDirty()
    return true
end

function MSCharacter:SetVitals(health, stamina, isDead)
    if health ~= nil then self.health = math.max(0, math.floor(tonumber(health) or self.health)) end
    if stamina ~= nil then self.stamina = math.max(0, math.floor(tonumber(stamina) or self.stamina)) end
    if isDead ~= nil then self.isDead = isDead == true end
    self:MarkDirty()
end

function MSCharacter:AddXp(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    self.xp = math.max(0, self.xp + amount)
    self:MarkDirty()
    self:Sync()
    return true
end

function MSCharacter:Save(force)
    if not self.id or (not self.dirty and force ~= true) then return true end
    local affected = MySQL.update.await([[
        UPDATE `mscore_characters`
        SET `firstname` = ?, `lastname` = ?, `date_of_birth` = ?, `sex` = ?,
            `group_name` = ?, `job_name` = ?, `job_grade` = ?, `job_label` = ?,
            `money` = ?, `gold` = ?, `xp` = ?, `health` = ?, `stamina` = ?,
            `is_dead` = ?, `coords` = ?, `metadata` = ?
        WHERE `id` = ? AND `account_id` = ? AND `is_deleted` = 0
    ]], {
        self.firstname,
        self.lastname,
        self.dateOfBirth,
        self.sex,
        self.group,
        self.job,
        self.jobGrade,
        self.jobLabel,
        self.money,
        self.gold,
        self.xp,
        self.health,
        self.stamina,
        self.isDead and 1 or 0,
        MSUtils.SafeEncode(self.coords),
        MSUtils.SafeEncode(self.metadata),
        self.id,
        self.accountId
    })
    if affected == 1 then self.dirty = false end
    return affected == 1
end
