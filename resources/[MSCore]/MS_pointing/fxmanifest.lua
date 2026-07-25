fx_version 'cerulean'
game 'rdr3'

author 'Masterson Studios'
description 'Configurable finger-pointing gesture for MSCore Framework'
version '1.0.0'

lua54 'yes'

shared_script 'config.lua'
client_script 'client/main.lua'

dependency 'MSCore'

client_exports {
    'StartPointing',
    'CanPoint',
    'IsPointing'
}
