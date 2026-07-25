MSMedicConfig = {}

MSMedicConfig.MedicCommand = 'medic'
MSMedicConfig.HealthCommand = 'healthstatus'
MSMedicConfig.AdminDiseaseCommand = 'medicdisease'
MSMedicConfig.DefaultKey = 'F6'
MSMedicConfig.AdminAce = 'mscore.admin'

MSMedicConfig.MedicJobs = {
    medic = 0
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
        label = 'Lebensmittelvergiftung',
        description = 'Übelkeit, Krämpfe und Kreislaufprobleme.',
        chance = 0.004,
        progressionChance = 0.1,
        maxSeverity = 2,
        healthDrainPerSeverity = 1,
        symptoms = { 'Übelkeit', 'Bauchkrämpfe', 'Schwindel' },
        messages = {
            'Dir wird plötzlich übel.',
            'Starke Bauchkrämpfe zwingen dich zu einer Pause.'
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
