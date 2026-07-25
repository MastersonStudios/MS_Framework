Config = {}

Config.Debug = false
Config.VersionCheck = {
    Enabled = true,
    Url = 'https://raw.githubusercontent.com/MastersonStudios/MS_Framework/main/version.json',
    RepositoryUrl = 'https://github.com/MastersonStudios/MS_Framework',
    DelayMs = 2500,
    MinimumIntervalMinutes = 10,
    AdminAce = 'frontier.version.check'
}
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
    },
    tailor_hat_male = {
        label = 'Klassischer Filzhut',
        description = 'Ein sauber gearbeiteter Filzhut aus der Herrenkollektion.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 420,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'hat', componentHash = 0xC2F59087, sex = 'male' }
    },
    tailor_hat_female = {
        label = 'Damen-Reisehut',
        description = 'Ein eleganter und wetterfester Reisehut.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 380,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'hat', componentHash = 0x00349628, sex = 'female' }
    },
    tailor_shirt_male = {
        label = 'Baumwollhemd',
        description = 'Ein ordentliches Baumwollhemd für Arbeit und Stadt.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 620,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'shirt', componentHash = 0x9CDC866A, sex = 'male' }
    },
    tailor_shirt_female = {
        label = 'Baumwollbluse',
        description = 'Eine fein vernähte Bluse aus weicher Baumwolle.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 560,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'shirt', componentHash = 0x004869A5, sex = 'female' }
    },
    tailor_coat_male = {
        label = 'Stadtmantel',
        description = 'Ein langer Herrenmantel mit kräftigem Innenfutter.',
        category = 'clothing',
        rarity = 'uncommon',
        maxStack = 1,
        weight = 1650,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'coat', componentHash = 0x13BD3752, sex = 'male' }
    },
    tailor_coat_female = {
        label = 'Damen-Reisemantel',
        description = 'Ein warmer Reisemantel mit klassischem Schnitt.',
        category = 'clothing',
        rarity = 'uncommon',
        maxStack = 1,
        weight = 1480,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'coat', componentHash = 0x007F6FBD, sex = 'female' }
    },
    tailor_pants_male = {
        label = 'Stadthose',
        description = 'Eine robuste Hose mit sauberem, geradem Schnitt.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 820,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'pants', componentHash = 0xD00D4014, sex = 'male' }
    },
    tailor_pants_female = {
        label = 'Damen-Reithose',
        description = 'Eine bequeme Hose für Reise und Ausritt.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 760,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'pants', componentHash = 0x0113B76C, sex = 'female' }
    },
    tailor_boots_male = {
        label = 'Polierte Lederstiefel',
        description = 'Feste Lederstiefel mit polierter Oberfläche.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 1160,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'boots', componentHash = 0x38B4CA64, sex = 'male' }
    },
    tailor_boots_female = {
        label = 'Damen-Schnürstiefel',
        description = 'Feine Schnürstiefel aus widerstandsfähigem Leder.',
        category = 'clothing',
        rarity = 'common',
        maxStack = 1,
        weight = 1020,
        usable = false,
        consumable = false,
        unique = true,
        tradable = true,
        metadata = { clothingSlot = 'boots', componentHash = 0x019ADA9E, sex = 'female' }
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
