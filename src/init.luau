-- Bold
-- init
-- Plinko Labs

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local _Main     = script._Main
local _Patterns = script._Patterns
local _Utility  = script._Utility
local _Classes  = script._Classes

local Types    = require(script.Types)
local Events   = require(_Utility.Events)
local Hooks    = require(_Utility.Hooks)
local Config   = require(_Utility.Config)
local HardBlock = require(_Utility.HardBlockFilter)
local Network  = require(_Main.Network)

local MsgPattern = require(_Patterns.Message)
local Parser     = require(_Patterns.Parser)
local Commands   = require(_Patterns.Commands)
local Builder    = require(_Classes.Builder)

local IS_SERVER = RunService:IsServer()
local _started  = false

--[=[
	@class Bold

	The chat library's entry point. Require it on both realms and call [Bold.Start].
	Everything tunable flows through [Bold.Configure]; messages go out via
	[Bold.Message] or the fluent [Builder] from [Bold.Compose].
]=]
local Bold = {}

Bold.Events = Events
Bold.Hooks  = Hooks
Bold.Types  = Types
Bold.Config = Config
Bold.Commands = Commands

Bold._sink = nil :: ((payload: any) -> ())?

-- ─── Startup ─────────────────────────────────────────────────────────────────

-- Deep-merge config at any time. Safe before or after Start.
--[=[
	@within Bold
	Deep-merges a [BoldConfig] into the live config. Safe before or after [Bold.Start].
	Sections: `interface`, `parsing`, `filter`, `keys`, `animation`, `sounds`.
]=]
function Bold.Configure(config: Types.BoldConfig?)
	Config.Apply(config)
	if not IS_SERVER and Bold._Interface and config and config.interface and config.interface.theme then
		Bold._Interface.SetTheme(config.interface.theme)
	end
end

--[=[
	@within Bold
	Applies a built-in theme preset (`dark`, `light`, `midnight`, `neon`). Returns
	`false` if the name is unknown.
]=]
function Bold.Theme(preset: string): boolean
	local ok = Config.ApplyThemePreset(preset)
	if ok and not IS_SERVER and Bold._Interface then
		Bold._Interface.SetTheme(Config.Interface.theme)
	end
	return ok
end

--[=[
	@within Bold
	Applies a window layout preset (`top_left`, `top_right`, `bottom_left`,
	`bottom_right`, `center`). Returns `false` if the name is unknown.
]=]
function Bold.Layout(preset: string): boolean
	return Config.ApplyLayoutPreset(preset)
end

local function registerBuiltinPanels(Interface)
	local Skin = require(_Utility.Skin)

	Interface.RegisterPanel("divider", function(args)
		local frame = Instance.new("Frame")
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.BackgroundTransparency = 1
		Skin.pad(frame, 0, 0, 4, 4)
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, 0, 0, 1)
		line.BackgroundColor3 = Skin.tk("subtext")
		line.BackgroundTransparency = 0.6
		line.BorderSizePixel = 0
		line.Parent = frame
		if args.label then
			local lbl = Instance.new("TextLabel")
			lbl.AutomaticSize = Enum.AutomaticSize.Y
			lbl.Size = UDim2.new(1, 0, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = tostring(args.label)
			lbl.Font = Skin.tk("font")
			lbl.TextSize = Skin.density().text_size - 3
			lbl.TextColor3 = Skin.tk("subtext")
			lbl.TextXAlignment = Enum.TextXAlignment.Center
			lbl.Parent = frame
		end
		return frame
	end)

	Interface.RegisterPanel("note", function(args, _message)
		local frame = Instance.new("Frame")
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.Size = UDim2.new(1, 0, 0, 0)
		frame.BackgroundColor3 = Skin.tk("accent")
		frame.BackgroundTransparency = 0.85
		frame.BorderSizePixel = 0
		Skin.corner(frame, 6)
		Skin.pad(frame, 8, 8, 6, 6)
		Skin.list(frame, nil, 2)
		if args.title then
			local t = Instance.new("TextLabel")
			t.AutomaticSize = Enum.AutomaticSize.Y
			t.Size = UDim2.new(1, 0, 0, 0)
			t.BackgroundTransparency = 1
			t.Text = tostring(args.title)
			t.Font = Skin.tk("font_bold")
			t.TextSize = Skin.density().text_size
			t.TextColor3 = Skin.tk("text")
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.TextWrapped = true
			t.Parent = frame
		end
		local body = Instance.new("TextLabel")
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.Size = UDim2.new(1, 0, 0, 0)
		body.BackgroundTransparency = 1
		body.Text = args._positional and args._positional[1] or (args.text and tostring(args.text)) or ""
		body.Font = Skin.tk("font")
		body.TextSize = Skin.density().text_size - 1
		body.TextColor3 = Skin.tk("subtext")
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextWrapped = true
		body.Parent = frame
		return frame
	end)
end

--[=[
	@within Bold
	Boots Bold on the current realm. On the server it wires the receive → filter →
	broadcast pipeline; on the client it builds the UI and input. Accepts an optional
	[BoldConfig] (the same shape [Bold.Configure] takes). Call once per realm.
]=]
function Bold.Start(config: Types.BoldConfig?)
	if _started then return end
	_started = true

	Config.Apply(config)
	Network.Start()
	Events.Start()

	if IS_SERVER then
		local Server = require(_Main.Server)
		Bold._Server = Server
		Bold._sink = function(payload)
			Bold.Message({
				content  = { raw_text = payload.text, embeds = payload.embeds },
				kind     = payload.kind,
				tags     = payload.tags,
				pinned   = payload.pinned,
				metadata = { recipient_id = payload.recipient_id, reply_to = payload.reply_to } :: any,
			})
		end
		Server.Start()
	else
		local Client    = require(_Main.Client)
		local Interface = require(_Main.Interface)
		Bold._Client    = Client
		Bold._Interface = Interface

		Interface.SetReactHandler(Client.React)
		registerBuiltinPanels(Interface)

		Bold._sink = function(payload) Client.Send(payload) end
		Client.Start()
	end
end

-- ─── Messaging ───────────────────────────────────────────────────────────────

-- Construct and send/broadcast a message.
--[=[
	@within Bold
	Constructs and sends a message. On the server it broadcasts, or whispers when
	`metadata.recipient_id` is set; on the client it goes through the send pipeline.
]=]
function Bold.Message(config: Types.MessageClass?): Types.MessageClass
	local message = MsgPattern.Construct(config)

	if IS_SERVER then
		local recipientId = message.metadata and message.metadata.recipient_id
		local target = recipientId and Players:GetPlayerByUserId(recipientId) or nil
		Bold._Server.Dispatch(message, target)
	else
		Bold._Client.Send({
			text = message.content.raw_text,
			embeds = message.content.embeds,
			kind = message.kind,
			tags = message.tags,
			pinned = message.pinned,
			recipient_id = message.metadata.recipient_id,
			reply_to = message.metadata.reply_to,
		})
	end

	return message
end

-- Fluent builder: Bold.Compose():Bold("hi"):Mention(plr):Send()
--[=[
	@within Bold
	@return Builder
	Returns a fluent [Builder] for assembling a message from markdown + embeds, e.g.
	`Bold.Compose():Bold("gg"):Mention(plr):Send()`.
]=]
function Bold.Compose()
	return Builder.new(Bold._sink)
end

-- Server-only: dispatch a message without going through the SEND channel.
--[=[
	@within Bold
	@server
	Sends a server-originated message without routing through the client SEND channel.
	Pass `target` to whisper it to one player.
]=]
function Bold.Dispatch(config: Types.MessageClass?, target: Player?): Types.MessageClass?
	if not IS_SERVER then
		warn("[Bold] Bold.Dispatch is server-only")
		return nil
	end
	local message = MsgPattern.Construct(config)
	Bold._Server.Dispatch(message, target)
	return message
end

-- ─── Embeds ──────────────────────────────────────────────────────────────────

--[=[
	@within Bold
	Builds an Image embed for a message's `content.embeds`.
]=]
function Bold.Image(image_id: string, config: Types.ImageEmbed?): Types.ImageEmbed
	local e = config and table.clone(config) or {}
	e.type = "Image"; e.image_id = image_id
	return e :: any
end

--[=[
	@within Bold
	Builds a Gif (VideoFrame) embed for a message's `content.embeds`.
]=]
function Bold.Gif(video_id: string, config: { loop: boolean?, autoplay: boolean?, color: Color3? }?): Types.GifEmbed
	local e = config and table.clone(config) or {}
	e.type = "Gif"; e.video_id = video_id
	return e :: any
end

--[=[
	@within Bold
	Builds a Sticker embed for a message's `content.embeds`.
]=]
function Bold.Sticker(sticker_id: string, config: { size: number?, color: Color3? }?): Types.StickerEmbed
	local e = config and table.clone(config) or {}
	e.type = "Sticker"; e.sticker_id = sticker_id
	return e :: any
end

--[=[
	@within Bold
	Builds a RichText embed (title, description, fields) for a message's `content.embeds`.
]=]
function Bold.RichText(config: Types.RichTextEmbed): Types.RichTextEmbed
	local e = table.clone(config)
	e.type = "RichText"
	return e :: any
end

--[=[
	@within Bold
	Builds an Action (button) embed. Handle clicks via the `EmbedActionFired` event.
]=]
function Bold.Action(action_id: string, config: {
	title: string?,
	button_text: string?,
	style: ("primary" | "danger" | "ghost")?,
	color: Color3?,
	}?): Types.ActionEmbed
	local e = config and table.clone(config) or {}
	e.type = "Action"; e.action_id = action_id
	return e :: any
end

-- ─── Events / Hooks ──────────────────────────────────────────────────────────

--[=[
	@within Bold
	Connects to a Bold event by name (`MessageReceived`, `Mentioned`, `ReactionAdded`,
	`LinkClicked`, `ThemeChanged`, …). Returns the connection.
]=]
function Bold.On(eventName: string, callback: (...any) -> ()): RBXScriptConnection
	local signal = Events[eventName]
	assert(signal, "[Bold] Unknown event: " .. tostring(eventName))
	return signal:Connect(callback)
end

function Bold.Once(eventName: string, callback: (...any) -> ()): RBXScriptConnection
	local signal = Events[eventName]
	assert(signal, "[Bold] Unknown event: " .. tostring(eventName))
	return signal:Once(callback)
end

--[=[
	@within Bold
	Registers an observational lifecycle hook (`BeforeSend`, `AfterDeliver`,
	`BeforeRender`, …). Fire-and-forget: it can observe but not alter or drop a message.
]=]
function Bold.Hook(hookName: string, fn: (...any) -> ())
	Hooks:On(hookName, fn)
end

-- Fires when the local player is @mentioned.
--[=[
	@within Bold
	@client
	Fires when the local player is @mentioned in a delivered message.
]=]
function Bold.OnMentioned(fn: (message: any) -> ()): RBXScriptConnection
	return Events.Mentioned:Connect(fn)
end

-- Server / client message guard: return false to drop.
--[=[
	@within Bold
	Installs a message guard for the current realm. Return `false` to drop a message
	before it is delivered (server) or rendered (client).
]=]
function Bold.Guard(fn: (message: any, player: Player?) -> (boolean?))
	if IS_SERVER then
		if Bold._Server then Bold._Server.OnMessage = fn end
	else
		if Bold._Client then Bold._Client.OnMessage = fn end
	end
end

-- ─── Classification ──────────────────────────────────────────────────────────

--[=[
	@within Bold
	Sets a message's `kind` (and optional tags), firing the relevant events.
]=]
function Bold.Classify(message: Types.MessageClass, kind: string, tags: { string }?): Types.MessageClass
	message.kind = kind
	if tags then message.tags = tags end
	Events.MessageClassified:Fire(message, kind)
	if tags then Events.MessageTagged:Fire(message, tags) end
	return message
end

--[=[
	@within Bold
	Adds one or more tags to a message, de-duplicated.
]=]
function Bold.Tag(message: Types.MessageClass, ...: string): Types.MessageClass
	local newTags = { ... }
	if not message.tags then message.tags = {} end
	for _, t in newTags do
		if not table.find(message.tags, t) then table.insert(message.tags, t) end
	end
	Events.MessageTagged:Fire(message, message.tags)
	return message
end

--[=[
	@within Bold
	Pins a message card (adds the pinned indicator).
]=]
function Bold.Pin(message: Types.MessageClass): Types.MessageClass
	message.pinned = true
	Events.MessagePinned:Fire(message)
	return message
end

function Bold.Unpin(message: Types.MessageClass): Types.MessageClass
	message.pinned = false
	Events.MessageUnpinned:Fire(message)
	return message
end

-- ─── Reactions ───────────────────────────────────────────────────────────────

--[=[
	@within Bold
	@client
	Toggles the local player's reaction (an emoji) on a message. Accepts a message
	object or a message id.
]=]
function Bold.React(message: any, emoji: string)
	if IS_SERVER or not Bold._Client then return end
	local id = type(message) == "table" and message.metadata and message.metadata.id or message
	if type(id) == "string" then Bold._Client.React(id, emoji) end
end

-- ─── Emoji / Stickers / Commands / Panels ────────────────────────────────────

function Bold.RegisterEmoji(name: string, assetId: string)
	Parser.RegisterEmoji(name, assetId)
end

function Bold.RegisterSticker(id: string, assetId: string)
	Parser.RegisterSticker(id, assetId)
end

function Bold.SearchEmoji(query: string): { string }
	local results = Parser.SearchEmoji(query)
	Events.EmojiSearched:Fire(query, results)
	return results
end

function Bold.RegisterCommand(name: string, spec: Types.CommandSpec)
	Commands.Register(name, spec)
end

function Bold.RegisterPanel(name: string, fn: (args: any, message: any, theme: any) -> Frame)
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.RegisterPanel(name, fn) end
end

-- ─── Filtering ───────────────────────────────────────────────────────────────

function Bold.AddBlockedWords(words: { string } | string)
	HardBlock.Add(words)
end

-- ─── UI (client) ─────────────────────────────────────────────────────────────

local function ui(): any?
	if IS_SERVER then return nil end
	return Bold._Interface
end

function Bold.SetTheme(theme: Types.Theme)
	local i = ui(); if i then i.SetTheme(theme) end
end

function Bold.SetDensity(d: "compact" | "cozy" | "comfortable")
	local i = ui(); if i then i.SetDensity(d) end
end

function Bold.FocusInput()
	local i = ui(); if i then i.FocusInput() end
end

function Bold.SetKindStyle(kind: string, textKey: string, prefix: string?, bold: boolean?)
	local i = ui(); if i then i.SetKindStyle(kind, textKey, prefix, bold) end
end

function Bold.SetKindOverride(kind: string, bgKey: string, textKey: string)
	local i = ui(); if i then i.SetKindOverride(kind, bgKey, textKey) end
end

function Bold.Decorate(fn: (any) -> string?)
	local i = ui(); if i then i.RegisterLineDecorator(fn) end
end

function Bold.SetChannelName(name: string)
	local i = ui(); if i then i.SetChannelName(name) end
end

function Bold.Toggle(visible: boolean?)
	local i = ui(); if i then i.Toggle(visible) end
end

function Bold.Clear()
	local i = ui(); if i then i.Clear() end
end

function Bold.RegisterRenderer(kind: string, fn: (any, any) -> Frame)
	local i = ui(); if i then i.RegisterRenderer(kind, fn) end
end

return Bold
