fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'MSCore Framework'
description 'Admin character logout for MSCore Framework'
version '1.0.0'

lua54 'yes'

server_scripts {
    'config.lua',
    'server.lua'
}

dependency 'MSCore'
