local Config = MSHUDConfig
local CharacterId = nil
local Needs = nil
local Status = nil
local UserVisible = true
local HudVisible = false
local CurrentWeather = Config.Temperature.DefaultWeather or 'sunny'
local CachedTemperature = nil
local NextTemperatureUpdate = 0

local function debugLog(message, ...)
    if Config.Debug ~= true then return end
    print(('[MS_HUD] ' .. message):format(...))
end

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

local function configureHud()
    local layout = type(Config.Layout) == 'table' and Config.Layout or {}
    SendNUIMessage({
        action = 'configure',
        config = {
            position = layout.Position or 'bottom-right',
            offsetX = tonumber(layout.OffsetX) or 32,
            offsetY = tonumber(layout.OffsetY) or 36,
            scale = tonumber(layout.Scale) or 1.0,
            orientation = layout.Orientation or 'horizontal',
            showLabels = layout.ShowLabels ~= false,
            showValues = layout.ShowValues ~= false,
            labels = {
                health = Config.Health.Label or 'Gesundheit',
                hunger = Config.Needs.HungerLabel or 'Hunger',
                thirst = Config.Needs.ThirstLabel or 'Durst',
                temperature = Config.Temperature.Label or 'Temperatur'
            }
        }
    })
end

local function setUiVisible(visible)
    visible = visible == true
    if HudVisible == visible then return end
    HudVisible = visible
    SendNUIMessage({ action = 'visibility', visible = visible })
end

local function resetHud()
    CharacterId = nil
    Needs = nil
    Status = nil
    CachedTemperature = nil
    setUiVisible(false)
    SendNUIMessage({ action = 'reset' })
end

local function loadNeeds()
    if GetResourceState('MS_BasicNeeds') ~= 'started' then return end
    local success, data = pcall(function()
        return exports.MS_BasicNeeds:GetNeeds()
    end)
    if success and type(data) == 'table' then Needs = data end
end

local function zoneTemperature(coords)
    local temperature = tonumber(Config.Temperature.DefaultCelsius) or 18.0
    local bestRatio = math.huge
    for _, zone in ipairs(Config.Temperature.Zones or {}) do
        local center = zone.center
        local radius = math.max(1.0, tonumber(zone.radius) or 1.0)
        if center then
            local dx, dy = coords.x - center.x, coords.y - center.y
            local distance = math.sqrt(dx * dx + dy * dy)
            local ratio = distance / radius
            if ratio <= 1.0 and ratio < bestRatio then
                bestRatio = ratio
                temperature = tonumber(zone.baseCelsius) or temperature
            end
        end
    end
    return temperature
end

local function timeModifier(hour)
    hour = math.floor(tonumber(hour) or 12) % 24
    for _, period in ipairs(Config.Temperature.DayCycle or {}) do
        local from = math.floor(tonumber(period.from) or 0) % 24
        local to = math.floor(tonumber(period.to) or 0) % 25
        local matches = from < to and hour >= from and hour < to
            or from > to and (hour >= from or hour < to)
        if matches then return tonumber(period.modifier) or 0.0 end
    end
    return 0.0
end

local function ambientTemperature(ped)
    local temperatureConfig = type(Config.Temperature) == 'table' and Config.Temperature or {}
    local coords = GetEntityCoords(ped)
    local celsius = zoneTemperature(coords)
    celsius = celsius + timeModifier(GetClockHours())
    celsius = celsius + (
        tonumber((temperatureConfig.WeatherModifiers or {})[CurrentWeather]) or 0.0
    )

    local altitude = type(temperatureConfig.Altitude) == 'table' and temperatureConfig.Altitude or {}
    local startZ = tonumber(altitude.StartZ) or 150.0
    if altitude.Enabled == true and coords.z > startZ then
        local steps = (coords.z - startZ) / 100.0
        celsius = celsius + steps * (tonumber(altitude.DegreesPer100Meters) or -0.65)
    end

    if IsEntityInWater and IsEntityInWater(ped) then
        celsius = celsius + (tonumber(temperatureConfig.WaterModifier) or 0.0)
    end

    local minimum = tonumber(temperatureConfig.MinimumCelsius) or -20.0
    local maximum = tonumber(temperatureConfig.MaximumCelsius) or 45.0
    celsius = clamp(celsius, minimum, maximum)
    return math.floor(celsius * 10 + 0.5) / 10
end

local function temperatureView(celsius)
    local config = Config.Temperature
    local fahrenheit = celsius * 9.0 / 5.0 + 32.0
    local useFahrenheit = tostring(config.Unit or 'C'):upper() == 'F'
    local value = useFahrenheit and fahrenheit or celsius
    local minimum = useFahrenheit
        and ((tonumber(config.MinimumCelsius) or -20.0) * 9.0 / 5.0 + 32.0)
        or (tonumber(config.MinimumCelsius) or -20.0)
    local maximum = useFahrenheit
        and ((tonumber(config.MaximumCelsius) or 45.0) * 9.0 / 5.0 + 32.0)
        or (tonumber(config.MaximumCelsius) or 45.0)

    return {
        value = math.floor(value * 10 + 0.5) / 10,
        celsius = celsius,
        unit = useFahrenheit and '°F' or '°C',
        minimum = minimum,
        maximum = maximum,
        cold = celsius <= (tonumber(config.ColdThresholdCelsius) or 5.0),
        hot = celsius >= (tonumber(config.HotThresholdCelsius) or 32.0),
        weather = CurrentWeather
    }
end

local function healthView(ped)
    local maximum = tonumber(GetEntityMaxHealth(ped)) or 0
    if maximum < 1 then maximum = tonumber(Config.Health.FallbackMaximum) or 200 end
    local current = clamp(GetEntityHealth(ped), 0, maximum)
    return {
        value = current,
        maximum = maximum,
        percent = maximum > 0 and current / maximum * 100.0 or 0.0,
        criticalThreshold = tonumber(Config.Health.CriticalThreshold) or 25.0
    }
end

local function needsView()
    local config = Config.Needs
    local minimum = Needs and tonumber(Needs.minimum) or tonumber(config.FallbackMinimum) or 0.0
    local maximum = Needs and tonumber(Needs.maximum) or tonumber(config.FallbackMaximum) or 100.0
    if maximum <= minimum then maximum = minimum + 100.0 end
    return {
        hunger = clamp(Needs and Needs.hunger or maximum, minimum, maximum),
        thirst = clamp(Needs and Needs.thirst or maximum, minimum, maximum),
        minimum = minimum,
        maximum = maximum,
        criticalThreshold = Needs and tonumber(Needs.criticalThreshold)
            or tonumber(config.FallbackCriticalThreshold)
            or 20.0
    }
end

local function updateStatus()
    local ped = PlayerPedId()
    if ped == 0 then return end
    local now = GetGameTimer()
    if not CachedTemperature or now >= NextTemperatureUpdate then
        CachedTemperature = ambientTemperature(ped)
        NextTemperatureUpdate = now + math.max(
            1000,
            math.floor(tonumber(Config.Temperature.UpdateIntervalMs) or 5000)
        )
    end

    Status = {
        health = healthView(ped),
        needs = needsView(),
        temperature = temperatureView(CachedTemperature)
    }
    SendNUIMessage({ action = 'update', status = Status })
    TriggerEvent('MS_HUD:client:statusChanged', Status)
end

AddEventHandler('MS_BasicNeeds:client:needsChanged', function(data)
    if type(data) == 'table' then Needs = data end
end)

AddEventHandler('mscore:client:weatherChanged', function(weatherId)
    if type(weatherId) ~= 'string' or weatherId == '' then return end
    CurrentWeather = weatherId
    NextTemperatureUpdate = 0
    debugLog('Wetter geändert: %s', weatherId)
end)

AddEventHandler('mscore:client:playerDataChanged', function(playerData)
    local nextCharacterId = type(playerData) == 'table' and tonumber(playerData.characterId) or nil
    if not nextCharacterId then return resetHud() end
    if nextCharacterId ~= CharacterId then
        CharacterId = nextCharacterId
        loadNeeds()
        NextTemperatureUpdate = 0
    end
end)

AddEventHandler('mscore:client:prepareLogout', resetHud)

CreateThread(function()
    configureHud()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
    Wait(1000)

    local playerData = exports.MSCore:GetPlayerData()
    CharacterId = type(playerData) == 'table' and tonumber(playerData.characterId) or nil
    local weatherState = GlobalState and GlobalState.mscoreWeather
    if type(weatherState) == 'table' and type(weatherState.id) == 'string' then
        CurrentWeather = weatherState.id
    end
    if CharacterId then loadNeeds() end
end)

CreateThread(function()
    while true do
        Wait(math.max(100, math.floor(tonumber(Config.UpdateIntervalMs) or 250)))
        local visible = Config.Enabled == true
            and UserVisible
            and CharacterId ~= nil
            and not (Config.HideInPauseMenu == true and IsPauseMenuActive())
        setUiVisible(visible)
        if visible then updateStatus() end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    setUiVisible(false)
    SendNUIMessage({ action = 'reset' })
end)

function GetHudStatus()
    return Status
end

function SetHudVisible(visible)
    UserVisible = visible == true
    if not UserVisible then setUiVisible(false) end
    return UserVisible
end

function IsHudVisible()
    return HudVisible
end

exports('GetHudStatus', GetHudStatus)
exports('SetHudVisible', SetHudVisible)
exports('IsHudVisible', IsHudVisible)
