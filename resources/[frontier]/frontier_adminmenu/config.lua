AdminMenuConfig = {}

AdminMenuConfig.Permission = 'frontier.admin.menu'
AdminMenuConfig.Command = 'acp'
AdminMenuConfig.CommandAliases = { 'adminmenu' }
AdminMenuConfig.DefaultKey = 'F2'
AdminMenuConfig.MaxMoneyGrant = 100000
AdminMenuConfig.MaxItemGrant = 50
AdminMenuConfig.MaxKickReasonLength = 120
AdminMenuConfig.DefaultWeather = 'sunny'
AdminMenuConfig.DefaultTransition = 8.0
AdminMenuConfig.MaxWeatherTransition = 30.0
AdminMenuConfig.MaxCraftingDefinitions = 500
AdminMenuConfig.MaxCraftingIngredients = 8
AdminMenuConfig.MaxCraftingAmount = 100
AdminMenuConfig.MaxCraftingDuration = 30000
AdminMenuConfig.DefaultCraftingRadius = 2.0
AdminMenuConfig.MaxPlacementDistance = 12.0
AdminMenuConfig.CraftingInteractionKey = 'E'

AdminMenuConfig.Permissions = {
    {
        id = 'access',
        label = 'ACP-Zugriff',
        description = 'Darf das Administrations-Control-Panel öffnen.'
    },
    {
        id = 'players',
        label = 'Spielerverwaltung',
        description = 'Teleport, Heilen, Wiederbeleben, Einfrieren, Kick und Noclip.'
    },
    {
        id = 'economy',
        label = 'Wirtschaft',
        description = 'Darf Geld und Items vergeben.'
    },
    {
        id = 'weather',
        label = 'Wetter',
        description = 'Darf das globale Wetter konfigurieren.'
    },
    {
        id = 'world',
        label = 'World Builder',
        description = 'Darf NPCs, Storages und Türen verwalten.'
    },
    {
        id = 'crafting',
        label = 'Crafting',
        description = 'Darf Rezepte und Crafting-Punkte verwalten.'
    },
    {
        id = 'rights',
        label = 'Rechteverwaltung',
        description = 'Darf ACP-Rechte an andere Spieler vergeben und entziehen.'
    }
}

AdminMenuConfig.GuarmaBounds = {
    minX = 0.0,
    maxX = 2500.0,
    minY = -8000.0,
    maxY = -5000.0
}

AdminMenuConfig.Weathers = {
    {
        id = 'sunny',
        label = 'Sonnig',
        description = 'Klarer Himmel und warmes Licht.',
        hash = 0x614A1F91
    },
    {
        id = 'overcast',
        label = 'Bewölkt',
        description = 'Dichte Wolkendecke ohne Gewitter.',
        hash = 0xBB898D2D
    },
    {
        id = 'fog',
        label = 'Nebel',
        description = 'Starker Bodennebel mit geringer Sicht.',
        hash = 0xD61BDE01
    },
    {
        id = 'thunderstorm',
        label = 'Gewitter',
        description = 'Starkregen, Wind, Donner und Blitze.',
        hash = 0x7C1C4A13
    },
    {
        id = 'snow',
        label = 'Schnee',
        description = 'Winterliches Wetter mit Schneefall.',
        hash = 0xEFB6EFF6
    }
}
