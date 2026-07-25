MSHUDConfig = {}

MSHUDConfig.Enabled = true
MSHUDConfig.UpdateIntervalMs = 250
MSHUDConfig.HideInPauseMenu = true

MSHUDConfig.Layout = {
    Position = 'bottom-right', -- bottom-right, bottom-left, top-right, top-left
    OffsetX = 32,
    OffsetY = 36,
    Scale = 1.0,
    Orientation = 'horizontal', -- horizontal oder vertical
    ShowLabels = true,
    ShowValues = true
}

MSHUDConfig.Health = {
    Label = 'Gesundheit',
    CriticalThreshold = 25.0,
    FallbackMaximum = 200
}

MSHUDConfig.Needs = {
    HungerLabel = 'Hunger',
    ThirstLabel = 'Durst',
    FallbackMinimum = 0.0,
    FallbackMaximum = 100.0,
    FallbackCriticalThreshold = 20.0
}

MSHUDConfig.Temperature = {
    Label = 'Temperatur',
    Unit = 'C', -- C oder F
    UpdateIntervalMs = 5000,
    DefaultWeather = 'sunny',
    DefaultCelsius = 18.0,
    MinimumCelsius = -20.0,
    MaximumCelsius = 45.0,
    ColdThresholdCelsius = 5.0,
    HotThresholdCelsius = 32.0,

    -- Änderungen durch das aktuelle, vom ACP synchronisierte Wetter.
    WeatherModifiers = {
        sunny = 3.0,
        overcast = -2.0,
        fog = -3.0,
        thunderstorm = -5.0,
        snow = -12.0
    },

    -- Der erste passende Zeitraum wird verwendet. Zeiträume über Mitternacht
    -- werden unterstützt, beispielsweise 20 bis 6 Uhr.
    DayCycle = {
        { from = 0, to = 6, modifier = -6.0 },
        { from = 6, to = 9, modifier = -2.0 },
        { from = 9, to = 17, modifier = 2.0 },
        { from = 17, to = 20, modifier = 0.0 },
        { from = 20, to = 24, modifier = -3.0 }
    },

    Altitude = {
        Enabled = true,
        StartZ = 150.0,
        DegreesPer100Meters = -0.65
    },

    WaterModifier = -4.0,

    -- Die nächstgelegene passende Zone überschreibt DefaultCelsius.
    Zones = {
        {
            name = 'Guarma',
            center = vector3(1300.0, -7000.0, 20.0),
            radius = 2200.0,
            baseCelsius = 28.0
        },
        {
            name = 'Colter',
            center = vector3(-1350.0, 2400.0, 310.0),
            radius = 1450.0,
            baseCelsius = -3.0
        },
        {
            name = 'Ambarino',
            center = vector3(500.0, 1700.0, 220.0),
            radius = 1850.0,
            baseCelsius = 5.0
        },
        {
            name = 'New Austin',
            center = vector3(-4200.0, -2700.0, 20.0),
            radius = 2300.0,
            baseCelsius = 27.0
        },
        {
            name = 'Bayou Nwa',
            center = vector3(2300.0, -900.0, 45.0),
            radius = 1500.0,
            baseCelsius = 24.0
        },
        {
            name = 'Great Plains',
            center = vector3(-1300.0, -1200.0, 70.0),
            radius = 1700.0,
            baseCelsius = 19.0
        },
        {
            name = 'Heartlands',
            center = vector3(350.0, 250.0, 100.0),
            radius = 1800.0,
            baseCelsius = 18.0
        }
    }
}

MSHUDConfig.Debug = false
