<div align="center">

<br />

# Bold

<img src="https://img.shields.io/badge/Bold-v0.1.0-6C3EF4?style=for-the-badge&logoColor=white" alt="version" />
<img src="https://img.shields.io/badge/Luau-Roblox-00A2FF?style=for-the-badge&logoColor=white" alt="luau" />
<img src="https://img.shields.io/badge/License-MIT-22c55e?style=for-the-badge" alt="license" />
<img src="https://img.shields.io/badge/Status-In%20Development-f59e0b?style=for-the-badge" alt="status" />
<img src="https://img.shields.io/badge/Plinko%20Labs-Built%20By-e11d48?style=for-the-badge" alt="plinko labs" />

<br />
<br />

**A rich chat & messaging interface for Roblox — markdown, real mentions, custom panels, reactions, replies and slash commands, behind a single `Bold.Start()`.**
**Part of the [Material Develop](https://github.com/mkl48/Material-Develop) suite by Plinko Labs.**

</div>

---

## Why Bold

Roblox's default chat is a black box. Rolling your own means re-solving the same problems every time: filtering that's actually authoritative, mention pings, an input box with autocomplete, markdown, and a theme you can bend. Bold is that layer — one `Start` call on each realm and you have a full messaging UI, with the pipeline built so **the filter governs what renders** and mentions genuinely ping the people they name.

- **Authoritative, fast filtering** — Roblox TextService + a local hard-block backstop deliver instantly; a third profanity pass runs *after* delivery and patches the message in place, so a slow service never stalls chat.
- **Real mentions** — `@Name` resolves server-side, highlights, flashes the mentioned player's card, and fires `Bold.OnMentioned`.
- **Custom panels** — type a `:::name … :::` fence and Bold renders a registered component (polls, stat cards, buttons — whatever you build).
- **Markdown that matters** — bold/italic/underline/strike/code, spoilers, `{color|text}`, links, blockquotes, emoji.
- **Reactions, replies, slash commands** — including `/incog <player> <message>` private whispers.
- **Customize like crazy** — one `Bold.Configure()` deep-merge over theme, density, layout, parsing, filtering, keys, animation and sounds, plus theme/layout presets.

---

## Installation

### Studio command bar (fastest)

Paste the bootstrap into the command bar (needs **Game Settings → Security → Allow HTTP Requests**):

```lua
loadstring(game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/mkl48/BOLD/main/dist/bootstrap.luau"))()
```

Or paste [`dist/install.luau`](dist/install.luau) directly. Either rebuilds `ReplicatedStorage.Bold`.

### Wally

```toml
[dependencies]
Bold = "kr3ative/bold@0.1.0"
```

Bold vendors its own dependencies (Promise, Signal, Substance, Switch), so there is nothing else to install.

---

## Quick start

**Server** — start Bold so it can receive, filter and broadcast:

```lua
local Bold = require(game.ReplicatedStorage.Bold)
Bold.Start()
```

**Client** — start Bold to build the UI and wire input:

```lua
local Bold = require(game.ReplicatedStorage.Bold)

Bold.Start({
    interface = { channel_name = "Global" },
})
Bold.Theme("midnight")

-- ping when you're mentioned
Bold.OnMentioned(function(message)
    print("you were mentioned:", message.content.raw_text)
end)
```

That's the whole loop. Players type in the box; `@names`, `:emoji:`, `**markdown**`, `||spoilers||`, `/commands` and `:::panels:::` all just work.

### Sending from code

```lua
-- quick path
Bold.Message({ content = { raw_text = "Welcome **home**, @Builderman :wave:" } })

-- fluent builder
Bold.Compose()
    :Text("nice shot ")
    :Mention(somePlayer)
    :Emoji("fire")
    :Send()

-- an embed
Bold.Message({
    content = { raw_text = "patch notes", embeds = { Bold.Image("rbxassetid://123") } },
})
```

### Custom panels

```lua
Bold.RegisterPanel("poll", function(args, message, theme)
    local frame = Instance.new("Frame")
    -- build your poll UI from args.question / args.options ...
    return frame
end)
```

A player (or you) then writes:

```
:::poll question="Best map?" options="A,B,C"
:::
```

### Slash commands

```lua
Bold.RegisterCommand("roll", {
    description = "Roll a die",
    handler = function(ctx)
        return { text = "rolled a " .. math.random(1, 6), kind = "system" }
    end,
})
```

Built-ins: `/me`, `/shrug`, `/clear`, `/help`, and `/incog <player> <message>` for private whispers.

---

## Documentation

Full guides and the API reference live at **[mkl48.github.io/BOLD](https://mkl48.github.io/BOLD/)** (Moonwave).

---

## License

MIT — built by [Plinko Labs](https://github.com/mkl48).
