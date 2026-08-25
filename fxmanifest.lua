fx_version 'cerulean'
game 'common'

name 'topstats'
author 'TopStats'
description 'Official TopStats Analytics integration for FiveM servers.'
repository 'https://github.com/top-stats/analytics-fivem-integration'

lua54 'yes'
server_only 'yes'

server_scripts {
    'server/topstats.lua',
    'server/main.lua',
}
