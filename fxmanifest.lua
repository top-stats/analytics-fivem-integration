fx_version 'cerulean'
-- 'common' covers both CitizenFX games: FiveM (GTA V) and RedM (RDR2). The
-- resource only touches server-side natives shared by both runtimes.
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
