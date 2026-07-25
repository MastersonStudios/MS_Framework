AdminMenuConfig = {}

AdminMenuConfig.Permission = 'mscore.admin.menu'
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
AdminMenuConfig.MaxItemDefinitions = 2000
AdminMenuConfig.SupportLogLimit = 500
AdminMenuConfig.SupportLogRetentionDays = 30
AdminMenuConfig.SupportLogBatchSize = 50
AdminMenuConfig.SupportLogFlushInterval = 500
AdminMenuConfig.SupportLogQueueLimit = 5000
AdminMenuConfig.SupportLogMinimumDamage = 1
AdminMenuConfig.GhostRefreshIntervalMs = 100

AdminMenuConfig.Permissions = {
    {
        id = 'access',
        label = 'ACP-Zugriff',
        description = 'Darf das Administrations-Control-Panel öffnen.'
    },
    {
        id = 'players',
        label = 'Spielerverwaltung',
        description = 'Teleport, Heilen, Wiederbeleben, Einfrieren, Kick, Ghost Mode und Noclip.'
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
        id = 'data',
        label = 'Data Admin',
        description = 'Darf Datenbank-Items erstellen und löschen.'
    },
    {
        id = 'support',
        label = 'Support Admin',
        description = 'Darf Verbindungs-, Spawn-, Schadens- und Tötungslogs einsehen.'
    },
    {
        id = 'rights',
        label = 'Rechteverwaltung',
        description = 'Darf ACP-Rechte an andere Spieler vergeben und entziehen.'
    }
}

AdminMenuConfig.ItemProps = {
    { label = 'Keine Prop-Zuordnung', model = '', category = 'Allgemein' },
    { label = 'Bierflasche', model = 'p_bottlebeer01x', category = 'Getränke' },
    { label = 'Whiskeyflasche', model = 'p_bottlewhiskey01x', category = 'Getränke' },
    { label = 'Medizinflasche', model = 'p_bottlemedicine01x', category = 'Getränke' },
    { label = 'Wasserkanne', model = 'p_jug01x', category = 'Getränke' },
    { label = 'Kaffeetasse', model = 'p_mugcoffee01x', category = 'Getränke' },
    { label = 'Brotlaib', model = 'p_bread_06x', category = 'Nahrung' },
    { label = 'Konservendose', model = 'p_can01x', category = 'Nahrung' },
    { label = 'Apfel', model = 'p_apple01x', category = 'Nahrung' },
    { label = 'Fleischstück', model = 'p_meat_chunk01x', category = 'Nahrung' },
    { label = 'Verband', model = 'p_cs_bandage01x', category = 'Medizin' },
    { label = 'Medizintasche', model = 'p_medicalbag01x', category = 'Medizin' },
    { label = 'Spritze', model = 'p_syringe01x', category = 'Medizin' },
    { label = 'Buch', model = 'p_book02x', category = 'Dokumente' },
    { label = 'Notizbuch', model = 'p_notebook01x', category = 'Dokumente' },
    { label = 'Brief', model = 'p_cs_letter01x', category = 'Dokumente' },
    { label = 'Zeitung', model = 'p_newspaper01x', category = 'Dokumente' },
    { label = 'Landkarte', model = 'p_map01x', category = 'Dokumente' },
    { label = 'Münze', model = 'p_coin01x', category = 'Wertsachen' },
    { label = 'Geldbündel', model = 'p_moneybag01x', category = 'Wertsachen' },
    { label = 'Goldbarren', model = 'p_goldbar01x', category = 'Wertsachen' },
    { label = 'Ring', model = 'p_ring01x', category = 'Wertsachen' },
    { label = 'Taschenuhr', model = 'p_watch01x', category = 'Wertsachen' },
    { label = 'Hammer', model = 'p_hammer01x', category = 'Werkzeuge' },
    { label = 'Spitzhacke', model = 'p_pickaxe01x', category = 'Werkzeuge' },
    { label = 'Schaufel', model = 'p_shovel01x', category = 'Werkzeuge' },
    { label = 'Axt', model = 'p_axe01x', category = 'Werkzeuge' },
    { label = 'Messer', model = 'p_knife01x', category = 'Werkzeuge' },
    { label = 'Seilrolle', model = 'p_rope01x', category = 'Werkzeuge' },
    { label = 'Werkzeugkasten', model = 'p_toolbox01x', category = 'Werkzeuge' },
    { label = 'Laterne', model = 'p_lantern09x', category = 'Ausrüstung' },
    { label = 'Fernglas', model = 'p_binoculars01x', category = 'Ausrüstung' },
    { label = 'Kompass', model = 'p_compass01x', category = 'Ausrüstung' },
    { label = 'Feldflasche', model = 'p_canteen01x', category = 'Ausrüstung' },
    { label = 'Rucksack', model = 'p_ambpack01x', category = 'Ausrüstung' },
    { label = 'Sattel', model = 'p_saddle01x', category = 'Ausrüstung' },
    { label = 'Zigarette', model = 'p_cigarette01x', category = 'Genussmittel' },
    { label = 'Zigarre', model = 'p_cigar01x', category = 'Genussmittel' },
    { label = 'Pfeife', model = 'p_pipe01x', category = 'Genussmittel' },
    { label = 'Kartenspiel', model = 'p_cards01x', category = 'Genussmittel' },
    { label = 'Holzkiste', model = 'p_crate03x', category = 'Weltobjekte' },
    { label = 'Fass', model = 'p_barrel01x', category = 'Weltobjekte' },
    { label = 'Stuhl', model = 'p_chair02x', category = 'Weltobjekte' },
    { label = 'Tisch', model = 'p_table02x', category = 'Weltobjekte' },
    { label = 'Lagerfeuer', model = 'p_campfire01x', category = 'Weltobjekte' },
    { label = 'Heuballen', model = 'p_haybale03x', category = 'Weltobjekte' },
    { label = 'Sack', model = 'p_sack03x', category = 'Weltobjekte' },
    { label = 'Eimer', model = 'p_bucket01x', category = 'Weltobjekte' }
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
