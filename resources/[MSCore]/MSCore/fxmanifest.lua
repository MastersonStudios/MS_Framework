fx_version 'cerulean'
game 'rdr3'

author 'MSCore Framework'
description 'Standalone RedM roleplay core'
version '0.0.2'

lua54 'yes'

ui_page 'html/index.html'

shared_scripts {
    'config.lua',
    'shared/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/version.lua',
    'server/items.lua',
    'server/player.lua',
    'server/main.lua',
    'server/commands.lua'
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
server_export 'GetItem'
server_export 'GetItemCatalog'
server_export 'GetInventoryLimits'
server_export 'CreateItem'
server_export 'DeleteItem'
server_export 'LogoutPlayer'
server_export 'GetFrameworkVersion'
server_export 'GetFrameworkVersionState'
server_export 'CheckFrameworkVersion'
