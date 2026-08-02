Config = {}

Config.Version = '0.1.0'
Config.Debug = false
Config.IdentifierType = 'license'
Config.AdminAce = 'mscore.admin'

Config.MaxCharacters = 3
Config.AutoSelectSingleCharacter = true
Config.SelectionBucketEnabled = true
Config.SelectionBucketBase = 60000

Config.CallbackTimeoutMs = 15000
Config.SaveIntervalMs = 5 * 60 * 1000
Config.PositionUpdateMs = 30 * 1000
Config.SpawnStreamingTimeoutMs = 8000

Config.Database = {
    AutoMigrate = true
}

Config.Limits = {
    NameMinLength = 2,
    NameMaxLength = 32,
    MetadataBytes = 32768,
    MaximumMoney = 100000000.00
}

Config.DefaultCharacter = {
    money = 50.00,
    gold = 0.00,
    xp = 0,
    group = 'user',
    job = 'unemployed',
    jobGrade = 0,
    health = 500,
    stamina = 100,
    spawn = vector4(-169.47, 629.38, 114.03, 236.72)
}

Config.Jobs = {
    unemployed = {
        label = 'Arbeitslos',
        grades = {
            [0] = {
                label = 'Bürger',
                salary = 0
            }
        }
    }
}
