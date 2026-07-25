local OnboardingActive = false
local TutorialActive = false
local AdminMenuOpen = false
local CompletedInputs = {}
local TutorialBlip = nil
local CinematicCamera = nil
local CinematicPlaying = false

local GUARMA_ZONE_HASH = 1935063277
local WORLD_ZONE_HASH = -1868977180
local WEATHER_THUNDERSTORM = 0x7C1C4A13
local WEATHER_SUNNY = 0x614A1F91
local MARKER_TYPE = -1795314153

local function setGuarmaMode(enabled)
    Citizen.InvokeNative(0x74E2261D2A66849A, not enabled)
    Citizen.InvokeNative(0x63E7279D04160477, enabled)
    Citizen.InvokeNative(0xA657EC9DBC6CC900, enabled and GUARMA_ZONE_HASH or WORLD_ZONE_HASH)
end

local function setLocalWeather(hash, transition)
    Citizen.InvokeNative(0x59174F1AFE095B5A, hash, false, true, true, transition or 5.0, false)
end

local function stopCinematic()
    local wasPlaying = CinematicPlaying or CinematicCamera ~= nil
    CinematicPlaying = false
    if CinematicCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(CinematicCamera, false)
        CinematicCamera = nil
    end
    SendNUIMessage({ action = 'cinematicEnd' })
    if not wasPlaying then return end
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    setLocalWeather(WEATHER_SUNNY, 3.0)
end

local function teleport(coords)
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    setGuarmaMode(true)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)
    FreezeEntityPosition(ped, true)
    Wait(900)
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(600)
end

local function removeTutorialBlip()
    if TutorialBlip then
        RemoveBlip(TutorialBlip)
        TutorialBlip = nil
    end
end

local function setTutorialBlip(coords)
    removeTutorialBlip()
    TutorialBlip = Citizen.InvokeNative(
        0x554D9D53F696D002,
        GetHashKey('BLIP_STYLE_CREATOR_DEFAULT'),
        coords.x,
        coords.y,
        coords.z
    )
    if TutorialBlip then
        SetBlipSprite(TutorialBlip, GetHashKey('blip_ambient_delivery'), true)
    end
end

local function lerp(a, b, value)
    return a + (b - a) * value
end

local function playCameraShot(camera, shot)
    SendNUIMessage({
        action = 'cinematicCaption',
        title = shot.title,
        text = shot.text
    })
    local startedAt = GetGameTimer()
    while OnboardingActive and GetGameTimer() - startedAt < shot.duration do
        local progress = math.min((GetGameTimer() - startedAt) / shot.duration, 1.0)
        local eased = progress * progress * (3.0 - 2.0 * progress)
        SetCamCoord(
            camera,
            lerp(shot.from.x, shot.to.x, eased),
            lerp(shot.from.y, shot.to.y, eased),
            lerp(shot.from.z, shot.to.z, eased)
        )
        PointCamAtCoord(camera, shot.lookAt.x, shot.lookAt.y, shot.lookAt.z)
        Wait(0)
    end
end

local function playIntro()
    local ped = PlayerPedId()
    CinematicPlaying = true
    setGuarmaMode(true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    setLocalWeather(WEATHER_THUNDERSTORM, 1.5)

    CinematicCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(CinematicCamera, true)
    RenderScriptCams(true, false, 0, true, true)
    SendNUIMessage({ action = 'cinematicStart' })

    for _, shot in ipairs(GuarmaConfig.CinematicCameras) do
        if not OnboardingActive then break end
        playCameraShot(CinematicCamera, shot)
    end

    if not OnboardingActive then
        stopCinematic()
        return false
    end
    DoScreenFadeOut(700)
    while not IsScreenFadedOut() do Wait(0) end
    stopCinematic()

    local spawn = GuarmaConfig.BeachSpawn
    RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
    SetEntityCoords(ped, spawn.x, spawn.y, spawn.z, false, false, false, false)
    SetEntityHeading(ped, spawn.w)
    Wait(1000)
    setLocalWeather(WEATHER_SUNNY, 8.0)
    DoScreenFadeIn(900)
    TriggerServerEvent('frontier_guarma:server:beachArrived')
    SetTimeout(1800, function()
        if OnboardingActive then TriggerServerEvent('frontier_guarma:server:beachArrived') end
    end)
    return true
end

local function runTutorial(startIndex)
    TutorialActive = true
    if not startIndex then
        CompletedInputs = {}
        SendNUIMessage({ action = 'tutorialStart' })
    end

    for index = startIndex or 1, #GuarmaConfig.TutorialSteps do
        local step = GuarmaConfig.TutorialSteps[index]
        if not TutorialActive then return end
        setTutorialBlip(step.coords)
        SendNUIMessage({
            action = 'tutorialStep',
            index = index,
            total = #GuarmaConfig.TutorialSteps,
            title = step.title,
            text = step.text,
            key = step.key
        })

        local lastDistanceUpdate = 0
        while TutorialActive do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local dx, dy, dz = playerCoords.x - step.coords.x, playerCoords.y - step.coords.y, playerCoords.z - step.coords.z
            local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
            DrawMarker(
                MARKER_TYPE,
                step.coords.x, step.coords.y, step.coords.z + 0.2,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                0.65, 0.65, 0.65,
                199, 154, 75, 180,
                false, true, 2, false, nil, nil, false
            )
            if GetGameTimer() - lastDistanceUpdate > 200 then
                SendNUIMessage({ action = 'tutorialDistance', distance = math.floor(distance + 0.5) })
                lastDistanceUpdate = GetGameTimer()
            end

            local inputComplete = not step.input or CompletedInputs[step.input]
            if distance <= step.radius and inputComplete then break end
            Wait(0)
        end

        SendNUIMessage({ action = 'tutorialProgress', index = index })
        Wait(500)
    end

    removeTutorialBlip()
    TutorialActive = false
    SendNUIMessage({ action = 'tutorialFinishing' })
    Wait(1200)
    if OnboardingActive then TriggerServerEvent('frontier_guarma:server:complete') end
end

RegisterNetEvent('frontier_guarma:client:start', function(resume)
    if OnboardingActive then return end
    OnboardingActive = true
    CreateThread(function()
        Wait(GuarmaConfig.StartDelay)
        if not resume then
            if not playIntro() then return end
        else
            teleport(GuarmaConfig.BeachSpawn)
            TriggerServerEvent('frontier_guarma:server:beachArrived')
            SetTimeout(1800, function()
                if OnboardingActive then TriggerServerEvent('frontier_guarma:server:beachArrived') end
            end)
        end
        if OnboardingActive then runTutorial() end
    end)
end)

RegisterNetEvent('frontier_guarma:client:forceStop', function()
    OnboardingActive = false
    TutorialActive = false
    removeTutorialBlip()
    stopCinematic()
    setGuarmaMode(false)
    SendNUIMessage({ action = 'reset' })
end)

RegisterNetEvent('frontier_guarma:client:setIslandMode', function(enabled)
    setGuarmaMode(enabled == true)
end)

RegisterNetEvent('frontier_guarma:client:completeConfirmed', function()
    OnboardingActive = false
    TutorialActive = false
    removeTutorialBlip()
    SendNUIMessage({ action = 'tutorialComplete' })
end)

RegisterNetEvent('frontier_guarma:client:completionRejected', function()
    if not OnboardingActive or TutorialActive then return end
    CreateThread(function()
        runTutorial(#GuarmaConfig.TutorialSteps)
    end)
end)

RegisterNetEvent('frontier_guarma:client:adminAlert', function(data)
    SendNUIMessage({
        action = 'adminAlert',
        name = data.characterName or data.name or 'Ein neuer Spieler',
        source = data.source,
        command = '/' .. GuarmaConfig.AdminMenuCommand
    })
end)

RegisterNetEvent('frontier_guarma:client:openAdminMenu', function(data)
    AdminMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'adminMenu',
        locations = data.locations or {},
        newcomers = data.newcomers or {}
    })
end)

RegisterNetEvent('frontier_guarma:client:teleport', function(coords)
    TriggerEvent('frontier:client:beforeTeleport')
    AdminMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'adminMenuClose' })
    teleport(coords)
end)

RegisterNUICallback('adminTeleport', function(data, cb)
    if not AdminMenuOpen or type(data.locationId) ~= 'string' then
        return cb({ ok = false })
    end
    TriggerServerEvent('frontier_guarma:server:teleportAdmin', data.locationId)
    cb({ ok = true })
end)

RegisterNUICallback('closeAdminMenu', function(_, cb)
    AdminMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'adminMenuClose' })
    cb({ ok = true })
end)

local function bindTutorialKey(command, description, key, input)
    RegisterCommand('+' .. command, function()
        if TutorialActive then CompletedInputs[input] = true end
    end, false)
    RegisterCommand('-' .. command, function() end, false)
    RegisterKeyMapping('+' .. command, description, 'keyboard', key)
end

bindTutorialKey('frontier_tutorial_walk', 'Tutorial: bewegen', 'W', 'walk')
bindTutorialKey('frontier_tutorial_sprint', 'Tutorial: sprinten', 'LSHIFT', 'sprint')
bindTutorialKey('frontier_tutorial_jump', 'Tutorial: springen', 'SPACE', 'jump')
bindTutorialKey('frontier_tutorial_crouch', 'Tutorial: ducken', 'LCONTROL', 'crouch')

exports('IsOnboardingActive', function()
    return OnboardingActive
end)

AddEventHandler('frontier:client:prepareLogout', function()
    OnboardingActive = false
    TutorialActive = false
    removeTutorialBlip()
    stopCinematic()
    setGuarmaMode(false)
    SendNUIMessage({ action = 'reset' })
    if AdminMenuOpen then
        AdminMenuOpen = false
        SetNuiFocus(false, false)
    end
end)

AddEventHandler('frontier:client:beforeTeleport', function()
    if OnboardingActive then
        TutorialActive = false
        OnboardingActive = false
        removeTutorialBlip()
        stopCinematic()
        SendNUIMessage({ action = 'reset' })
    end
    setGuarmaMode(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    OnboardingActive = false
    TutorialActive = false
    removeTutorialBlip()
    stopCinematic()
    setGuarmaMode(false)
    SetNuiFocus(false, false)
    SetEntityVisible(PlayerPedId(), true, false)
    SetEntityInvincible(PlayerPedId(), false)
    FreezeEntityPosition(PlayerPedId(), false)
end)
