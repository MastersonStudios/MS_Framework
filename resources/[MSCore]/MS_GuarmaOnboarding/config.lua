GuarmaConfig = {}

GuarmaConfig.Enabled = true
GuarmaConfig.AdminPermission = 'mscore.admin.guarma'
GuarmaConfig.AdminMenuCommand = 'guarmaadmin'
GuarmaConfig.ResetCommand = 'guarmareset'
GuarmaConfig.StartDelay = 1800
GuarmaConfig.FadeTimeoutMs = 3000
GuarmaConfig.StreamingTimeoutMs = 8000
GuarmaConfig.NuiReadyTimeoutMs = 1500
GuarmaConfig.NotifyAdmins = true
GuarmaConfig.CompletionRadius = 10.0

GuarmaConfig.BeachSpawn = vector4(1261.82, -6905.09, 49.06, 4.0)
GuarmaConfig.Port = vector4(1267.03, -6852.97, 43.31, 36.85)
GuarmaConfig.IslandBounds = {
    minX = 0.0,
    maxX = 2500.0,
    minY = -8000.0,
    maxY = -5000.0
}

GuarmaConfig.CinematicCameras = {
    {
        from = vector3(1120.0, -7035.0, 67.0),
        to = vector3(1190.0, -6980.0, 54.0),
        lookAt = vector3(1245.0, -6920.0, 45.0),
        duration = 5500,
        title = 'DER STURM',
        text = 'Der Ozean kennt weder Gnade noch Namen.'
    },
    {
        from = vector3(1190.0, -6980.0, 54.0),
        to = vector3(1230.0, -6940.0, 48.0),
        lookAt = vector3(1261.82, -6905.09, 49.06),
        duration = 6000,
        title = 'SCHIFFBRUCH',
        text = 'Holz zerbricht. Die See verschlingt alles.'
    },
    {
        from = vector3(1230.0, -6940.0, 48.0),
        to = vector3(1252.0, -6917.0, 51.0),
        lookAt = vector3(1261.82, -6905.09, 49.06),
        duration = 5000,
        title = 'GUARMA',
        text = 'Doch der Morgen findet einen Überlebenden.'
    }
}

GuarmaConfig.TutorialSteps = {
    {
        id = 'walk',
        title = 'Erste Schritte',
        text = 'Bewege dich mit W nach vorn.',
        key = 'W',
        input = 'walk',
        coords = vector3(1261.9, -6892.0, 47.5),
        radius = 3.0
    },
    {
        id = 'sprint',
        title = 'Schneller voran',
        text = 'Halte Shift und sprinte zum nächsten Punkt.',
        key = 'SHIFT',
        input = 'sprint',
        coords = vector3(1263.0, -6879.0, 45.8),
        radius = 3.0
    },
    {
        id = 'jump',
        title = 'Hindernisse',
        text = 'Springe mit der Leertaste und folge dem Pfad.',
        key = 'LEERTASTE',
        input = 'jump',
        coords = vector3(1264.2, -6868.0, 44.4),
        radius = 3.0
    },
    {
        id = 'crouch',
        title = 'In Deckung',
        text = 'Drücke Strg, um dich zu ducken.',
        key = 'STRG',
        input = 'crouch',
        coords = vector3(1265.2, -6860.0, 43.8),
        radius = 3.0
    },
    {
        id = 'port',
        title = 'Der Hafen',
        text = 'Erreiche den Hafen und beginne dein neues Leben.',
        key = 'ZIEL',
        coords = vector3(1267.03, -6852.97, 43.31),
        radius = 4.0
    }
}

-- Alle Ziele sind frei editierbar. Das Adminmenü verwendet nur diese IDs.
GuarmaConfig.AdminLocations = {
    { id = 'beach', label = 'Bahia de la Paz – Strand', coords = vector4(1261.82, -6905.09, 49.06, 4.0) },
    { id = 'port', label = 'Guarma – Hafen', coords = vector4(1267.03, -6852.97, 43.31, 36.85) },
    { id = 'cinco', label = 'Cinco Torres', coords = vector4(999.91, -6749.74, 63.12, 78.0) },
    { id = 'mansion', label = 'Guarma – Anwesen', coords = vector4(1464.29, -7108.62, 81.59, 190.0) },
    { id = 'elnido', label = 'El Nido', coords = vector4(1765.19, -5960.06, 64.96, 120.0) }
}
