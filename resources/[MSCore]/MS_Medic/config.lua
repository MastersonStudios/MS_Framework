MSMedicConfig = {}

MSMedicConfig.MedicCommand = 'medic'
MSMedicConfig.HealthCommand = 'healthstatus'
MSMedicConfig.AdminDiseaseCommand = 'medicdisease'
MSMedicConfig.DefaultKey = 'F6'
MSMedicConfig.AdminAce = 'mscore.admin'

MSMedicConfig.MedicJobs = {
    medic = 0
}

MSMedicConfig.Unconscious = {
    Enabled = true,
    InitialSeconds = 10 * 60,
    EmergencySeconds = 20 * 60,
    EmergencyRadius = 15.0,
    ServerCheckIntervalMs = 1000,
    ClientCheckIntervalMs = 250,
    ReportIntervalMs = 2000,
    DetectionDelayMs = 1500,
    SyncIntervalSeconds = 30,
    WakeHealth = 100,
    RespectJail = true,
    FadeOutMs = 500,
    CollisionWaitMs = 1000,
    FadeInMs = 650,
    EmergencyBlip = {
        Style = 'BLIP_STYLE_CREATOR_DEFAULT',
        Sprite = 'blip_ambient_doctor',
        RadiusSprite = 'blip_mission_area_bounty',
        Scale = 0.9
    },
    RespawnCities = {
        {
            label = 'Valentine',
            coords = vector4(-280.47, 806.17, 119.38, 100.0)
        },
        {
            label = 'Blackwater',
            coords = vector4(-876.89, -1332.38, 43.96, 180.0)
        },
        {
            label = 'Rhodes',
            coords = vector4(1232.78, -1305.29, 76.90, 240.0)
        },
        {
            label = 'Saint Denis',
            coords = vector4(2683.06, -1365.81, 47.47, 90.0)
        },
        {
            label = 'Strawberry',
            coords = vector4(-1801.75, -374.64, 161.15, 150.0)
        },
        {
            label = 'Annesburg',
            coords = vector4(2934.42, 1283.26, 44.65, 70.0)
        },
        {
            label = 'Van Horn',
            coords = vector4(2982.50, 561.70, 44.80, 170.0)
        },
        {
            label = 'Armadillo',
            coords = vector4(-3686.15, -2623.25, -13.43, 275.0)
        },
        {
            label = 'Tumbleweed',
            coords = vector4(-5516.65, -2941.37, -1.87, 30.0)
        }
    }
}

MSMedicConfig.SearchDistance = 8.0
MSMedicConfig.TreatmentDistance = 3.0
MSMedicConfig.ActionCooldownMs = 1000
MSMedicConfig.MaxActiveDiseases = 2

-- Jede Wahrscheinlichkeit gilt pro Krankheitsprüfung: 0.01 entspricht 1 %.
MSMedicConfig.InitialRollDelayMs = 120000
MSMedicConfig.DiseaseRollIntervalMs = 600000
MSMedicConfig.SymptomIntervalMs = 60000
MSMedicConfig.MinimumDiseaseHealth = 25
MSMedicConfig.DiseasesCanKill = false

MSMedicConfig.Diseases = {
    influenza = {
        label = 'Grippe',
        description = 'Fieber, Husten und allgemeine Schwäche.',
        chance = 0.006,
        progressionChance = 0.12,
        maxSeverity = 3,
        healthDrainPerSeverity = 1,
        symptoms = { 'Husten', 'Fieber', 'Erschöpfung' },
        messages = {
            'Ein heftiger Hustenanfall überkommt dich.',
            'Du fühlst dich fiebrig und erschöpft.'
        },
        treatment = {
            label = 'Grippe behandeln',
            durationMs = 5000,
            successChance = 1.0,
            items = { medicine = 1 }
        }
    },
    pneumonia = {
        label = 'Lungenentzündung',
        description = 'Schwere Atembeschwerden und hohes Fieber.',
        chance = 0.001,
        progressionChance = 0.18,
        maxSeverity = 3,
        healthDrainPerSeverity = 2,
        symptoms = { 'Atemnot', 'Brustschmerz', 'Hohes Fieber' },
        messages = {
            'Jeder Atemzug fällt dir schwer.',
            'Ein stechender Schmerz zieht durch deine Brust.'
        },
        treatment = {
            label = 'Lungenentzündung behandeln',
            durationMs = 8000,
            successChance = 0.9,
            items = { medicine = 2, herbal_tonic = 1 }
        }
    },
    food_poisoning = {
        label = 'Vergiftung',
        description = 'Giftstoffe verursachen Übelkeit, Erbrechen, Krämpfe und Kreislaufprobleme.',
        chance = 0.004,
        progressionChance = 0.1,
        maxSeverity = 2,
        healthDrainPerSeverity = 1,
        symptoms = { 'Übelkeit', 'Erbrechen', 'Bauchkrämpfe', 'Schwindel', 'Starker Durst' },
        messages = {
            'Dir wird plötzlich übel.',
            'Starke Bauchkrämpfe zwingen dich zu einer Pause.'
        },
        periodicEffect = {
            kind = 'vomit',
            minIntervalMs = 45000,
            maxIntervalMs = 120000,
            severityIntervalReduction = 0.12,
            durationMs = 6500,
            thirstDelta = -1.0,
            scenario = 'WORLD_HUMAN_VOMIT',
            messages = {
                'Die Vergiftung zwingt dich, dich zu übergeben.',
                'Dir wird schlagartig schlecht und du musst erbrechen.'
            }
        },
        treatment = {
            label = 'Vergiftung behandeln',
            durationMs = 5000,
            successChance = 1.0,
            items = { herbal_tonic = 1 }
        }
    },
    wound_infection = {
        label = 'Wundinfektion',
        description = 'Eine entzündete Verletzung schwächt den Körper.',
        chance = 0.002,
        progressionChance = 0.15,
        maxSeverity = 3,
        healthDrainPerSeverity = 2,
        symptoms = { 'Entzündung', 'Fieber', 'Wundschmerz' },
        messages = {
            'Eine alte Wunde pocht schmerzhaft.',
            'Die entzündete Wunde brennt und schwächt dich.'
        },
        treatment = {
            label = 'Infektion behandeln',
            durationMs = 7000,
            successChance = 0.95,
            items = { bandage = 1, medicine = 1 }
        }
    },
    bone_fracture = {
        label = 'Knochenbruch',
        description = 'Ein gebrochener Knochen verursacht starke Schmerzen und schränkt die Bewegung ein.',
        chance = 0.001,
        progressionChance = 0.08,
        maxSeverity = 3,
        healthDrainPerSeverity = 1,
        symptoms = { 'Starke Schmerzen', 'Eingeschränkte Bewegung', 'Schmerzhafte Belastung' },
        messages = {
            'Der gebrochene Knochen schmerzt bei jeder Bewegung.',
            'Ein stechender Schmerz fährt durch deinen Körper.'
        },
        effects = {
            movementMultiplier = 0.78,
            movementPenaltyPerSeverity = 0.10,
            minimumMovementMultiplier = 0.50,
            disableSprint = true,
            painIntervalMs = 30000,
            painChance = 0.65,
            painDurationMs = 2500,
            painMovementMultiplier = 0.60,
            painMessages = {
                'Der Knochenbruch verursacht einen heftigen Schmerzschub.',
                'Du zuckst vor Schmerzen zusammen und musst langsamer werden.'
            }
        },
        treatment = {
            label = 'Knochenbruch schienen',
            durationMs = 10000,
            successChance = 0.95,
            items = { bandage = 2, medicine = 1 }
        }
    },
    gunshot_wound = {
        label = 'Schusswunde',
        description = 'Eine offene Schussverletzung verursacht Blutverlust und starke Schmerzen.',
        chance = 0.0,
        progressionChance = 0.0,
        maxSeverity = 3,
        healthDrainPerSeverity = 0,
        ignoreActiveLimit = true,
        symptoms = { 'Blutung', 'Starke Schmerzen', 'Schwäche', 'Kreislaufprobleme' },
        messages = {
            'Die Schusswunde blutet weiter.',
            'Die Verletzung pocht schmerzhaft.'
        },
        periodicEffect = {
            kind = 'gunshot_pain',
            minIntervalMs = 25000,
            maxIntervalMs = 75000,
            severityIntervalReduction = 0.15,
            durationMs = 2600,
            healthDrainPerSeverity = 1,
            emoteKit = 'KIT_EMOTE_REACTION_SHOT_1',
            emoteType = 1,
            emoteVariation = 2,
            messages = {
                'Die Schusswunde beginnt erneut zu bluten und schmerzt heftig.',
                'Ein stechender Schmerz fährt durch die Schusswunde.'
            }
        },
        treatment = {
            label = 'Schusswunde versorgen',
            durationMs = 12000,
            successChance = 0.9,
            items = { bandage = 2, medicine = 1 }
        }
    }
}

MSMedicConfig.GunshotDetection = {
    Enabled = true,
    WoundChance = 1.0,
    IncreaseSeverityOnHit = true,
    SeverityIncreaseCooldownMs = 15000,
    LethalHitSeverity = 3,
    WeaponNames = {
        'WEAPON_PISTOL_VOLCANIC',
        'WEAPON_PISTOL_MAUSER_DRUNK',
        'WEAPON_PISTOL_M1899',
        'WEAPON_PISTOL_SEMIAUTO',
        'WEAPON_PISTOL_MAUSER',
        'WEAPON_REPEATER_EVANS',
        'WEAPON_REPEATER_CARBINE_SADIE',
        'WEAPON_REPEATER_HENRY',
        'WEAPON_REPEATER_WINCHESTER',
        'WEAPON_REPEATER_WINCHESTER_JOHN',
        'WEAPON_REPEATER_CARBINE',
        'WEAPON_REVOLVER_DOUBLEACTION_MICAH_DUALWIELD',
        'WEAPON_REVOLVER_DOUBLEACTION_MICAH',
        'WEAPON_REVOLVER_SCHOFIELD_CALLOWAY',
        'WEAPON_REVOLVER_DOUBLEACTION',
        'WEAPON_REVOLVER_CATTLEMAN',
        'WEAPON_REVOLVER_CATTLEMAN_MEXICAN',
        'WEAPON_REVOLVER_CATTLEMAN_HOSEA_DUALWIELD',
        'WEAPON_REVOLVER_DOUBLEACTION_EXOTIC',
        'WEAPON_REVOLVER_CATTLEMAN_SEAN',
        'WEAPON_REVOLVER_CATTLEMAN_SADIE',
        'WEAPON_REVOLVER_DOUBLEACTION_JAVIER',
        'WEAPON_REVOLVER_LEMAT',
        'WEAPON_REVOLVER_SCHOFIELD_BILL',
        'WEAPON_REVOLVER_SCHOFIELD',
        'WEAPON_REVOLVER_CATTLEMAN_SADIE_DUALWIELD',
        'WEAPON_REVOLVER_DOUBLEACTION_GAMBLER',
        'WEAPON_REVOLVER_CATTLEMAN_KIERAN',
        'WEAPON_REVOLVER_SCHOFIELD_UNCLE',
        'WEAPON_REVOLVER_CATTLEMAN_HOSEA',
        'WEAPON_REVOLVER_CATTLEMAN_LENNY',
        'WEAPON_REVOLVER_CATTLEMAN_JOHN',
        'WEAPON_REVOLVER_SCHOFIELD_DUTCH_DUALWIELD',
        'WEAPON_REVOLVER_SCHOFIELD_GOLDEN',
        'WEAPON_REVOLVER_CATTLEMAN_PIG',
        'WEAPON_REVOLVER_SCHOFIELD_DUTCH',
        'WEAPON_REVOLVER_NAVY',
        'WEAPON_REVOLVER_NAVY_CROSSOVER',
        'WEAPON_RIFLE_SPRINGFIELD',
        'WEAPON_RIFLE_BOLTACTION',
        'WEAPON_RIFLE_BOLTACTION_BILL',
        'WEAPON_RIFLE_VARMINT',
        'WEAPON_RIFLE_ELEPHANT',
        'WEAPON_SHOTGUN_SAWEDOFF',
        'WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC',
        'WEAPON_SHOTGUN_PUMP',
        'WEAPON_SHOTGUN_REPEATING',
        'WEAPON_SHOTGUN_SEMIAUTO',
        'WEAPON_SHOTGUN_DOUBLEBARREL',
        'WEAPON_SHOTGUN_DOUBLEBARREL_UNCLE',
        'WEAPON_SHOTGUN_SAWEDOFF_CHARLES',
        'WEAPON_SHOTGUN_SEMIAUTO_HOSEA',
        'WEAPON_SNIPERRIFLE_ROLLINGBLOCK_LENNY',
        'WEAPON_SNIPERRIFLE_ROLLINGBLOCK_EXOTIC',
        'WEAPON_SNIPERRIFLE_CARCANO',
        'WEAPON_SNIPERRIFLE_ROLLINGBLOCK'
    }
}

MSMedicConfig.CareActions = {
    stabilize = {
        label = 'Wunden versorgen',
        description = 'Stellt Gesundheit wieder her.',
        durationMs = 4500,
        healAmount = 60,
        items = { bandage = 1 }
    },
    revive = {
        label = 'Wiederbeleben',
        description = 'Belebt einen verstorbenen Spieler wieder.',
        durationMs = 9000,
        reviveHealth = 100,
        items = { revive_kit = 1 }
    }
}

MSMedicConfig.Debug = false
