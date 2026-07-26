MSCrimeConfig = {}

MSCrimeConfig.JobName = 'crime'
MSCrimeConfig.SearchCommand = 'durchsuchen'
MSCrimeConfig.DefaultKey = 'H'
MSCrimeConfig.SearchDurationMs = 60000
MSCrimeConfig.SearchDistance = 3.0
MSCrimeConfig.LootDistance = 3.5
MSCrimeConfig.LootWindowMs = 120000
MSCrimeConfig.MaxRobAmount = 100
MSCrimeConfig.ActionCooldownMs = 500
MSCrimeConfig.RestraintPollMs = 500
MSCrimeConfig.RestraintStateMaxAgeMs = 2500
MSCrimeConfig.Debug = false

-- Zusätzliche Fesselscripts können einen dieser LocalPlayer-State-Bag-Schlüssel
-- setzen oder serverseitig den Export SetRestrained verwenden.
MSCrimeConfig.RestraintStateKeys = {
    'ms_crime_restrained',
    'restrained',
    'isRestrained',
    'cuffed',
    'isCuffed',
    'hogtied',
    'isHogtied'
}

MSCrimeConfig.VanHorn = {
    Enabled = true,
    Label = 'Van Horn – Crime-Stadt',
    Center = vector3(2981.65, 561.72, 44.85),
    Radius = 235.0,
    CheckIntervalMs = 750,
    AllowedJobs = {
        crime = true,
        medic = true
    },
    Warning = 'Du betrittst Van Horn ohne Erlaubnis. Bewaffnete Wachen greifen an!',
    ModelLoadTimeoutMs = 10000,
    RespawnCooldownMs = 30000,
    GuardAccuracy = 55,
    GuardHealth = 250,
    GuardArmor = 50,
    GuardModels = {
        'g_m_m_unicriminals_01',
        'g_m_m_unibanditos_01',
        'g_m_m_unimountainmen_01'
    },
    GuardWeapons = {
        'WEAPON_REPEATER_CARBINE',
        'WEAPON_REVOLVER_CATTLEMAN',
        'WEAPON_SHOTGUN_DOUBLEBARREL'
    },
    -- Lokale Abstände zum unberechtigten Spieler. Dadurch erscheinen die
    -- Wachen unabhängig davon, von welcher Seite Van Horn betreten wird.
    GuardOffsets = {
        { x = 18.0, y = 7.0 },
        { x = -16.0, y = 11.0 },
        { x = 5.0, y = -19.0 }
    }
}
