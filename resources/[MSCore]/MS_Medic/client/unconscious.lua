local Config = MSMedicConfig
local Settings = type(Config.Unconscious) == 'table' and Config.Unconscious or {}
local RESURRECT_PED = 0x71BC8E838B9C6035
local BLIP_ADD_FOR_COORD = 0x554D9D53F696D002
local BLIP_ADD_FOR_RADIUS = 0x45F13B7E0A15C880
local SET_BLIP_NAME_FROM_PLAYER_STRING = 0x9CB1A1623062F402

local UnconsciousActive = false
local UnconsciousState
local EmergencyRequested = false
local SuppressReports = false
local LastReportAt = -1000000
local EmergencyBlips = {}

local function playerLoaded()
    local data = exports.MSCore:GetPlayerData()
    return type(data) == 'table' and tonumber(data.characterId) ~= nil
end

local function pedIsDead()
    local ped = PlayerPedId()
    return ped ~= 0
        and DoesEntityExist(ped)
        and (IsEntityDead(ped) or GetEntityHealth(ped) <= 0)
end

local function setHudVisible(visible)
    if type(DisplayHud) == 'function' then pcall(DisplayHud, visible) end
    if type(DisplayRadar) == 'function' then pcall(DisplayRadar, visible) end
end

local function stopUnconsciousScreen(reason, restoreHud)
    local wasActive = UnconsciousActive
    UnconsciousActive = false
    UnconsciousState = nil
    EmergencyRequested = false
    if wasActive then
        SetNuiFocus(false, false)
        SendNUIMessage({
            action = 'unconsciousClose',
            reason = tostring(reason or 'resolved')
        })
    end
    if restoreHud ~= false then setHudVisible(true) end
end

local function showUnconsciousScreen(payload)
    if type(payload) ~= 'table' then return end
    TriggerEvent('ms_medic:client:forceClose')

    local ped = PlayerPedId()
    if payload.forceDead == true and DoesEntityExist(ped) and not pedIsDead() then
        SetEntityHealth(ped, 0)
    end

    UnconsciousActive = true
    UnconsciousState = payload
    EmergencyRequested = payload.emergencyCalled == true
    setHudVisible(false)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'unconsciousOpen',
        payload = payload
    })
end

local function removeBlipSafe(blip)
    if not blip or blip == 0 then return end
    pcall(RemoveBlip, blip)
end

local function removeEmergencyBlip(incidentId)
    incidentId = tostring(incidentId or '')
    local entry = EmergencyBlips[incidentId]
    if not entry then return end
    removeBlipSafe(entry.point)
    removeBlipSafe(entry.radius)
    EmergencyBlips[incidentId] = nil
end

local function clearEmergencyBlips()
    local identifiers = {}
    for incidentId in pairs(EmergencyBlips) do identifiers[#identifiers + 1] = incidentId end
    for _, incidentId in ipairs(identifiers) do removeEmergencyBlip(incidentId) end
end

local function createBlip(nativeHash, ...)
    local success, blip = pcall(Citizen.InvokeNative, nativeHash, ...)
    return success and blip and blip ~= 0 and blip or nil
end

local function configureBlip(blip, sprite, label, scale)
    if not blip then return end
    if type(SetBlipSprite) == 'function' and type(sprite) == 'string' and sprite ~= '' then
        pcall(SetBlipSprite, blip, GetHashKey(sprite), true)
    end
    if type(SetBlipScale) == 'function' then pcall(SetBlipScale, blip, scale) end
    pcall(Citizen.InvokeNative, SET_BLIP_NAME_FROM_PLAYER_STRING, blip, label)
end

RegisterNetEvent('ms_medic:client:unconsciousStart', showUnconsciousScreen)

RegisterNetEvent('ms_medic:client:unconsciousUpdate', function(payload)
    if type(payload) ~= 'table' then return end
    if not UnconsciousActive then return showUnconsciousScreen(payload) end
    UnconsciousState = payload
    EmergencyRequested = payload.emergencyCalled == true
    SendNUIMessage({
        action = 'unconsciousUpdate',
        payload = payload
    })
end)

RegisterNetEvent('ms_medic:client:unconsciousStop', function(payload)
    local reason = type(payload) == 'table' and tostring(payload.reason or 'resolved') or 'resolved'
    if reason == 'permadeath' then SuppressReports = true end
    stopUnconsciousScreen(reason, reason ~= 'permadeath')
end)

RegisterNetEvent('ms_medic:client:autoWake', function(payload)
    if type(payload) ~= 'table' or type(payload.coords) ~= 'table' then return end
    local coords = payload.coords
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end

    stopUnconsciousScreen('automatic_wake', false)
    TriggerEvent('mscore:client:beforeTeleport')
    local ped = PlayerPedId()
    local fadeOut = math.max(0, math.floor(tonumber(Settings.FadeOutMs) or 500))
    if fadeOut > 0 then
        DoScreenFadeOut(fadeOut)
        local expiresAt = GetGameTimer() + fadeOut + 1000
        while not IsScreenFadedOut() and GetGameTimer() < expiresAt do Wait(0) end
    end

    if pedIsDead() then
        Citizen.InvokeNative(RESURRECT_PED, ped)
        ClearPedTasksImmediately(ped)
    end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, tonumber(coords.w) or tonumber(coords.heading) or 0.0)
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, math.max(1, math.min(200, math.floor(tonumber(payload.health) or 100))))
    ClearPedBloodDamage(ped)
    FreezeEntityPosition(ped, true)
    Wait(math.max(0, math.floor(tonumber(Settings.CollisionWaitMs) or 1000)))
    FreezeEntityPosition(ped, false)
    setHudVisible(true)
    DoScreenFadeIn(math.max(0, math.floor(tonumber(Settings.FadeInMs) or 650)))
    TriggerEvent(
        'mscore:client:notify',
        ('Du bist wieder zu Bewusstsein gekommen und wachst in %s auf.'):format(
            tostring(payload.city or 'der nächsten Stadt')
        )
    )
end)

RegisterNetEvent('ms_medic:client:restoreHealth', function()
    stopUnconsciousScreen('revived', true)
end)

RegisterNetEvent('ms_permadeath:client:startFinale', function()
    SuppressReports = true
    stopUnconsciousScreen('permadeath', false)
end)

RegisterNetEvent('ms_permadeath:client:finalized', function()
    SuppressReports = true
    stopUnconsciousScreen('permadeath', false)
end)

RegisterNetEvent('ms_medic:client:emergencyCall', function(payload)
    if type(payload) ~= 'table' or type(payload.coords) ~= 'table' then return end
    local incidentId = tostring(payload.incidentId or '')
    local x = tonumber(payload.coords.x)
    local y = tonumber(payload.coords.y)
    local z = tonumber(payload.coords.z)
    if incidentId == '' or not x or not y or not z then return end
    removeEmergencyBlip(incidentId)

    local settings = type(Settings.EmergencyBlip) == 'table' and Settings.EmergencyBlip or {}
    local style = GetHashKey(tostring(settings.Style or 'BLIP_STYLE_CREATOR_DEFAULT'))
    local point = createBlip(BLIP_ADD_FOR_COORD, style, x, y, z)
    local radius = math.max(1.0, tonumber(payload.radius) or 15.0)
    local area = createBlip(BLIP_ADD_FOR_RADIUS, style, x, y, z, radius)
    local label = ('Notruf: %s (ID %d)'):format(
        tostring(payload.patientName or 'Patient'),
        tonumber(payload.patientSource) or 0
    )
    configureBlip(point, tostring(settings.Sprite or 'blip_ambient_doctor'), label, tonumber(settings.Scale) or 0.9)
    configureBlip(area, tostring(settings.RadiusSprite or 'blip_mission_area_bounty'), label, 1.0)

    EmergencyBlips[incidentId] = {
        point = point,
        radius = area,
        expiresAt = GetGameTimer()
            + math.max(1, math.floor(tonumber(payload.remainingSeconds) or 1200)) * 1000
    }
end)

RegisterNetEvent('ms_medic:client:emergencyResolved', function(incidentId)
    removeEmergencyBlip(incidentId)
end)

RegisterNetEvent('ms_medic:client:clearEmergencyCalls', clearEmergencyBlips)

RegisterNUICallback('emergency', function(_, callback)
    if not UnconsciousActive or EmergencyRequested then
        return callback({ ok = false })
    end
    EmergencyRequested = true
    TriggerServerEvent('ms_medic:server:emergencyCall')
    callback({ ok = true })
end)

AddEventHandler('baseevents:onPlayerDied', function()
    if Settings.Enabled == true and playerLoaded() and not SuppressReports then
        LastReportAt = GetGameTimer()
        TriggerServerEvent('ms_medic:server:reportUnconscious')
    end
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    if Settings.Enabled == true and playerLoaded() and not SuppressReports then
        LastReportAt = GetGameTimer()
        TriggerServerEvent('ms_medic:server:reportUnconscious')
    end
end)

CreateThread(function()
    while true do
        local wait = math.max(100, math.floor(tonumber(Settings.ClientCheckIntervalMs) or 250))
        if Settings.Enabled == true and playerLoaded() then
            if pedIsDead() then
                local now = GetGameTimer()
                local reportInterval = math.max(
                    1000,
                    math.floor(tonumber(Settings.ReportIntervalMs) or 2000)
                )
                if not UnconsciousActive
                    and not SuppressReports
                    and now - LastReportAt >= reportInterval
                then
                    LastReportAt = now
                    TriggerServerEvent('ms_medic:server:reportUnconscious')
                end
            else
                SuppressReports = false
                if UnconsciousActive then
                    stopUnconsciousScreen('conscious', true)
                    TriggerServerEvent('ms_medic:server:reportConscious')
                end
            end
        else
            SuppressReports = false
            LastReportAt = -1000000
            if UnconsciousActive then stopUnconsciousScreen('logout', true) end
        end
        Wait(wait)
    end
end)

CreateThread(function()
    while true do
        if UnconsciousActive then
            DisableAllControlActions(0)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while true do
        local now = GetGameTimer()
        local expired = {}
        for incidentId, entry in pairs(EmergencyBlips) do
            if now >= entry.expiresAt then expired[#expired + 1] = incidentId end
        end
        for _, incidentId in ipairs(expired) do removeEmergencyBlip(incidentId) end
        Wait(1000)
    end
end)

AddEventHandler('mscore:client:prepareLogout', function()
    SuppressReports = false
    LastReportAt = -1000000
    stopUnconsciousScreen('logout', true)
    clearEmergencyBlips()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopUnconsciousScreen('resource_stop', true)
    clearEmergencyBlips()
end)

function GetUnconsciousState()
    return UnconsciousState
end

function IsUnconscious()
    return UnconsciousActive
end

exports('GetUnconsciousState', GetUnconsciousState)
exports('IsUnconscious', IsUnconscious)
