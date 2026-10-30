Aces = {}

local applied = {} -- server id -> { [group] = true }

-- which groups a set of role ids should grant
function Aces.wanted(roles)
    local have, groups = {}, {}
    for _, r in ipairs(roles or {}) do have[r] = true end

    for role, group in pairs(Config.aces) do
        local id = Guild.roleId(role)
        if id and have[id] then groups[group] = true end
    end

    return groups
end

local function principal(cmd, src, group)
    ExecuteCommand(('%s player.%d %s'):format(cmd, src, group))
    Http.debug(cmd, src, group)
end

function Aces.sync(src, roles)
    if next(Config.aces) == nil then return end

    local want = Aces.wanted(roles)
    local have = applied[src] or {}

    for group in pairs(want) do
        if not have[group] then principal('add_principal', src, group) end
    end

    for group in pairs(have) do
        if not want[group] then principal('remove_principal', src, group) end
    end

    applied[src] = want
end

function Aces.clear(src)
    for group in pairs(applied[src] or {}) do
        principal('remove_principal', src, group)
    end
    applied[src] = nil
end

function Aces.clearAll()
    for src in pairs(applied) do Aces.clear(src) end
end
