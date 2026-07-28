Config = {}

Config.Debug = false
Config.VersionCheck = {
    Enabled = true,
    Url = 'https://raw.githubusercontent.com/MastersonStudios/MS_Framework/main/version.json',
    RepositoryUrl = 'https://github.com/MastersonStudios/MS_Framework',
    DelayMs = 2500,
    MinimumIntervalMinutes = 10,
    AdminAce = 'mscore.version.check'
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

Config.CharacterCreator = {
    Enabled = true,
    ModelLoadTimeoutMs = 10000,
    CreateCooldownMs = 3000,
    SpawnLoadingMs = 1500,
    Models = {
        male = 'mp_male',
        female = 'mp_female'
    },
    Profile = {
        NicknameMaxLength = 32,
        DescriptionMaxLength = 280,
        BannedNames = {
            'admin',
            'administrator',
            'moderator'
        }
    },
    -- Die Einträge sind absichtlich vollständig konfigurierbar. Komponenten
    -- dürfen als Modellname oder als bereits berechneter Hash angegeben werden.
    AppearanceOptions = {
        head = {
            male = {
                { label = 'Herkunft 01', components = { 'CLOTHING_ITEM_M_HEAD_001_V_001' } },
                { label = 'Herkunft 02', components = { 'CLOTHING_ITEM_M_HEAD_002_V_001' } },
                { label = 'Herkunft 03', components = { 'CLOTHING_ITEM_M_HEAD_003_V_001' } },
                { label = 'Herkunft 04', components = { 'CLOTHING_ITEM_M_HEAD_004_V_001' } },
                { label = 'Herkunft 05', components = { 'CLOTHING_ITEM_M_HEAD_005_V_001' } },
                { label = 'Herkunft 06', components = { 'CLOTHING_ITEM_M_HEAD_006_V_001' } }
            },
            female = {
                { label = 'Herkunft 01', components = { 'CLOTHING_ITEM_F_HEAD_001_V_001' } },
                { label = 'Herkunft 02', components = { 'CLOTHING_ITEM_F_HEAD_002_V_001' } },
                { label = 'Herkunft 03', components = { 'CLOTHING_ITEM_F_HEAD_003_V_001' } },
                { label = 'Herkunft 04', components = { 'CLOTHING_ITEM_F_HEAD_004_V_001' } },
                { label = 'Herkunft 05', components = { 'CLOTHING_ITEM_F_HEAD_005_V_001' } },
                { label = 'Herkunft 06', components = { 'CLOTHING_ITEM_F_HEAD_006_V_001' } }
            }
        },
        body = {
            male = {
                {
                    label = 'Schlank',
                    components = {
                        'CLOTHING_ITEM_M_BODIES_UPPER_001_V_001',
                        'CLOTHING_ITEM_M_BODIES_LOWER_001_V_001'
                    }
                },
                {
                    label = 'Durchschnittlich',
                    components = {
                        'CLOTHING_ITEM_M_BODIES_UPPER_002_V_001',
                        'CLOTHING_ITEM_M_BODIES_LOWER_002_V_001'
                    }
                },
                {
                    label = 'Kräftig',
                    components = {
                        'CLOTHING_ITEM_M_BODIES_UPPER_003_V_001',
                        'CLOTHING_ITEM_M_BODIES_LOWER_003_V_001'
                    }
                }
            },
            female = {
                {
                    label = 'Schlank',
                    components = {
                        'CLOTHING_ITEM_F_BODIES_UPPER_001_V_001',
                        'CLOTHING_ITEM_F_BODIES_LOWER_001_V_001'
                    }
                },
                {
                    label = 'Durchschnittlich',
                    components = {
                        'CLOTHING_ITEM_F_BODIES_UPPER_002_V_001',
                        'CLOTHING_ITEM_F_BODIES_LOWER_002_V_001'
                    }
                },
                {
                    label = 'Kräftig',
                    components = {
                        'CLOTHING_ITEM_F_BODIES_UPPER_003_V_001',
                        'CLOTHING_ITEM_F_BODIES_LOWER_003_V_001'
                    }
                }
            }
        },
        hair = {
            male = {
                { label = 'Kurz', components = { 'CLOTHING_ITEM_M_HAIR_001_BLONDE' } },
                { label = 'Seitenscheitel', components = { 'CLOTHING_ITEM_M_HAIR_002_BLONDE' } },
                { label = 'Mittellang', components = { 'CLOTHING_ITEM_M_HAIR_003_BLONDE' } },
                { label = 'Lang', components = { 'CLOTHING_ITEM_M_HAIR_004_BLONDE' } }
            },
            female = {
                { label = 'Kurz', components = { 'CLOTHING_ITEM_F_HAIR_001_BLONDE' } },
                { label = 'Gebunden', components = { 'CLOTHING_ITEM_F_HAIR_002_BLONDE' } },
                { label = 'Mittellang', components = { 'CLOTHING_ITEM_F_HAIR_003_BLONDE' } },
                { label = 'Lang', components = { 'CLOTHING_ITEM_F_HAIR_004_BLONDE' } }
            }
        },
        beard = {
            male = {
                { label = 'Kein Bart', components = {} },
                { label = 'Kurzer Bart', components = { 'CLOTHING_ITEM_M_BEARD_001_BLONDE' } },
                { label = 'Vollbart', components = { 'CLOTHING_ITEM_M_BEARD_002_BLONDE' } },
                { label = 'Langer Bart', components = { 'CLOTHING_ITEM_M_BEARD_003_BLONDE' } }
            },
            female = {
                { label = 'Nicht verfügbar', components = {} }
            }
        },
        eyes = {
            male = {
                { label = 'Braun', components = { 'CLOTHING_ITEM_M_EYES_001_TINT_001' } },
                { label = 'Grün', components = { 'CLOTHING_ITEM_M_EYES_001_TINT_005' } },
                { label = 'Blau', components = { 'CLOTHING_ITEM_M_EYES_001_TINT_009' } },
                { label = 'Grau', components = { 'CLOTHING_ITEM_M_EYES_001_TINT_014' } }
            },
            female = {
                { label = 'Braun', components = { 'CLOTHING_ITEM_F_EYES_001_TINT_001' } },
                { label = 'Grün', components = { 'CLOTHING_ITEM_F_EYES_001_TINT_005' } },
                { label = 'Blau', components = { 'CLOTHING_ITEM_F_EYES_001_TINT_009' } },
                { label = 'Grau', components = { 'CLOTHING_ITEM_F_EYES_001_TINT_014' } }
            }
        },
        height = {
            male = {
                { label = 'Klein', scale = 0.94 },
                { label = 'Normal', scale = 1.00 },
                { label = 'Groß', scale = 1.04 }
            },
            female = {
                { label = 'Klein', scale = 0.94 },
                { label = 'Normal', scale = 1.00 },
                { label = 'Groß', scale = 1.04 }
            }
        }
    },
    Defaults = {
        head = 1,
        body = 1,
        hair = 1,
        beard = 1,
        eyes = 1,
        height = 2,
        outfit = 'frontier'
    },
    Preview = {
        coords = vector4(-277.65, 803.78, 119.39, 105.0),
        cameraDistance = 2.45,
        cameraHeight = 0.72,
        cameraFov = 38.0,
        minZoom = 1.35,
        maxZoom = 3.20,
        rotationStep = 18.0,
        selectorEnabled = true
    },
    -- Die Presets verwenden die bereits in Config.Items definierten
    -- Bekleidungskomponenten. Item-Namen können hier frei ausgetauscht werden.
    Outfits = {
        work = {
            order = 1,
            label = 'Arbeit',
            description = 'Schlicht, robust und bereit für den ersten Arbeitstag.',
            items = {
                male = { 'tailor_shirt_male', 'tailor_pants_male', 'tailor_boots_male' },
                female = { 'tailor_shirt_female', 'tailor_pants_female', 'tailor_boots_female' }
            }
        },
        traveler = {
            order = 2,
            label = 'Reise',
            description = 'Ein warmer Mantel für lange Wege durch den Westen.',
            items = {
                male = {
                    'tailor_shirt_male', 'tailor_coat_male',
                    'tailor_pants_male', 'tailor_boots_male'
                },
                female = {
                    'tailor_shirt_female', 'tailor_coat_female',
                    'tailor_pants_female', 'tailor_boots_female'
                }
            }
        },
        frontier = {
            order = 3,
            label = 'Frontier',
            description = 'Das vollständige Startoutfit für eine neue Geschichte.',
            items = {
                male = {
                    'tailor_hat_male', 'tailor_shirt_male', 'tailor_coat_male',
                    'tailor_pants_male', 'tailor_boots_male'
                },
                female = {
                    'tailor_hat_female', 'tailor_shirt_female', 'tailor_coat_female',
                    'tailor_pants_female', 'tailor_boots_female'
                }
            }
        }
    }
}

-- Neue Charaktere starten vor dem Bahnhof von Valentine.
Config.Spawn = vector4(-169.47, 629.38, 114.03, 236.72)

-- Charaktere, deren letzte Position noch vom entfernten Guarma-Onboarding
-- stammt, werden beim nächsten Laden einmalig zum neuen Standardspawn versetzt.
Config.LegacySpawnMigration = {
    Enabled = true,
    GuarmaBounds = {
        minX = 0.0,
        maxX = 2500.0,
        minY = -8000.0,
        maxY = -5000.0
    }
}
Config.SaveInterval = 60 * 1000
Config.PaycheckCheckIntervalMs = 30 * 1000
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
    medicine = {
        label = 'Arznei',
        description = 'Eine medizinische Arznei zur Behandlung von Krankheiten.',
        category = 'medical',
        rarity = 'uncommon',
        maxStack = 10,
        weight = 150,
        usable = false,
        consumable = false,
        tradable = true,
        prop = 'p_bottlemedicine01x'
    },
    herbal_tonic = {
        label = 'Kräutertonikum',
        description = 'Ein kräftigendes Tonikum aus Heilkräutern.',
        category = 'medical',
        rarity = 'uncommon',
        maxStack = 10,
        weight = 300,
        usable = false,
        consumable = false,
        tradable = true,
        prop = 'p_bottlemedicine01x'
    },
    revive_kit = {
        label = 'Wiederbelebungsset',
        description = 'Medizinisches Material für eine Wiederbelebung.',
        category = 'medical',
        rarity = 'rare',
        maxStack = 5,
        weight = 1200,
        usable = false,
        consumable = false,
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
        payIntervalMinutes = 60,
        payAccount = 'bank',
        grades = {
            [0] = { label = 'Deputy', salary = 10 },
            [1] = { label = 'Sheriff', salary = 12 }
        }
    },
    medic = {
        label = 'Medic',
        payIntervalMinutes = 60,
        payAccount = 'bank',
        grades = {
            [0] = { label = 'Sanitäter', salary = 8 },
            [1] = { label = 'Arzt', salary = 10 },
            [2] = { label = 'Chefarzt', salary = 15 }
        }
    },
    native = {
        label = 'Native',
        grades = {
            [0] = { label = 'Stammesmitglied', salary = 0 },
            [1] = { label = 'Häuptling', salary = 0 }
        }
    },
    gunsmith = {
        label = 'Büchsenmacher',
        grades = {
            [0] = { label = 'Lehrling', salary = 0 },
            [1] = { label = 'Meister', salary = 0 }
        }
    },
    law = {
        label = 'Law',
        payIntervalMinutes = 60,
        payAccount = 'bank',
        grades = {
            [0] = { label = 'Countysheriff', salary = 12 },
            [1] = { label = 'Marschall', salary = 20 }
        }
    },
    crime = {
        label = 'Crime',
        grades = {
            [0] = { label = 'Krimineller', salary = 0 }
        }
    }
}
