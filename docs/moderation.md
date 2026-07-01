---
sidebar_position: 6
---

# Moderation & filtering

Bold filters in layers, split by whether delivery waits on them.

## The pipeline

```
fast (blocking, authoritative, cached):
    Roblox TextService → sets the delivered text; everything renders from this

deferred (non-blocking, best-effort):
    PurgoMalum
        → runs AFTER the message is on screen; patches it in place if it
          catches more (via an UPDATE channel)

Advise (local word list): WARN-ONLY
    → powers the live input warning pill; it never masks message text.
```

Because delivery only ever waits on the fast, cached layers, a slow or down third-party service can never stall chat. The deferred pass edits the already-visible message a beat later if needed.

Only Roblox's TextService actually edits what's shown. Advise's local word list is used purely to **warn** the sender as they type (it never masks or drops), so it can't false-positive its way into censoring real words.

Crucially, the client sends **raw text** and parses the **filtered** text at render time — the filter always governs what is shown.

## Configuring it

```lua
Bold.Configure({
    filter = {
        enabled = true,        -- master switch
        purgomalum = true,     -- run the deferred third-party pass
        rate_limit = 5,        -- anti-spam: max messages...
        rate_window = 4,       -- ...per this many seconds, per player (0 disables)
    },
})
```

`purgomalum` uses [purgomalum.com](https://www.purgomalum.com) and is fail-open — any error or timeout leaves the text unchanged. It needs *Allow HTTP Requests* enabled; turn it off if you don't want the dependency.

## Advise & the word list

`Advise` is a **warn-only** local word list layered alongside TextService. It normalizes text before matching — collapsing spacing/punctuation, mapping leetspeak, and treating interior vowels as optional — so `f u c k`, `f.u.c.k`, `f0ck` and vowel-dropped `fck` are detected. It does **not** mask or drop anything; it only lights the input warning pill so the sender knows their message will likely be filtered. (Roblox's TextService does the actual masking.) An allow-list handles Scunthorpe-style exceptions.

Its list (a few thousand words) is sourced from **Proflis** as JSON *data*, not as string literals in any script — so Roblox's automated moderation never flags Bold's own source. The server fetches the list once over HttpService and relays it to clients through a RemoteFunction.

:::caution Enable HttpService for the full experience
Proflis fetches the word list over `HttpService:GetAsync`. If HTTP is disabled the local list is simply **empty** and Bold falls back to Roblox's TextService filter alone — everything still works, just with a smaller backstop. Turn on **Game Settings → Security → Allow HTTP Requests** to get the full local filter (and the same is required for the PurgoMalum layer).
:::

Extend or refine which words *warn* at runtime:

```lua
Bold.AddBlockedWords({ "myword", "anotherone" })  -- warn on these
Bold.AddAllowedWords({ "assassin", "class" })     -- never warn on these
```

## Rate limiting

Spam is capped per player, server-side — at most `rate_limit` messages per `rate_window` seconds. Over that, the message is dropped and `MessageDropped` fires with reason `"rate_limit"`.

```lua
Bold.Configure({ filter = { rate_limit = 5, rate_window = 4 } }) -- 0 disables
```

## Dropping messages

For custom rules, install a guard. Returning `false` drops the message before delivery.

```lua
-- server
Bold.Guard(function(message, player)
    if isMuted(player) then return false end
    return true
end)
```

The live input box also shows a warning pill the moment a locally-known blocked word is typed, before the player even sends.
