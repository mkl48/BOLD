---
sidebar_position: 5
---

# Moderation & filtering

Bold filters in layers, split by whether delivery waits on them.

## The pipeline

```
fast (blocking, authoritative, cached):
    Roblox TextService  →  local Advise backstop
        → sets the delivered text; everything renders from this

deferred (non-blocking, best-effort):
    PurgoMalum
        → runs AFTER the message is on screen; patches it in place if it
          catches more (via an UPDATE channel)

client backstop:
    Advise runs again at render — "filter on our side too"
```

Because delivery only ever waits on the fast, cached layers, a slow or down third-party service can never stall chat. The deferred pass edits the already-visible message a beat later if needed.

Crucially, the client sends **raw text** and parses the **filtered** text at render time — the filter always governs what is shown.

## Configuring it

```lua
Bold.Configure({
    filter = {
        enabled = true,          -- master switch
        purgomalum = true,       -- run the deferred third-party pass
        client_backstop = true,  -- re-run the local hard-block at render
    },
})
```

`purgomalum` uses [purgomalum.com](https://www.purgomalum.com) and is fail-open — any error or timeout leaves the text unchanged. It needs *Allow HTTP Requests* enabled; turn it off if you don't want the dependency.

## Advise & the word list

`Advise` is the local backstop layered on top of TextService (not a replacement). It normalizes text before matching — collapsing spacing/punctuation, mapping leetspeak, and treating vowels as optional — so `f u c k`, `f.u.c.k`, `f0ck` and even vowel-dropped `fck` are caught, with masking projected back onto the original text. An allow-list handles Scunthorpe-style exceptions.

Its blocklist (a few thousand words) is sourced from **Proflis** as JSON *data*, not as string literals in any script — so Roblox's automated moderation never flags Bold's own source for the words it filters. The server fetches the list once over HttpService and relays it to clients through a RemoteFunction.

:::caution Enable HttpService for the full experience
Proflis fetches the word list over `HttpService:GetAsync`. If HTTP is disabled the local list is simply **empty** and Bold falls back to Roblox's TextService filter alone — everything still works, just with a smaller backstop. Turn on **Game Settings → Security → Allow HTTP Requests** to get the full local filter (and the same is required for the PurgoMalum layer).
:::

Extend or refine it at runtime:

```lua
Bold.AddBlockedWords({ "myword", "anotherone" })
Bold.AddAllowedWords({ "assassin", "class" })  -- never mask these
```

Keep additions narrow: matching is substring-based, so it's only safe for words that never legitimately appear inside other words. TextService remains the authoritative layer.

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
