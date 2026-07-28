MSBossMenuConfig = {}

MSBossMenuConfig.InteractionKey = 'E'
MSBossMenuConfig.InteractionDistance = 2.0
MSBossMenuConfig.ServerInteractionDistance = 5.0
MSBossMenuConfig.DrawDistance = 18.0
MSBossMenuConfig.HireDistance = 5.0
MSBossMenuConfig.SessionDurationMs = 15 * 60 * 1000
MSBossMenuConfig.ActionCooldownMs = 800
MSBossMenuConfig.RequireUnemployedForHire = true
MSBossMenuConfig.UnemployedJob = 'unemployed'
MSBossMenuConfig.UnemployedGrade = 0
MSBossMenuConfig.AllowSelfFire = false
MSBossMenuConfig.AllowManageSameGrade = false
MSBossMenuConfig.EmployeeLimit = 200
MSBossMenuConfig.Debug = false

MSBossMenuConfig.Marker = {
    Enabled = true,
    Type = -1795314153,
    Scale = vector3(0.45, 0.45, 0.28),
    Color = { r = 199, g = 154, b = 75, a = 175 },
    HeightOffset = 0.12
}

-- Für einen Job können beliebig viele Dienst- und Boss-Punkte eingetragen werden.
-- Alle Spieler ab dutyGrade können sich dort zum Dienst melden.
-- Verwaltungsfunktionen bleiben Spielern ab bossGrade vorbehalten.
MSBossMenuConfig.Jobs = {
    sheriff = {
        label = 'Sheriff Office',
        dutyGrade = 0,
        bossGrade = 1,
        hireGrade = 0,
        points = {
            {
                label = 'Valentine Sheriff Office',
                coords = vector3(-278.17, 814.88, 119.28)
            }
        }
    },
    law = {
        label = 'Law',
        dutyGrade = 0,
        bossGrade = 1,
        hireGrade = 0,
        points = {
            {
                label = 'Blackwater Sheriff Office',
                coords = vector3(-752.53, -1266.10, 43.43)
            }
        }
    },
    medic = {
        label = 'Medic',
        dutyGrade = 0,
        bossGrade = 2,
        hireGrade = 0,
        points = {
            {
                label = 'Saint Denis Praxis',
                coords = vector3(2721.29, -1233.11, 50.37)
            }
        }
    }
}
