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
local SelectionPreviewOpen = false
local SelectorPlayerWasVisible = false
local SpawnRecoveryToken = 0
local APPEARANCE_KEYS = { 'head', 'body', 'hair', 'beard', 'eyes', 'height' }

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
local EQUIP_META_PED_OUTFIT_PRESET = 0x77FF8D35EEC6BBC4
local EQUIP_META_PED_OUTFIT_EXTRA = 0xA5BAE410B03E7371
local APPLY_SHOP_ITEM_TO_PED = 0xD3A7B003ED343FD9
local UPDATE_PED_VARIATION = 0xCC8CA3E88256E58F
local IS_PED_READY_TO_RENDER = 0xA0BC8FAED8CFEB3C
local FINALIZE_PED_VARIATION = 0xAAB86462966168CE
local SET_PED_SCALE = 0x25ACFC650B65C538

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
    if NextRequest > 2147483647 then NextRequest = 1 end

    local requestId = NextRequest
    local entry = {
        callback = type(callback) == 'function' and callback or function() end,
        name = tostring(name or 'unknown')
    }
    Callbacks[requestId] = entry
    TriggerServerEvent('mscore:server:callback', requestId, name, ...)

    local timeout = math.max(1000, math.floor(tonumber(Config.CallbackTimeoutMs) or 15000))
    SetTimeout(timeout, function()
        if Callbacks[requestId] ~= entry then return end
        Callbacks[requestId] = nil
        entry.callback(nil, ('Zeitüberschreitung bei Server-Callback "%s".'):format(entry.name))
    end)
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

local function creatorOptions(key, sex)
    local options = creatorConfig().AppearanceOptions
    options = type(options) == 'table' and options[key] or nil
    return type(options) == 'table' and type(options[sex]) == 'table' and options[sex] or {}
end

local function normalizeCreatorAppearance(raw)
    local config = creatorConfig()
    local defaults = type(config.Defaults) == 'table' and config.Defaults or {}
    local outfits = type(config.Outfits) == 'table' and config.Outfits or {}
    raw = type(raw) == 'table' and raw or {}

    local sex = raw.sex == 'female' and 'female' or 'male'
    local appearance = { sex = sex }
    for _, key in ipairs(APPEARANCE_KEYS) do
        local options = creatorOptions(key, sex)
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

local function creatorUiData()
    local config = creatorConfig()
    local defaults = normalizeCreatorAppearance({
        sex = Config.DefaultCharacter.sex,
        head = config.Defaults and config.Defaults.head,
        body = config.Defaults and config.Defaults.body,
        hair = config.Defaults and config.Defaults.hair,
        beard = config.Defaults and config.Defaults.beard,
        eyes = config.Defaults and config.Defaults.eyes,
        height = config.Defaults and config.Defaults.height,
        outfit = config.Defaults and config.Defaults.outfit
    })
    local outfits = {}
    local options = { male = {}, female = {} }

    for _, sex in ipairs({ 'male', 'female' }) do
        for _, key in ipairs(APPEARANCE_KEYS) do
            options[sex][key] = {}
            for index, option in ipairs(creatorOptions(key, sex)) do
                options[sex][key][index] = tostring(option.label or ('Option ' .. index))
            end
        end
    end

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
        options = options,
        profile = {
            nicknameMaxLength = tonumber(config.Profile and config.Profile.NicknameMaxLength) or 32,
            descriptionMaxLength = tonumber(config.Profile and config.Profile.DescriptionMaxLength) or 280
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

local function creatorOption(key, appearance)
    local options = creatorOptions(key, appearance.sex)
    return options[appearance[key]]
end

local function componentHash(component)
    if type(component) == 'number' then return component end
    if type(component) == 'string' and component ~= '' then return GetHashKey(component) end
end

local function applyCreatorOption(ped, key, appearance)
    local option = creatorOption(key, appearance)
    local components = type(option) == 'table' and option.components or nil
    for _, component in ipairs(type(components) == 'table' and components or {}) do
        local hash = componentHash(component)
        if hash and hash ~= 0 then
            Citizen.InvokeNative(EQUIP_META_PED_OUTFIT_EXTRA, ped, hash, 0, 0, 0)
        end
    end
end

local function resetCreatorPed(ped, sex)
    local success = pcall(
        Citizen.InvokeNative,
        EQUIP_META_PED_OUTFIT_PRESET,
        ped,
        sex == 'female' and 7 or 3
    )
    if success then return end
    Citizen.InvokeNative(SET_RANDOM_OUTFIT_VARIATION, ped, true)
end

local function applyCreatorAppearance(ped, rawAppearance, includeOutfit)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local appearance = normalizeCreatorAppearance(rawAppearance)

    local readyExpires = GetGameTimer() + 2500
    while not Citizen.InvokeNative(IS_PED_READY_TO_RENDER, ped)
        and GetGameTimer() < readyExpires
    do
        Wait(0)
    end
    resetCreatorPed(ped, appearance.sex)
    for _, key in ipairs({ 'head', 'body', 'hair', 'beard', 'eyes' }) do
        applyCreatorOption(ped, key, appearance)
    end
    if includeOutfit ~= false then applyCreatorOutfit(ped, appearance) end
    Citizen.InvokeNative(UPDATE_PED_VARIATION, ped, false, true, true, true, false)
    Citizen.InvokeNative(FINALIZE_PED_VARIATION, ped, true)

    local heightOption = creatorOption('height', appearance)
    local scale = type(heightOption) == 'table' and tonumber(heightOption.scale) or 1.0
    Citizen.InvokeNative(SET_PED_SCALE, ped, scale or 1.0)
    return appearance
end

local function applyAppearanceToPlayer()
    local config = creatorConfig()
    local metadata = type(PlayerData.metadata) == 'table' and PlayerData.metadata or {}
    local rawAppearance = { sex = PlayerData.sex }
    for key, value in pairs(type(metadata.appearance) == 'table' and metadata.appearance or {}) do
        rawAppearance[key] = value
    end
    local appearance = normalizeCreatorAppearance(rawAppearance)
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
    applyCreatorAppearance(ped, appearance, GetResourceState('MS_Inventory') ~= 'started')
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

local function startSelectionPreview(rawAppearance)
    local preview = type(creatorConfig().Preview) == 'table' and creatorConfig().Preview or {}
    if preview.selectorEnabled == false or CreatorOpen then return false end

    local appearance = normalizeCreatorAppearance(rawAppearance)
    SelectionPreviewOpen = true
    CreatorZoom = 0.5
    DisplayRadar(false)

    if CreatorPed and DoesEntityExist(CreatorPed)
        and CreatorAppearance and CreatorAppearance.sex == appearance.sex
    then
        CreatorAppearance = appearance
        applyCreatorAppearance(CreatorPed, appearance)
        updateCreatorCamera()
        return true
    end

    CreatorAppearance = appearance
    local success, err = createCreatorPed(appearance)
    if not success then
        SelectionPreviewOpen = false
        CreatorAppearance = nil
        ClearFocus()
        return false, err
    end
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
    SelectionPreviewOpen = false
    CreatorAppearance = appearance
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    DisplayRadar(false)

    local success, err = createCreatorPed(appearance)
    if not success then
        CreatorOpen = false
        SetEntityVisible(playerPed, CreatorPlayerWasVisible, false)
        ClearFocus()
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
        -- Eine Kamera-Interpolation auf ein direkt danach gelöschtes Ziel kann
        -- RedM dauerhaft schwarz lassen. Deshalb immer sofort zur Spielkamera
        -- zurückschalten und erst danach die Creator-Kamera entfernen.
        pcall(SetCamActive, CreatorCamera, false)
        pcall(RenderScriptCams, false, false, 0, true, true, 0)
        pcall(DestroyCam, CreatorCamera, false)
    elseif type(RenderScriptCams) == 'function' then
        pcall(RenderScriptCams, false, false, 0, true, true, 0)
    end
    CreatorCamera = nil
    CreatorCameraDirection = nil
    deleteCreatorPed()

    if CreatorOpen and restorePlayer ~= false then
        SetEntityVisible(PlayerPedId(), CreatorPlayerWasVisible, false)
    end
    CreatorOpen = false
    SelectionPreviewOpen = false
    CreatorAppearance = nil
    CreatorZoom = 0.5
    if type(ClearFocus) == 'function' then pcall(ClearFocus) end
    DisplayRadar(true)
end

local function setSelectorVisible(visible)
    SelectorOpen = visible
    setSelectorInputFocus(visible, false)
    if not visible then
        stopCharacterCreator(true)
        SendNUIMessage({ action = 'close' })
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, PlayerData.characterId ~= nil or SelectorPlayerWasVisible, false)
    end
end

local function shutdownLoadingScreens()
    if type(ShutdownLoadingScreen) == 'function' then
        pcall(ShutdownLoadingScreen)
    end
    if type(ShutdownLoadingScreenNui) == 'function' then
        pcall(ShutdownLoadingScreenNui)
    end
end

local function closeSelectorOverlay()
    SelectorOpen = false
    setSelectorInputFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopCharacterCreator(false)
    shutdownLoadingScreens()
end

local function restoreGameplayView(ped)
    ped = ped and ped ~= 0 and ped or PlayerPedId()
    closeSelectorOverlay()

    if type(ClearFocus) == 'function' then pcall(ClearFocus) end
    if type(RenderScriptCams) == 'function' then
        pcall(RenderScriptCams, false, false, 0, true, true, 0)
    end
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityVisible(ped, true, false)
        if type(ResetEntityAlpha) == 'function' then ResetEntityAlpha(ped) end
        SetEntityInvincible(ped, false)
        SetEntityCanBeDamaged(ped, true)
        FreezeEntityPosition(ped, false)
    end
    if type(SetPlayerInvincible) == 'function' then
        SetPlayerInvincible(PlayerId(), false)
    end
    if type(SetPlayerControl) == 'function' then
        SetPlayerControl(PlayerId(), true, 0)
    end
    DisplayRadar(true)
    if type(DisplayHud) == 'function' then DisplayHud(true) end
    DoScreenFadeIn(0)
end

local function scheduleGameplayRecovery(delay)
    SpawnRecoveryToken = SpawnRecoveryToken + 1
    local token = SpawnRecoveryToken
    SetTimeout(math.max(0, math.floor(tonumber(delay) or 0)), function()
        if token ~= SpawnRecoveryToken or SelectorOpen or not PlayerData.characterId then return end
        restoreGameplayView(PlayerPedId())
    end)
    return token
end

local function streamSpawnArea(ped, x, y, z, heading)
    RequestCollisionAtCoord(x, y, z)
    if type(SetEntityCoordsAndHeading) == 'function' then
        SetEntityCoordsAndHeading(ped, x, y, z, heading, false, false, false)
    else
        SetEntityCoords(ped, x, y, z, false, false, false, false)
        SetEntityHeading(ped, heading)
    end

    if type(LoadSceneStart) == 'function' and type(IsLoadSceneLoaded) == 'function' then
        LoadSceneStart(x, y, z, 0.0, 0.0, 0.0, 40.0, 0)
        local sceneDeadline = GetGameTimer() + 6000
        while IsLoadSceneLoaded() == 0 and GetGameTimer() < sceneDeadline do
            RequestCollisionAtCoord(x, y, z)
            Wait(0)
        end
        if type(LoadSceneStop) == 'function' then LoadSceneStop() end
    end

    local collisionDeadline = GetGameTimer() + 5000
    while type(HasCollisionLoadedAroundEntity) == 'function'
        and not HasCollisionLoadedAroundEntity(ped)
        and GetGameTimer() < collisionDeadline
    do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end
end

local function openCharacterSelector()
    SpawnRecoveryToken = SpawnRecoveryToken + 1
    shutdownLoadingScreens()
    if SelectorOpen then
        setSelectorInputFocus(true, false)
        SendNUIMessage({ action = 'loading' })
    else
        SelectorOpen = true
        local ped = PlayerPedId()
        SelectorPlayerWasVisible = IsEntityVisible(ped)
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
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
    local entry = Callbacks[requestId]
    if not entry then return end
    Callbacks[requestId] = nil
    entry.callback(...)
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
    coords = type(coords) == 'table' and coords or {}
    local fallback = Config.Spawn
    local x = tonumber(coords.x) or tonumber(fallback and fallback.x)
    local y = tonumber(coords.y) or tonumber(fallback and fallback.y)
    local z = tonumber(coords.z) or tonumber(fallback and fallback.z)
    local heading = tonumber(coords.w) or tonumber(fallback and fallback.w) or 0.0
    if not x or not y or not z then
        restoreGameplayView(PlayerPedId())
        return TriggerEvent('mscore:client:notify', 'Spawnkoordinaten sind ungültig.')
    end
    local spawnStartedAt = GetGameTimer()
    SpawnRecoveryToken = SpawnRecoveryToken + 1

    DoScreenFadeIn(0)
    stopCharacterCreator(false)
    local ped = PlayerPedId()
    local spawnError
    local success, errorMessage = xpcall(function()
        local appearanceApplied, appearancePed, appearanceError = pcall(applyAppearanceToPlayer)
        ped = appearanceApplied and appearancePed or PlayerPedId()
        ped = ped and ped ~= 0 and ped or PlayerPedId()
        if not appearanceApplied then
            spawnError = ('Aussehen konnte nicht angewendet werden: %s'):format(tostring(appearancePed))
        elseif appearanceError then
            spawnError = tostring(appearanceError)
        end

        SetEntityVisible(ped, true, false)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)
        streamSpawnArea(ped, x, y, z, heading)

        local minimumLoadingMs = math.max(
            0,
            math.floor(tonumber(
                Config.CharacterCreator and Config.CharacterCreator.SpawnLoadingMs
            ) or 1500)
        )
        local remainingLoadingMs = minimumLoadingMs - (GetGameTimer() - spawnStartedAt)
        if remainingLoadingMs > 0 then Wait(remainingLoadingMs) end
    end, function(message)
        if type(debug) == 'table' and type(debug.traceback) == 'function' then
            return debug.traceback(tostring(message), 2)
        end
        return tostring(message)
    end)

    restoreGameplayView(ped)
    scheduleGameplayRecovery(1000)
    SetTimeout(4000, function()
        if SelectorOpen or not PlayerData.characterId then return end
        restoreGameplayView(PlayerPedId())
    end)

    if not success then
        print(('[MSCore] Charakterspawn fehlgeschlagen:\n%s'):format(tostring(errorMessage)))
        TriggerEvent('mscore:client:notify', 'Der Spawn wurde wiederhergestellt; Details stehen in der F8-Konsole.')
    elseif spawnError then
        TriggerEvent('mscore:client:notify', spawnError)
    end
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
        if success then
            closeSelectorOverlay()
            scheduleGameplayRecovery(7000)
        end
    end, id)
end)

RegisterNUICallback('createCharacter', function(data, cb)
    MSCore.TriggerCallback('mscore:createCharacter', function(success, err)
        cb({ ok = success == true, error = err })
        if success then
            SetTimeout(250, function()
                if SelectorOpen then closeSelectorOverlay() end
            end)
            scheduleGameplayRecovery(7000)
        end
    end, {
        firstname = data and data.firstname,
        lastname = data and data.lastname,
        nickname = data and data.nickname,
        description = data and data.description,
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

RegisterNUICallback('previewSelectedCharacter', function(data, cb)
    if not SelectorOpen or CreatorOpen then
        return cb({ ok = false, error = 'Die Charaktervorschau ist nicht verfügbar.' })
    end
    local appearance = type(data and data.appearance) == 'table' and data.appearance or {}
    appearance.sex = data and data.sex
    local success, err = startSelectionPreview(appearance)
    cb({ ok = success == true, error = err })
end)

RegisterNUICallback('rotateCreator', function(data, cb)
    if (not CreatorOpen and not SelectionPreviewOpen)
        or not CreatorPed or not DoesEntityExist(CreatorPed)
    then
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
    if not CreatorOpen and not SelectionPreviewOpen then
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
            closeSelectorOverlay()
            scheduleGameplayRecovery(7000)
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
            closeSelectorOverlay()
            scheduleGameplayRecovery(7000)
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
            TriggerServerEvent('mscore:server:updatePosition')
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
