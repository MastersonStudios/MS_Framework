fx_version 'cerulean'
game 'rdr3'

author 'Masterson Studios'
description 'Preview clothing shop with cart purchases for Frontier Framework'
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
    'frontier_core',
    'MS_Inventory'
}

client_export 'IsShopOpen'
