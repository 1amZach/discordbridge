Guild = {}

local cache = {} -- guild id -> { roles, byName, info, expires }

-- accepts a configured name ('main'), a raw guild id, or nil for the first guild
function Guild.resolve(guild)
    if guild == nil then return Config.guilds[1] and Config.guilds[1].id end

    guild = tostring(guild)
    for _, g in ipairs(Config.guilds) do
        if g.name == guild or g.id == guild then return g.id end
    end

    if guild:match('^%d+$') then return guild end
end

local function load(id)
    local entry = cache[id]
    if entry and entry.expires > os.time() then return entry end

    local roles = Http.request('GET', ('/guilds/%s/roles'):format(id))
    local info = Http.request('GET', ('/guilds/%s?with_counts=true'):format(id))

    -- keep the old copy if Discord is having a moment
    if not roles or not info then return entry end

    entry = { roles = {}, byName = {}, info = info, expires = os.time() + Config.guildCacheMinutes * 60 }

    for _, role in ipairs(roles) do
        entry.roles[role.id] = { id = role.id, name = role.name, color = role.color, position = role.position }
        entry.byName[role.name:lower()] = role.id
    end

    cache[id] = entry
    return entry
end

-- role name or id -> role id, nil if the guild doesn't have it
function Guild.roleId(role, guild)
    role = tostring(role)
    if role:match('^%d+$') then return role end

    local id = Guild.resolve(guild)
    local entry = id and load(id)
    return entry and entry.byName[role:lower()]
end

function Guild.roleName(roleId, guild)
    local id = Guild.resolve(guild)
    local entry = id and load(id)
    local role = entry and entry.roles[tostring(roleId)]
    return role and role.name
end

function Guild.roles(guild)
    local id = Guild.resolve(guild)
    local entry = id and load(id)
    if not entry then return {} end

    local list = {}
    for _, role in pairs(entry.roles) do list[#list + 1] = role end
    table.sort(list, function(a, b) return a.position > b.position end)
    return list
end

function Guild.info(guild)
    local id = Guild.resolve(guild)
    local entry = id and load(id)
    if not entry then return nil end

    local info = entry.info
    local icon = info.icon and ('https://cdn.discordapp.com/icons/%s/%s.%s?size=256')
        :format(id, info.icon, info.icon:sub(1, 2) == 'a_' and 'gif' or 'png')

    return {
        id = id,
        name = info.name,
        description = info.description,
        icon = icon,
        members = info.approximate_member_count,
        online = info.approximate_presence_count,
    }
end

function Guild.clear()
    cache = {}
end
