ResourceGuardConfig = {}

ResourceGuardConfig.Enabled = true
ResourceGuardConfig.CheckIntervalMs = 5000
ResourceGuardConfig.StartupGraceMs = 60000
ResourceGuardConfig.TransitionWindowMs = 60000
ResourceGuardConfig.TransitionThreshold = 10
ResourceGuardConfig.UnstableConfirmations = 3
ResourceGuardConfig.StartingTimeoutMs = 45000
ResourceGuardConfig.AlertCooldownMs = 60000
ResourceGuardConfig.CommandPermission = 'mscore.resourceguard'

ResourceGuardConfig.AutoStop = {
    Enabled = true,
    Flapping = true,
    StuckTransitions = true,
    BlockedResources = true,
    UnknownResources = false
}

-- Ist AllowedResources leer, werden unbekannte Resources nur beobachtet.
-- Sobald Einträge vorhanden sind und UnknownResources aktiv ist, können
-- gestartete Resources außerhalb dieser Liste automatisch gestoppt werden.
ResourceGuardConfig.AllowedResources = {}
ResourceGuardConfig.BlockedResources = {}

ResourceGuardConfig.ExpectedResources = {
    'mapmanager',
    'chat',
    'spawnmanager',
    'sessionmanager-rdr3',
    'redm-map-one',
    'hardcap',
    'MS_LoadingScreen',
    'oxmysql',
    'MSCore',
    'MS_Banking',
    'MS_BossMenu',
    'MS_PlayerSync',
    'MS_mechat',
    'MS_pointing',
    'MS_Permadeath',
    'MS_Medic',
    'MS_WeaponDamage',
    'MS_Inventory',
    'MS_Crime',
    'MS_RestrictedAreas',
    'MS_BasicNeeds',
    'MS_HUD',
    'MS_Jail',
    'MS_ClothingShop',
    'MS_Stables',
    'MS_Trains',
    'MS_Telegrams',
    'MS_WorldBuilder',
    'MS_ResourceGuard',
    'MS_AdminMenu',
    'MS_MapEditor',
    'MS_AdminLogout',
    'MS_Example'
}

ResourceGuardConfig.CriticalResources = {
    'mapmanager',
    'chat',
    'spawnmanager',
    'sessionmanager-rdr3',
    'redm-map-one',
    'hardcap',
    'oxmysql',
    'MSCore',
    'MS_Permadeath',
    'MS_PlayerSync',
    'MS_Inventory',
    'MS_BasicNeeds',
    'MS_ResourceGuard',
    'MS_AdminMenu'
}

-- Geschützte Resources werden gemeldet, aber niemals automatisch oder über
-- das ACP gestoppt. Der Wächter schützt sich selbst unabhängig von der Liste.
ResourceGuardConfig.ProtectedResources = {
    'oxmysql',
    'MSCore',
    'MS_ResourceGuard',
    'MS_AdminMenu',
    'chat',
    'mapmanager',
    'spawnmanager',
    'sessionmanager',
    'sessionmanager-rdr3',
    'redm-map-one',
    'hardcap',
    'baseevents',
    'monitor',
    'webpack',
    'yarn'
}
