# discordbridge

Discord roles, names and avatars for your FiveM server, and Discord roles that turn straight into FiveM permissions.

- **Roles become permissions.** Map a Discord role to an ace group and players get it while they have the role. Take the role away in Discord and they lose the group on the next refresh. No extra resource needed.
- **Built to survive a busy restart.** Every request goes through one queue that follows Discord's rate limits, waits and retries when it's told to slow down, and gives up after 10 seconds instead of hanging.
- **Cached properly.** A player's Discord data loads once when they join and refreshes every few minutes, so other scripts can ask as often as they like.
- **Events** when a member loads or their roles change, so scripts can react instead of polling.
- Look roles up by name or id, check several at once, add and remove roles, set nicknames, read guild info.
- Optional: only let in players with Discord linked, or only members of your Discord.
- Works with several Discord servers.
- No dependencies.

## Setup

1. Create a bot at the [Discord developer portal](https://discord.com/developers/applications) and invite it to your Discord with the `bot` scope. No privileged intents are needed.
2. If you want to add or remove roles or set nicknames, give the bot **Manage Roles** and **Manage Nicknames**, and drag its role above the roles it should manage.
3. In `server.cfg`, ensure it **before** anything that uses it:

```
set discordbridge_token "your-bot-token"

add_ace resource.discordbridge command.add_principal allow
add_ace resource.discordbridge command.remove_principal allow

ensure discordbridge
```

4. Put your Discord server id in `config.lua` (Developer Mode on, right click the server icon, Copy Server ID).

The token lives in a convar on purpose, so it never ends up in a file you upload or share.

## Roles as permissions

```lua
Config.aces = {
    ['Staff'] = 'group.admin',
    ['Server Booster'] = 'group.vip',
    ['123456789012345678'] = 'group.police',
}
```

Names are matched case-insensitively, ids always work. Anything that checks aces (txAdmin, ox_lib's `IsPlayerAceAllowed`, your own scripts) sees the group like any other.

## Exports

These can wait on Discord, so call them from a thread or an event handler. `guild` is optional everywhere and can be a configured name (`'main'`) or an id.

```lua
local bridge = exports.discordbridge

bridge:hasRole(source, 'Staff')                 -- name or id
bridge:hasRole(source, { 'Police', 'Sheriff' })  -- any of them
bridge:getRoles(source)                          -- { '123...', ... }
bridge:isMember(source)
bridge:getName(source)       -- server nickname, falling back to their Discord name
bridge:getAvatar(source)     -- image url
bridge:getDiscordId(source)
bridge:getMember(source)     -- everything below in one table

bridge:refresh(source)       -- fetch now instead of waiting for the next refresh
bridge:addRole(source, 'Whitelisted', nil, 'Passed the application')
bridge:removeRole(source, 'Whitelisted')
bridge:setNickname(source, 'Zach | LSPD')

bridge:getGuild()            -- { id, name, description, icon, members, online }
bridge:getGuildRoles()       -- every role, highest first
bridge:getRoleId('Staff')
```

`getMember` returns:

```lua
{
    id = '578733197366657025',
    name = 'Zach',          -- nickname or display name
    username = 'iamzach',
    globalName = 'IamZach',
    nick = 'Zach',
    avatar = 'https://cdn.discordapp.com/...',
    member = true,
    roles = { '123...', '456...' },
    roleNames = { 'Staff', 'Server Booster' },
    joined = '2024-01-31T15:10:25.000000+00:00',
}
```

## Events

```lua
AddEventHandler('discordbridge:memberLoaded', function(source, member)
    print(member.name .. ' joined with ' .. #member.roles .. ' roles')
end)

AddEventHandler('discordbridge:rolesChanged', function(source, added, removed)
    -- role ids, fired after a refresh notices a change
end)
```

## Client side

Set `Config.stateBag = true` and each player gets `Player(source).state.discord` with their id, name, avatar and role ids, readable from client scripts for HUDs and scoreboards.

## Console

```
discordbridge info <id>      roles and membership for an online player
discordbridge refresh <id>   fetch them again now
discordbridge roles          every role in the main Discord with its id
discordbridge guild          member and online counts
```

## Support

Made by **IamZach**. Questions, bugs or ideas: [discord.gg/agn](https://discord.gg/agn)

## License

MIT
