# TopStats for FiveM

The official TopStats Analytics resource for FiveM servers. Player connects,
drops with session length, and a server stats heartbeat land in your TopStats
workspace as events, attributed per player - plus an export so any resource
can track its own events through the same buffered client.

Runs entirely server-side. No client script, no chat, no positions, no
message content of any kind.

## Install

1. Drop this resource into your server's `resources/` folder as `topstats`.

2. Create an API key in your TopStats workspace (Settings -> API keys) and
   add to `server.cfg`:

   ```cfg
   set topstats_api_key "ts_live_your_key_here"
   ensure topstats
   ```

3. Restart. Connects, drops, and server stats appear in your workspace
   within seconds.

## What gets sent

| Event | Properties | When |
| --- | --- | --- |
| `player_connected` | | A player joins. |
| `player_dropped` | `reason`, `session_seconds` | A player leaves. |
| `server_stats` | `players_online`, `max_players`, `resources`, `uptime_seconds` | Every `topstats_heartbeat_seconds` (default 60). |

Players are identified by their `license` identifier, so the same person is
the same actor across sessions and server restarts; their current name rides
along as the display label.

## Track your own events

Any resource on the server can post through the same buffered client:

```lua
exports.topstats:track('mission_completed', { payout = 500 }, {
    actor = GetPlayerIdentifierByType(source, 'license'),
    actor_label = GetPlayerName(source),
})
```

`track(name, properties, context)` never raises, batches with everything
else, and retries transient failures. `exports.topstats:flush()` sends the
buffer immediately.

## Configuration

All via convars in `server.cfg`:

| Convar | Default | What it does |
| --- | --- | --- |
| `topstats_api_key` | required | Your workspace API key. |
| `topstats_host` | `https://topstats.gg` | API origin override. |
| `topstats_source` | `fivem` | The `_source` label on every event. |
| `topstats_events_sessions` | `true` | Player connect and drop events. |
| `topstats_heartbeat_seconds` | `60` | Seconds between `server_stats`. 0 disables. |
| `topstats_flush_at` | `20` | Buffered events that trigger a send. |
| `topstats_flush_seconds` | `5` | Timer flush period. |

## How it works

The wire client is the [TopStats Lua SDK](https://github.com/top-stats/analytics-lua-sdk),
vendored into `server/topstats.lua` with FiveM's natives injected:
`PerformHttpRequest` for HTTP, `SetTimeout` for timers, the built-in `json`
for encoding. Batching, retries with backoff, and the drop-oldest queue are
the SDK's, tested in its own CI on the exact Lua version FiveM runs.

Full product documentation: <https://docs.topstats.gg/docs/analytics>
