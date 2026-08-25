--- Wires the platform-agnostic core to FiveM: natives in, convars as
--- configuration, gameplay events out. Everything runs server-side; no
--- client script exists and no chat or position data is ever read.

local function convar(name, fallback)
    return GetConvar(name, fallback)
end

local function convar_number(name, fallback)
    local value = tonumber(GetConvar(name, tostring(fallback)))

    if value == nil then
        return fallback
    end

    return value
end

local function convar_flag(name, fallback)
    local value = GetConvar(name, fallback)
    return value ~= 'false' and value ~= '0' and value ~= 'off'
end

local platform = {
    http = function(url, body, headers, callback)
        PerformHttpRequest(url, function(status, response_body, response_headers)
            local retry_after = nil

            if type(response_headers) == 'table' then
                retry_after = response_headers['Retry-After'] or response_headers['retry-after']
            end

            callback(status or 0, response_body, retry_after)
        end, 'POST', body, headers)
    end,
    set_timeout = function(ms, fn)
        SetTimeout(ms, fn)
    end,
    now_iso = function()
        -- Second precision: FiveM Lua has no portable millisecond clock, and
        -- the API accepts the fraction-free Z form.
        return os.date('!%Y-%m-%dT%H:%M:%SZ')
    end,
    json_encode = function(value)
        local ok, encoded = pcall(json.encode, value)

        if not ok then
            return nil
        end

        return encoded
    end,
    log = function(message)
        print('^3[topstats]^7 ' .. message)
    end,
    random = function()
        return math.random()
    end,
}

local api_key = convar('topstats_api_key', '')

if api_key == '' then
    print('^3[topstats]^7 no topstats_api_key convar set - TopStats is disabled until you add one.'
        .. ' Create a key in your workspace under Settings -> API keys, then put'
        .. ' `set topstats_api_key "ts_live_..."` in server.cfg.')
    return
end

local core, problem = TopStatsCore.new(platform, {
    api_key = api_key,
    host = convar('topstats_host', ''),
    default_source = convar('topstats_source', 'fivem'),
    flush_at = convar_number('topstats_flush_at', 20),
    flush_seconds = convar_number('topstats_flush_seconds', 5),
})

if core == nil then
    print('^3[topstats]^7 ' .. tostring(problem))
    return
end

local track_sessions = convar_flag('topstats_events_sessions', 'true')
local heartbeat_seconds = convar_number('topstats_heartbeat_seconds', 60)
local started_at = os.time()
local joined_at = {}

--- The license identifier is the stable cross-session identity; server ids
--- recycle every restart. Falls back to the first identifier of any kind so
--- local test servers without licenses still attribute events.
local function actor_for(source_id)
    local license = GetPlayerIdentifierByType(source_id, 'license')

    if license ~= nil then
        return license
    end

    return GetPlayerIdentifier(source_id, 0)
end

local function context_for(source_id)
    local context = {}
    local actor = actor_for(source_id)

    if actor ~= nil then
        context.actor = actor
    end

    local name = GetPlayerName(source_id)

    if name ~= nil and name ~= '' then
        context.actor_label = name
    end

    return context
end

if track_sessions then
    AddEventHandler('playerJoining', function()
        local source_id = source
        joined_at[tostring(source_id)] = os.time()
        core:track('player_connected', nil, context_for(source_id))
    end)

    AddEventHandler('playerDropped', function(reason)
        local source_id = source
        local key = tostring(source_id)
        local properties = { reason = tostring(reason or 'unknown') }

        if joined_at[key] ~= nil then
            properties.session_seconds = math.max(0, os.time() - joined_at[key])
            joined_at[key] = nil
        end

        core:track('player_dropped', properties, context_for(source_id))
    end)
end

if heartbeat_seconds > 0 then
    local function heartbeat()
        SetTimeout(heartbeat_seconds * 1000, function()
            core:track('server_stats', {
                players_online = #GetPlayers(),
                max_players = convar_number('sv_maxclients', 0),
                resources = GetNumResources(),
                uptime_seconds = os.time() - started_at,
            })
            heartbeat()
        end)
    end

    heartbeat()
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        core:shutdown()
    end
end)

--- Other resources post their own events through the same buffered client:
---   exports.topstats:track('mission_completed', { payout = 500 }, {
---       actor = license, actor_label = playerName,
---   })
exports('track', function(name, properties, context)
    core:track(name, properties, context)
end)

--- Sends everything buffered immediately.
exports('flush', function()
    core:flush()
end)
