fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Masterson Studios'
description 'Configurable job-restricted and completely locked areas for MSCore'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config.lua',
    'shared/geometry.lua'
}

server_script 'server/main.lua'
client_script 'client/main.lua'

dependencies {
    '/server:7290',
    '/onesync',
    'MSCore'
}

server_exports {
    'GetPlayerArea',
    'IsPlayerAreaAuthorized',
    'RefreshPlayerArea'
}

client_exports {
    'GetCurrentArea',
    'IsCurrentAreaAuthorized'
}
