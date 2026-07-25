local Config = MSMeChatConfig
local LastMessages = {}
local MessageSequence = 0

local function notify(playerSource, message)
    if playerSource == 0 then
        print(('[MS_mechat] %s'):format(message))
        return
    end

    TriggerClientEvent('mscore:client:notify', playerSource, message)
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function characterLength(value)
    return utf8.len(value)
end

local function sanitizeText(value)
    local text = tostring(value or '')
        :gsub('%c', ' ')
        :gsub('%s+', ' ')

    if Config.AllowTextFormatting ~= true then
        text = text:gsub('[~^]', '')
    end

    text = trim(text)
    if text == '' then
        return nil, ('Verwendung: /%s <Aktion>'):format(tostring(Config.Command or 'me'))
    end

    local length = characterLength(text)
    if not length then
        return nil, 'Die Aktion enthält ungültige Zeichen.'
    end

    local maximum = math.max(1, math.floor(tonumber(Config.MaxLength) or 160))
    if length > maximum then
        return nil, ('Die Aktion darf höchstens %d Zeichen enthalten.'):format(maximum)
    end

    return text
end

local function playerPosition(playerSource)
    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return nil end

    local coords = GetEntityCoords(ped)
    if not coords then return nil end

    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not x or not y or not z then return nil end

    return { x = x, y = y, z = z }
end

local function distanceSquared(left, right)
    local x = left.x - right.x
    local y = left.y - right.y
    local z = left.z - right.z
    return x * x + y * y + z * z
end

local function nextMessageId()
    MessageSequence = MessageSequence + 1
    if MessageSequence > 2147483647 then MessageSequence = 1 end
    return MessageSequence
end

function SendAction(playerSource, rawText)
    playerSource = tonumber(playerSource)
    if not playerSource or playerSource <= 0 then
        return false, 'Dieser Befehl ist nur ingame verfügbar.'
    end

    local player = exports.MSCore:GetPlayer(playerSource)
    if not player then
        return false, 'Wähle zuerst einen Charakter.'
    end

    local text, textError = sanitizeText(rawText)
    if not text then return false, textError end

    local now = GetGameTimer()
    local cooldown = math.max(0, math.floor(tonumber(Config.CooldownMs) or 1500))
    local lastMessage = LastMessages[playerSource]
    if lastMessage and now - lastMessage < cooldown then
        local remaining = math.max(0, cooldown - (now - lastMessage))
        return false, ('Bitte warte noch %.1f Sekunden.'):format(remaining / 1000)
    end

    local origin = playerPosition(playerSource)
    if not origin then
        return false, 'Deine Position konnte nicht ermittelt werden.'
    end

    local displayDistance = math.max(1.0, tonumber(Config.DisplayDistance) or 18.0)
    local padding = math.max(0.0, tonumber(Config.ServerDistancePadding) or 2.0)
    local maximumDistanceSquared = (displayDistance + padding) ^ 2
    local routingBucket = GetPlayerRoutingBucket(playerSource)
    local authorName = trim(player:getName())
    if authorName == '' then
        authorName = tostring(GetPlayerName(playerSource) or ('Spieler %d'):format(playerSource))
    end

    local payload = {
        id = nextMessageId(),
        authorSource = playerSource,
        authorName = authorName,
        text = text,
        duration = math.max(500, math.floor(tonumber(Config.DisplayDurationMs) or 7000))
    }
    local recipientCount = 0

    for targetSource in pairs(exports.MSCore:GetPlayers()) do
        targetSource = tonumber(targetSource)
        if targetSource and GetPlayerRoutingBucket(targetSource) == routingBucket then
            local targetPosition = targetSource == playerSource and origin or playerPosition(targetSource)
            if targetPosition and distanceSquared(origin, targetPosition) <= maximumDistanceSquared then
                TriggerClientEvent('MS_mechat:client:displayAction', targetSource, payload)
                recipientCount = recipientCount + 1
            end
        end
    end

    LastMessages[playerSource] = now

    if Config.LogToConsole == true then
        print(('[MS_mechat] %s (%d): %s'):format(authorName, playerSource, text))
    end

    TriggerEvent('MS_mechat:server:message', {
        id = payload.id,
        authorSource = playerSource,
        characterId = player.characterId,
        authorName = authorName,
        text = text,
        recipientCount = recipientCount,
        routingBucket = routingBucket
    })

    return true, payload.id
end

RegisterCommand(Config.Command or 'me', function(playerSource, args)
    if playerSource == 0 then
        notify(playerSource, 'Dieser Befehl ist nur ingame verfügbar.')
        return
    end

    local success, result = SendAction(playerSource, table.concat(args or {}, ' '))
    if not success then notify(playerSource, result) end
end, false)

AddEventHandler('playerDropped', function()
    LastMessages[source] = nil
end)

AddEventHandler('mscore:server:playerUnloaded', function(playerSource)
    LastMessages[tonumber(playerSource)] = nil
end)

exports('SendAction', SendAction)
