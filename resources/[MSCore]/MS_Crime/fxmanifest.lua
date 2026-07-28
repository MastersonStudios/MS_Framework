fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Masterson Studios'
description 'Crime job robbery and Van Horn access control for MSCore Framework'
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
    '/onesync',
    'MSCore'
}

server_exports {
    'IsRestrained',
    'SetRestrained'
}

client_export 'IsCrimeUiOpen'
