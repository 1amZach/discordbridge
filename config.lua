Config = {}

-- The bot token is read from a convar so it never ends up in a file you share:
--   set discordbridge_token "your-bot-token"
Config.tokenConvar = 'discordbridge_token'

-- Discord servers to read from. The first one is used when a function isn't told which.
-- Right click your server icon -> Copy Server ID (turn on Developer Mode first).
Config.guilds = {
    { name = 'main', id = '000000000000000000' },
}

-- How often online players' roles are checked again, in minutes.
Config.refreshMinutes = 5

-- How long the guild's role list and info are cached, in minutes.
Config.guildCacheMinutes = 10

-- Turn Discord roles into FiveM permissions. While a player has the role they get the group,
-- and lose it as soon as the role is removed (on the next refresh).
-- Roles can be names or ids. Needs (in server.cfg):
--   add_ace resource.discordbridge command.add_principal allow
--   add_ace resource.discordbridge command.remove_principal allow
Config.aces = {
    -- ['Staff'] = 'group.admin',
    -- ['123456789012345678'] = 'group.vip',
}

-- Refuse connections from players without Discord linked, or who aren't in the first guild.
Config.requireDiscord = false
Config.requireMember = false

-- Put the player's Discord name, avatar and role ids on Player(source).state.discord,
-- replicated so client scripts (HUDs, scoreboards) can read them too.
Config.stateBag = false

Config.debug = false

Config.messages = {
    checking = 'Checking your Discord...',
    noDiscord = 'Link your Discord to FiveM to join this server. Open FiveM settings, then Accounts.',
    notMember = 'Join our Discord before connecting.',
}
