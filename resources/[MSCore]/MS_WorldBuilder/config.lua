WorldBuilderConfig = {}

WorldBuilderConfig.Permission = 'mscore.worldbuilder'
WorldBuilderConfig.Command = 'worldbuilder'
WorldBuilderConfig.DefaultKey = 'F9'
WorldBuilderConfig.InteractionKey = 'E'
WorldBuilderConfig.MaxPlacementDistance = 12.0
WorldBuilderConfig.NpcStreamDistance = 120.0
WorldBuilderConfig.NpcDespawnDistance = 150.0
WorldBuilderConfig.DoorApplyDistance = 90.0
WorldBuilderConfig.DefaultStorageRadius = 2.0
WorldBuilderConfig.MaxStorageCapacity = 1000
WorldBuilderConfig.MaxDefinitionsPerType = 500
WorldBuilderConfig.TransferLimit = 100

WorldBuilderConfig.NpcModels = {
    { model = 'u_m_m_valgenstoreowner_01', label = 'Händler – Valentine' },
    { model = 'u_m_m_rhdtrainstationworker_01', label = 'Bahnhofsarbeiter – Rhodes' },
    { model = 'a_m_m_valtownfolk_01', label = 'Bürger – Valentine' },
    { model = 'cs_sheriff_freeman', label = 'Sheriff Freeman' }
}

WorldBuilderConfig.NpcScenarios = {
    { scenario = '', label = 'Nur stehen' },
    { scenario = 'GENERIC_STANDING_SCENARIO', label = 'Neutrales Stehen' },
    { scenario = 'WORLD_HUMAN_SMOKING', label = 'Rauchen' }
}
