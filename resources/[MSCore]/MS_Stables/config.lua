MSStablesConfig = {}

MSStablesConfig.Command = 'stables'
MSStablesConfig.InteractionKey = 'E'
MSStablesConfig.Account = 'bank'
MSStablesConfig.CurrencyLabel = '$'
MSStablesConfig.InteractionDistance = 2.4
MSStablesConfig.ServerInteractionDistance = 5.0
MSStablesConfig.SellerStreamDistance = 110.0
MSStablesConfig.SellerDespawnDistance = 140.0
MSStablesConfig.ModelLoadTimeout = 10000
MSStablesConfig.ActionCooldown = 500
MSStablesConfig.SpawnCooldown = 2500
MSStablesConfig.MaxHorses = 8
MSStablesConfig.MaxWagons = 5
MSStablesConfig.BaseHorseHealth = 300
MSStablesConfig.Debug = false

-- Verkäufer-, Pferde- und Kutschenpositionen können für jeden Stall frei geändert werden.
MSStablesConfig.Stables = {
    valentine = {
        label = 'Valentine Stallungen',
        seller = {
            model = 'u_m_m_valgenstoreowner_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = -365.18,
            y = 791.72,
            z = 116.18,
            heading = 96.0
        },
        horseSpawn = {
            x = -372.55,
            y = 786.84,
            z = 116.13,
            heading = 270.0
        },
        wagonSpawn = {
            x = -382.62,
            y = 783.48,
            z = 115.91,
            heading = 272.0
        }
    },
    blackwater = {
        label = 'Blackwater Stallungen',
        seller = {
            model = 'u_m_m_valgenstoreowner_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = -875.16,
            y = -1365.18,
            z = 43.53,
            heading = 88.0
        },
        horseSpawn = {
            x = -864.42,
            y = -1366.56,
            z = 43.66,
            heading = 92.0
        },
        wagonSpawn = {
            x = -851.95,
            y = -1364.03,
            z = 43.56,
            heading = 89.0
        }
    }
}

MSStablesConfig.Horses = {
    morgan = {
        label = 'Morgan',
        description = 'Ein zuverlässiges, wendiges Pferd für den Alltag.',
        price = 180,
        coats = {
            { key = 'bay', label = 'Braun', model = 'a_c_horse_morgan_bay', price = 0 },
            { key = 'flaxen_chestnut', label = 'Fuchs', model = 'a_c_horse_morgan_flaxenchestnut', price = 55 }
        }
    },
    tennessee_walker = {
        label = 'Tennessee Walker',
        description = 'Ruhiges Reitpferd mit angenehmem Gang.',
        price = 260,
        coats = {
            { key = 'chestnut', label = 'Kastanie', model = 'a_c_horse_tennesseewalker_chestnut', price = 0 },
            { key = 'black_rabicano', label = 'Schwarz-Rabicano', model = 'a_c_horse_tennesseewalker_blackrabicano', price = 85 }
        }
    },
    american_paint = {
        label = 'American Paint',
        description = 'Robustes Arbeitspferd mit auffälliger Scheckung.',
        price = 390,
        coats = {
            { key = 'grey_overo', label = 'Grau-Overo', model = 'a_c_horse_americanpaint_greyovero', price = 0 },
            { key = 'overo', label = 'Braun-Overo', model = 'a_c_horse_americanpaint_overo', price = 110 }
        }
    },
    arabian = {
        label = 'Araber',
        description = 'Schnelles und temperamentvolles Premium-Reitpferd.',
        price = 850,
        coats = {
            { key = 'white', label = 'Weiß', model = 'a_c_horse_arabian_white', price = 0 },
            { key = 'black', label = 'Schwarz', model = 'a_c_horse_arabian_black', price = 250 }
        }
    }
}

MSStablesConfig.Equipment = {
    trail_saddle = {
        label = 'Wandersattel',
        description = 'Bequemer Sattel für längere Reisen.',
        category = 'saddle',
        categoryLabel = 'Sattel',
        price = 85,
        healthBonus = 20
    },
    ranch_saddle = {
        label = 'Ranchsattel',
        description = 'Stabiler Arbeitssattel mit guter Gewichtsverteilung.',
        category = 'saddle',
        categoryLabel = 'Sattel',
        price = 150,
        healthBonus = 40
    },
    wool_blanket = {
        label = 'Wolldecke',
        description = 'Warme Satteldecke für kalte Nächte.',
        category = 'blanket',
        categoryLabel = 'Satteldecke',
        price = 45,
        healthBonus = 10
    },
    reinforced_stirrups = {
        label = 'Verstärkte Steigbügel',
        description = 'Robuste Steigbügel aus gehärtetem Metall.',
        category = 'stirrups',
        categoryLabel = 'Steigbügel',
        price = 70,
        healthBonus = 15
    }
}

-- Optional kann einem Ausrüstungseintrag ein RedM-Meta-Ped-Shop-Hash gegeben
-- werden: componentHash = 123456789. Er wird beim Spawn auf das Pferd angewandt.

MSStablesConfig.Wagons = {
    utility_cart = {
        label = 'Arbeitskarren',
        description = 'Kleiner Karren für Waren und kurze Wege.',
        model = 'cart01',
        price = 300
    },
    passenger_coach = {
        label = 'Personenkutsche',
        description = 'Geschlossene Kutsche für komfortable Reisen.',
        model = 'coach2',
        price = 575
    },
    freight_wagon = {
        label = 'Frachtwagen',
        description = 'Großer Wagen für Handel und Transporte.',
        model = 'wagon02x',
        price = 725
    }
}
