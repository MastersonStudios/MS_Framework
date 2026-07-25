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

    local userId = MySQL.scalar.await('SELECT id FROM frontier_users WHERE license = ?', { license })
    if not userId then
        userId = MySQL.insert.await('INSERT INTO frontier_users (license) VALUES (?)', { license })
    else
        MySQL.update.await('UPDATE frontier_users SET last_seen = CURRENT_TIMESTAMP WHERE id = ?', { userId })
    end
    return userId
end

local function characterRows(userId)
    return MySQL.query.await([[
        SELECT id, firstname, lastname, sex, job, job_grade, cash, bank
        FROM frontier_characters
        WHERE user_id = ? AND is_deleted = 0
        ORDER BY id ASC
    ]], { userId })
end

local function createCharacter(userId, data)
    if not Frontier.ValidName(data.firstname) or not Frontier.ValidName(data.lastname) then
        return nil, 'Ungültiger Name.'
    end
    if data.sex ~= 'male' and data.sex ~= 'female' then return nil, 'Ungültiges Geschlecht.' end

    local defaults = Config.DefaultCharacter
    return MySQL.insert.await([[
        INSERT INTO frontier_characters
            (user_id, firstname, lastname, sex, job, job_grade, group_name, cash, bank, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        userId, Frontier.Trim(data.firstname), Frontier.Trim(data.lastname), data.sex,
        defaults.job, defaults.jobGrade, defaults.group, defaults.cash, defaults.bank, '{}'
    })
end

local function loadCharacter(source, characterId)
    local userId, err = getOrCreateUser(source)
    if not userId then return false, err end
    local row = MySQL.single.await([[
        SELECT * FROM frontier_characters
        WHERE id = ? AND user_id = ? AND is_deleted = 0
    ]], { characterId, userId })
    if not row then return false, 'Charakter nicht gefunden.' end

    Players[source] = Frontier.Player:new(source, row)
    Players[source]:sync()
    TriggerClientEvent('frontier:client:spawn', source, Players[source].coords or Config.Spawn)
    TriggerEvent('frontier:server:playerLoaded', source, Players[source])
    return true
end

function GetPlayer(source) return Players[tonumber(source)] end
function GetPlayerFromCharacterId(characterId)
    for _, player in pairs(Players) do
        if player.characterId == tonumber(characterId) then return player end
    end
end
function GetPlayers() return Players end

exports('GetPlayer', GetPlayer)
exports('GetPlayerFromCharacterId', GetPlayerFromCharacterId)
exports('GetPlayers', GetPlayers)

function Frontier.RegisterCallback(name, callback)
    Callbacks[name] = callback
end
exports('RegisterCallback', Frontier.RegisterCallback)

RegisterNetEvent('frontier:server:callback', function(requestId, name, ...)
    local source = source
    if type(requestId) ~= 'number' or type(name) ~= 'string' or not Callbacks[name] then return end
    local replied = false
    local function reply(...)
        if replied then return end
        replied = true
        TriggerClientEvent('frontier:client:callback', source, requestId, ...)
    end
    Callbacks[name](source, reply, ...)
end)

Frontier.RegisterCallback('frontier:getCharacters', function(source, reply)
    local userId, err = getOrCreateUser(source)
    if not userId then return reply(nil, err) end
    local rows = characterRows(userId)
    if #rows == 0 and Config.AutoCreateCharacter then
        local id = createCharacter(userId, Config.DefaultCharacter)
        rows = characterRows(userId)
        if id then loadCharacter(source, id) end
    end
    reply(rows)
end)

Frontier.RegisterCallback('frontier:createCharacter', function(source, reply, data)
    local userId, err = getOrCreateUser(source)
    if not userId then return reply(false, err) end
    if #characterRows(userId) >= Config.MaxCharacters then
        return reply(false, 'Maximale Charakteranzahl erreicht.')
    end
    local id, createError = createCharacter(userId, data or {})
    if not id then return reply(false, createError) end
    reply(loadCharacter(source, id))
end)

Frontier.RegisterCallback('frontier:selectCharacter', function(source, reply, characterId)
    reply(loadCharacter(source, tonumber(characterId)))
end)

RegisterNetEvent('frontier:server:updatePosition', function(coords, health)
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
    TriggerEvent('frontier:server:playerUnloaded', source, Players[source])
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
