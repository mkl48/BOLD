---
sidebar_position: 5
---

# Formatting & panels

Bold parses message text into typed elements at render time. Everything below is written by players in the input box, or by you via [`Bold.Compose`](/api/Builder).

## Markdown

| Syntax | Result |
| --- | --- |
| `**bold**` | **bold** |
| `*italic*` | *italic* |
| `__underline__` | underline |
| `~~strike~~` | ~~strike~~ |
| `` `code` `` | inline code |
| `\|\|spoiler\|\|` | click-to-reveal spoiler |
| `{red\|text}` / `{#ff0000\|text}` | coloured text (named or hex) |
| `[label](url)` | link — fires the `LinkClicked` event |
| `> quoted` | blockquote |
| `# Title` | heading (`#`, `##`, `###`) |
| `:fire:` | emoji |
| `@Name` | [mention](#mentions) |

Each feature can be toggled globally under `parsing`:

```lua
Bold.Configure({
    parsing = { markdown = true, mentions = true, emoji = true, links = true, panels = true },
})
```

## Mentions

`@Name` (or `@DisplayName`) resolves to a player **on the server**, against the filtered text, so a masked name can't ping anyone. When the local player is named, their card highlights and flashes, and `Bold.OnMentioned` fires.

```lua
Bold.OnMentioned(function(message)
    SoundService:PlayLocalSound(pingSound)
end)
```

## Emoji & stickers

Built-in `:name:` emoji are ready to go. Register your own:

```lua
Bold.RegisterEmoji("plinko", "rbxassetid://123")
Bold.RegisterSticker("gg", "rbxassetid://456")
```

Typing `@`, `:` or `/` in the input box opens an autocomplete popup (players, emoji + stickers, and commands respectively).

## Custom panels

A `:::name … :::` fence renders a component you register. Arguments are parsed as `key="value"` pairs (and bare flags); everything between the fences is the panel body.

```lua
Bold.RegisterPanel("poll", function(args, message, theme)
    local frame = Instance.new("Frame")
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.Size = UDim2.new(1, 0, 0, 0)
    -- build from args.question and args.options ("A,B,C")
    return frame
end)
```

A message containing:

```
:::poll question="Best map?" options="A,B,C"
vote below
:::
```

renders your poll frame inline, with `args = { question = "Best map?", options = "A,B,C", _positional = {} }` and `args`'s body available as `panel_body`. Unregistered panel names render a graceful placeholder. Bold ships `:::divider:::` and `:::note:::` as examples.
