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

MSBankingConfig.AdminAccount = {
    key = 'administration',
    label = 'Administrationskonto',
    acePermission = 'mscore.admin',
    allowedGroups = {
        admin = true,
        superadmin = true
    }
}

-- Die Steuer wird vom Bruttobetrag abgezogen und dem Adminkonto gutgeschrieben.
-- MSCore verwendet ganze Dollar. Mit "ceil" wird daher auf den nächsten
-- vollen Dollar aufgerundet. Erlaubte Rundungen: ceil, floor, round.
MSBankingConfig.TransactionTax = {
    enabled = true,
    percent = 1.0,
    minimum = 1,
    rounding = 'ceil',
    appliesTo = {
        deposit = true,
        withdrawal = true,
        companyDeposit = true,
        companyWithdrawal = true
    }
}

-- Alle vorhandenen, beschäftigten Jobs erhalten ein gemeinsames Firmenkonto.
-- Jeder Rang ab minDepositGrade darf einzahlen. Auszahlungen sind
-- standardmäßig dem jeweiligen Leitungsrang vorbehalten.
MSBankingConfig.CompanyAccounts = {
    sheriff = {
        label = 'Sheriff Office',
        minDepositGrade = 0,
        minWithdrawGrade = 1
    },
    medic = {
        label = 'Medic',
        minDepositGrade = 0,
        minWithdrawGrade = 2
    },
    native = {
        label = 'Stammeskonto',
        minDepositGrade = 0,
        minWithdrawGrade = 1
    },
    gunsmith = {
        label = 'Büchsenmacher',
        minDepositGrade = 0,
        minWithdrawGrade = 1
    },
    law = {
        label = 'Law',
        minDepositGrade = 0,
        minWithdrawGrade = 1
    }
}

-- Neue Jobschlüssel erhalten beim ersten Bankbesuch automatisch ein Konto,
-- auch wenn sie oben noch keinen eigenen Eintrag besitzen.
MSBankingConfig.CompanyAccountDefaults = {
    enabled = true,
    minDepositGrade = 0,
    minWithdrawGrade = 1,
    excludedJobs = {
        unemployed = true
    }
}

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
