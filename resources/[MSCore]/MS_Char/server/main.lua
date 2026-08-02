local Core = exports.MSCore:GetCore()
local lastActions = {}

local function trim(value)
    if type(value) ~= 'string' then return '' end
    return value:match('^%s*(.-)%s*$') or ''
end

local function validDate(value)
    if type(value) ~= 'string' then return nil end
    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or not month or not day or month < 1 or month > 12 or day < 1 then return nil end
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if year % 400 == 0 or (year % 4 == 0 and year % 100 ~= 0) then days[2] = 29 end
    if day > days[month] then return nil end
    return year, month, day
end

local function validateAge(dateOfBirth)
    local year, month, day = validDate(dateOfBirth)
    if not year then return false, 'Das Geburtsdatum ist ungültig.' end
    local roleplayDate = Config.RoleplayDate
    local age = roleplayDate.year - year
    if month > roleplayDate.month or (month == roleplayDate.month and day > roleplayDate.day) then age = age - 1 end
    if age < Config.MinimumAge or age > Config.MaximumAge then
        return false, ('Das Alter muss zwischen %d und %d Jahren liegen.'):format(Config.MinimumAge, Config.MaximumAge)
    end
    return true
end

local function containsBannedName(firstname, lastname)
    local fullName = (firstname .. ' ' .. lastname):lower()
    for _, blocked in ipairs(Config.BannedNames or {}) do
        if fullName:find(tostring(blocked):lower(), 1, true) then return true end
    end
    return false
end

local function validPreset(presetId)
    presetId = math.floor(tonumber(presetId) or -1)
    for _, preset in ipairs(Config.OutfitPresets or {}) do
        if presetId == tonumber(preset.id) then return presetId end
    end
    return nil
end

local function sanitizeAppearance(appearance, sex)
    appearance = type(appearance) == 'table' and appearance or {}
    sex = sex == 'female' and 'female' or sex == 'male' and 'male' or nil
    local preset = validPreset(appearance.outfitPreset)
    if not sex or not preset then return nil, 'Das gewählte Aussehen ist ungültig.' end
    return {
        model = Config.Models[sex],
        sex = sex,
        outfitPreset = preset
    }
end

local function actionAllowed(playerSource)
    local now = os.time()
    local lastAction = lastActions[playerSource] or 0
    if now - lastAction < math.max(0, tonumber(Config.ActionCooldownSeconds) or 1) then
        return false
    end
    lastActions[playerSource] = now
    return true
end

local function getPlayer(playerSource)
    local player = Core.GetPlayer(playerSource)
    if player then return player end
    return Core.EnsurePlayer(playerSource)
end

Core.RegisterCallback('mschar:list', function(playerSource, reply)
    local player, errorMessage = getPlayer(playerSource)
    if not player then return reply(false, errorMessage or 'Account konnte nicht geladen werden.') end
    reply(true, player:GetCharacters(), player.maxCharacters)
end)

Core.RegisterCallback('mschar:create', function(playerSource, reply, data)
    if not actionAllowed(playerSource) then return reply(false, 'Bitte warte einen Moment.') end
    data = type(data) == 'table' and data or {}

    local firstname = trim(data.firstname)
    local lastname = trim(data.lastname)
    local sex = data.sex == 'female' and 'female' or data.sex == 'male' and 'male' or nil
    local ageValid, ageError = validateAge(data.dateOfBirth)
    if not ageValid then return reply(false, ageError) end
    if containsBannedName(firstname, lastname) then return reply(false, 'Dieser Charaktername ist nicht erlaubt.') end

    local appearance, appearanceError = sanitizeAppearance(data.appearance, sex)
    if not appearance then return reply(false, appearanceError) end

    local description = trim(data.description):gsub('[%c]', ' ')
    if #description > (tonumber(Config.DescriptionMaxLength) or 240) then
        return reply(false, 'Die Beschreibung ist zu lang.')
    end

    local player, loadError = getPlayer(playerSource)
    if not player then return reply(false, loadError or 'Account konnte nicht geladen werden.') end
    local character, createError = player:CreateCharacter({
        firstname = firstname,
        lastname = lastname,
        sex = sex,
        dateOfBirth = data.dateOfBirth,
        metadata = {
            appearance = appearance,
            description = description
        }
    })
    if not character then return reply(false, createError) end

    local selected, selectError = player:SelectCharacter(character.id)
    if not selected then return reply(false, selectError) end
    TriggerEvent('mschar:server:characterCreated', playerSource, character)
    reply(true, character:ToSelectionData())
end)

Core.RegisterCallback('mschar:select', function(playerSource, reply, characterId)
    if not actionAllowed(playerSource) then return reply(false, 'Bitte warte einen Moment.') end
    local player, loadError = getPlayer(playerSource)
    if not player then return reply(false, loadError or 'Account konnte nicht geladen werden.') end
    local success, characterOrError = player:SelectCharacter(characterId)
    if not success then return reply(false, characterOrError) end
    reply(true, characterOrError:ToClientData())
end)

Core.RegisterCallback('mschar:delete', function(playerSource, reply, characterId)
    if not Config.AllowDelete then return reply(false, 'Das Löschen von Charakteren ist deaktiviert.') end
    if not actionAllowed(playerSource) then return reply(false, 'Bitte warte einen Moment.') end
    local player, loadError = getPlayer(playerSource)
    if not player then return reply(false, loadError or 'Account konnte nicht geladen werden.') end
    local success, deleteError = player:DeleteCharacter(characterId)
    if not success then return reply(false, deleteError) end
    TriggerEvent('mschar:server:characterDeleted', playerSource, tonumber(characterId))
    reply(true, player:GetCharacters(), player.maxCharacters)
end)

exports('GetAppearance', function(playerSource)
    local player = Core.GetPlayer(playerSource)
    local character = player and player:GetActiveCharacter() or nil
    return character and character:GetMetadata('appearance') or nil
end)

exports('SetAppearance', function(playerSource, appearance)
    local player = Core.GetPlayer(playerSource)
    local character = player and player:GetActiveCharacter() or nil
    if not character then return false, 'Kein aktiver Charakter.' end
    local sanitized, errorMessage = sanitizeAppearance(appearance, character.sex)
    if not sanitized then return false, errorMessage end
    local success, metadataError = character:SetMetadata('appearance', sanitized)
    if not success then return false, metadataError end
    TriggerClientEvent('mschar:client:applyAppearance', playerSource, sanitized)
    return true, sanitized
end)

AddEventHandler('playerDropped', function()
    lastActions[source] = nil
end)
