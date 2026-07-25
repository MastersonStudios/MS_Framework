Config = {}

Config.Debug = false
Config.AutoCreateCharacter = false
Config.MaxCharacters = 3
Config.CharacterBirthDateMin = '1800-01-01'
Config.CharacterBirthDateMax = '1905-12-31'
Config.DefaultCharacter = {
    firstname = 'New',
    lastname = 'Citizen',
    sex = 'male',
    cash = 50,
    bank = 250,
    job = 'unemployed',
    jobGrade = 0,
    group = 'user'
}

Config.Spawn = vector4(-275.14, 805.09, 119.38, 282.0)
Config.SaveInterval = 60 * 1000
Config.IdentifierType = 'license'
Config.MaxItemStack = 100

Config.Items = {
    water = {
        label = 'Wasserflasche',
        description = 'Sauberes Trinkwasser.',
        maxStack = 20
    },
    bread = {
        label = 'Brot',
        description = 'Ein einfacher Reiseproviant.',
        maxStack = 20
    },
    bandage = {
        label = 'Verband',
        description = 'Medizinischer Verband zur Wundversorgung.',
        maxStack = 10
    },
    lockpick = {
        label = 'Dietrich',
        description = 'Ein empfindliches Werkzeug für Schlösser.',
        maxStack = 10
    }
}

Config.Jobs = {
    unemployed = {
        label = 'Arbeitslos',
        grades = {
            [0] = { label = 'Bürger', salary = 0 }
        }
    },
    sheriff = {
        label = 'Sheriff',
        grades = {
            [0] = { label = 'Deputy', salary = 5 },
            [1] = { label = 'Sheriff', salary = 10 }
        }
    }
}
