
fx_version "cerulean"
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
games {"rdr3"}
lua54 "yes"
version '1.0.06'

escrow_ignore {
    'fw_func.lua',
	'config.lua',
    'events.lua',
    'webhook.lua',
}

files {
    'not.js',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client.lua',
    'events.lua',
    'not.js'
}


server_scripts {
    'fw_func.lua',
    'server.lua',
    'webhook.lua',
}
dependency '/assetpacks'
dependency '/assetpacks-redm'