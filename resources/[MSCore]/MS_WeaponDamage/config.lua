MSWeaponDamageConfig = {}

-- 1.00 = originaler Schaden, 0.50 = halber Schaden, 2.00 = doppelter Schaden.
MSWeaponDamageConfig.Enabled = true
MSWeaponDamageConfig.DefaultMultiplier = 1.00
MSWeaponDamageConfig.MinimumMultiplier = 0.00
MSWeaponDamageConfig.MaximumMultiplier = 5.00

-- Der aktive Waffentyp wird regelmäßig erneut angewendet, falls ein anderes
-- Script den Spielwert überschreibt.
MSWeaponDamageConfig.ReapplyIntervalMs = 1000
MSWeaponDamageConfig.RequestCooldownMs = 2000
MSWeaponDamageConfig.Debug = false

-- Laufzeitänderungen per /weapondamage werden nicht in diese Datei geschrieben
-- und gelten bis zum nächsten Resource-Neustart.
MSWeaponDamageConfig.AllowRuntimeOverrides = true
MSWeaponDamageConfig.AdminAce = 'mscore.weapon.damage'

local function weapon(category, name, damage)
    return {
        category = category,
        name = name,
        damage = damage or MSWeaponDamageConfig.DefaultMultiplier,
        enabled = true
    }
end

MSWeaponDamageConfig.Weapons = {
    -- Unbewaffnet
    weapon('unarmed', 'WEAPON_UNARMED', 1.00),

    -- Messer, Macheten und sonstige Nahkampfwaffen
    weapon('melee', 'WEAPON_MELEE_HATCHET_MELEEONLY', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_MINER', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_JAWBONE', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_VAMPIRE', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_JOHN', 1.00),
    weapon('melee', 'WEAPON_MELEE_MACHETE', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_BEAR', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_DUTCH', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_KIERAN', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_UNCLE', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_SEAN', 1.00),
    weapon('melee', 'WEAPON_MELEE_TORCH', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_LENNY', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_SADIE', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_CHARLES', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_HOSEA', 1.00),
    weapon('melee', 'WEAPON_MELEE_TORCH_CROWD', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_BILL', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_CIVIL_WAR', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_MICAH', 1.00),
    weapon('melee', 'WEAPON_MELEE_BROKEN_SWORD', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_JAVIER', 1.00),
    weapon('melee', 'WEAPON_MELEE_HAMMER', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_RUSTIC', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_HORROR', 1.00),
    weapon('melee', 'WEAPON_MELEE_KNIFE_TRADER', 1.00),
    weapon('melee', 'WEAPON_MELEE_MACHETE_HORROR', 1.00),
    weapon('melee', 'WEAPON_MELEE_MACHETE_COLLECTOR', 1.00),

    -- Pistolen
    weapon('pistol', 'WEAPON_PISTOL_VOLCANIC', 1.00),
    weapon('pistol', 'WEAPON_PISTOL_MAUSER_DRUNK', 1.00),
    weapon('pistol', 'WEAPON_PISTOL_M1899', 1.00),
    weapon('pistol', 'WEAPON_PISTOL_SEMIAUTO', 1.00),
    weapon('pistol', 'WEAPON_PISTOL_MAUSER', 1.00),

    -- Repetierer
    weapon('repeater', 'WEAPON_REPEATER_EVANS', 1.00),
    weapon('repeater', 'WEAPON_REPEATER_CARBINE_SADIE', 1.00),
    weapon('repeater', 'WEAPON_REPEATER_HENRY', 1.00),
    weapon('repeater', 'WEAPON_REPEATER_WINCHESTER', 1.00),
    weapon('repeater', 'WEAPON_REPEATER_WINCHESTER_JOHN', 1.00),
    weapon('repeater', 'WEAPON_REPEATER_CARBINE', 1.00),

    -- Revolver
    weapon('revolver', 'WEAPON_REVOLVER_DOUBLEACTION_MICAH_DUALWIELD', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_DOUBLEACTION_MICAH', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_SCHOFIELD_CALLOWAY', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_DOUBLEACTION', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_MEXICAN', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_HOSEA_DUALWIELD', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_DOUBLEACTION_EXOTIC', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_SEAN', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_SADIE', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_DOUBLEACTION_JAVIER', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_LEMAT', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_SCHOFIELD_BILL', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_SCHOFIELD', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_SADIE_DUALWIELD', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_DOUBLEACTION_GAMBLER', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_KIERAN', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_SCHOFIELD_UNCLE', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_HOSEA', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_LENNY', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_JOHN', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_SCHOFIELD_DUTCH_DUALWIELD', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_SCHOFIELD_GOLDEN', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_CATTLEMAN_PIG', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_SCHOFIELD_DUTCH', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_NAVY', 1.00),
    weapon('revolver', 'WEAPON_REVOLVER_NAVY_CROSSOVER', 1.00),

    -- Gewehre
    weapon('rifle', 'WEAPON_RIFLE_SPRINGFIELD', 1.00),
    weapon('rifle', 'WEAPON_RIFLE_BOLTACTION', 1.00),
    weapon('rifle', 'WEAPON_RIFLE_BOLTACTION_BILL', 1.00),
    weapon('rifle', 'WEAPON_RIFLE_VARMINT', 1.00),
    weapon('rifle', 'WEAPON_RIFLE_ELEPHANT', 1.00),

    -- Schrotflinten
    weapon('shotgun', 'WEAPON_SHOTGUN_SAWEDOFF', 1.00),
    weapon('shotgun', 'WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC', 1.00),
    weapon('shotgun', 'WEAPON_SHOTGUN_PUMP', 1.00),
    weapon('shotgun', 'WEAPON_SHOTGUN_REPEATING', 1.00),
    weapon('shotgun', 'WEAPON_SHOTGUN_SEMIAUTO', 1.00),
    weapon('shotgun', 'WEAPON_SHOTGUN_DOUBLEBARREL', 1.00),
    weapon('shotgun', 'WEAPON_SHOTGUN_DOUBLEBARREL_UNCLE', 1.00),
    weapon('shotgun', 'WEAPON_SHOTGUN_SAWEDOFF_CHARLES', 1.00),
    weapon('shotgun', 'WEAPON_SHOTGUN_SEMIAUTO_HOSEA', 1.00),

    -- Scharfschützengewehre
    weapon('sniper', 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK_LENNY', 1.00),
    weapon('sniper', 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK_EXOTIC', 1.00),
    weapon('sniper', 'WEAPON_SNIPERRIFLE_CARCANO', 1.00),
    weapon('sniper', 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK', 1.00),

    -- Bögen
    weapon('bow', 'WEAPON_BOW_CHARLES', 1.00),
    weapon('bow', 'WEAPON_BOW', 1.00),
    weapon('bow', 'WEAPON_BOW_IMPROVED', 1.00),

    -- Äxte und Wurfwaffen
    weapon('thrown', 'WEAPON_MELEE_HATCHET', 1.00),
    weapon('thrown', 'WEAPON_MELEE_HATCHET_HEWING', 1.00),
    weapon('thrown', 'WEAPON_MELEE_ANCIENT_HATCHET', 1.00),
    weapon('thrown', 'WEAPON_MELEE_HATCHET_HUNTER', 1.00),
    weapon('thrown', 'WEAPON_THROWN_THROWING_KNIVES_JAVIER', 1.00),
    weapon('thrown', 'WEAPON_THROWN_MOLOTOV', 1.00),
    weapon('thrown', 'WEAPON_MELEE_HATCHET_VIKING', 1.00),
    weapon('thrown', 'WEAPON_THROWN_TOMAHAWK_ANCIENT', 1.00),
    weapon('thrown', 'WEAPON_MELEE_HATCHET_DOUBLE_BIT_RUSTED', 1.00),
    weapon('thrown', 'WEAPON_THROWN_TOMAHAWK', 1.00),
    weapon('thrown', 'WEAPON_THROWN_DYNAMITE', 1.00),
    weapon('thrown', 'WEAPON_MELEE_HATCHET_DOUBLE_BIT', 1.00),
    weapon('thrown', 'WEAPON_THROWN_THROWING_KNIVES', 1.00),
    weapon('thrown', 'WEAPON_MELEE_HATCHET_HUNTER_RUSTED', 1.00),
    weapon('thrown', 'WEAPON_MELEE_CLEAVER', 1.00),
    weapon('thrown', 'WEAPON_THROWN_POISONBOTTLE', 1.00),
    weapon('thrown', 'WEAPON_THROWN_BOLAS', 1.00),
    weapon('thrown', 'WEAPON_THROWN_BOLAS_HAWKMOTH', 1.00),
    weapon('thrown', 'WEAPON_THROWN_BOLAS_IRONSPIKED', 1.00),
    weapon('thrown', 'WEAPON_THROWN_BOLAS_INTERTWINED', 1.00),
    weapon('thrown', 'WEAPON_MOONSHINEJUG', 1.00),
    weapon('thrown', 'WEAPON_MOONSHINEJUG_MP', 1.00),

    -- Werkzeuge und nicht-tödliche Ausrüstung. Die Einträge sind vollständig
    -- enthalten; einige Spielobjekte besitzen von sich aus keinen Schaden.
    weapon('utility', 'WEAPON_MELEE_LANTERN', 1.00),
    weapon('utility', 'WEAPON_MELEE_DAVY_LANTERN', 1.00),
    weapon('utility', 'WEAPON_MELEE_LANTERN_ELECTRIC', 1.00),
    weapon('utility', 'WEAPON_KIT_BINOCULARS', 1.00),
    weapon('utility', 'WEAPON_KIT_BINOCULARS_IMPROVED', 1.00),
    weapon('utility', 'WEAPON_KIT_CAMERA', 1.00),
    weapon('utility', 'WEAPON_KIT_CAMERA_ADVANCED', 1.00),
    weapon('utility', 'WEAPON_KIT_DETECTOR', 1.00),
    weapon('utility', 'WEAPON_KIT_METAL_DETECTOR', 1.00),
    weapon('utility', 'WEAPON_FISHINGROD', 1.00),
    weapon('utility', 'WEAPON_LASSO', 1.00),
    weapon('utility', 'WEAPON_LASSO_REINFORCED', 1.00)
}
