MSBasicNeedsConfig = {}

MSBasicNeedsConfig.Enabled = true

-- Wertebereich und Startwerte eines neuen Charakters.
MSBasicNeedsConfig.Minimum = 0.0
MSBasicNeedsConfig.Maximum = 100.0
MSBasicNeedsConfig.Defaults = {
    hunger = 100.0,
    thirst = 100.0
}

-- Abzug pro Tick. Mit den Standardwerten dauert vollständiger Hungerabbau
-- etwa 2,5 Stunden und vollständiger Durstabbau etwa 1 Stunde 40 Minuten.
MSBasicNeedsConfig.TickIntervalMs = 60 * 1000
MSBasicNeedsConfig.Drain = {
    hunger = 0.65,
    thirst = 1.0
}

-- Zusätzlicher Sofort-DB-Save nach dieser Anzahl Ticks. Der Core speichert
-- schmutzige Charakterdaten unabhängig davon weiterhin in seinem Intervall.
MSBasicNeedsConfig.SaveEveryTicks = 5
MSBasicNeedsConfig.RequestCooldownMs = 1000

MSBasicNeedsConfig.Critical = {
    Threshold = 20.0,
    WarningIntervalTicks = 5,
    HungerMessage = 'Du solltest bald etwas essen.',
    ThirstMessage = 'Du solltest bald etwas trinken.',
    BothMessage = 'Du brauchst dringend Essen und Wasser.'
}

MSBasicNeedsConfig.Damage = {
    Enabled = true,
    Threshold = 0.0,
    AmountPerTick = 5,
    CanKill = false,
    MinimumHealth = 25,
    Message = 'Hunger und Durst schwächen dich.'
}

MSBasicNeedsConfig.Hud = {
    Enabled = true,
    Position = 'bottom-right', -- bottom-right, bottom-left, top-right, top-left
    OffsetX = 32,
    OffsetY = 36,
    Scale = 1.0,
    ShowLabels = true,
    ShowValues = true,
    HideInPauseMenu = true
}

-- Effekte werden ausgelöst, sobald ein nutzbares Item über MS_Inventory
-- konsumiert wurde. Weitere Essen- oder Getränkeitems können hier ergänzt
-- werden, sofern sie im Core-Itemkatalog als usable/consumable angelegt sind.
MSBasicNeedsConfig.Consumables = {
    water = {
        hunger = 0,
        thirst = 25
    },
    bread = {
        hunger = 20,
        thirst = 0
    }
}

MSBasicNeedsConfig.Debug = false
