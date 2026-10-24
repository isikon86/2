-- fks-deadmoon · Copyright (C) 2026 FKS · Licensed under the GNU GPL v3 or later (see LICENSE)
fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'fks-deadmoon'
author 'FKS'
description 'TEOT zombie tiers, rare jumper knockdowns, tier-based corpse loot and guarded city population; no scripted medical effects'
version '1.6.9'
license 'GPL-3.0-or-later'

shared_scripts {
    'config.lua',
    'locales/*.lua',
    'shared/locale.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/bridge.lua',
    'client/main.lua',
    'client/weather.lua',
    'client/zombies.lua',
    'client/tier_combat.lua',
    'client/loot.lua',
    'client/sounds.lua',
}

server_scripts {
    'server/bridge.lua',
    'server/main.lua',
    'server/city_population.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/sound.js',
    'sounds/*.wav',
    'sounds/*.mp3',
    'sounds/*.ogg',
}

-- + a framework (vorp_core or rsg-core) and an inventory (vorp_inventory, rsg-inventory or ox_inventory)
