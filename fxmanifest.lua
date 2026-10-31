fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'discordbridge'
description 'Discord roles, names and avatars for FiveM, with role-based permissions'
version '1.0.0'
author 'IamZach'
discord 'https://discord.gg/agn'
repository 'https://github.com/1amZach/discordbridge'

server_scripts {
    'config.lua',
    'server/http.lua',
    'server/guild.lua',
    'server/members.lua',
    'server/aces.lua',
    'server/main.lua',
}
