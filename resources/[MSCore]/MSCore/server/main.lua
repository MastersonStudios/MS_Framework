local Players = {}
local Callbacks = {}

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

local function characterRows(userId)
    return MySQL.query.await([[
        SELECT id, firstname, lastname, date_of_birth, sex, job, job_grade, cash, bank, created_at
        FROM mscore_characters
        WHERE user_id = ? AND is_deleted = 0
        ORDER BY id ASC
    ]], { userId })
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

local function createCharacter(userId, data)
    if not MSCore.ValidName(data.firstname) or not MSCore.ValidName(data.lastname) then
        return nil, 'Ungültiger Name.'
    end
    if data.sex ~= 'male' and data.sex ~= 'female' then return nil, 'Ungültiges Geschlecht.' end
    local birthDate = validBirthDate(data.dateOfBirth)
    if birthDate == false then return nil, 'Ungültiges Geburtsdatum.' end

    local defaults = Config.DefaultCharacter
    return MySQL.insert.await([[
        INSERT INTO mscore_characters
            (user_id, firstname, lastname, date_of_birth, sex, job, job_grade, group_name, cash, bank, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        userId, MSCore.Trim(data.firstname), MSCore.Trim(data.lastname), birthDate, data.sex,
        defaults.job, defaults.jobGrade, defaults.group, defaults.cash, defaults.bank, '{}'
    })
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
    Players[source]:sync()
    TriggerClientEvent('mscore:client:spawn', source, Players[source].coords or Config.Spawn)
    TriggerEvent('mscore:server:playerLoaded', source, Players[source])
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
    if #characterRows(userId) >= Config.MaxCharacters then
        return reply(false, 'Maximale Charakteranzahl erreicht.')
    end
    local id, createError = createCharacter(userId, data or {})
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

AddEventHandler('playerDropped', function()
    savePlayer(source)
    TriggerEvent('mscore:server:playerUnloaded', source, Players[source])
    Players[source] = nil
end)

CreateThread(function()
    while true do
        Wait(Config.SaveInterval)
        for _, player in pairs(Players) do
            if player.dirty then player:save() end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for source in pairs(Players) do savePlayer(source) end
end)
