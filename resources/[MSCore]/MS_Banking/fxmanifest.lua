fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'Masterson Studios'
description 'Persistent bank accounts and configurable banker NPCs for MSCore'
version '1.3.0'

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

server_exports {
    'GetAccount',
    'GetCompanyAccount',
    'GetAdminAccount',
    'OpenCompanySession',
    'CloseCompanySession',
    'CompanySessionDeposit',
    'CompanySessionWithdraw'
}

client_exports {
    'IsBankOpen'
}
