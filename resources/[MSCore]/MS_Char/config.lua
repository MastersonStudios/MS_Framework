Config = {}

Config.Debug = false
Config.MinimumAge = 18
Config.MaximumAge = 90
Config.RoleplayDate = { year = 1899, month = 12, day = 31 }
Config.AllowDelete = true
Config.ActionCooldownSeconds = 1
Config.DescriptionMaxLength = 240
Config.ModelLoadTimeoutMs = 10000
Config.CollisionTimeoutMs = 8000

Config.BannedNames = {
    'admin',
    'administrator',
    'moderator',
    'rockstar',
    'arthur morgan'
}

Config.Models = {
    male = 'mp_male',
    female = 'mp_female'
}

Config.OutfitPresets = {
    { id = 3, label = 'Reisender' },
    { id = 4, label = 'Siedler' },
    { id = 5, label = 'Arbeiter' },
    { id = 6, label = 'Stadtbewohner' },
    { id = 7, label = 'Grenzland' }
}

Config.Preview = {
    position = vector4(-174.30, 621.18, 114.08, 240.38),
    camera = vector3(-170.90, 619.10, 115.35),
    cameraFov = 34.0
}

Config.Text = {
    title = 'CHARAKTERE',
    subtitle = 'Wähle dein nächstes Kapitel',
    create = 'Neuer Charakter',
    play = 'Spielen',
    delete = 'Löschen',
    deleteConfirm = 'Wirklich löschen?',
    back = 'Zurück',
    save = 'Charakter erstellen',
    firstname = 'Vorname',
    lastname = 'Nachname',
    dateOfBirth = 'Geburtsdatum',
    sex = 'Geschlecht',
    male = 'Männlich',
    female = 'Weiblich',
    outfit = 'Startbekleidung',
    description = 'Kurzbeschreibung',
    empty = 'Noch kein Charakter vorhanden.',
    slots = 'Charakterplätze',
    loading = 'Wird verarbeitet …',
    money = 'Dollar',
    rotateLeft = 'Nach links drehen',
    rotateRight = 'Nach rechts drehen'
}
