fx_version 'cerulean'
game 'rdr3'

author 'Frontier Framework'
description 'Standalone RedM roleplay core'
version '1.2.0'

lua54 'yes'

ui_page 'html/index.html'

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

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    '/server:7290',
    'oxmysql'
}

server_export 'GetPlayer'
server_export 'GetPlayerFromCharacterId'
server_export 'GetPlayers'
server_export 'LogoutPlayer'
