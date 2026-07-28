local PlayerData = {}
local Callbacks, NextRequest = {}, 0
local SelectorOpen = false
local CreatorOpen = false
local CreatorPed = nil
local CreatorCamera = nil
local CreatorAppearance = nil
local CreatorCameraDirection = nil
local CreatorZoom = 0.5
local CreatorPlayerWasVisible = false

local RawKeyBindings = {}
local RegisteredRawCommands = {}
local RawKeymapFallbackAnnounced = false
local RAW_KEY_CODES = {
    BACK = 0x08,
    BACKSPACE = 0x08,
    TAB = 0x09,
    RETURN = 0x0D,
    ENTER = 0x0D,
    SHIFT = 0x10,
    CONTROL = 0x11,
    CTRL = 0x11,
    MENU = 0x12,
    ALT = 0x12,
    PAUSE = 0x13,
    CAPSLOCK = 0x14,
    ESC = 0x1B,
    ESCAPE = 0x1B,
    SPACE = 0x20,
    PAGEUP = 0x21,
    PAGEDOWN = 0x22,
    END = 0x23,
    HOME = 0x24,
    LEFT = 0x25,
    UP = 0x26,
    RIGHT = 0x27,
    DOWN = 0x28,
    INSERT = 0x2D,
    DELETE = 0x2E,
    MULTIPLY = 0x6A,
    ADD = 0x6B,
    SUBTRACT = 0x6D,
    DECIMAL = 0x6E,
    DIVIDE = 0x6F,
    LSHIFT = 0xA0,
    RSHIFT = 0xA1,
    LCONTROL = 0xA2,
    LCTRL = 0xA2,
    RCONTROL = 0xA3,
    RCTRL = 0xA3,
    LMENU = 0xA4,
    LALT = 0xA4,
    RMENU = 0xA5,
    RALT = 0xA5
}

for keyCode = string.byte('0'), string.byte('9') do
    RAW_KEY_CODES[string.char(keyCode)] = keyCode
end
for keyCode = string.byte('A'), string.byte('Z') do
    RAW_KEY_CODES[string.char(keyCode)] = keyCode
end
for index = 0, 9 do
    RAW_KEY_CODES['NUMPAD' .. index] = 0x60 + index
end
for index = 1, 24 do
    RAW_KEY_CODES['F' .. index] = 0x6F + index
end

local SET_RANDOM_OUTFIT_VARIATION = 0x283978A15512B2FE
local ADD_META_PED_COMPONENT = 0xA5BAE410B03E7371
local APPLY_SHOP_ITEM_TO_PED = 0xD3A7B003ED343FD9
local UPDATE_PED_VARIATION = 0xCC8CA3E88256E58F
local IS_PED_READY_TO_RENDER = 0xA0BC8FAED8CFEB3C
local FINALIZE_PED_VARIATION = 0xAAB86462966168CE

function MSCore.RegisterKeyMappingCompat(command, description, mapper, defaultKey)
    if type(command) ~= 'string' or command == '' then
        return false
    end

    if type(RegisterKeyMapping) == 'function' then
        RegisterKeyMapping(command, description or command, mapper or 'keyboard', defaultKey or '')
        return true
    end

    if type(RegisterRawKeymap) ~= 'function' then
        print(('[MSCore] Tastenbelegung fuer "%s" fehlgeschlagen: RegisterRawKeymap ist nicht verfuegbar.'):format(command))
        return false
    end

    if type(mapper) == 'string' and mapper:lower() ~= 'keyboard' then
        print(('[MSCore] Tastenbelegung fuer "%s" fehlgeschlagen: RedM-Fallback unterstuetzt nur Tastaturbelegungen.'):format(command))
        return false
    end

    local normalizedKey = tostring(defaultKey or ''):upper():gsub('%s+', '')
    local keyCode = RAW_KEY_CODES[normalizedKey]
    if not keyCode then
        print(('[MSCore] Tastenbelegung fuer "%s" fehlgeschlagen: Taste "%s" ist unbekannt.'):format(command, normalizedKey))
        return false
    end

    local owner = type(GetInvokingResource) == 'function' and GetInvokingResource() or nil
    owner = type(owner) == 'string' and owner or 'MSCore'
    local commandKey = ('%s:%s:%d'):format(owner, command, keyCode)
    if RegisteredRawCommands[commandKey] then
        return true
    end

    local binding = RawKeyBindings[keyCode]
    if not binding then
        binding = { commands = {} }
        RawKeyBindings[keyCode] = binding

        local registered, errorMessage = pcall(
            RegisterRawKeymap,
            ('mscore_key_%02x'):format(keyCode),
            function()
                for index = 1, #binding.commands do
                    ExecuteCommand(binding.commands[index].down)
                end
            end,
            function()
                for index = 1, #binding.commands do
                    local releaseCommand = binding.commands[index].up
                    if releaseCommand then
                        ExecuteCommand(releaseCommand)
                    end
                end
            end,
            keyCode,
            true
        )

        if not registered then
            RawKeyBindings[keyCode] = nil
            print(('[MSCore] Tastenbelegung fuer "%s" fehlgeschlagen: %s'):format(command, tostring(errorMessage)))
            return false
        end
    end

    binding.commands[#binding.commands + 1] = {
        down = command,
        key = commandKey,
        owner = owner,
        up = command:sub(1, 1) == '+' and ('-' .. command:sub(2)) or nil
    }
    RegisteredRawCommands[commandKey] = true

    if not RawKeymapFallbackAnnounced then
        RawKeymapFallbackAnnounced = true
        print('[MSCore] RedM Raw-Keymap-Kompatibilitaet ist aktiv.')
    end

    return true
end
exports('RegisterKeyMappingCompat', MSCore.RegisterKeyMappingCompat)

AddEventHandler('onClientResourceStop', function(resourceName)
    for _, binding in pairs(RawKeyBindings) do
        for index = #binding.commands, 1, -1 do
            local command = binding.commands[index]
            if command.owner == resourceName then
                RegisteredRawCommands[command.key] = nil
                table.remove(binding.commands, index)
            end
        end
    end
end)

function MSCore.TriggerCallback(name, callback, ...)
    NextRequest = NextRequest + 1
    Callbacks[NextRequest] = callback
    TriggerServerEvent('mscore:server:callback', NextRequest, name, ...)
end
exports('TriggerCallback', MSCore.TriggerCallback)

function MSCore.GetPlayerData() return PlayerData end
exports('GetPlayerData', MSCore.GetPlayerData)

local function setSelectorInputFocus(focused, centerCursor)
    SetNuiFocus(focused, focused)
    if type(SetNuiFocusKeepInput) == 'function' then
        SetNuiFocusKeepInput(false)
    end
    if focused and centerCursor and type(SetCursorLocation) == 'function' then
        SetCursorLocation(0.5, 0.5)
    end
end

local function creatorConfig()
    return type(Config.CharacterCreator) == 'table' and Config.CharacterCreator or {}
end

local function creatorOptions(kind, sex)
    local options = creatorConfig()[kind]
    return type(options) == 'table' and type(options[sex]) == 'table' and options[sex] or {}
end

local function normalizeCreatorAppearance(raw)
    local config = creatorConfig()
    local defaults = type(config.Defaults) == 'table' and config.Defaults or {}
    local outfits = type(config.Outfits) == 'table' and config.Outfits or {}
    raw = type(raw) == 'table' and raw or {}

    local sex = raw.sex == 'female' and 'female' or 'male'
    local faceOptions = creatorOptions('FaceOptions', sex)
    local bodyOptions = creatorOptions('BodyOptions', sex)
    local faceMaximum = math.max(1, math.floor(tonumber(faceOptions.count) or 1))
    local bodyMaximum = math.max(1, math.floor(tonumber(bodyOptions.count) or 1))
    local face = math.floor(tonumber(raw.face) or tonumber(defaults.face) or 1)
    local body = math.floor(tonumber(raw.body) or tonumber(defaults.body) or 1)
    local outfit = type(raw.outfit) == 'string' and raw.outfit or defaults.outfit

    face = math.max(1, math.min(faceMaximum, face))
    body = math.max(1, math.min(bodyMaximum, body))
    if type(outfit) ~= 'string' or type(outfits[outfit]) ~= 'table' then
        outfit = type(defaults.outfit) == 'string' and defaults.outfit or next(outfits)
    end

    return {
        sex = sex,
        face = face,
        body = body,
        outfit = outfit
    }
end

local function creatorUiData()
    local config = creatorConfig()
    local defaults = normalizeCreatorAppearance({
        sex = Config.DefaultCharacter.sex,
        face = config.Defaults and config.Defaults.face,
        body = config.Defaults and config.Defaults.body,
        outfit = config.Defaults and config.Defaults.outfit
    })
    local outfits = {}

    for key, outfit in pairs(type(config.Outfits) == 'table' and config.Outfits or {}) do
        outfits[#outfits + 1] = {
            key = key,
            order = tonumber(outfit.order) or 999,
            label = tostring(outfit.label or key),
            description = tostring(outfit.description or '')
        }
    end
    table.sort(outfits, function(left, right)
        if left.order == right.order then return left.key < right.key end
        return left.order < right.order
    end)

    return {
        enabled = config.Enabled ~= false,
        defaults = defaults,
        limits = {
            male = {
                face = math.max(1, math.floor(tonumber(creatorOptions('FaceOptions', 'male').count) or 1)),
                body = math.max(1, math.floor(tonumber(creatorOptions('BodyOptions', 'male').count) or 1))
            },
            female = {
                face = math.max(1, math.floor(tonumber(creatorOptions('FaceOptions', 'female').count) or 1)),
                body = math.max(1, math.floor(tonumber(creatorOptions('BodyOptions', 'female').count) or 1))
            }
        },
        outfits = outfits
    }
end

local function loadCreatorModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(tostring(model or ''))
    if not IsModelValid(hash) then return nil end

    RequestModel(hash, false)
    local expires = GetGameTimer() + (tonumber(creatorConfig().ModelLoadTimeoutMs) or 10000)
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function applyCreatorOutfit(ped, appearance)
    local outfits = type(creatorConfig().Outfits) == 'table' and creatorConfig().Outfits or {}
    local outfit = outfits[appearance.outfit]
    local items = type(outfit) == 'table' and type(outfit.items) == 'table' and outfit.items[appearance.sex] or {}
    local female = appearance.sex == 'female'

    for _, itemName in ipairs(type(items) == 'table' and items or {}) do
        local item = type(Config.Items) == 'table' and Config.Items[itemName]
        local metadata = type(item) == 'table' and item.metadata
        local componentHash = type(metadata) == 'table' and tonumber(metadata.componentHash)
        if componentHash and (metadata.sex == nil or metadata.sex == appearance.sex) then
            Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, ped, componentHash, true, false, female)
            Citizen.InvokeNative(APPLY_SHOP_ITEM_TO_PED, ped, componentHash, true, true, female)
        end
    end
end

local function applyCreatorAppearance(ped, rawAppearance)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local appearance = normalizeCreatorAppearance(rawAppearance)
    local faceOptions = creatorOptions('FaceOptions', appearance.sex)
    local bodyOptions = creatorOptions('BodyOptions', appearance.sex)
    local faceComponent = math.floor(tonumber(faceOptions.first) or 0) + appearance.face - 1
    local bodyComponent = math.floor(tonumber(bodyOptions.first) or 0) + appearance.body - 1

    local readyExpires = GetGameTimer() + 2500
    while not Citizen.InvokeNative(IS_PED_READY_TO_RENDER, ped)
        and GetGameTimer() < readyExpires
    do
        Wait(0)
    end
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
    Citizen.InvokeNative(ADD_META_PED_COMPONENT, ped, faceComponent, 0, 0, 0)
    Citizen.InvokeNative(ADD_META_PED_COMPONENT, ped, bodyComponent, 0, 0, 0)
    applyCreatorOutfit(ped, appearance)
    Citizen.InvokeNative(UPDATE_PED_VARIATION, ped, false, true, true, true, false)
    Citizen.InvokeNative(FINALIZE_PED_VARIATION, ped, true)
    return appearance
end

local function applyAppearanceToPlayer()
    local config = creatorConfig()
    local metadata = type(PlayerData.metadata) == 'table' and PlayerData.metadata or {}
    local appearance = normalizeCreatorAppearance({
        sex = PlayerData.sex,
        face = metadata.appearance and metadata.appearance.face,
        body = metadata.appearance and metadata.appearance.body,
        outfit = metadata.appearance and metadata.appearance.outfit
    })
    if config.Enabled == false then return PlayerPedId() end

    local models = type(config.Models) == 'table' and config.Models or {}
    local model = loadCreatorModel(models[appearance.sex])
    if not model then return PlayerPedId(), 'Charaktermodell konnte nicht geladen werden.' end

    if GetEntityModel(PlayerPedId()) ~= model then
        SetPlayerModel(PlayerId(), model, false)
        Wait(0)
    end
    SetModelAsNoLongerNeeded(model)

    local ped = PlayerPedId()
    applyCreatorAppearance(ped, appearance)
    return ped
end

local function deleteCreatorPed()
    if not CreatorPed or CreatorPed == 0 or not DoesEntityExist(CreatorPed) then
        CreatorPed = nil
        return
    end
    SetEntityAsMissionEntity(CreatorPed, true, true)
    DeleteEntity(CreatorPed)
    CreatorPed = nil
end

local function updateCreatorCamera()
    if not CreatorCamera or not DoesCamExist(CreatorCamera)
        or not CreatorPed or not DoesEntityExist(CreatorPed)
        or not CreatorCameraDirection
    then
        return
    end

    local preview = type(creatorConfig().Preview) == 'table' and creatorConfig().Preview or {}
    local minimum = tonumber(preview.minZoom) or 1.35
    local maximum = tonumber(preview.maxZoom) or 3.20
    local distance = maximum - (maximum - minimum) * CreatorZoom
    local coords = GetEntityCoords(CreatorPed)

    SetCamCoord(
        CreatorCamera,
        coords.x + CreatorCameraDirection.x * distance,
        coords.y + CreatorCameraDirection.y * distance,
        coords.z + (tonumber(preview.cameraHeight) or 0.72)
    )
    PointCamAtEntity(CreatorCamera, CreatorPed, 0.0, 0.0, 0.58, true)
end

local function createCreatorPed(appearance)
    local config = creatorConfig()
    local preview = type(config.Preview) == 'table' and config.Preview or {}
    local coords = preview.coords or Config.Spawn
    local models = type(config.Models) == 'table' and config.Models or {}
    local model = loadCreatorModel(models[appearance.sex])
    if not model then return false, 'Vorschaumodell konnte nicht geladen werden.' end

    RequestCollisionAtCoord(
        tonumber(coords.x) or 0.0,
        tonumber(coords.y) or 0.0,
        tonumber(coords.z) or 0.0
    )
    SetFocusPosAndVel(
        tonumber(coords.x) or 0.0,
        tonumber(coords.y) or 0.0,
        tonumber(coords.z) or 0.0,
        0.0,
        0.0,
        0.0
    )
    deleteCreatorPed()
    CreatorPed = CreatePed(
        model,
        tonumber(coords.x) or 0.0,
        tonumber(coords.y) or 0.0,
        tonumber(coords.z) or 0.0,
        tonumber(coords.w) or 0.0,
        false,
        false,
        false,
        false
    )
    SetModelAsNoLongerNeeded(model)
    if not CreatorPed or CreatorPed == 0 or not DoesEntityExist(CreatorPed) then
        CreatorPed = nil
        return false, 'Vorschau konnte nicht erstellt werden.'
    end

    SetEntityAsMissionEntity(CreatorPed, true, true)
    SetEntityInvincible(CreatorPed, true)
    SetBlockingOfNonTemporaryEvents(CreatorPed, true)
    SetPedCanRagdoll(CreatorPed, false)
    SetEntityNoCollisionEntity(CreatorPed, PlayerPedId(), false)
    RemoveAllPedWeapons(CreatorPed, true, true)
    FreezeEntityPosition(CreatorPed, true)
    applyCreatorAppearance(CreatorPed, appearance)

    local initial = GetOffsetFromEntityInWorldCoords(
        CreatorPed,
        0.0,
        tonumber(preview.cameraDistance) or 2.45,
        tonumber(preview.cameraHeight) or 0.72
    )
    local pedCoords = GetEntityCoords(CreatorPed)
    local dx, dy = initial.x - pedCoords.x, initial.y - pedCoords.y
    local length = math.sqrt(dx * dx + dy * dy)
    CreatorCameraDirection = length > 0.001
        and { x = dx / length, y = dy / length }
        or { x = 0.0, y = 1.0 }

    if not CreatorCamera or not DoesCamExist(CreatorCamera) then
        CreatorCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(CreatorCamera, tonumber(preview.cameraFov) or 38.0)
        SetCamActive(CreatorCamera, true)
        RenderScriptCams(true, true, 350, true, true, 0)
    end
    updateCreatorCamera()
    return true
end

local function startCharacterCreator(rawAppearance)
    if creatorConfig().Enabled == false then return false, 'Charakter-Creator ist deaktiviert.' end
    local appearance = normalizeCreatorAppearance(rawAppearance)
    local playerPed = PlayerPedId()

    if not CreatorOpen then
        CreatorPlayerWasVisible = IsEntityVisible(playerPed)
        CreatorZoom = 0.5
    end
    CreatorOpen = true
    CreatorAppearance = appearance
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    DisplayRadar(false)

    local success, err = createCreatorPed(appearance)
    if not success then
        CreatorOpen = false
        SetEntityVisible(playerPed, CreatorPlayerWasVisible, false)
        return false, err
    end
    return true
end

local function previewCharacterCreator(rawAppearance)
    if not CreatorOpen then return false, 'Charakter-Creator ist nicht geöffnet.' end
    local appearance = normalizeCreatorAppearance(rawAppearance)
    local changedModel = not CreatorAppearance or CreatorAppearance.sex ~= appearance.sex

    if changedModel then
        local success, err = createCreatorPed(appearance)
        if success then CreatorAppearance = appearance end
        return success, err
    end
    CreatorAppearance = appearance
    applyCreatorAppearance(CreatorPed, appearance)
    return true
end

local function stopCharacterCreator(restorePlayer)
    if CreatorCamera and DoesCamExist(CreatorCamera) then
        RenderScriptCams(false, true, 350, true, true, 0)
        DestroyCam(CreatorCamera, false)
    end
    CreatorCamera = nil
    CreatorCameraDirection = nil
    deleteCreatorPed()

    if CreatorOpen and restorePlayer ~= false then
        SetEntityVisible(PlayerPedId(), CreatorPlayerWasVisible, false)
    end
    CreatorOpen = false
    CreatorAppearance = nil
    CreatorZoom = 0.5
    ClearFocus()
    DisplayRadar(true)
end

local function setSelectorVisible(visible)
    SelectorOpen = visible
    setSelectorInputFocus(visible, false)
    if not visible then
        stopCharacterCreator(true)
        SendNUIMessage({ action = 'close' })
        FreezeEntityPosition(PlayerPedId(), false)
    end
end

local function openCharacterSelector()
    if SelectorOpen then
        setSelectorInputFocus(true, false)
        SendNUIMessage({ action = 'loading' })
    else
        SelectorOpen = true
        FreezeEntityPosition(PlayerPedId(), true)
        if not PlayerData.characterId then SetEntityVisible(PlayerPedId(), false, false) end
        setSelectorInputFocus(true, true)
        SendNUIMessage({ action = 'loading' })
    end

    MSCore.TriggerCallback('mscore:getCharacters', function(characters, err)
        if not characters then
            SendNUIMessage({ action = 'error', message = err or 'Charaktere konnten nicht geladen werden.' })
            return
        end
        SendNUIMessage({
            action = 'open',
            characters = characters,
            maxCharacters = Config.MaxCharacters,
            canClose = PlayerData.characterId ~= nil,
            activeCharacterId = PlayerData.characterId,
            minBirthDate = Config.CharacterBirthDateMin,
            maxBirthDate = Config.CharacterBirthDateMax,
            creator = creatorUiData()
        })
        SetTimeout(50, function()
            if SelectorOpen then setSelectorInputFocus(true, false) end
        end)
    end)
end

RegisterNetEvent('mscore:client:callback', function(requestId, ...)
    local callback = Callbacks[requestId]
    if not callback then return end
    Callbacks[requestId] = nil
    callback(...)
end)

RegisterNetEvent('mscore:client:setPlayerData', function(data)
    PlayerData = data
    TriggerEvent('mscore:client:playerDataChanged', data)
end)

RegisterNetEvent('mscore:client:clearPlayerData', function()
    PlayerData = {}
    stopCharacterCreator(false)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    TriggerEvent('mscore:client:playerDataChanged', PlayerData)
end)

RegisterNetEvent('mscore:client:notify', function(message)
    TriggerEvent('chat:addMessage', { color = { 219, 176, 93 }, args = { 'MSCore', tostring(message) } })
end)

RegisterNetEvent('mscore:client:spawn', function(coords)
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    stopCharacterCreator(false)
    local ped, appearanceError = applyAppearanceToPlayer()
    if appearanceError then
        TriggerEvent('mscore:client:notify', appearanceError)
    end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, tonumber(coords.w) or 0.0)
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, true)
    Wait(1000)
    setSelectorVisible(false)
    DoScreenFadeIn(500)
    if GetResourceState('MS_Inventory') == 'started' then
        TriggerServerEvent('ms_inventory:server:requestOutfit')
    end
end)

RegisterNetEvent('mscore:client:showCharacters', openCharacterSelector)

RegisterNUICallback('selectCharacter', function(data, cb)
    local id = tonumber(data and data.id)
    if not id then return cb({ ok = false, error = 'Ungültiger Charakter.' }) end
    MSCore.TriggerCallback('mscore:selectCharacter', function(success, err)
        cb({ ok = success == true, error = err })
        if success then setSelectorVisible(false) end
    end, id)
end)

RegisterNUICallback('createCharacter', function(data, cb)
    MSCore.TriggerCallback('mscore:createCharacter', function(success, err)
        cb({ ok = success == true, error = err })
        if success then setSelectorVisible(false) end
    end, {
        firstname = data and data.firstname,
        lastname = data and data.lastname,
        dateOfBirth = data and data.dateOfBirth,
        sex = data and data.sex,
        appearance = data and data.appearance
    })
end)

RegisterNUICallback('beginCreator', function(data, cb)
    if not SelectorOpen then
        return cb({ ok = false, error = 'Charakterauswahl ist geschlossen.' })
    end
    local success, err = startCharacterCreator(data and data.appearance)
    cb({ ok = success == true, error = err })
end)

RegisterNUICallback('previewAppearance', function(data, cb)
    local success, err = previewCharacterCreator(data and data.appearance)
    cb({ ok = success == true, error = err })
end)

RegisterNUICallback('rotateCreator', function(data, cb)
    if not CreatorOpen or not CreatorPed or not DoesEntityExist(CreatorPed) then
        return cb({ ok = false, error = 'Charakter-Creator ist nicht geöffnet.' })
    end
    local direction = tonumber(data and data.direction) or 0
    if direction ~= -1 and direction ~= 1 then
        return cb({ ok = false, error = 'Ungültige Drehrichtung.' })
    end
    local preview = type(creatorConfig().Preview) == 'table' and creatorConfig().Preview or {}
    SetEntityHeading(
        CreatorPed,
        GetEntityHeading(CreatorPed) + direction * (tonumber(preview.rotationStep) or 18.0)
    )
    updateCreatorCamera()
    cb({ ok = true })
end)

RegisterNUICallback('zoomCreator', function(data, cb)
    if not CreatorOpen then
        return cb({ ok = false, error = 'Charakter-Creator ist nicht geöffnet.' })
    end
    CreatorZoom = math.max(0.0, math.min(1.0, tonumber(data and data.zoom) or 0.5))
    updateCreatorCamera()
    cb({ ok = true })
end)

RegisterNUICallback('cancelCreator', function(_, cb)
    stopCharacterCreator(true)
    if SelectorOpen then setSelectorInputFocus(true, false) end
    cb({ ok = true })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    local id = tonumber(data and data.id)
    if not id then return cb({ ok = false, error = 'Ungültiger Charakter.' }) end
    MSCore.TriggerCallback('mscore:deleteCharacter', function(success, charactersOrError)
        if not success then return cb({ ok = false, error = charactersOrError }) end
        cb({ ok = true, characters = charactersOrError })
    end, id)
end)

RegisterNUICallback('closeCharacters', function(_, cb)
    if not PlayerData.characterId then
        return cb({ ok = false, error = 'Wähle zuerst einen Charakter.' })
    end
    setSelectorVisible(false)
    cb({ ok = true })
end)

RegisterNUICallback('requestFocus', function(data, cb)
    if not SelectorOpen then
        return cb({ ok = false, error = 'Charakterauswahl ist geschlossen.' })
    end
    setSelectorInputFocus(true, data and data.centerCursor == true)
    cb({ ok = true })
end)

RegisterCommand('selectchar', function(_, args)
    local id = tonumber(args[1])
    if not id then return end
    MSCore.TriggerCallback('mscore:selectCharacter', function(success, err)
        if not success then
            TriggerEvent('mscore:client:notify', err or 'Auswahl fehlgeschlagen.')
        else
            setSelectorVisible(false)
        end
    end, id)
end)

RegisterCommand('newchar', function(_, args)
    local firstname, lastname, sex = args[1], args[2], args[3] or 'male'
    if not firstname or not lastname then
        return TriggerEvent('mscore:client:notify', 'Verwendung: /newchar Vorname Nachname male|female')
    end
    MSCore.TriggerCallback('mscore:createCharacter', function(success, err)
        if not success then
            TriggerEvent('mscore:client:notify', err or 'Erstellung fehlgeschlagen.')
        else
            setSelectorVisible(false)
        end
    end, { firstname = firstname, lastname = lastname, sex = sex })
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1000)
    openCharacterSelector()
end)

CreateThread(function()
    while true do
        Wait(30000)
        if PlayerData.characterId then
            local ped, coords = PlayerPedId(), GetEntityCoords(PlayerPedId())
            TriggerServerEvent('mscore:server:updatePosition', {
                x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(ped)
            }, GetEntityHealth(ped))
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopCharacterCreator(true)
    setSelectorInputFocus(false, false)
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityVisible(PlayerPedId(), true, false)
end)
