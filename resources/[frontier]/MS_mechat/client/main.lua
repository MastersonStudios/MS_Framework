local Config = MSMeChatConfig
local ActiveMessages = {}
local SeenMessages = {}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function characterLength(value)
    local length = utf8.len(value)
    return length or #value
end

local function sanitizePayloadText(value, maximum)
    local text = tostring(value or '')
        :gsub('%c', ' ')
        :gsub('%s+', ' ')
        :gsub('^%s+', '')
        :gsub('%s+$', '')

    if Config.AllowTextFormatting ~= true then
        text = text:gsub('[~^]', '')
    end

    local length = utf8.len(text)
    if not length then return '' end
    if length <= maximum then return text end

    local nextByte = utf8.offset(text, maximum + 1)
    return text:sub(1, nextByte and nextByte - 1 or -1)
end

local function characterSub(value, firstCharacter, lastCharacter)
    local firstByte = utf8.offset(value, firstCharacter)
    if not firstByte then return '' end

    local nextByte = utf8.offset(value, lastCharacter + 1)
    return value:sub(firstByte, nextByte and nextByte - 1 or -1)
end

local function splitLongWord(word, maximum)
    local chunks = {}
    local length = characterLength(word)
    local start = 1

    while start <= length do
        chunks[#chunks + 1] = characterSub(word, start, math.min(start + maximum - 1, length))
        start = start + maximum
    end

    return chunks
end

local function wrapText(value)
    local maximum = math.max(10, math.floor(tonumber(Config.CharactersPerLine) or 42))
    local lines = {}
    local current = ''

    local function appendWord(word)
        if current == '' then
            current = word
        elseif characterLength(current) + characterLength(word) + 1 <= maximum then
            current = current .. ' ' .. word
        else
            lines[#lines + 1] = current
            current = word
        end
    end

    for word in tostring(value or ''):gmatch('%S+') do
        if characterLength(word) <= maximum then
            appendWord(word)
        else
            if current ~= '' then
                lines[#lines + 1] = current
                current = ''
            end

            local chunks = splitLongWord(word, maximum)
            for index, chunk in ipairs(chunks) do
                if index < #chunks then
                    lines[#lines + 1] = chunk
                else
                    current = chunk
                end
            end
        end
    end

    if current ~= '' then lines[#lines + 1] = current end
    if #lines == 0 then lines[1] = tostring(value or '') end
    return lines
end

local function colorComponent(color, index, fallback)
    return clamp(math.floor(tonumber(type(color) == 'table' and color[index]) or fallback), 0, 255)
end

local function drawWorldText(x, y, z, text, alpha, distance)
    local visible, screenX, screenY = GetScreenCoordFromWorldCoord(x, y, z)
    if not visible then return end

    local configuredScale = tonumber(Config.TextScale) or 0.30
    local minimumScale = tonumber(Config.MinimumTextScale) or 0.22
    local scale = math.max(minimumScale, configuredScale - math.max(0.0, distance - 2.0) * 0.003)
    local color = Config.TextColor

    SetTextScale(scale, scale)
    SetTextColor(
        colorComponent(color, 1, 255),
        colorComponent(color, 2, 226),
        colorComponent(color, 3, 166),
        math.floor(colorComponent(color, 4, 255) * alpha)
    )
    SetTextCentre(true)
    SetTextFontForCurrentCommand(math.max(0, math.floor(tonumber(Config.TextFont) or 1)))
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), screenX, screenY)
end

local function removeExpired(messages, now)
    for index = #messages, 1, -1 do
        if messages[index].expiresAt <= now then table.remove(messages, index) end
    end
end

local function addChatMessage(authorName, text)
    if Config.ShowInChat ~= true then return end

    local color = Config.ChatColor
    local prefix = tostring(Config.ChatPrefix or 'ME')
    TriggerEvent('chat:addMessage', {
        color = {
            colorComponent(color, 1, 219),
            colorComponent(color, 2, 176),
            colorComponent(color, 3, 93)
        },
        multiline = true,
        args = { ('%s · %s'):format(prefix, authorName), text }
    })
end

RegisterNetEvent('MS_mechat:client:displayAction', function(payload)
    if type(payload) ~= 'table' then return end

    local messageId = tonumber(payload.id)
    local authorSource = tonumber(payload.authorSource)
    local authorName = sanitizePayloadText(payload.authorName, 64)
    local maximumLength = clamp(
        math.floor(tonumber(Config.MaxLength) or 160),
        1,
        300
    )
    local text = sanitizePayloadText(payload.text, maximumLength)
    if not messageId or not authorSource or authorSource <= 0 or authorName == '' or text == '' then return end

    local now = GetGameTimer()
    if SeenMessages[messageId] and SeenMessages[messageId] > now then return end

    local duration = clamp(
        math.floor(tonumber(payload.duration) or tonumber(Config.DisplayDurationMs) or 7000),
        500,
        30000
    )
    SeenMessages[messageId] = now + duration

    addChatMessage(authorName, text)
    if Config.Show3DText ~= true then return end

    local displayText = Config.ShowAuthorName3D == true
        and ('* %s %s'):format(authorName, text)
        or ('* %s'):format(text)
    local messages = ActiveMessages[authorSource] or {}
    removeExpired(messages, now)

    messages[#messages + 1] = {
        id = messageId,
        lines = wrapText(displayText),
        expiresAt = now + duration
    }

    local maximum = math.max(1, math.floor(tonumber(Config.MaxVisibleMessages) or 3))
    while #messages > maximum do table.remove(messages, 1) end
    ActiveMessages[authorSource] = messages
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()
        local hasMessages = false
        local localPed = PlayerPedId()
        local localCoords = GetEntityCoords(localPed)
        local maximumDistance = math.max(1.0, tonumber(Config.DisplayDistance) or 18.0)

        for authorSource, messages in pairs(ActiveMessages) do
            removeExpired(messages, now)
            if #messages == 0 then
                ActiveMessages[authorSource] = nil
            else
                hasMessages = true
                local playerId = GetPlayerFromServerId(authorSource)
                local authorPed = playerId ~= -1 and GetPlayerPed(playerId) or 0

                if authorPed ~= 0 and DoesEntityExist(authorPed) then
                    local authorCoords = GetEntityCoords(authorPed)
                    local x = authorCoords.x - localCoords.x
                    local y = authorCoords.y - localCoords.y
                    local z = authorCoords.z - localCoords.z
                    local distance = math.sqrt(x * x + y * y + z * z)
                    local hasLineOfSight = Config.RequireLineOfSight ~= true
                        or authorPed == localPed
                        or HasEntityClearLosToEntity(localPed, authorPed, 17)

                    if distance <= maximumDistance and hasLineOfSight then
                        local head = GetPedBoneCoords(
                            authorPed,
                            tonumber(Config.HeadBone) or 0x796E,
                            0.0,
                            0.0,
                            0.0
                        )
                        local baseX = tonumber(head and head.x) or authorCoords.x
                        local baseY = tonumber(head and head.y) or authorCoords.y
                        local baseZ = tonumber(head and head.z) or (authorCoords.z + 1.0)
                        local lineHeight = math.max(0.01, tonumber(Config.LineHeight) or 0.055)
                        local messageSpacing = math.max(0.0, tonumber(Config.MessageSpacing) or 0.035)
                        local currentOffset = math.max(0.0, tonumber(Config.HeightOffset) or 0.38)

                        for messageIndex = #messages, 1, -1 do
                            local message = messages[messageIndex]
                            local remaining = message.expiresAt - now
                            local fadeDuration = math.max(1, tonumber(Config.FadeDurationMs) or 1000)
                            local alpha = clamp(remaining / fadeDuration, 0.0, 1.0)

                            for lineIndex = #message.lines, 1, -1 do
                                drawWorldText(
                                    baseX,
                                    baseY,
                                    baseZ + currentOffset,
                                    message.lines[lineIndex],
                                    alpha,
                                    distance
                                )
                                currentOffset = currentOffset + lineHeight
                            end

                            currentOffset = currentOffset + messageSpacing
                        end
                    end
                end
            end
        end

        for messageId, expiresAt in pairs(SeenMessages) do
            if expiresAt <= now then SeenMessages[messageId] = nil end
        end

        Wait(hasMessages and 0 or 250)
    end
end)

CreateThread(function()
    if Config.RegisterChatSuggestion ~= true then return end

    TriggerEvent('chat:addSuggestion', '/' .. tostring(Config.Command or 'me'),
        'Beschreibt eine Aktion für Spieler in deiner Nähe.', {
            { name = 'Aktion', help = 'Zum Beispiel: zieht langsam seinen Hut.' }
        })
end)

AddEventHandler('frontier:client:prepareLogout', function()
    ActiveMessages = {}
    SeenMessages = {}
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    TriggerEvent('chat:removeSuggestion', '/' .. tostring(Config.Command or 'me'))
end)

function IsDisplayingActions()
    return next(ActiveMessages) ~= nil
end

exports('IsDisplayingActions', IsDisplayingActions)
