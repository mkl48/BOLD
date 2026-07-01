---
sidebar_position: 6
---

# Customization

Everything tunable lives in one config, deep-merged through [`Bold.Configure`](/api/Bold#Configure). Call it before or after `Start`.

```lua
Bold.Configure({
    interface = { … },
    parsing   = { … },
    filter    = { … },
    keys      = { … },
    animation = { … },
    sounds    = { … },
})
```

## Theme

The theme is a flat table of colour/typography tokens (`background`, `text`, `accent`, `mention_bg`, `code_text`, `spoiler_bg`, `font`, `corner_radius`, …). Merge overrides, or apply a preset.

```lua
Bold.Theme("midnight")      -- "dark" | "light" | "midnight" | "neon"

Bold.SetTheme({
    accent = Color3.fromRGB(0, 200, 160),
    mention_bg = Color3.fromRGB(0, 200, 160),
    font = Enum.Font.Gotham,
})
```

## Layout

```lua
Bold.Layout("bottom_left")  -- top_left | top_right | bottom_left | bottom_right | center

Bold.Configure({
    interface = {
        density = "cozy",           -- "compact" | "cozy" | "comfortable"
        window_size = UDim2.fromOffset(460, 0),
        max_list_height = 400,
        max_messages = 200,
        show_timestamps = true,
        message_grouping = true,
        draggable = true,
    },
})
```

## Keybinds

Bold drives its keybinds through [Switch](https://github.com/mkl48/Switch) when present, falling back to `UserInputService`. Every bind is rebindable, or disable one with `false`.

```lua
Bold.Configure({
    keys = {
        focus  = Enum.KeyCode.Slash,   -- focus the input box
        toggle = Enum.KeyCode.F1,      -- show/hide the window
        up     = { Enum.KeyCode.Up },
        down   = { Enum.KeyCode.Down },
        accept = { Enum.KeyCode.Return, Enum.KeyCode.Tab },
        close  = { Enum.KeyCode.Escape },
    },
})
```

## Animation

```lua
Bold.Configure({
    animation = {
        enabled = true,
        in_style = "slide",   -- "slide" | "fade" | "none"
        in_time = 0.18,
        stagger = 0.02,
        smooth_scroll = true,
    },
})
```

## Events & hooks

Observe the whole lifecycle with `Bold.On(name, fn)` — `MessageSent`, `MessageReceived`, `MessageRendered`, `MessageUpdated`, `Mentioned`, `ReactionAdded`, `ReplyClicked`, `LinkClicked`, `CardClicked`, `FilterApplied`, `ThemeChanged`, and more. For inline decoration, append rich text to every row:

```lua
Bold.Decorate(function(message)
    if message.metadata.author_id and isVIP(message.metadata.author_id) then
        return "<font color=\"rgb(255,210,80)\">★</font>"
    end
end)
```

See the [Bold API](/api/Bold) for the full surface.
