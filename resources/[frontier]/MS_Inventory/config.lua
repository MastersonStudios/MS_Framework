MSInventoryConfig = {}

MSInventoryConfig.Command = 'inventory'
MSInventoryConfig.DefaultKey = 'I'
MSInventoryConfig.GiveDistance = 3.0
MSInventoryConfig.MaxActionAmount = 100
MSInventoryConfig.ActionCooldown = 350
MSInventoryConfig.AllowDiscard = true
MSInventoryConfig.Debug = false

MSInventoryConfig.OutfitSlots = {
    { key = 'hat', label = 'Hut', icon = 'H' },
    { key = 'shirt', label = 'Hemd', icon = 'O' },
    { key = 'vest', label = 'Weste', icon = 'W' },
    { key = 'coat', label = 'Mantel', icon = 'M' },
    { key = 'pants', label = 'Hose', icon = 'B' },
    { key = 'boots', label = 'Stiefel', icon = 'S' },
    { key = 'gloves', label = 'Handschuhe', icon = 'G' },
    { key = 'neckwear', label = 'Halstuch', icon = 'N' }
}

-- Positive Werte füllen die jeweilige Spieler-Metadatenanzeige bis maximal 100.
MSInventoryConfig.UseEffects = {
    water = {
        metadata = { thirst = 25 },
        message = 'Du hast Wasser getrunken.'
    },
    bread = {
        metadata = { hunger = 20 },
        message = 'Du hast Brot gegessen.'
    },
    bandage = {
        health = 35,
        message = 'Du hast einen Verband benutzt.'
    }
}

-- Bekleidungsitems benötigen in ihren Item-Metadaten:
-- { "clothingSlot": "hat", "componentHash": 123456789 }
-- componentHash ist optional; ohne Hash bleibt die itembezogene Ausrüstung
-- persistent und sichtbar im Inventar, verändert aber kein Meta-Ped-Bauteil.
