local RunService = game:GetService("RunService")

local _Main     = script._Main
local _Patterns = script._Patterns
local _Utility  = script._Utility

local Types   = require(script.Types)
local Events  = require(_Utility.Events)
local Hooks   = require(_Utility.Hooks)
local Network = require(_Main.Network)

local MsgPattern = require(_Patterns.Message)
local Parser     = require(_Patterns.Parser)

local IS_SERVER = RunService:IsServer()
local _started  = false

local Bold = {}

-- Public references
Bold.Events = Events
Bold.Hooks  = Hooks
Bold.Types  = Types

-- ─── Startup ───────────────────────────────────────────────────────────────

function Bold.Start(config: Types.BoldConfig?)
	if _started then return end
	_started = true

	Network.Start()
	Events.Start()

	if config and config.parsing then
		MsgPattern.SetParseOptions(config.parsing)
	end

	if IS_SERVER then
		local Server = require(_Main.Server)
		Bold._Server = Server

		if config then
			if config.interface == nil then
				-- server-side: no interface config needed
			end
		end

		Server.FilterEnabled = (config and config.parsing and config.parsing.filter) ~= false
		Server.Start()
	else
		local Client    = require(_Main.Client)
		local Interface = require(_Main.Interface)

		Bold._Client    = Client
		Bold._Interface = Interface

		if config and config.interface then
			local ic = config.interface
			if ic.theme           then Interface.SetTheme(ic.theme) end
			if ic.density         then Interface.Config.density        = ic.density end
			if ic.window_size     then Interface.Config.window_size    = ic.window_size end
			if ic.window_position then Interface.Config.window_pos     = ic.window_position end
			if ic.window_anchor   then Interface.Config.window_anchor  = ic.window_anchor end
			if ic.header_height   then Interface.Config.header_height  = ic.header_height end
			if ic.input_height    then Interface.Config.input_height   = ic.input_height end
			if ic.max_messages    then Interface.Config.max_messages   = ic.max_messages end
			if ic.channel_name    then Interface.Config.channel_name   = ic.channel_name end
			if ic.show_header     ~= nil then Interface.Config.show_header     = ic.show_header end
			if ic.show_input      ~= nil then Interface.Config.show_input      = ic.show_input end
			if ic.show_timestamps ~= nil then Interface.Config.show_timestamps = ic.show_timestamps end
			if ic.show_scrollbar  ~= nil then Interface.Config.show_scrollbar  = ic.show_scrollbar end
			if ic.visible         ~= nil then Interface.Config.visible         = ic.visible end
			if ic.animate_in      ~= nil then Interface.Config.animate_in      = ic.animate_in end
			if ic.message_grouping ~= nil then Interface.Config.message_grouping = ic.message_grouping end
			if ic.grouping_window then Interface.Config.grouping_window = ic.grouping_window end
		end

		Client.Start()
	end
end

-- ─── Messaging ─────────────────────────────────────────────────────────────

-- Construct and send/broadcast a message
function Bold.Message(config: Types.MessageClass?): Types.MessageClass
	local message = MsgPattern.Construct(config)

	if IS_SERVER then
		local recipientId = message.metadata and message.metadata.recipient_id
		if recipientId then
			local target = game:GetService("Players"):GetPlayerByUserId(recipientId)
			if target then Bold._Server.SendTo(message, target) end
		else
			Bold._Server.Broadcast(message)
		end
	else
		Bold._Client.Send(message)
	end

	return message
end

-- Server-only: dispatch a message without going through the SEND channel
function Bold.Dispatch(config: Types.MessageClass?, target: Player?): Types.MessageClass?
	if not IS_SERVER then
		warn("[Bold] Bold.Dispatch is server-only")
		return nil
	end
	local message = MsgPattern.Construct(config)
	Bold._Server.Dispatch(message, target)
	return message
end

-- ─── Embeds ────────────────────────────────────────────────────────────────

function Bold.Image(image_id: string, config: Types.ImageEmbed?): Types.ImageEmbed
	local e = config and table.clone(config) or {}
	e.type     = "Image"
	e.image_id = image_id
	return e :: any
end

function Bold.Gif(video_id: string, config: { loop: boolean?, autoplay: boolean?, color: Color3? }?): Types.GifEmbed
	local e = config and table.clone(config) or {}
	e.type     = "Gif"
	e.video_id = video_id
	return e :: any
end

function Bold.Sticker(sticker_id: string, config: { size: number?, color: Color3? }?): Types.StickerEmbed
	local e = config and table.clone(config) or {}
	e.type       = "Sticker"
	e.sticker_id = sticker_id
	return e :: any
end

function Bold.RichText(config: Types.RichTextEmbed): Types.RichTextEmbed
	local e = table.clone(config)
	e.type = "RichText"
	return e :: any
end

function Bold.Action(action_id: string, config: {
	title: string?,
	button_text: string?,
	style: ("primary" | "danger" | "ghost")?,
	color: Color3?,
	}?): Types.ActionEmbed
	local e = config and table.clone(config) or {}
	e.type      = "Action"
	e.action_id = action_id
	return e :: any
end

-- ─── Events ────────────────────────────────────────────────────────────────

-- Connect to a Bold event by name
-- Returns the RBXScriptConnection
function Bold.On(eventName: string, callback: (...any) -> ()): RBXScriptConnection
	local signal = Events[eventName]
	assert(signal, "[Bold] Unknown event: " .. tostring(eventName))
	return signal:Connect(callback)
end

-- One-shot connection -- auto-disconnects after first fire
function Bold.Once(eventName: string, callback: (...any) -> ()): RBXScriptConnection
	local signal = Events[eventName]
	assert(signal, "[Bold] Unknown event: " .. tostring(eventName))
	return signal:Once(callback)
end

-- ─── Hooks ─────────────────────────────────────────────────────────────────

-- Listen on a hook point -- purely observational, fires for every callback
-- registered, in any order, via task.spawn. Can't cancel or alter the message.
-- Available hook names: BeforeSend, AfterSend, BeforeDeliver, AfterDeliver,
-- BeforeRender, AfterRender, BeforeParse, AfterParse.
-- To actually drop a message server-side, use Server.OnMessage instead.
function Bold.Hook(hookName: string, fn: (...any) -> ())
	Hooks:On(hookName, fn)
end

-- ─── Classification ────────────────────────────────────────────────────────

-- Set the kind and optional tags on a message
function Bold.Classify(message: Types.MessageClass, kind: string, tags: { string }?): Types.MessageClass
	message.kind = kind
	if tags then message.tags = tags end
	Events.MessageClassified:Fire(message, kind)
	if tags then Events.MessageTagged:Fire(message, tags) end
	return message
end

-- Add tags to an existing message -- merges with current tags
function Bold.Tag(message: Types.MessageClass, ...: string): Types.MessageClass
	local newTags = { ... }
	if not message.tags then message.tags = {} end
	for _, t in newTags do
		if not table.find(message.tags, t) then
			table.insert(message.tags, t)
		end
	end
	Events.MessageTagged:Fire(message, message.tags)
	return message
end

-- Pin / unpin a message card
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

-- ─── Emoji & Stickers ──────────────────────────────────────────────────────

-- Register a custom emoji -- :name: will resolve to this asset ID
function Bold.RegisterEmoji(name: string, assetId: string)
	Parser.RegisterEmoji(name, assetId)
end

-- Register a sticker -- Bold.Sticker(id) will embed this asset
function Bold.RegisterSticker(id: string, assetId: string)
	Parser.RegisterSticker(id, assetId)
end

-- Search built-in + custom emoji by partial name
function Bold.SearchEmoji(query: string): { string }
	local results = Parser.SearchEmoji(query)
	Events.EmojiSearched:Fire(query, results)
	return results
end

-- ─── UI ────────────────────────────────────────────────────────────────────

function Bold.SetTheme(theme: Types.Theme)
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.SetTheme(theme) end
end

function Bold.SetDensity(d: "compact" | "cozy" | "comfortable")
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.SetDensity(d) end
end

function Bold.FocusInput()
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.FocusInput() end
end

-- Set the text-color key + optional prefix/bold for a kind's default row style
function Bold.SetKindStyle(kind: string, textKey: string, prefix: string?, bold: boolean?)
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.SetKindStyle(kind, textKey, prefix, bold) end
end

-- Inject extra inline rich-text at the end of every row -- fn(message) -> string?
function Bold.Decorate(fn: (any) -> string?)
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.RegisterLineDecorator(fn) end
end

function Bold.SetChannelName(name: string)
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.SetChannelName(name) end
end

function Bold.Toggle(visible: boolean?)
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.Toggle(visible) end
end

function Bold.Clear()
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.Clear() end
end

-- Register a fully custom card renderer for a message kind
-- fn(message, theme) must return a Frame
function Bold.RegisterRenderer(kind: string, fn: (any, any) -> Frame)
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.RegisterRenderer(kind, fn) end
end

-- Register a kind override for bg/text theme keys
-- e.g. Bold.SetKindOverride("vip", "announcement_bg", "announcement_text")
function Bold.SetKindOverride(kind: string, bgKey: string, textKey: string)
	if IS_SERVER then return end
	if Bold._Interface then Bold._Interface.SetKindOverride(kind, bgKey, textKey) end
end

return Bold