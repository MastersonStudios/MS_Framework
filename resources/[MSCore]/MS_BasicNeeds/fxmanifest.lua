fx_version 'cerulean'
game 'rdr3'

author 'Masterson Studios'
description 'Configurable hunger and thirst system for MSCore Framework'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    '/server:7290',
    'MSCore',
    'MS_Inventory'
}

server_exports {
    'GetNeeds',
    'SetNeeds',
    'AddNeed'
}

client_exports {
    'GetNeeds',
    'IsHudVisible'
}
