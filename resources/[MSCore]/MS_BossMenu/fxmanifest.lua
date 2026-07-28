fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Masterson Studios'
description 'Configurable duty tracking, job boss points and company management for MSCore'
version '1.1.0'

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
    'MSCore',
    'MS_Banking'
}

client_export 'IsBossMenuOpen'
