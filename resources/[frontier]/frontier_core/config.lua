Config = {}

Config.Debug = false
Config.AutoCreateCharacter = true
Config.MaxCharacters = 3
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
