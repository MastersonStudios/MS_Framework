fx_version 'cerulean'
game 'rdr3'

author 'MSCore Framework'
description 'Administration Control Panel with support logs, permissions, world builder and crafting'
version '2.1.0'

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
    'MSCore',
    'MS_WorldBuilder'
}
