fx_version 'cerulean'
game 'rdr3'

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
