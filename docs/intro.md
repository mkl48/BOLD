---
sidebar_position: 1
---

# Introduction

Bold is a rich chat & messaging interface for Roblox. One `Bold.Start()` on each realm gives you a full messaging UI — an input box with autocomplete, a themeable message list, and a networking + filtering pipeline underneath.

The design principle is that **the filter governs what renders**. The client never pre-decides how a message looks; it sends raw text, the server filters authoritatively, and the receiving client parses the *filtered* text at render time. Profanity can't sneak through by being formatted client-side first.

```lua
-- server
local Bold = require(game.ReplicatedStorage.Bold)
Bold.Start()
```

```lua
-- client
local Bold = require(game.ReplicatedStorage.Bold)
Bold.Start({ interface = { channel_name = "Global" } })
```

## What you get

- **Markdown** — `**bold**`, `*italic*`, `__underline__`, `~~strike~~`, `` `code` ``, `||spoiler||`, `{color|text}`, `[links](url)`, `> quotes`, and `:emoji:`.
- **Real mentions** — `@Name` resolves to a player server-side, highlights in the message, flashes the mentioned player's card, and fires [`Bold.OnMentioned`](/api/Bold#OnMentioned).
- **Custom panels** — a `:::name … :::` fence renders a component you register with [`Bold.RegisterPanel`](/api/Bold#RegisterPanel).
- **Reactions & replies** — hover a message to react or quote-reply.
- **Slash commands** — register `/commands`; ships `/me`, `/shrug`, `/clear`, `/help` and `/incog` private whispers.
- **Deep customization** — one [`Bold.Configure`](/api/Bold#Configure) deep-merge over theme, density, layout, parsing, filtering, keybinds, animation and sounds.

## The pipeline

```
compose (client): raw text + embeds
  → local hard-block guard
  → server: stamp → fast filter (TextService + hard-block, cached) → deliver instantly
           → PurgoMalum (deferred, non-blocking) → patch in place if it catches more
  → client: hard-block backstop → parse filtered text → render
```

Delivery only ever waits on the fast, cached layers, so a slow third-party service can never stall chat.

Continue to [Getting started](./getting-started).
