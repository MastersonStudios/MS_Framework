MSTrainsConfig = {}

MSTrainsConfig.Command = 'trains'
MSTrainsConfig.ReturnCommand = 'trainreturn'
MSTrainsConfig.InteractionKey = 'E'
MSTrainsConfig.AccelerateKey = 'W'
MSTrainsConfig.BrakeKey = 'S'
MSTrainsConfig.ReverseKey = 'R'
MSTrainsConfig.EmergencyBrakeKey = 'SPACE'

MSTrainsConfig.InteractionDistance = 2.5
MSTrainsConfig.ServerInteractionDistance = 6.0
MSTrainsConfig.NpcStreamDistance = 120.0
MSTrainsConfig.NpcDespawnDistance = 150.0
MSTrainsConfig.SpawnClearance = 24.0
MSTrainsConfig.ModelLoadTimeout = 20000
MSTrainsConfig.SpawnTimeout = 30000
MSTrainsConfig.SpawnCooldown = 15000
MSTrainsConfig.ActionCooldown = 500
MSTrainsConfig.MaxActiveTrains = 8
MSTrainsConfig.ControlInterval = 100
MSTrainsConfig.Debug = false

-- Zugkompositionen stammen aus trainconfigs.ymt. Eigene gültige
-- Konfigurations-Hashes können hier ergänzt und je Bahnhof freigegeben werden.
MSTrainsConfig.Trains = {
    passenger = {
        label = 'Personenzug',
        description = 'Klassischer Reisezug mit mehreren Personenwagen.',
        configHash = 0x3D72571D,
        maxSpeed = 18.0,
        reverseMaxSpeed = 7.0,
        acceleration = 1.25,
        braking = 2.4,
        passengers = false
    },
    pacific_union = {
        label = 'Pacific Union',
        description = 'Grüner Langstrecken-Personenzug der Pacific Union.',
        configHash = 0x2D3645FA,
        maxSpeed = 16.0,
        reverseMaxSpeed = 6.0,
        acceleration = 1.0,
        braking = 2.2,
        passengers = false
    },
    industry = {
        label = 'Industriezug',
        description = 'Schwerer Zug für Güter- und Arbeitseinsätze.',
        configHash = 0x767DEB32,
        maxSpeed = 13.0,
        reverseMaxSpeed = 5.0,
        acceleration = 0.8,
        braking = 1.8,
        passengers = false
    }
}

-- Alle NPC- und Gleiskoordinaten sind frei konfigurierbar.
-- npc: Position des Bahnhof-NPCs.
-- spawn: Muss direkt auf einem vorhandenen Gleis liegen. RedM prüft und
--        rastet den Zug beim Erzeugen auf dieses Gleis ein.
-- direction: Standardrichtung; Spieler können sie im Menü umkehren.
MSTrainsConfig.Stations = {
    valentine = {
        label = 'Valentine Bahnhof',
        region = 'The Heartlands',
        npc = {
            model = 'u_m_m_rhdtrainstationworker_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = -180.2,
            y = 627.1,
            z = 114.1,
            heading = 92.0
        },
        spawn = {
            x = -150.728,
            y = 643.9002,
            z = 115.1231,
            direction = false
        },
        trains = { 'passenger', 'pacific_union', 'industry' }
    },
    emerald = {
        label = 'Emerald Station',
        region = 'The Heartlands',
        npc = {
            model = 'u_m_m_rhdtrainstationworker_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = 1522.92,
            y = 442.73,
            z = 90.68,
            heading = 184.0
        },
        spawn = {
            x = 1528.799,
            y = 417.9227,
            z = 91.82778,
            direction = false
        },
        trains = { 'passenger', 'pacific_union', 'industry' }
    },
    rhodes = {
        label = 'Rhodes Bahnhof',
        region = 'Scarlett Meadows',
        npc = {
            model = 'u_m_m_rhdtrainstationworker_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = 1229.36,
            y = -1298.83,
            z = 76.90,
            heading = 318.0
        },
        spawn = {
            x = 1246.924,
            y = -1331.255,
            z = 78.03119,
            direction = true
        },
        trains = { 'passenger', 'pacific_union', 'industry' }
    },
    saint_denis = {
        label = 'Saint Denis Bahnhof',
        region = 'Bayou Nwa',
        npc = {
            model = 'u_m_m_rhdtrainstationworker_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = 2747.15,
            y = -1394.55,
            z = 46.18,
            heading = 21.0
        },
        spawn = {
            x = 2748.035,
            y = -1436.106,
            z = 47.473,
            direction = false
        },
        trains = { 'passenger', 'pacific_union', 'industry' }
    }
}
