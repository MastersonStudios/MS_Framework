MSPermadeathConfig = {}

MSPermadeathConfig.Enabled = true

-- Bei jedem serverseitig bestätigten Tod steigt das Risiko zufällig um
-- einen ganzzahligen Prozentpunkt innerhalb dieses Bereichs.
MSPermadeathConfig.IncreaseMin = 1
MSPermadeathConfig.IncreaseMax = 3
MSPermadeathConfig.ThresholdPercent = 60

-- false bedeutet: Erst 61 % löst bei einem Schwellwert von 60 % aus.
MSPermadeathConfig.TriggerAtOrAbove = false

-- Schutz vor doppelten optionalen Death-Events und der eigenen RedM-Prüfung.
MSPermadeathConfig.DeathReportCooldownSeconds = 20
MSPermadeathConfig.ClientAliveResetMs = 3000
MSPermadeathConfig.ClientPollIntervalMs = 500
MSPermadeathConfig.ServerDeathHealth = 0

MSPermadeathConfig.PlayerRiskCommand = 'deathrisk'
MSPermadeathConfig.AdminCommand = 'permadeath'
MSPermadeathConfig.AdminAce = 'mscore.admin.permadeath'

MSPermadeathConfig.Finale = {
    ServerTimeoutMs = 90000,
    Title = 'Das Ende eines Weges',
    Subtitle = 'Die aufgehende Sonne begleitet deinen letzten Atemzug.',

    -- Story-Cutscenes sind vom verwendeten RDR2-Build und dessen Assets
    -- abhängig. Ist Name leer oder das Asset nicht ladbar, wird automatisch
    -- die zuverlässige geskriptete Sonnenaufgangsszene verwendet.
    NativeCutscene = {
        Enabled = true,
        Name = '',
        LoadTimeoutMs = 6000,
        MaximumDurationMs = 65000
    },

    Fallback = {
        FadeOutMs = 800,
        FadeInMs = 900,
        EndingHoldMs = 1800,
        Shots = {
            {
                from = { x = -4.4, y = -5.5, z = 2.7 },
                to = { x = -2.7, y = -3.8, z = 1.8 },
                lookZ = 0.55,
                durationMs = 5500,
                caption = 'Jeder Weg findet einmal sein Ende.'
            },
            {
                from = { x = 4.0, y = -2.2, z = 1.8 },
                to = { x = 2.7, y = -1.5, z = 1.35 },
                lookZ = 0.45,
                durationMs = 5000,
                caption = 'Was bleibt, sind die Spuren, die du hinterlassen hast.'
            },
            {
                from = { x = 0.2, y = -5.8, z = 3.6 },
                to = { x = 0.0, y = -4.3, z = 2.65 },
                lookZ = 0.35,
                durationMs = 6500,
                caption = 'Ein letzter Blick in das Licht.'
            }
        }
    }
}
