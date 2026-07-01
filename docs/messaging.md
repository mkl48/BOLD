---
sidebar_position: 3
---

# Sending messages

## The quick path

`Bold.Message(config)` constructs and routes a message. On the server it broadcasts; on the client it goes through the send pipeline.

```lua
Bold.Message({
    content = { raw_text = "server announcement", },
    kind = "announcement",
})
```

## The builder

`Bold.Compose()` returns a fluent builder that assembles the text (in Bold's markdown) plus structured embeds, then `:Send()`s it.

```lua
Bold.Compose()
    :Bold("Round over!")
    :Line()
    :Text("winner: ")
    :Mention(winner)
    :Space()
    :Color(Color3.fromRGB(255, 210, 80), "+50")
    :Kind("announcement")
    :Send()
```

Chainable inline builders: `:Text :Bold :Italic :Underline :Strike :Code :Spoiler :Color :Link :Mention :Emoji :Quote :Space :Line`. Structure & metadata: `:Panel :Embed :Image :Sticker :Kind :Tag :Reply :To :Pin`. Terminals: `:Send()` and `:Payload()`.

## Embeds

```lua
Bold.Message({
    content = {
        raw_text = "new skin dropped",
        embeds = {
            Bold.Image("rbxassetid://123", { caption = "Midnight" }),
            Bold.Action("buy_skin", { title = "500 coins", button_text = "Buy", style = "primary" }),
        },
    },
})
```

Embed constructors: `Bold.Image`, `Bold.Gif`, `Bold.Sticker`, `Bold.RichText`, `Bold.Action`. Handle `Action` clicks via the `EmbedActionFired` event.

## Replies & reactions

Players reply and react from the hover toolbar on each message. From code:

```lua
Bold.Compose():Text("agreed"):Reply(someMessage):Send()

Bold.On("ReactionAdded", function(id, emoji, userId) ... end)
```

Configure the quick-reaction set and toggle either feature under `interface`:

```lua
Bold.Configure({
    interface = {
        reactions = true,
        reply_enabled = true,
        quick_reactions = { "👍", "❤️", "😂", "🔥", "🎉" },
    },
})
```

## Whispers

Set a recipient and the message is delivered only to them (and echoed back to the sender), filtered per-viewer:

```lua
Bold.Compose():Text("meet me at spawn"):To(targetPlayer):Send()
```

The built-in `/incog <player> <message>` command does exactly this from the input box.

## Kinds

Every message has a `kind` — `chat`, `system`, `announcement`, `whisper`, `team`, `me`, or your own. Kinds drive the row's prefix, colour and grouping. Restyle one, or register a fully custom renderer:

```lua
Bold.SetKindStyle("vip", "announcement_text", "★ ", true)
Bold.RegisterRenderer("trade", function(message, theme)
    local frame = Instance.new("Frame")
    -- your bespoke card
    return frame
end)
```
