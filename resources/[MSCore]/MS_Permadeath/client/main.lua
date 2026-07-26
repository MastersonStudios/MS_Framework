local Config = MSPermadeathConfig
local FinaleActive = false
local FinaleToken = nil
local FinaleIsTest = false
local FinaleCamera = nil
local NativeCutsceneActive = false
local DeathReported = false
local AliveSince = nil
local AliveReported = false

local function finite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function setHudVisible(visible)
    if type(DisplayHud) == 'function' then pcall(DisplayHud, visible) end
    if type(DisplayRadar) == 'function' then pcall(DisplayRadar, visible) end
end

local function stopNativeCutscene()
    if not NativeCutsceneActive then return end
    NativeCutsceneActive = false
    if type(StopCutsceneImmediately) == 'function' then pcall(StopCutsceneImmediately) end
    if type(RemoveCutscene) == 'function' then pcall(RemoveCutscene) end
end

local function cleanupFinale()
    FinaleActive = false
    FinaleToken = nil
    FinaleIsTest = false
    stopNativeCutscene()

    if FinaleCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(FinaleCamera, false)
        FinaleCamera = nil
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    setHudVisible(true)
    SendNUIMessage({ action = 'finaleEnd' })
end

local function pedIsDead()
    local ped = PlayerPedId()
    return ped ~= 0 and (IsEntityDead(ped) or GetEntityHealth(ped) <= 0)
end

local function reportDeath(cause)
    if Config.Enabled ~= true or FinaleActive or DeathReported then return end
    local data = exports.MSCore:GetPlayerData()
    if not data or not data.characterId or not pedIsDead() then return end

    DeathReported = true
    AliveSince = nil
    AliveReported = false
    TriggerServerEvent('ms_permadeath:server:reportDeath', tostring(cause or 'unknown'))
end

AddEventHandler('baseevents:onPlayerDied', function()
    reportDeath('died')
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    reportDeath('killed')
end)

CreateThread(function()
    while true do
        local waitTime = math.max(100, math.floor(tonumber(Config.ClientPollIntervalMs) or 500))
        local data = exports.MSCore:GetPlayerData()
        local hasCharacter = data and data.characterId ~= nil
        if hasCharacter and pedIsDead() then
            AliveSince = nil
            AliveReported = false
            reportDeath('polling')
        elseif hasCharacter then
            if not AliveSince then AliveSince = GetGameTimer() end
            if GetGameTimer() - AliveSince >= math.max(500, math.floor(
                tonumber(Config.ClientAliveResetMs) or 3000
            )) then
                DeathReported = false
                if not AliveReported then
                    AliveReported = true
                    TriggerServerEvent('ms_permadeath:server:reportAlive')
                end
            end
        else
            AliveSince = nil
            AliveReported = false
        end
        Wait(waitTime)
    end
end)

local function offsetPoint(origin, heading, offset)
    local radians = math.rad(heading)
    local sinHeading, cosHeading = math.sin(radians), math.cos(radians)
    return {
        x = origin.x + offset.x * cosHeading - offset.y * sinHeading,
        y = origin.y + offset.x * sinHeading + offset.y * cosHeading,
        z = origin.z + offset.z
    }
end

local function lerp(first, second, progress)
    return first + (second - first) * progress
end

local function playShot(camera, origin, heading, shot)
    local from = offsetPoint(origin, heading, shot.from)
    local to = offsetPoint(origin, heading, shot.to)
    local duration = math.max(500, math.floor(tonumber(shot.durationMs) or 4000))
    local lookZ = tonumber(shot.lookZ) or 0.4
    local startedAt = GetGameTimer()

    SendNUIMessage({
        action = 'caption',
        text = tostring(shot.caption or '')
    })

    while FinaleActive and GetGameTimer() - startedAt < duration do
        local progress = math.min((GetGameTimer() - startedAt) / duration, 1.0)
        local eased = progress * progress * (3.0 - 2.0 * progress)
        SetCamCoord(
            camera,
            lerp(from.x, to.x, eased),
            lerp(from.y, to.y, eased),
            lerp(from.z, to.z, eased)
        )
        PointCamAtCoord(camera, origin.x, origin.y, origin.z + lookZ)
        Wait(0)
    end
end

local function playNativeCutscene()
    local native = Config.Finale and Config.Finale.NativeCutscene or {}
    local name = type(native.Name) == 'string' and native.Name:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if native.Enabled ~= true or name == '' then return false end
    if type(RequestCutscene) ~= 'function'
        or type(HasCutsceneLoaded) ~= 'function'
        or type(StartCutscene) ~= 'function'
        or type(IsCutscenePlaying) ~= 'function'
    then
        return false
    end

    local requested = pcall(RequestCutscene, name, 8)
    if not requested then return false end

    local timeout = math.max(1000, math.floor(tonumber(native.LoadTimeoutMs) or 6000))
    local loadStarted = GetGameTimer()
    while FinaleActive and GetGameTimer() - loadStarted < timeout do
        local ok, loaded = pcall(HasCutsceneLoaded)
        if ok and loaded then break end
        Wait(0)
    end

    local okLoaded, loaded = pcall(HasCutsceneLoaded)
    if not FinaleActive or not okLoaded or not loaded then
        if type(RemoveCutscene) == 'function' then pcall(RemoveCutscene) end
        return false
    end

    if not pcall(StartCutscene, 0) then
        if type(RemoveCutscene) == 'function' then pcall(RemoveCutscene) end
        return false
    end

    NativeCutsceneActive = true
    local startedAt = GetGameTimer()
    local maximum = math.max(3000, math.floor(tonumber(native.MaximumDurationMs) or 65000))
    local played = false
    while FinaleActive and GetGameTimer() - startedAt < maximum do
        local ok, running = pcall(IsCutscenePlaying)
        if not ok or not running then break end
        played = true
        Wait(0)
    end
    stopNativeCutscene()
    return played and GetGameTimer() - startedAt >= 1000
end

local function playFallback()
    local fallback = Config.Finale and Config.Finale.Fallback or {}
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local origin = {
        x = finite(coords.x) and coords.x or 0.0,
        y = finite(coords.y) and coords.y or 0.0,
        z = finite(coords.z) and coords.z or 0.0
    }
    local heading = tonumber(GetEntityHeading(ped)) or 0.0

    FinaleCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(FinaleCamera, true)
    RenderScriptCams(true, false, 0, true, true)

    local shots = type(fallback.Shots) == 'table' and fallback.Shots or {}
    for _, shot in ipairs(shots) do
        if not FinaleActive then break end
        if type(shot) == 'table' and type(shot.from) == 'table' and type(shot.to) == 'table' then
            playShot(FinaleCamera, origin, heading, shot)
        end
    end
end

local function playFinale(payload)
    if FinaleActive then return end
    payload = type(payload) == 'table' and payload or {}
    FinaleActive = true
    FinaleToken = type(payload.token) == 'string' and payload.token or nil
    FinaleIsTest = payload.test == true

    CreateThread(function()
        local fallback = Config.Finale and Config.Finale.Fallback or {}
        local ped = PlayerPedId()
        local fadeOut = math.max(0, math.floor(tonumber(fallback.FadeOutMs) or 800))
        local fadeIn = math.max(0, math.floor(tonumber(fallback.FadeInMs) or 900))

        DoScreenFadeOut(fadeOut)
        while FinaleActive and not IsScreenFadedOut() do Wait(0) end
        if not FinaleActive then return end

        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        setHudVisible(false)
        SendNUIMessage({
            action = 'finaleStart',
            title = tostring(Config.Finale.Title or 'Das Ende eines Weges'),
            subtitle = tostring(Config.Finale.Subtitle or ''),
            characterName = tostring(payload.characterName or ''),
            risk = math.floor(tonumber(payload.risk) or 0),
            threshold = math.floor(tonumber(payload.threshold) or 60),
            test = FinaleIsTest
        })
        DoScreenFadeIn(fadeIn)

        local nativePlayed = playNativeCutscene()
        if FinaleActive and not nativePlayed then playFallback() end
        if not FinaleActive then return end

        SendNUIMessage({
            action = 'caption',
            text = FinaleIsTest
                and 'Testszene beendet – der Charakter bleibt unverändert.'
                or 'Deine Geschichte ist zu Ende.'
        })
        Wait(math.max(500, math.floor(tonumber(fallback.EndingHoldMs) or 1800)))

        DoScreenFadeOut(fadeOut)
        while FinaleActive and not IsScreenFadedOut() do Wait(0) end
        if not FinaleActive then return end

        if FinaleIsTest then
            cleanupFinale()
            DoScreenFadeIn(fadeIn)
        elseif FinaleToken then
            TriggerServerEvent('ms_permadeath:server:finaleComplete', FinaleToken)
        end
    end)
end

RegisterNetEvent('ms_permadeath:client:riskUpdated', function(payload)
    payload = type(payload) == 'table' and payload or {}
    SendNUIMessage({
        action = 'risk',
        risk = math.floor(tonumber(payload.risk) or 0),
        increase = math.floor(tonumber(payload.increase) or 0),
        threshold = math.floor(tonumber(payload.threshold) or 60)
    })
end)

RegisterNetEvent('ms_permadeath:client:startFinale', playFinale)

RegisterNetEvent('ms_permadeath:client:finalized', function()
    cleanupFinale()
    if IsScreenFadedOut() then
        DoScreenFadeIn(math.max(0, math.floor(tonumber(
            Config.Finale and Config.Finale.Fallback and Config.Finale.Fallback.FadeInMs
        ) or 900)))
    end
end)

CreateThread(function()
    while true do
        if FinaleActive then
            DisableAllControlActions(0)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('mscore:client:playerDataChanged', function()
    DeathReported = false
    AliveSince = nil
    AliveReported = false
end)

AddEventHandler('mscore:client:prepareLogout', function()
    DeathReported = false
    AliveSince = nil
    AliveReported = false
    cleanupFinale()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanupFinale()
end)
