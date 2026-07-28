fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Masterson Studios'
description 'Central health, hunger, thirst and temperature HUD for MSCore Framework'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

shared_script 'config.lua'
client_script 'client/main.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    '/server:7290',
    'MSCore',
    'MS_BasicNeeds'
}

client_exports {
    'GetHudStatus',
    'SetHudVisible',
    'IsHudVisible'
}
