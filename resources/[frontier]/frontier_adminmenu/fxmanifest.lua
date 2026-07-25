fx_version 'cerulean'
game 'rdr3'

author 'Frontier Framework'
description 'Graphical and server-secured administration menu'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    '/onesync',
    'frontier_core'
}
