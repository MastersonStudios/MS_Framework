fx_version 'cerulean'
game 'rdr3'

author 'Masterson Studios'
description 'Proximity-based /me roleplay chat for Frontier Framework'
version '1.0.0'

lua54 'yes'

shared_script 'config.lua'
server_script 'server/main.lua'
client_script 'client/main.lua'

dependencies {
    '/server:7290',
    '/onesync',
    'frontier_core'
}

server_export 'SendAction'
client_export 'IsDisplayingActions'
