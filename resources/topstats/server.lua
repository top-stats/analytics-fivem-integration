-- TopStats integration
-- Reads config from server.cfg:
--   set topstats_api_key "YOUR_API_KEY"
--   set topstats_source "fivem"   -- use "redm" on RedM servers

local apiKey = GetConvar('topstats_api_key', '')
local sourceLabel = GetConvar('topstats_source', 'fivem')

if apiKey == '' then
    print('^1[topstats] WARNING: topstats_api_key is not set in server.cfg. Events will not be sent.^0')
end

--- Sends a single event to TopStats.
--- @param name string        event name, e.g. "player_join"
--- @param properties table   key/value payload for the event
local function sendEvent(name, properties)
    if apiKey == '' then return end

    properties = properties or {}
    properties.mode = properties.mode or sourceLabel

    PerformHttpRequest('https://topstats.gg/v1/events', function(statusCode, response)
        if statusCode ~= 200 and statusCode ~= 201 and statusCode ~= 202 then
            print(('^1[topstats] event "%s" failed (%s): %s^0'):format(name, tostring(statusCode), tostring(response)))
        end
    end, 'POST', json.encode({
        name = name,
        properties = properties
    }), {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. apiKey
    })
end

-- Track connect time per player so we can compute session length on disconnect
local sessionStart = {}

-- Player joined. Inside this handler FiveM's global `source` is the
-- connecting player's server id, so we capture it into a local right away.
AddEventHandler('playerConnecting', function(playerName, _setKickReason, _deferrals)
    local playerId = tostring(source)
    sessionStart[playerId] = os.time()

    sendEvent('player_join', {
        playtime = 0
    })
end)

-- Player disconnected. Same rule: `source` is the disconnecting player's id.
AddEventHandler('playerDropped', function(reason)
    local playerId = tostring(source)
    local startedAt = sessionStart[playerId]
    local playtime = startedAt and (os.time() - startedAt) or 0
    sessionStart[playerId] = nil

    sendEvent('player_disconnect', {
        reason = reason,
        playtime = playtime
    })
end)