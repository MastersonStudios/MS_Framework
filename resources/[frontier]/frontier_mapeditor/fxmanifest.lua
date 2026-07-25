fx_version 'cerulean'
game 'rdr3'

author 'Frontier Framework'
description 'Persistent and secured RedM map editor'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    '/onesync',
    'oxmysql',
    'frontier_core'
}
