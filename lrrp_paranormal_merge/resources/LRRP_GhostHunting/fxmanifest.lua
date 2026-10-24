fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'LRRP Studio'
description 'LRRP Ghost Hunting FREE - Case 1 paranormal investigation'
version '0.1.24'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/journal_book.png',
    'html/assets/dialogue_ui.png',
    'inventory_images/*.png',
    'data/progress.json'
}

dependency '/assetpacks'
dependency '/assetpacks-redm'