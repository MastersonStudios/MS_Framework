local Players = {}
local Callbacks = {}
local CharacterCreateLocks = {}
local CharacterCreateCooldowns = {}
local APPEARANCE_KEYS = { 'head', 'body', 'hair', 'beard', 'eyes', 'height' }
local normalizeCharacterAppearance
local normalizeCharacterProfile

local function identifier(source)
    local prefix = Config.IdentifierType .. ':'
    for _, value in ipairs(GetPlayerIdentifiers(source)) do
        if value:sub(1, #prefix) == prefix then return value end
    end
end

local function getOrCreateUser(source)
    local license = identifier(source)
    if not license then return nil, 'Keine Rockstar-Lizenz gefunden.' end

    local userId = MySQL.scalar.await('SELECT id FROM mscore_users WHERE license = ?', { license })
    if not userId then
        userId = MySQL.insert.await('INSERT INTO mscore_users (license) VALUES (?)', { license })
    else
        MySQL.update.await('UPDATE mscore_users SET last_seen = CURRENT_TIMESTAMP WHERE id = ?', { userId })
    end
    return userId
end

local function decodeMetadata(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end

    local success, decoded = pcall(json.decode, value)
    return success and type(decoded) == 'table' and decoded or {}
end

local function characterRows(userId)
    local rows = MySQL.query.await([[
        SELECT id, firstname, lastname, date_of_birth, sex, job, job_grade, cash, bank, metadata, created_at
        FROM mscore_characters
        WHERE user_id = ? AND is_deleted = 0
        ORDER BY id ASC
    ]], { userId })

    for _, row in ipairs(rows) do
        local metadata = decodeMetadata(row.metadata)
        row.appearance = normalizeCharacterAppearance(row.sex, metadata.appearance)
        row.profile = normalizeCharacterProfile(metadata.profile)
        row.nickname = row.profile.nickname
        row.description = row.profile.description
        row.metadata = nil
    end

    return rows
end

local function validBirthDate(value)
    if value == nil or value == '' then return nil end
    if type(value) ~= 'string' or not value:match('^%d%d%d%d%-%d%d%-%d%d$') then return false end
    if value < Config.CharacterBirthDateMin or value > Config.CharacterBirthDateMax then return false end

    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or not month or not day or month < 1 or month > 12 or day < 1 then return false end
    local daysInMonth = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0) then daysInMonth[2] = 29 end
    if day > daysInMonth[month] then return false end
    return value
end

local function cleanProfileText(value)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('\r\n', '\n'):gsub('\r', '\n')
    value = value:gsub('[%z\1-\8\11\12\14-\31]', '')
    return MSCore.Trim(value)
end

local function textLength(value)
    local success, length = pcall(utf8.len, value)
    return success and length or #value
end

local function truncateText(value, maximum)
    if textLength(value) <= maximum then return value end
    local success, offset = pcall(utf8.offset, value, maximum + 1)
    if success and offset then return value:sub(1, offset - 1) end
    return value:sub(1, maximum)
end

normalizeCharacterProfile = function(raw, strict)
    local creator = type(Config.CharacterCreator) == 'table' and Config.CharacterCreator or {}
    local profileConfig = type(creator.Profile) == 'table' and creator.Profile or {}
    raw = type(raw) == 'table' and raw or {}
    local nickname = cleanProfileText(raw.nickname)
    local description = cleanProfileText(raw.description)
    local nicknameMax = math.max(1, math.floor(tonumber(profileConfig.NicknameMaxLength) or 32))
    local descriptionMax = math.max(1, math.floor(tonumber(profileConfig.DescriptionMaxLength) or 280))

    if strict and textLength(nickname) > nicknameMax then
        return nil, ('Der Spitzname darf höchstens %d Zeichen enthalten.'):format(nicknameMax)
    end
    if strict and textLength(description) > descriptionMax then
        return nil, ('Die Beschreibung darf höchstens %d Zeichen enthalten.'):format(descriptionMax)
    end

    return {
        nickname = truncateText(nickname, nicknameMax),
        description = truncateText(description, descriptionMax)
    }
end

local function appearanceOptions(creator, key, sex)
    local options = type(creator.AppearanceOptions) == 'table' and creator.AppearanceOptions[key] or nil
    options = type(options) == 'table' and options[sex] or nil
    return type(options) == 'table' and options or {}
end

normalizeCharacterAppearance = function(sex, raw)
    local creator = type(Config.CharacterCreator) == 'table' and Config.CharacterCreator or {}
    local defaults = type(creator.Defaults) == 'table' and creator.Defaults or {}
    local outfits = type(creator.Outfits) == 'table' and creator.Outfits or {}
    raw = type(raw) == 'table' and raw or {}
    sex = sex == 'female' and 'female' or 'male'

    local appearance = { version = 2 }
    for _, key in ipairs(APPEARANCE_KEYS) do
        local options = appearanceOptions(creator, key, sex)
        local legacyValue = key == 'head' and raw.face or nil
        local value = math.floor(tonumber(raw[key]) or tonumber(legacyValue) or tonumber(defaults[key]) or 1)
        appearance[key] = math.max(1, math.min(math.max(1, #options), value))
    end

    local outfit = type(raw.outfit) == 'string' and raw.outfit or defaults.outfit
    if type(outfit) ~= 'string' or type(outfits[outfit]) ~= 'table' then
        outfit = type(defaults.outfit) == 'string' and defaults.outfit or next(outfits)
    end
    appearance.outfit = outfit
    return appearance
end

local function initialOutfit(sex, appearance)
    local creator = type(Config.CharacterCreator) == 'table' and Config.CharacterCreator or {}
    local outfits = type(creator.Outfits) == 'table' and creator.Outfits or {}
    local outfit = outfits[appearance.outfit]
    local itemNames = type(outfit) == 'table' and type(outfit.items) == 'table' and outfit.items[sex] or {}
    local equipped = {}

    for _, itemName in ipairs(type(itemNames) == 'table' and itemNames or {}) do
        local item = type(Config.Items) == 'table' and Config.Items[itemName]
        local itemMetadata = type(item) == 'table' and item.metadata or nil
        local slot = type(itemMetadata) == 'table' and itemMetadata.clothingSlot or nil
        local itemSex = type(itemMetadata) == 'table' and itemMetadata.sex or nil
        if type(slot) == 'string' and (not itemSex or itemSex == 'unisex' or itemSex == sex) then
            equipped[slot] = itemName
        end
    end

    return equipped
end

local function containsBannedName(...)
    local creator = type(Config.CharacterCreator) == 'table' and Config.CharacterCreator or {}
    local profileConfig = type(creator.Profile) == 'table' and creator.Profile or {}
    local combined = table.concat({ ... }, ' '):lower()
    for _, banned in ipairs(type(profileConfig.BannedNames) == 'table' and profileConfig.BannedNames or {}) do
        banned = cleanProfileText(tostring(banned)):lower()
        if banned ~= '' and combined:find(banned, 1, true) then return true end
    end
    return false
end

local function createCharacter(userId, data)
    data = type(data) == 'table' and data or {}
    local firstname = cleanProfileText(data.firstname)
    local lastname = cleanProfileText(data.lastname)
    if not MSCore.ValidName(firstname) or not MSCore.ValidName(lastname) then
        return nil, 'Ungültiger Name.'
    end
    if data.sex ~= 'male' and data.sex ~= 'female' then return nil, 'Ungültiges Geschlecht.' end
    local birthDate = validBirthDate(data.dateOfBirth)
    if birthDate == false then return nil, 'Ungültiges Geburtsdatum.' end

    local profile, profileError = normalizeCharacterProfile({
        nickname = data.nickname,
        description = data.description
    }, true)
    if not profile then return nil, profileError end
    if containsBannedName(firstname, lastname, profile.nickname) then
        return nil, 'Dieser Name oder Spitzname ist nicht erlaubt.'
    end

    local defaults = Config.DefaultCharacter
    local appearance = normalizeCharacterAppearance(data.sex, data.appearance)
    local metadata = {
        appearance = appearance,
        profile = profile,
        outfit = initialOutfit(data.sex, appearance)
    }
    return MySQL.insert.await([[
        INSERT INTO mscore_characters
            (user_id, firstname, lastname, date_of_birth, sex, job, job_grade, group_name, cash, bank, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        userId, firstname, lastname, birthDate, data.sex,
        defaults.job, defaults.jobGrade, defaults.group, defaults.cash, defaults.bank, json.encode(metadata)
    })
end

local function resolveCharacterSpawn(player)
    local coords = type(player.coords) == 'table' and player.coords or nil
    if not coords then return Config.Spawn, false end

    local migration = type(Config.LegacySpawnMigration) == 'table'
        and Config.LegacySpawnMigration
        or {}
    local bounds = type(migration.GuarmaBounds) == 'table'
        and migration.GuarmaBounds
        or {}
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return Config.Spawn, false end
    local onLegacyGuarmaSpawn = migration.Enabled == true
        and x >= (tonumber(bounds.minX) or 0.0)
        and x <= (tonumber(bounds.maxX) or 2500.0)
        and y >= (tonumber(bounds.minY) or -8000.0)
        and y <= (tonumber(bounds.maxY) or -5000.0)

    if not onLegacyGuarmaSpawn then return coords, false end

    player.coords = {
        x = Config.Spawn.x,
        y = Config.Spawn.y,
        z = Config.Spawn.z,
        w = Config.Spawn.w
    }
    player.metadata.guarmaOnboardingComplete = nil
    player.metadata.guarmaOnboardingStage = nil
    player.dirty = true
    return player.coords, true
end

local function loadCharacter(source, characterId)
    local userId, err = getOrCreateUser(source)
    if not userId then return false, err end
    local row = MySQL.single.await([[
        SELECT * FROM mscore_characters
        WHERE id = ? AND user_id = ? AND is_deleted = 0
    ]], { characterId, userId })
    if not row then return false, 'Charakter nicht gefunden.' end

    if Players[source] then
        Players[source]:save()
        TriggerEvent('mscore:server:playerUnloaded', source, Players[source])
    end
    Players[source] = MSCore.Player:new(source, row)
    local player = Players[source]
    local spawnCoords, spawnMigrated = resolveCharacterSpawn(player)
    local currentAppearance = player.metadata.appearance
    local appearance = normalizeCharacterAppearance(player.sex, currentAppearance)
    local appearanceChanged = type(currentAppearance) ~= 'table'
        or tonumber(currentAppearance.version) ~= appearance.version
        or currentAppearance.outfit ~= appearance.outfit
    for _, key in ipairs(APPEARANCE_KEYS) do
        if type(currentAppearance) ~= 'table' or tonumber(currentAppearance[key]) ~= appearance[key] then
            appearanceChanged = true
            break
        end
    end
    if appearanceChanged then
        player.metadata.appearance = appearance
        player.dirty = true
    end

    local currentProfile = player.metadata.profile
    local profile = normalizeCharacterProfile(currentProfile)
    if type(currentProfile) ~= 'table'
        or currentProfile.nickname ~= profile.nickname
        or currentProfile.description ~= profile.description
    then
        player.metadata.profile = profile
        player.dirty = true
    end

    if type(player.metadata.outfit) ~= 'table' then
        player.metadata.outfit = initialOutfit(player.sex, appearance)
        player.dirty = true
    end
    if spawnMigrated then player:save() end
    player:sync()
    TriggerClientEvent('mscore:client:spawn', source, spawnCoords)
    TriggerEvent('mscore:server:playerLoaded', source, player)
    return true
end

function GetPlayer(source) return Players[tonumber(source)] end
function GetPlayerFromCharacterId(characterId)
    for _, player in pairs(Players) do
        if player.characterId == tonumber(characterId) then return player end
    end
end
function GetPlayers() return Players end
MSCore.GetPlayers = GetPlayers
function LogoutPlayer(source)
    source = tonumber(source)
    local player = source and Players[source]
    if not player then return false, 'Kein aktiver Charakter.' end

    local characterId = player.characterId
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 then
        local coords = GetEntityCoords(ped)
        player.coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            w = GetEntityHeading(ped)
        }
        player.metadata.health = GetEntityHealth(ped)
    end
    player:save()
    TriggerEvent('mscore:server:playerUnloaded', source, player)
    Players[source] = nil

    TriggerClientEvent('mscore:client:prepareLogout', source)
    TriggerClientEvent('mscore:client:clearPlayerData', source)
    TriggerClientEvent('mscore:client:showCharacters', source)
    return true, characterId
end

exports('GetPlayer', GetPlayer)
exports('GetPlayerFromCharacterId', GetPlayerFromCharacterId)
exports('GetPlayers', GetPlayers)
exports('LogoutPlayer', LogoutPlayer)

function MSCore.RegisterCallback(name, callback)
    Callbacks[name] = callback
end
exports('RegisterCallback', MSCore.RegisterCallback)

RegisterNetEvent('mscore:server:callback', function(requestId, name, ...)
    local source = source
    if type(requestId) ~= 'number' or type(name) ~= 'string' or not Callbacks[name] then return end
    local replied = false
    local function reply(...)
        if replied then return end
        replied = true
        TriggerClientEvent('mscore:client:callback', source, requestId, ...)
    end
    Callbacks[name](source, reply, ...)
end)

MSCore.RegisterCallback('mscore:getCharacters', function(source, reply)
    local userId, err = getOrCreateUser(source)
    if not userId then return reply(nil, err) end
    local rows = characterRows(userId)
    if #rows == 0 and Config.AutoCreateCharacter then
        createCharacter(userId, Config.DefaultCharacter)
        rows = characterRows(userId)
    end
    reply(rows)
end)

MSCore.RegisterCallback('mscore:createCharacter', function(source, reply, data)
    local userId, err = getOrCreateUser(source)
    if not userId then return reply(false, err) end

    local now = GetGameTimer()
    if CharacterCreateLocks[userId] then
        return reply(false, 'Eine Charaktererstellung wird bereits verarbeitet.')
    end
    if now < (CharacterCreateCooldowns[source] or 0) then
        return reply(false, 'Bitte warte einen Moment.')
    end

    CharacterCreateLocks[userId] = true
    local success, id, createError = xpcall(function()
        if #characterRows(userId) >= Config.MaxCharacters then
            return nil, 'Maximale Charakteranzahl erreicht.'
        end
        return createCharacter(userId, data or {})
    end, debug.traceback)
    CharacterCreateLocks[userId] = nil
    local creator = type(Config.CharacterCreator) == 'table' and Config.CharacterCreator or {}
    CharacterCreateCooldowns[source] = now
        + math.max(0, math.floor(tonumber(creator.CreateCooldownMs) or 3000))

    if not success then
        print(('[MSCore] Charaktererstellung für Spieler %d fehlgeschlagen: %s'):format(source, tostring(id)))
        return reply(false, 'Der Charakter konnte nicht erstellt werden.')
    end
    if not id then return reply(false, createError) end
    reply(loadCharacter(source, id))
end)

MSCore.RegisterCallback('mscore:selectCharacter', function(source, reply, characterId)
    reply(loadCharacter(source, tonumber(characterId)))
end)

MSCore.RegisterCallback('mscore:deleteCharacter', function(source, reply, characterId)
    characterId = tonumber(characterId)
    local userId, err = getOrCreateUser(source)
    if not userId then return reply(false, err) end
    if not characterId then return reply(false, 'Ungültiger Charakter.') end
    if Players[source] and Players[source].characterId == characterId then
        return reply(false, 'Der aktive Charakter kann nicht gelöscht werden.')
    end

    local affected = MySQL.update.await([[
        UPDATE mscore_characters
        SET is_deleted = 1
        WHERE id = ? AND user_id = ? AND is_deleted = 0
    ]], { characterId, userId })
    if affected ~= 1 then return reply(false, 'Charakter nicht gefunden.') end
    reply(true, characterRows(userId))
end)

RegisterNetEvent('mscore:server:updatePosition', function(coords, health)
    local player = Players[source]
    if not player or type(coords) ~= 'table' then return end
    local x, y, z, heading = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z), tonumber(coords.w)
    if not x or not y or not z or math.abs(x) > 10000 or math.abs(y) > 10000 then return end
    player.coords = { x = x, y = y, z = z, w = heading or 0.0 }
    player.metadata.health = math.max(0, math.min(tonumber(health) or 200, 200))
    player.dirty = true
end)

local function savePlayer(source)
    local player = Players[source]
    if player then player:save() end
end

local function saveAllPlayers()
    for source in pairs(Players) do savePlayer(source) end
end

AddEventHandler('playerDropped', function()
    -- Das globale Cfx-`source` darf nicht über ein DB-await hinweg verwendet
    -- werden. Nach player:save() kann es bereits nil oder neu belegt sein.
    local playerSource = tonumber(source)
    local player = playerSource and Players[playerSource]
    if playerSource then CharacterCreateCooldowns[playerSource] = nil end
    if not playerSource or not player then return end

    player:save()
    if Players[playerSource] ~= player then return end
    TriggerEvent('mscore:server:playerUnloaded', playerSource, player)
    Players[playerSource] = nil
end)

CreateThread(function()
    while true do
        Wait(Config.SaveInterval)
        for _, player in pairs(Players) do
            if player.dirty then player:save() end
        end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    saveAllPlayers()
    print('[MSCore] Aktive Charaktere vor dem txAdmin-Shutdown gespeichert.')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    saveAllPlayers()
end)
