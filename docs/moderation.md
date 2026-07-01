---
sidebar_position: 5
---

# Moderation & filtering

Bold filters in layers, split by whether delivery waits on them.

## The pipeline

```
fast (blocking, authoritative, cached):
    Roblox TextService  →  local HardBlockFilter
        → sets the delivered text; everything renders from this

deferred (non-blocking, best-effort):
    PurgoMalum
        → runs AFTER the message is on screen; patches it in place if it
          catches more (via an UPDATE channel)

client backstop:
    HardBlockFilter runs again at render — "filter on our side too"
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

## The hard-block list

`HardBlockFilter` is a narrow local backstop layered on top of TextService (not a replacement). It normalizes text before matching — collapsing spacing/punctuation and mapping leetspeak — so `f u c k`, `f.u.c.k` and `5h1t`-style obfuscation are caught, with masking projected back onto the original text.

Extend it at runtime:

```lua
Bold.AddBlockedWords({ "myword", "anotherone" })
```

Keep the list narrow: matching is substring-based, so it's only safe for words that never legitimately appear inside other words. TextService remains the authoritative layer.

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
