MSBankingConfig = {}

MSBankingConfig.Command = 'bank'
MSBankingConfig.InteractionKey = 'E'
MSBankingConfig.CurrencyLabel = '$'
MSBankingConfig.AccountPrefix = 'MS'
MSBankingConfig.AccountDigits = 10
MSBankingConfig.TransactionHistoryLimit = 25
MSBankingConfig.MaxTransactionAmount = 1000000
MSBankingConfig.InteractionDistance = 2.3
MSBankingConfig.ServerInteractionDistance = 6.0
MSBankingConfig.BankerStreamDistance = 100.0
MSBankingConfig.BankerDespawnDistance = 130.0
MSBankingConfig.ModelLoadTimeout = 10000
MSBankingConfig.ActionCooldown = 500
MSBankingConfig.Debug = false

-- Banker können ergänzt, verschoben oder entfernt werden. Die Kennung links
-- muss eindeutig bleiben. An jeder Filiale ist dasselbe Charakterkonto nutzbar.
MSBankingConfig.Bankers = {
    valentine = {
        label = 'Valentine Bank',
        npc = {
            model = 'u_m_m_valbanker_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = -308.42,
            y = 776.08,
            z = 118.70,
            heading = 10.0
        }
    },
    rhodes = {
        label = 'Rhodes Bank',
        npc = {
            model = 'u_m_m_rhdbanker_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = 1292.66,
            y = -1302.01,
            z = 77.04,
            heading = 315.0
        }
    },
    saint_denis = {
        label = 'Saint Denis Bank',
        npc = {
            model = 'u_m_m_nbxbanker_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = 2644.08,
            y = -1294.33,
            z = 52.25,
            heading = 110.0
        }
    },
    blackwater = {
        label = 'Blackwater Bank',
        npc = {
            model = 'u_m_m_bht_banker_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = -814.32,
            y = -1276.56,
            z = 43.64,
            heading = 175.0
        }
    }
}
