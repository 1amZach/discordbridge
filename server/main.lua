local main = function() return Config.guilds[1] and Config.guilds[1].id end

-- the shape other resources get back
local function view(member, guild)
    if not member then return nil end

    local guildId = Guild.resolve(guild) or main()
    local g = member.guilds[guildId] or { member = false, roles = {} }

    local names = {}
    for i, role in ipairs(g.roles) do names[i] = Guild.roleName(role, guildId) or role end

    return {
        id = member.id,
        name = g.nick or member.name,
        username = member.username,
        globalName = member.name,
        nick = g.nick,
        avatar = g.avatar or member.avatar,
        member = g.member,
        roles = g.roles,
        roleNames = names,
        joined = g.joined,
    }
end

local function publish(src, member)
    if not Config.stateBag then return end
    local v = view(member)
    Player(src).state:set('discord', v and {
        id = v.id, name = v.name, avatar = v.avatar, roles = v.roles,
    } or nil, true)
end

-- runs whenever a member is loaded or refreshed for an online player
local function settle(src, member, old)
    local roles = member and member.guilds[main()] and member.guilds[main()].roles or {}

    Aces.sync(src, roles)
    publish(src, member)

    if old == nil then
        TriggerEvent('discordbridge:memberLoaded', src, view(member))
        return
    end

    local added, removed = Members.diff(old, roles)
    if #added > 0 or #removed > 0 then
        TriggerEvent('discordbridge:rolesChanged', src, added, removed)
    end
end

local function rolesOf(member)
    local g = member and member.guilds[main()]
    return g and g.roles or {}
end

-- ---------------------------------------------------------------- joining

AddEventHandler('playerConnecting', function(_, _, deferrals)
    if not Config.requireDiscord and not Config.requireMember then return end

    local src = source
    deferrals.defer()
    Wait(0)
    deferrals.update(Config.messages.checking)

    local discordId = Members.discordId(src)
    if not discordId then return deferrals.done(Config.messages.noDiscord) end

    if Config.requireMember then
        local member = Members.fetch(discordId)
        -- if Discord is down, let them in rather than locking the whole server out
        if member and not member.guilds[main()].member then
            return deferrals.done(Config.messages.notMember)
        end
    end

    deferrals.done()
end)

local function load(src)
    local discordId = Members.discordId(src)
    if not discordId then return end

    Members.attach(src, discordId)

    -- a check made while they were connecting is fresh enough to reuse
    local member = Members.cached(discordId)
    if not member or os.time() - member.fetched > 60 then
        member = Members.fetch(discordId) or member
    end

    if member then settle(src, member, nil) end
end

AddEventHandler('playerJoining', function()
    local src = source
    CreateThread(function() load(src) end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    Aces.clear(src)
    Members.detach(src)
end)

-- picks up everyone already online after a restart
CreateThread(function()
    for _, id in ipairs(GetPlayers()) do
        load(tonumber(id))
        Wait(100)
    end
end)

-- ---------------------------------------------------------------- refresh

CreateThread(function()
    while true do
        Wait(Config.refreshMinutes * 60000)

        for src in pairs(Members.online()) do
            if GetPlayerName(src) then
                local before = rolesOf(Members.forSrc(src))
                local member = Members.forSrc(src, true)
                if member then settle(src, member, before) end
                -- spread requests out instead of firing them all at once
                Wait(250)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then Aces.clearAll() end
end)

-- ---------------------------------------------------------------- exports
-- These can wait on Discord, so call them from a thread or an event handler.

exports('getMember', function(src, guild)
    return view(Members.forSrc(src), guild)
end)

exports('getRoles', function(src, guild)
    local v = view(Members.forSrc(src), guild)
    return v and v.roles or {}
end)

-- role can be a name, an id, or a list of either (true if they have any of them)
exports('hasRole', function(src, role, guild)
    local v = view(Members.forSrc(src), guild)
    if not v then return false end

    local have = {}
    for _, r in ipairs(v.roles) do have[r] = true end

    for _, wanted in ipairs(type(role) == 'table' and role or { role }) do
        local id = Guild.roleId(wanted, guild)
        if id and have[id] then return true end
    end

    return false
end)

exports('isMember', function(src, guild)
    local v = view(Members.forSrc(src), guild)
    return v and v.member or false
end)

exports('getName', function(src, guild)
    local v = view(Members.forSrc(src), guild)
    return v and v.name
end)

exports('getAvatar', function(src, guild)
    local v = view(Members.forSrc(src), guild)
    return v and v.avatar
end)

exports('getDiscordId', function(src)
    return Members.discordId(src)
end)

local function refresh(src)
    local before = rolesOf(Members.forSrc(src))
    local member = Members.forSrc(src, true)
    if member then settle(src, member, before) end
    return view(member)
end

exports('refresh', refresh)

exports('getGuild', function(guild)
    return Guild.info(guild)
end)

exports('getGuildRoles', function(guild)
    return Guild.roles(guild)
end)

exports('getRoleId', function(name, guild)
    return Guild.roleId(name, guild)
end)

local function modify(method, src, role, guild, reason)
    local discordId = Members.discordId(src)
    local guildId = Guild.resolve(guild)
    local roleId = Guild.roleId(role, guild)
    if not discordId or not guildId or not roleId then return false end

    local ok = Http.request(method, ('/guilds/%s/members/%s/roles/%s'):format(guildId, discordId, roleId), nil, reason)
    if ok then refresh(src) end
    return ok ~= nil
end

exports('addRole', function(src, role, guild, reason)
    return modify('PUT', src, role, guild, reason)
end)

exports('removeRole', function(src, role, guild, reason)
    return modify('DELETE', src, role, guild, reason)
end)

exports('setNickname', function(src, nick, guild, reason)
    local discordId = Members.discordId(src)
    local guildId = Guild.resolve(guild)
    if not discordId or not guildId then return false end

    local ok = Http.request('PATCH', ('/guilds/%s/members/%s'):format(guildId, discordId), { nick = nick }, reason)
    return ok ~= nil
end)

-- ---------------------------------------------------------------- console

local function reply(src, text)
    if src == 0 then print(text) else TriggerClientEvent('chat:addMessage', src, { args = { 'discordbridge', text } }) end
end

RegisterCommand('discordbridge', function(src, args)
    local action, target = args[1], tonumber(args[2])

    if action == 'roles' then
        for _, role in ipairs(Guild.roles()) do reply(src, ('%s  %s'):format(role.id, role.name)) end
    elseif (action == 'info' or action == 'refresh') and target and GetPlayerName(target) then
        local v = action == 'refresh' and refresh(target) or view(Members.forSrc(target))
        if not v then return reply(src, 'No Discord linked or Discord unreachable') end
        reply(src, ('%s (%s) member=%s roles: %s'):format(v.name or '?', v.id, tostring(v.member), table.concat(v.roleNames, ', ')))
    elseif action == 'guild' then
        local g = Guild.info()
        reply(src, g and ('%s: %s members, %s online'):format(g.name, g.members, g.online) or 'Discord unreachable')
    else
        reply(src, 'usage: discordbridge info <id> | refresh <id> | roles | guild')
    end
end, true)
