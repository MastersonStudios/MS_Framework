MSPlayer = MSPlayer or {}
MSPlayer.__index = MSPlayer

local function defaultJobData()
    local jobName = tostring(Config.DefaultCharacter.job)
    local grade = tonumber(Config.DefaultCharacter.jobGrade) or 0
    local job = Config.Jobs[jobName] or {}
    local gradeDefinition = type(job.grades) == 'table' and job.grades[grade] or {}
    return jobName, grade, tostring(gradeDefinition and gradeDefinition.label or job.label or jobName)
end

local function validBirthDate(value)
    if value == nil or value == '' then return nil end
    value = tostring(value)
    if not value:match('^%d%d%d%d%-%d%d%-%d%d$') then return false end
    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or year < 1800 or year > 2100 or month < 1 or month > 12 or day < 1 then return false end
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0) then days[2] = 29 end
    return day <= days[month] and value or false
end

function MSPlayer.new(source, identifier, accountRow)
    local self = setmetatable({}, MSPlayer)
    self.source = tonumber(source)
    self.identifier = identifier
    self.accountId = tonumber(accountRow.id)
    self.group = tostring(accountRow.group_name or Config.DefaultCharacter.group)
    self.maxCharacters = math.max(1, math.floor(tonumber(accountRow.max_characters) or Config.MaxCharacters))
    self.characters = {}
    self.activeCharacterId = nil
    return self
end

function MSPlayer:LoadCharacters()
    local rows = MySQL.query.await([[
        SELECT * FROM `mscore_characters`
        WHERE `account_id` = ? AND `is_deleted` = 0
        ORDER BY `id` ASC
    ]], { self.accountId }) or {}

    self.characters = {}
    for _, row in ipairs(rows) do
        local character = MSCharacter.new(row, self)
        character.lastPlayedAt = row.last_played_at
        self.characters[character.id] = character
    end
    return self:GetCharacters()
end

function MSPlayer:GetCharacters()
    local characters = {}
    for _, character in pairs(self.characters) do
        characters[#characters + 1] = character:ToSelectionData()
    end
    table.sort(characters, function(left, right) return left.id < right.id end)
    return characters
end

function MSPlayer:GetCharacter(characterId)
    return self.characters[tonumber(characterId)]
end

function MSPlayer:GetActiveCharacter()
    return self.activeCharacterId and self.characters[self.activeCharacterId] or nil
end

function MSPlayer:SyncState(characterData)
    local player = Player(self.source)
    if not player or not player.state then return end
    player.state:set('MSCoreSession', {
        accountId = self.accountId,
        group = self.group,
        maxCharacters = self.maxCharacters,
        loaded = characterData ~= nil
    }, true)
    player.state:set('MSCharacter', characterData and {
        id = characterData.characterId,
        firstname = characterData.firstname,
        lastname = characterData.lastname,
        group = characterData.group,
        job = characterData.job,
        money = characterData.money,
        gold = characterData.gold
    } or nil, true)
end

function MSPlayer:SetSelectionBucket()
    if Config.SelectionBucketEnabled and type(SetPlayerRoutingBucket) == 'function' then
        SetPlayerRoutingBucket(self.source, (tonumber(Config.SelectionBucketBase) or 60000) + self.source)
    end
end

function MSPlayer:CreateCharacter(data)
    data = type(data) == 'table' and data or {}
    if #self:GetCharacters() >= self.maxCharacters then return nil, 'Maximale Charakteranzahl erreicht.' end

    local firstname = MSUtils.Trim(data.firstname or data.firstName)
    local lastname = MSUtils.Trim(data.lastname or data.lastName)
    if not MSUtils.ValidName(firstname) or not MSUtils.ValidName(lastname) then
        return nil, 'Vor- oder Nachname ist ungültig.'
    end
    local requestedSex = tostring(data.sex or ''):lower()
    local sex = requestedSex == 'female' and 'female' or requestedSex == 'male' and 'male' or nil
    if not sex then return nil, 'Geschlecht muss male oder female sein.' end
    local dateOfBirth = validBirthDate(data.dateOfBirth or data.date_of_birth or data.dob)
    if dateOfBirth == false then return nil, 'Geburtsdatum ist ungültig.' end

    local jobName, jobGrade, jobLabel = defaultJobData()
    local spawn = Config.DefaultCharacter.spawn
    local metadata = type(data.metadata) == 'table' and data.metadata or {}
    local encodedMetadata = MSUtils.SafeEncode(metadata)
    if #encodedMetadata > (tonumber(Config.Limits.MetadataBytes) or 32768) then
        return nil, 'Metadaten überschreiten das Größenlimit.'
    end

    local characterId = MySQL.insert.await([[
        INSERT INTO `mscore_characters`
            (`account_id`, `firstname`, `lastname`, `date_of_birth`, `sex`, `group_name`,
             `job_name`, `job_grade`, `job_label`, `money`, `gold`, `xp`, `health`,
             `stamina`, `is_dead`, `coords`, `metadata`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
    ]], {
        self.accountId,
        firstname,
        lastname,
        dateOfBirth,
        sex,
        self.group,
        jobName,
        jobGrade,
        jobLabel,
        MSUtils.RoundMoney(Config.DefaultCharacter.money),
        MSUtils.RoundMoney(Config.DefaultCharacter.gold),
        math.max(0, math.floor(tonumber(Config.DefaultCharacter.xp) or 0)),
        math.max(0, math.floor(tonumber(Config.DefaultCharacter.health) or 500)),
        math.max(0, math.floor(tonumber(Config.DefaultCharacter.stamina) or 100)),
        MSUtils.SafeEncode({ x = spawn.x, y = spawn.y, z = spawn.z, w = spawn.w }),
        encodedMetadata
    })
    if not characterId then return nil, 'Charakter konnte nicht gespeichert werden.' end

    local row = MySQL.single.await('SELECT * FROM `mscore_characters` WHERE `id` = ? AND `account_id` = ?', {
        characterId,
        self.accountId
    })
    if not row then return nil, 'Charakter konnte nicht erneut geladen werden.' end
    local character = MSCharacter.new(row, self)
    self.characters[character.id] = character
    TriggerEvent('mscore:server:characterCreated', self.source, character)
    return character
end

function MSPlayer:SelectCharacter(characterId)
    characterId = tonumber(characterId)
    local character = characterId and self.characters[characterId] or nil
    if not character then return false, 'Charakter nicht gefunden.' end
    if self.activeCharacterId == characterId then return true, character end

    local previous = self:GetActiveCharacter()
    if previous then
        previous:Save(true)
        TriggerEvent('mscore:server:characterUnloaded', self.source, previous, 'switch')
    end

    self.activeCharacterId = characterId
    MySQL.update.await(
        'UPDATE `mscore_characters` SET `last_played_at` = CURRENT_TIMESTAMP WHERE `id` = ? AND `account_id` = ?',
        { characterId, self.accountId }
    )
    if type(SetPlayerRoutingBucket) == 'function' then SetPlayerRoutingBucket(self.source, 0) end
    character:Sync()
    TriggerClientEvent('mscore:client:spawn', self.source, character.coords, character:ToClientData())
    TriggerEvent('mscore:server:characterSelected', self.source, character)
    return true, character
end

function MSPlayer:UnloadCharacter(reason)
    local character = self:GetActiveCharacter()
    if not character then return false, 'Kein aktiver Charakter.' end
    character:Save(true)
    TriggerEvent('mscore:server:characterUnloaded', self.source, character, reason or 'logout')
    self.activeCharacterId = nil
    self:SyncState(nil)
    self:SetSelectionBucket()
    TriggerClientEvent('mscore:client:clearPlayerData', self.source)
    return true
end

function MSPlayer:DeleteCharacter(characterId)
    characterId = tonumber(characterId)
    if not characterId or not self.characters[characterId] then return false, 'Charakter nicht gefunden.' end
    if self.activeCharacterId == characterId then return false, 'Der aktive Charakter kann nicht gelöscht werden.' end
    local affected = MySQL.update.await([[
        UPDATE `mscore_characters` SET `is_deleted` = 1
        WHERE `id` = ? AND `account_id` = ? AND `is_deleted` = 0
    ]], { characterId, self.accountId })
    if affected ~= 1 then return false, 'Charakter konnte nicht gelöscht werden.' end
    self.characters[characterId] = nil
    TriggerEvent('mscore:server:characterDeleted', self.source, characterId)
    return true
end

function MSPlayer:SetGroup(groupName)
    groupName = MSUtils.Trim(tostring(groupName or '')):lower()
    if groupName == '' or #groupName > 40 or groupName:find('[^%w_%-]') then
        return false, 'Ungültige Gruppe.'
    end
    self.group = groupName
    MySQL.update.await('UPDATE `mscore_accounts` SET `group_name` = ? WHERE `id` = ?', {
        groupName,
        self.accountId
    })
    MySQL.update.await([[
        UPDATE `mscore_characters` SET `group_name` = ?
        WHERE `account_id` = ? AND `is_deleted` = 0
    ]], { groupName, self.accountId })

    for _, character in pairs(self.characters) do
        character.group = groupName
        character:MarkDirty()
    end
    local activeCharacter = self:GetActiveCharacter()
    if activeCharacter then activeCharacter:Sync() else self:SyncState(nil) end
    return true
end

function MSPlayer:Save(reason)
    local character = self:GetActiveCharacter()
    if character then character:Save(true) end
    MySQL.update.await('UPDATE `mscore_accounts` SET `last_seen_at` = CURRENT_TIMESTAMP WHERE `id` = ?', {
        self.accountId
    })
    if Config.Debug then
        print(('[MSCore] Spieler %d gespeichert (%s).'):format(self.source, tostring(reason or 'manual')))
    end
    return true
end
