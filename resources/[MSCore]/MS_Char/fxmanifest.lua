fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MS_Char'
description 'Graphical character selection and creation for MSCore'
author 'Masterson Studios'
version '0.1.0'
repository 'https://github.com/MastersonStudios/MS_Framework'

ui_page 'ui/index.html'

shared_script 'config.lua'

client_script 'client/main.lua'
server_script 'server/main.lua'

files {
    'ui/index.html',
    'ui/styles.css',
    'ui/app.js'
}

dependency 'MSCore'
