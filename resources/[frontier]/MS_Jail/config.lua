MSJailConfig = {}

MSJailConfig.AdminAce = 'frontier.admin.jail'
MSJailConfig.JailCommand = 'jail'
MSJailConfig.UnjailCommand = 'unjail'
MSJailConfig.StatusCommand = 'jailstatus'

MSJailConfig.MinimumSentenceMinutes = 1
MSJailConfig.MaximumSentenceMinutes = 1440
MSJailConfig.MaximumReasonLength = 180
MSJailConfig.DefaultReason = 'Keine Begründung angegeben.'

-- Standardpunkt auf Sisika. Weitere Zellen können ergänzt werden; die Auswahl
-- erfolgt stabil anhand der Charakter-ID.
MSJailConfig.CellSpawns = {
    vector4(3348.683, -638.0975, 44.96677, 87.0)
}

-- Standardmäßige Entlassung in Saint Denis.
MSJailConfig.ReleaseCoords = vector4(2683.063, -1365.809, 47.4687, 90.0)

MSJailConfig.Boundary = {
    Center = vector3(3348.683, -638.0975, 44.96677),
    Radius = 260.0,
    CheckIntervalMs = 2000,
    ReturnCooldownMs = 3500
}

MSJailConfig.Teleport = {
    FadeOutMs = 450,
    CollisionWaitMs = 1000,
    FadeInMs = 600
}

MSJailConfig.Hud = {
    Enabled = true,
    HideInPauseMenu = true,
    Position = 'top-center',
    OffsetY = 28,
    Scale = 1.0
}

MSJailConfig.ClearWantedLevel = true
MSJailConfig.Debug = false
