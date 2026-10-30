Members = {}

-- Keyed by Discord id so a lookup made while someone is connecting is reused once they join.
local byId = {}   -- discord id -> member
local bySrc = {}  -- server id -> discord id

function Members.discordId(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        local discord = id:match('^discord:(%d+)$')
        if discord then return discord end
    end
end

-- Discord's fallback avatars are picked from the user id
local function defaultAvatar(id)
    local n = tonumber(id)
    return ('https://cdn.discordapp.com/embed/avatars/%d.png'):format(n and (n >> 22) % 6 or 0)
end

local function avatarUrl(userId, hash, guildId)
    if not hash then return nil end
    local ext = hash:sub(1, 2) == 'a_' and 'gif' or 'png'

    if guildId then
        return ('https://cdn.discordapp.com/guilds/%s/users/%s/avatars/%s.%s?size=256'):format(guildId, userId, hash, ext)
    end
    return ('https://cdn.discordapp.com/avatars/%s/%s.%s?size=256'):format(userId, hash, ext)
end

-- one guild's view of a member, or { member = false } when they aren't in it
local function fetchGuild(discordId, guildId)
    local data, status = Http.request('GET', ('/guilds/%s/members/%s'):format(guildId, discordId))

    if status == 404 then return { member = false, roles = {} } end
    if not data then return nil end

    return {
        member = true,
        roles = data.roles or {},
        nick = data.nick,
        avatar = avatarUrl(discordId, data.avatar, guildId),
        joined = data.joined_at,
        user = data.user,
    }
end

--[[
    Loads a member from every configured guild. Returns nil only when Discord couldn't be
    reached at all, in which case any older cached copy is kept.
]]
function Members.fetch(discordId)
    local member = { id = discordId, guilds = {}, fetched = os.time() }
    local user

    for _, g in ipairs(Config.guilds) do
        local view = fetchGuild(discordId, g.id)
        if not view then return nil end

        member.guilds[g.id] = view
        user = user or view.user
        view.user = nil
    end

    -- not in any guild means no user object came back, so ask for it directly
    if not user then
        user = Http.request('GET', ('/users/%s'):format(discordId))
    end

    if user then
        member.username = user.username
        member.name = user.global_name or user.username
        member.avatar = avatarUrl(discordId, user.avatar) or defaultAvatar(discordId)
    else
        member.avatar = defaultAvatar(discordId)
    end

    byId[discordId] = member
    return member
end

function Members.cached(discordId)
    return byId[discordId]
end

function Members.attach(src, discordId)
    bySrc[src] = discordId
end

function Members.detach(src)
    local id = bySrc[src]
    bySrc[src] = nil

    -- only forget the member when nobody else online uses the same account
    for _, other in pairs(bySrc) do
        if other == id then return end
    end
    if id then byId[id] = nil end
end

function Members.forSrc(src, refresh)
    local id = bySrc[src] or Members.discordId(src)
    if not id then return nil end

    bySrc[src] = id
    local member = byId[id]

    if refresh or not member then
        member = Members.fetch(id) or member
    end

    return member
end

function Members.online()
    return bySrc
end

-- what changed between two role lists
function Members.diff(old, new)
    local before, after = {}, {}
    for _, r in ipairs(old or {}) do before[r] = true end
    for _, r in ipairs(new or {}) do after[r] = true end

    local added, removed = {}, {}
    for r in pairs(after) do if not before[r] then added[#added + 1] = r end end
    for r in pairs(before) do if not after[r] then removed[#removed + 1] = r end end

    table.sort(added)
    table.sort(removed)
    return added, removed
end
