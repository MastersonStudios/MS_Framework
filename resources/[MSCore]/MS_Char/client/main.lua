local Core = exports.MSCore:GetCore()
local selectorOpen = false
local characters = {}
local charactersById = {}
local maximumCharacters = 1
local previewCamera = nil
local appliedSignature = nil

local function debugLog(message, ...)
    if not Config.Debug then return end
    print(('[MS_Char] ' .. message):format(...))
end

local function findPreset(presetId)
    presetId = math.floor(tonumber(presetId) or -1)
    for _, preset in ipairs(Config.OutfitPresets or {}) do
        if presetId == tonumber(preset.id) then return presetId end
    end
    return tonumber(Config.OutfitPresets[1] and Config.OutfitPresets[1].id) or 3
end

local function normalizeAppearance(appearance, fallbackSex)
    appearance = type(appearance) == 'table' and appearance or {}
    local sex = appearance.sex == 'female' and 'female'
        or appearance.sex == 'male' and 'male'
        or fallbackSex == 'female' and 'female'
        or 'male'
    return {
        sex = sex,
        model = Config.Models[sex],
        outfitPreset = findPreset(appearance.outfitPreset)
    }
end

local function waitForFade(fadedOut, timeoutMs)
    local startedAt = GetGameTimer()
    while GetGameTimer() - startedAt < timeoutMs do
        if fadedOut and IsScreenFadedOut() then return end
        if not fadedOut and IsScreenFadedIn() then return end
        Wait(0)
    end
end

local function loadModel(modelHash)
    if HasModelLoaded(modelHash) then return true end
    RequestModel(modelHash, false)
    local startedAt = GetGameTimer()
    while not HasModelLoaded(modelHash) and GetGameTimer() - startedAt < Config.ModelLoadTimeoutMs do Wait(25) end
    return HasModelLoaded(modelHash)
end

local function updateCameraTarget(ped)
    if previewCamera and DoesCamExist(previewCamera) then
        PointCamAtEntity(previewCamera, ped, 0.0, 0.0, 0.65, true)
    end
end

local function applyAppearance(appearance, fallbackSex, force)
    appearance = normalizeAppearance(appearance, fallbackSex)
    local modelHash = joaat(appearance.model)
    local signature = ('%s:%d'):format(appearance.model, appearance.outfitPreset)
    local currentPed = PlayerPedId()
    if not force and appliedSignature == signature and currentPed ~= 0 and GetEntityModel(currentPed) == modelHash then
        updateCameraTarget(currentPed)
        return true, appearance
    end
    if not loadModel(modelHash) then return false, 'Charaktermodell konnte nicht geladen werden.' end

    local oldCoords = GetEntityCoords(currentPed)
    local oldHeading = GetEntityHeading(currentPed)
    SetPlayerModel(PlayerId(), modelHash, false)
    local ped = PlayerPedId()
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, appearance.outfitPreset, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    SetEntityCoordsNoOffset(ped, oldCoords.x, oldCoords.y, oldCoords.z, false, false, false)
    SetEntityHeading(ped, oldHeading)
    SetEntityVisible(ped, true)
    SetEntityInvincible(ped, selectorOpen)
    FreezeEntityPosition(ped, selectorOpen)
    SetModelAsNoLongerNeeded(modelHash)
    appliedSignature = signature
    updateCameraTarget(ped)
    TriggerEvent('mschar:client:appearanceApplied', appearance)
    return true, appearance
end

local function characterAppearance(character)
    local metadata = type(character.metadata) == 'table' and character.metadata or {}
    return normalizeAppearance(metadata.appearance, character.sex)
end

local function indexCharacters(entries)
    characters = type(entries) == 'table' and entries or {}
    charactersById = {}
    for _, character in ipairs(characters) do charactersById[tonumber(character.id)] = character end
end

local function setupPreviewScene()
    local preview = Config.Preview
    local position = preview.position
    local ped = PlayerPedId()

    if type(DoScreenFadeOut) == 'function' then
        DoScreenFadeOut(250)
        waitForFade(true, 1500)
    end
    RequestCollisionAtCoord(position.x, position.y, position.z)
    SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false)
    SetEntityHeading(ped, position.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, true)

    local startedAt = GetGameTimer()
    while GetGameTimer() - startedAt < Config.CollisionTimeoutMs do
        if type(HasCollisionLoadedAroundEntity) ~= 'function' or HasCollisionLoadedAroundEntity(ped) then break end
        RequestCollisionAtCoord(position.x, position.y, position.z)
        Wait(50)
    end

    if previewCamera and DoesCamExist(previewCamera) then DestroyCam(previewCamera, false) end
    previewCamera = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        preview.camera.x,
        preview.camera.y,
        preview.camera.z,
        0.0,
        0.0,
        0.0,
        preview.cameraFov,
        false,
        2
    )
    updateCameraTarget(ped)
    SetCamActive(previewCamera, true)
    RenderScriptCams(true, true, 500, true, true, 0)
    if type(DisplayHud) == 'function' then DisplayHud(false) end
    if type(DisplayRadar) == 'function' then DisplayRadar(false) end

    if type(DoScreenFadeIn) == 'function' then
        DoScreenFadeIn(500)
        waitForFade(false, 2000)
    end
end

local function sendOpenMessage(startInCreator)
    local roleplayDate = Config.RoleplayDate
    local minimumYear = roleplayDate.year - Config.MaximumAge
    local maximumYear = roleplayDate.year - Config.MinimumAge
    SendNUIMessage({
        action = 'open',
        characters = characters,
        maximumCharacters = maximumCharacters,
        allowDelete = Config.AllowDelete,
        outfits = Config.OutfitPresets,
        text = Config.Text,
        startInCreator = startInCreator == true,
        minimumDate = ('%04d-01-01'):format(minimumYear),
        maximumDate = ('%04d-12-31'):format(maximumYear)
    })
end

local function openSelector(entries, maximum, forceCreator)
    indexCharacters(entries)
    maximumCharacters = math.max(1, tonumber(maximum) or 1)
    selectorOpen = true
    setupPreviewScene()
    SetNuiFocus(true, true)
    sendOpenMessage(forceCreator or #characters == 0)

    local firstCharacter = characters[1]
    if firstCharacter and not forceCreator then
        applyAppearance(characterAppearance(firstCharacter), firstCharacter.sex, true)
        local position = Config.Preview.position
        local ped = PlayerPedId()
        SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false)
        SetEntityHeading(ped, position.w)
        FreezeEntityPosition(ped, true)
    elseif not firstCharacter then
        applyAppearance({ sex = 'male', outfitPreset = Config.OutfitPresets[1].id }, 'male', true)
    end
    TriggerEvent('mschar:client:opened', characters, maximumCharacters)
end

local function closeSelector()
    if not selectorOpen then return end
    selectorOpen = false
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    if previewCamera and DoesCamExist(previewCamera) then
        SetCamActive(previewCamera, false)
        DestroyCam(previewCamera, false)
    end
    previewCamera = nil
    RenderScriptCams(false, true, 400, true, true, 0)
    if type(DisplayHud) == 'function' then DisplayHud(true) end
    if type(DisplayRadar) == 'function' then DisplayRadar(true) end
    TriggerEvent('mschar:client:closed')
end

RegisterNetEvent('mscore:client:characters', function(entries, maximum)
    openSelector(entries, maximum, type(entries) ~= 'table' or #entries == 0)
end)

RegisterNetEvent('mscore:client:characterRequired', function(maximum)
    if selectorOpen then
        maximumCharacters = math.max(1, tonumber(maximum) or maximumCharacters)
        sendOpenMessage(true)
    else
        openSelector({}, maximum, true)
    end
end)

AddEventHandler('mscore:client:playerLoaded', function()
    closeSelector()
end)

AddEventHandler('mscore:client:spawned', function(data)
    closeSelector()
    CreateThread(function()
        local metadata = type(data) == 'table' and type(data.metadata) == 'table' and data.metadata or {}
        local appearance = normalizeAppearance(metadata.appearance, data and data.sex)
        local modelHash = joaat(appearance.model)
        if appliedSignature == ('%s:%d'):format(appearance.model, appearance.outfitPreset)
            and GetEntityModel(PlayerPedId()) == modelHash then
            SetEntityInvincible(PlayerPedId(), false)
            FreezeEntityPosition(PlayerPedId(), false)
            return
        end

        DoScreenFadeOut(200)
        waitForFade(true, 1200)
        local success, errorMessage = applyAppearance(appearance, data and data.sex, true)
        SetEntityInvincible(PlayerPedId(), false)
        FreezeEntityPosition(PlayerPedId(), false)
        DoScreenFadeIn(500)
        if not success then Core.Notify(errorMessage, 'error') end
    end)
end)

RegisterNetEvent('mschar:client:applyAppearance', function(appearance)
    CreateThread(function() applyAppearance(appearance, nil, true) end)
end)

RegisterNUICallback('previewCharacter', function(data, reply)
    local character = charactersById[tonumber(data and data.characterId)]
    if not character then return reply({ ok = false, error = 'Charakter nicht gefunden.' }) end
    local success, result = applyAppearance(characterAppearance(character), character.sex, false)
    local position = Config.Preview.position
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false)
    SetEntityHeading(ped, position.w)
    FreezeEntityPosition(ped, true)
    reply({ ok = success, error = success and nil or result })
end)

RegisterNUICallback('previewAppearance', function(data, reply)
    data = type(data) == 'table' and data or {}
    local success, result = applyAppearance({
        sex = data.sex,
        outfitPreset = data.outfitPreset
    }, data.sex, false)
    local position = Config.Preview.position
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, position.x, position.y, position.z, false, false, false)
    SetEntityHeading(ped, position.w)
    FreezeEntityPosition(ped, true)
    reply({ ok = success, error = success and nil or result })
end)

RegisterNUICallback('rotate', function(data, reply)
    local ped = PlayerPedId()
    local delta = math.max(-45.0, math.min(45.0, tonumber(data and data.delta) or 0.0))
    SetEntityHeading(ped, GetEntityHeading(ped) + delta)
    reply({ ok = true })
end)

RegisterNUICallback('selectCharacter', function(data, reply)
    Core.TriggerCallback('mschar:select', function(success, result)
        if not success then debugLog('Auswahl fehlgeschlagen: %s', tostring(result)) end
        reply({ ok = success == true, error = success and nil or result })
    end, data and data.characterId)
end)

RegisterNUICallback('createCharacter', function(data, reply)
    Core.TriggerCallback('mschar:create', function(success, result)
        if not success then debugLog('Erstellung fehlgeschlagen: %s', tostring(result)) end
        reply({ ok = success == true, error = success and nil or result })
    end, data)
end)

RegisterNUICallback('deleteCharacter', function(data, reply)
    Core.TriggerCallback('mschar:delete', function(success, result, maximum)
        if not success then return reply({ ok = false, error = result }) end
        indexCharacters(result)
        maximumCharacters = math.max(1, tonumber(maximum) or maximumCharacters)
        sendOpenMessage(#characters == 0)
        if characters[1] then applyAppearance(characterAppearance(characters[1]), characters[1].sex, true) end
        reply({ ok = true })
    end, data and data.characterId)
end)

CreateThread(function()
    while true do
        if selectorOpen then
            DisableAllControlActions(0)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(1000)
        local data = Core.GetPlayerData()
        if type(data) ~= 'table' then return end
        local metadata = type(data.metadata) == 'table' and data.metadata or {}
        applyAppearance(metadata.appearance, data.sex, true)
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if previewCamera and DoesCamExist(previewCamera) then DestroyCam(previewCamera, false) end
    RenderScriptCams(false, false, 0, true, true, 0)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    if type(DoScreenFadeIn) == 'function' and IsScreenFadedOut() then DoScreenFadeIn(0) end
end)

exports('ApplyAppearance', function(appearance, fallbackSex)
    return applyAppearance(appearance, fallbackSex, true)
end)
