Http = {}

local API = 'https://discord.com/api/v10'
local TIMEOUT = 10000
local ATTEMPTS = 3

-- When each route (and Discord as a whole) is free to call again, in GetGameTimer() ms.
local buckets = {}
local globalUntil = 0

function Http.debug(...)
    if Config.debug then print('[discordbridge]', ...) end
end

-- Discord rate limits per route, with ids collapsed except the guild. Close enough to
-- their bucket rules that we wait before they'd tell us off.
function Http.route(method, path)
    local route = path
        :gsub('/members/%d+', '/members/:id')
        :gsub('/users/%d+', '/users/:id')
        :gsub('/roles/%d+', '/roles/:id')
        :gsub('%?.*$', '')
    return method .. ' ' .. route
end

local function lowerKeys(t)
    local out = {}
    for k, v in pairs(t or {}) do out[tostring(k):lower()] = v end
    return out
end

local function send(method, url, body, headers)
    local p, done = promise.new(), false

    PerformHttpRequest(url, function(status, data, resHeaders)
        if done then return end
        done = true
        p:resolve({ status = status, body = data, headers = lowerKeys(resHeaders) })
    end, method, body or '', headers)

    -- PerformHttpRequest has no timeout of its own, don't let a caller hang forever
    SetTimeout(TIMEOUT, function()
        if done then return end
        done = true
        p:resolve({ status = 0, headers = {} })
    end)

    return Citizen.Await(p)
end

local function decode(raw)
    if not raw or raw == '' then return nil end
    local ok, value = pcall(json.decode, raw)
    return ok and value or nil
end

-- Remember how long to back off, from either the headers or a 429 body.
function Http.learn(route, res, now)
    local h = res.headers or {}

    if h['x-ratelimit-remaining'] == '0' and tonumber(h['x-ratelimit-reset-after']) then
        buckets[route] = now + tonumber(h['x-ratelimit-reset-after']) * 1000
    end

    if res.status == 429 then
        local body = decode(res.body) or {}
        local after = (tonumber(body.retry_after) or tonumber(h['retry-after']) or 1) * 1000

        if body.global or h['x-ratelimit-global'] then
            globalUntil = now + after
        else
            buckets[route] = now + after
        end
    end
end

function Http.waitFor(route, now)
    return math.max(globalUntil, buckets[route] or 0) - now
end

--[[
    Blocking request, call it from a thread. Returns the decoded body on success, or nil.
    The second return value is the HTTP status (0 for timeouts, -1 when there's no token).
]]
function Http.request(method, path, body, reason)
    local token = GetConvar(Config.tokenConvar, '')
    if token == '' then
        print(('[discordbridge] no bot token set. Add  set %s "your-token"  to server.cfg'):format(Config.tokenConvar))
        return nil, -1
    end

    local route = Http.route(method, path)
    local headers = { ['Authorization'] = 'Bot ' .. token, ['Content-Type'] = 'application/json' }
    if reason then headers['X-Audit-Log-Reason'] = reason end

    local res
    for _ = 1, ATTEMPTS do
        local wait = Http.waitFor(route, GetGameTimer())
        if wait > 0 then
            Http.debug(('waiting %dms for %s'):format(wait, route))
            Wait(wait)
        end

        res = send(method, API .. path, body and json.encode(body) or nil, headers)
        Http.learn(route, res, GetGameTimer())

        if res.status ~= 429 then break end
        Http.debug('rate limited on', route)
    end

    if res.status >= 200 and res.status < 300 then
        return decode(res.body) or true, res.status
    end

    if res.status ~= 404 then
        Http.debug(('%s %s failed with %s: %s'):format(method, path, res.status, res.body or ''))
    end

    return nil, res.status
end
