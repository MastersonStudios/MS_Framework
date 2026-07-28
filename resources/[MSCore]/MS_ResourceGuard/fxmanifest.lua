fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'MSCore Framework'
description 'Passive resource health monitor with anomaly scoring and safe quarantine'
version '1.0.0'

lua54 'yes'

shared_script 'config.lua'
server_script 'server/main.lua'

server_exports {
    'GetSnapshot',
    'RunCheck',
    'SetEnabled',
    'QuarantineResource',
    'ReleaseResource'
}
