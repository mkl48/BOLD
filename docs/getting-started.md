---
sidebar_position: 2
---

# Getting started

## Install

Drop the `Bold` module into `ReplicatedStorage`, via any of:

- **HTTP bootstrap** — paste into the Studio command bar (needs *Game Settings → Security → Allow HTTP Requests*):

  ```lua
  loadstring(game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/mkl48/BOLD/main/dist/bootstrap.luau"))()
  ```

- **Wally** — `Bold = "kr3ative/bold@0.1.0"`
- **Rojo** — sync the `src` tree in as a ModuleScript named `Bold`.

## Start it

Bold is realm-split. Start it on the **server** so it can receive, filter and broadcast, and on the **client** so it builds the UI.

```lua
-- server
local Bold = require(game.ReplicatedStorage.Bold)
Bold.Start()
```

```lua
-- client
local Bold = require(game.ReplicatedStorage.Bold)

Bold.Start({
    interface = {
        channel_name = "Global",
        window_position = UDim2.new(0, 12, 1, -12),
        window_anchor = Vector2.new(0, 1),
    },
})
```

That's the whole loop. The input box appears, players type, and messages flow. Press `/` to focus the box (rebindable).

## Send from code

```lua
-- quick path
Bold.Message({ content = { raw_text = "Welcome **home** :wave:" } })

-- fluent builder
Bold.Compose()
    :Text("gg ")
    :Mention(somePlayer)
    :Emoji("fire")
    :Send()
```

On the server, `Bold.Message`/`Bold.Compose():Send()` broadcast (or whisper, with `:To(player)`). On the client they send through the same pipeline as the input box.

## React to events

```lua
Bold.OnMentioned(function(message)
    -- the local player was @mentioned
end)

Bold.On("MessageReceived", function(message)
    print(message.metadata.author_name, message.content.raw_text)
end)
```

Next: [Sending messages](./messaging), [Formatting & panels](./formatting), [Moderation](./moderation), and [Customization](./customization).
