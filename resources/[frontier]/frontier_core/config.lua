Config = {}

Config.Debug = false
Config.AutoCreateCharacter = false
Config.MaxCharacters = 3
Config.CharacterBirthDateMin = '1800-01-01'
Config.CharacterBirthDateMax = '1905-12-31'
Config.DefaultCharacter = {
    firstname = 'New',
    lastname = 'Citizen',
    sex = 'male',
    cash = 50,
    bank = 250,
    job = 'unemployed',
    jobGrade = 0,
    group = 'user'
}

Config.Spawn = vector4(-275.14, 805.09, 119.38, 282.0)
Config.SaveInterval = 60 * 1000
Config.IdentifierType = 'license'
Config.MaxItemStack = 100
Config.Inventory = {
    -- Anzahl der verfügbaren Stack-Plätze im Spielerinventar.
    Slots = 30,
    -- Maximales Gesamtgewicht in Gramm.
    MaxWeight = 30000
}

Config.Items = {
    water = {
        label = 'Wasserflasche',
        description = 'Sauberes Trinkwasser.',
        category = 'drink',
        rarity = 'common',
        maxStack = 20,
        weight = 500,
        usable = true,
        consumable = true,
        tradable = true,
        prop = 'p_canteen01x'
    },
    bread = {
        label = 'Brot',
        description = 'Ein einfacher Reiseproviant.',
        category = 'food',
        rarity = 'common',
        maxStack = 20,
        weight = 300,
        usable = true,
        consumable = true,
        tradable = true,
        prop = 'p_bread_06x'
    },
    bandage = {
        label = 'Verband',
        description = 'Medizinischer Verband zur Wundversorgung.',
        category = 'medical',
        rarity = 'common',
        maxStack = 10,
        weight = 120,
        usable = true,
        consumable = true,
        tradable = true,
        prop = 'p_cs_bandage01x'
    },
    lockpick = {
        label = 'Dietrich',
        description = 'Ein empfindliches Werkzeug für Schlösser.',
        category = 'tool',
        rarity = 'uncommon',
        maxStack = 10,
        weight = 50,
        usable = true,
        consumable = false,
        tradable = true,
        prop = 'p_lockpick01x'
    },
    felt_hat = {
        label = 'Filzhut',
        description = 'Ein schlichter Hut für Reisende.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 450,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'hat' }
    },
    work_shirt = {
        label = 'Arbeitshemd',
        description = 'Robustes Hemd für lange Arbeitstage.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 700,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'shirt' }
    },
    duster_coat = {
        label = 'Staubmantel',
        description = 'Langer Mantel gegen Staub und schlechtes Wetter.',
        category = 'clothing',
        rarity = 'uncommon',
        maxStack = 1,
        weight = 1800,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'coat' }
    },
    ranch_pants = {
        label = 'Ranchhose',
        description = 'Strapazierfähige Hose für Reiter und Rancher.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 900,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'pants' }
    },
    worn_boots = {
        label = 'Reitstiefel',
        description = 'Eingetragene Lederstiefel mit festem Absatz.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 1200,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'boots' }
    }
}

Config.Jobs = {
    unemployed = {
        label = 'Arbeitslos',
        grades = {
            [0] = { label = 'Bürger', salary = 0 }
        }
    },
    sheriff = {
        label = 'Sheriff',
        grades = {
            [0] = { label = 'Deputy', salary = 5 },
            [1] = { label = 'Sheriff', salary = 10 }
        }
    }
}
