MSClothingShopConfig = {}

MSClothingShopConfig.Command = 'clothingshop'
MSClothingShopConfig.InteractionKey = 'E'
MSClothingShopConfig.Account = 'cash'
MSClothingShopConfig.CurrencyLabel = '$'
MSClothingShopConfig.InteractionDistance = 2.3
MSClothingShopConfig.ServerInteractionDistance = 6.0
MSClothingShopConfig.SellerStreamDistance = 100.0
MSClothingShopConfig.SellerDespawnDistance = 130.0
MSClothingShopConfig.ModelLoadTimeout = 10000
MSClothingShopConfig.ActionCooldown = 650
MSClothingShopConfig.MaxCartItems = 12
MSClothingShopConfig.Debug = false

MSClothingShopConfig.Preview = {
    cameraDistance = 2.35,
    cameraHeight = 0.72,
    cameraFov = 38.0,
    minZoom = 1.45,
    maxZoom = 3.25,
    rotationStep = 18.0
}

-- Händlerpositionen sind frei konfigurierbar. Der Spieler bleibt während der
-- Vorschau an seiner aktuellen Position und wird lediglich eingefroren.
MSClothingShopConfig.Shops = {
    valentine = {
        label = 'Valentine Schneiderei',
        seller = {
            model = 'u_m_m_valgenstoreowner_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = -325.42,
            y = 802.72,
            z = 117.88,
            heading = 98.0
        }
    },
    blackwater = {
        label = 'Blackwater Modehaus',
        seller = {
            model = 'u_m_m_bwmstablehand_01',
            scenario = 'GENERIC_STANDING_SCENARIO',
            x = -761.84,
            y = -1291.64,
            z = 43.84,
            heading = 89.0
        }
    }
}

MSClothingShopConfig.Categories = {
    { key = 'all', label = 'Alle' },
    { key = 'hat', label = 'Hüte' },
    { key = 'shirt', label = 'Hemden & Blusen' },
    { key = 'coat', label = 'Mäntel' },
    { key = 'pants', label = 'Hosen' },
    { key = 'boots', label = 'Stiefel' }
}

-- Die eigentlichen Itemdaten einschließlich Geschlecht, Outfit-Slot und
-- componentHash befinden sich in MSCore/config.lua.
MSClothingShopConfig.Products = {
    { item = 'tailor_hat_male', price = 28, order = 10 },
    { item = 'tailor_hat_female', price = 32, order = 11 },
    { item = 'tailor_shirt_male', price = 36, order = 20 },
    { item = 'tailor_shirt_female', price = 38, order = 21 },
    { item = 'tailor_coat_male', price = 82, order = 30 },
    { item = 'tailor_coat_female', price = 86, order = 31 },
    { item = 'tailor_pants_male', price = 44, order = 40 },
    { item = 'tailor_pants_female', price = 46, order = 41 },
    { item = 'tailor_boots_male', price = 58, order = 50 },
    { item = 'tailor_boots_female', price = 62, order = 51 }
}
