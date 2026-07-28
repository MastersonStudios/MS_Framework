fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'MSCore Framework'
description 'Server-authoritative player presence synchronization for up to 64 players'
version '1.0.0'

lua54 'yes'

shared_script 'config.lua'

server_script 'server/main.lua'
client_script 'client/main.lua'

dependencies {
    '/server:7290',
    '/onesync',
    'MSCore'
}

server_exports {
    'GetPlayerState',
    'GetSnapshot',
    'GetSyncedPlayerCount'
}

client_exports {
    'GetPlayerState',
    'GetPlayers',
    'GetNearbyPlayers',
    'GetSyncedPlayerCount'
}
