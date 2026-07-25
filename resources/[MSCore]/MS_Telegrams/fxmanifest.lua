fx_version 'cerulean'
game 'rdr3'

author 'Masterson Studios'
description 'Persistent telegram messaging with character-bound numbers for MSCore Framework'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_script 'client/main.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    '/server:7290',
    '/onesync',
    'oxmysql',
    'MSCore'
}

server_export 'GetTelegramNumber'
client_export 'IsTelegramOpen'
