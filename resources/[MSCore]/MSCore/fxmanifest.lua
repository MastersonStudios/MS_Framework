fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'MSCore'
description 'Independent, modular RedM core framework by Masterson Studios'
author 'Masterson Studios'
version '0.1.0'
repository 'https://github.com/MastersonStudios/MS_Framework'

shared_scripts {
    'config.lua',
    'shared/utils.lua'
}

client_scripts {
    'client/callbacks.lua',
    'client/main.lua',
    'client/spawn.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/callbacks.lua',
    'server/classes/character.lua',
    'server/classes/player.lua',
    'server/core.lua',
    'server/lifecycle.lua',
    'server/commands.lua'
}

dependency 'oxmysql'
