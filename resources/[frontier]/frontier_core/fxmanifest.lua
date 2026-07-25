fx_version 'cerulean'
game 'rdr3'

author 'Frontier Framework'
description 'Standalone RedM roleplay core'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config.lua',
    'shared/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

client_scripts {
    'client/*.lua'
}

dependencies {
    '/server:7290',
    'oxmysql'
}

server_export 'GetPlayer'
server_export 'GetPlayerFromCharacterId'
server_export 'GetPlayers'
