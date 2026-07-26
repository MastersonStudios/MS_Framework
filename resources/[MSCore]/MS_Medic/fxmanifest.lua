fx_version 'cerulean'
game 'rdr3'

author 'Masterson Studios'
description 'Diseases, treatments, unconsciousness and Medic emergencies for MSCore Framework'
version '1.1.0'

lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/unconscious.lua'
}

client_scripts {
    'client/main.lua',
    'client/unconscious.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    '/server:7290',
    '/onesync',
    'oxmysql',
    'MSCore',
    'MS_BasicNeeds'
}

server_exports {
    'GetDiseases',
    'AddDisease',
    'RemoveDisease',
    'IsMedic',
    'GetUnconsciousState',
    'IsUnconscious'
}

client_exports {
    'GetDiseases',
    'HasDisease',
    'IsMedicMenuOpen',
    'GetUnconsciousState',
    'IsUnconscious'
}
