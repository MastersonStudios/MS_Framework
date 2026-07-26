MSRestrictedAreasConfig = {}

MSRestrictedAreasConfig.Debug = false
MSRestrictedAreasConfig.ServerCheckIntervalMs = 750
MSRestrictedAreasConfig.SafePositionIntervalMs = 500
MSRestrictedAreasConfig.ClientGuardIntervalMs = 750
MSRestrictedAreasConfig.ExitBuffer = 6.0
MSRestrictedAreasConfig.FadeDurationMs = 250

-- In vollständig gesperrten Gebieten gilt dieses Verhältnis pro Eindringling:
-- ein Spieler gegen fünf lokal erzeugte Wachen.
MSRestrictedAreasConfig.MexicanGuards = {
    RatioPerIntruder = 5,
    MaxPerPlayer = 10,
    RespawnCooldownMs = 15000,
    ModelLoadTimeoutMs = 10000,
    SpawnRadiusMin = 18.0,
    SpawnRadiusMax = 30.0,
    Accuracy = 55,
    Health = 250,
    Armor = 50,
    Models = {
        'g_m_m_unibanditos_01'
    },
    Weapons = {
        'WEAPON_REPEATER_CARBINE',
        'WEAPON_REVOLVER_CATTLEMAN',
        'WEAPON_SHOTGUN_DOUBLEBARREL'
    }
}

-- Dieses ACE-Recht umgeht Gebietsregeln für Administration und Tests.
-- Auf '' setzen, wenn auch Admins vollständig gesperrte Gebiete nicht betreten dürfen.
MSRestrictedAreasConfig.BypassAce = 'mscore.restrictedareas.bypass'

-- Mode:
--   jobs   = nur die unter AllowedJobs eingetragenen Jobs dürfen hinein.
--   locked = vollständig gesperrt; jeder Eindringling löst mexikanische Wachen aus.
--
-- Shape:
--   circle  = Center und Radius
--   polygon = mindestens drei Points sowie optional MinZ und MaxZ
--
-- AllowedJobs-Regeln:
--   sheriff = true                    jeder Rang
--   law = 1                           mindestens Rang 1
--   medic = { MinGrade = 0, MaxGrade = 2 }
--
-- Die Beispiele sind absichtlich deaktiviert, damit eine Installation nicht
-- ungefragt bestehende Orte sperrt. Koordinaten anpassen und Enabled aktivieren.
MSRestrictedAreasConfig.Zones = {
    {
        Id = 'sheriff_job_area_example',
        Enabled = false,
        Priority = 10,
        Label = 'Sheriff-Dienstbereich',
        Mode = 'jobs',
        Shape = 'circle',
        Center = vector3(-276.25, 805.05, 119.38),
        Radius = 35.0,
        MinZ = 110.0,
        MaxZ = 135.0,
        AllowedJobs = {
            sheriff = true,
            law = 0
        },
        DeniedMessage = 'Dieser Bereich ist nur für Sheriff und Law zugänglich.'
    },
    {
        Id = 'complete_lockdown_example',
        Enabled = false,
        Priority = 100,
        Label = 'Komplettsperrgebiet',
        Mode = 'locked',
        Shape = 'polygon',
        MinZ = -50.0,
        MaxZ = 150.0,
        Points = {
            { x = -4050.0, y = -3660.0 },
            { x = -3700.0, y = -3660.0 },
            { x = -3700.0, y = -3300.0 },
            { x = -4050.0, y = -3300.0 }
        },
        LockedMessage = 'Du betrittst ein vollständig gesperrtes Gebiet!',
        Guards = {
            RatioPerIntruder = 5
        }
    }
}
