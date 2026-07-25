MSTelegramsConfig = {}

MSTelegramsConfig.Command = 'telegrams'
MSTelegramsConfig.InteractionKey = 'E'
MSTelegramsConfig.Account = 'cash'
MSTelegramsConfig.SendCost = 1
MSTelegramsConfig.CurrencyLabel = '$'
MSTelegramsConfig.NumberDigits = 6
MSTelegramsConfig.MaxSubjectLength = 64
MSTelegramsConfig.MaxBodyLength = 1200
MSTelegramsConfig.MaxMessagesPerFolder = 100
MSTelegramsConfig.InteractionDistance = 2.3
MSTelegramsConfig.ServerInteractionDistance = 6.0
MSTelegramsConfig.ClerkStreamDistance = 100.0
MSTelegramsConfig.ClerkDespawnDistance = 130.0
MSTelegramsConfig.ModelLoadTimeout = 10000
MSTelegramsConfig.ActionCooldown = 650
MSTelegramsConfig.Debug = false

-- Alle Telegrafenbeamten und ihre Positionen können hier ergänzt, verschoben
-- oder entfernt werden. Die Tabellenkennung links muss eindeutig bleiben.
MSTelegramsConfig.Stations = {
    valentine = {
        label = 'Valentine Telegrafenamt',
        clerk = {
            model = 'u_m_m_valgenstoreowner_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = -177.88,
            y = 627.72,
            z = 114.09,
            heading = 54.0
        }
    },
    rhodes = {
        label = 'Rhodes Telegrafenamt',
        clerk = {
            model = 'u_m_m_rhdtrainstationworker_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = 1229.36,
            y = -1298.83,
            z = 76.90,
            heading = 318.0
        }
    },
    saint_denis = {
        label = 'Saint Denis Telegrafenamt',
        clerk = {
            model = 'u_m_m_nbxgeneralstoreowner_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = 2747.15,
            y = -1394.55,
            z = 46.18,
            heading = 21.0
        }
    },
    blackwater = {
        label = 'Blackwater Telegrafenamt',
        clerk = {
            model = 'u_m_m_bwmstablehand_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = -875.10,
            y = -1328.74,
            z = 43.96,
            heading = 91.0
        }
    }
}
