fx_version 'cerulean'
game 'gta5'

name 'meteo-clothingcapture'
description 'Clothing image capture tool for meteo-appearance'
author 'Meteo Studios'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.js'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
}

dependency 'screencapture'

lua54 'yes'