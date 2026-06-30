local Signal = require(script.Parent.Parent._Packages.Signal)

local Events = {}

-- Message lifecycle
Events.MessageSent         = Signal.new()  -- (message: MessageClass)
Events.MessageReceived     = Signal.new()  -- (message: MessageClass)
Events.MessageRendered     = Signal.new()  -- (message: MessageClass, card: Frame)
Events.MessagePinned       = Signal.new()  -- (message: MessageClass)
Events.MessageUnpinned     = Signal.new()  -- (message: MessageClass)
Events.MessageClassified   = Signal.new()  -- (message: MessageClass, kind: string)
Events.MessageTagged       = Signal.new()  -- (message: MessageClass, tags: {string})
Events.MessageDropped      = Signal.new()  -- (reason: string, player: Player?)

-- Interactions
Events.CardClicked         = Signal.new()  -- (message: MessageClass, card: Frame)
Events.EmbedActionFired    = Signal.new()  -- (action_id: string, message: MessageClass?)
Events.MentionClicked      = Signal.new()  -- (user_id: number, name: string, message: MessageClass?)

-- Emoji & stickers
Events.EmojiSearched       = Signal.new()  -- (query: string, results: {string})
Events.EmojiPicked         = Signal.new()  -- (name: string, char_or_asset: string)
Events.StickerSent         = Signal.new()  -- (sticker_id: string)

-- Parser
Events.ParseComplete       = Signal.new()  -- (raw: string, elements: {Element})
Events.MentionDetected     = Signal.new()  -- (name: string, user_id: number?)

-- Filtering
Events.FilterApplied       = Signal.new()  -- (original: string, filtered: string, player: Player?)

-- UI
Events.UIToggled           = Signal.new()  -- (visible: boolean)
Events.UIScrolled          = Signal.new()  -- (position: number)
Events.ChannelChanged      = Signal.new()  -- (new: string, old: string)
Events.ThemeChanged        = Signal.new()  -- (theme: Theme)

function Events.Start()
end

return Events