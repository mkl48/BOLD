-- Bold
-- _Main/Server
-- Plinko Labs

local Players = game:GetService("Players")

local _Main     = script.Parent
local _Utility  = _Main.Parent._Utility
local _Patterns = _Main.Parent._Patterns
local _Packages = _Main.Parent._Packages

local Substance = require(_Packages.Substance)
local Promise   = require(_Packages.Promise)
local Events    = require(_Utility.Events)
local Hooks     = require(_Utility.Hooks)
local Filter    = require(_Utility.Filter)
local Config    = require(_Utility.Config)
local Parser    = require(_Patterns.Parser)
local Network   = require(_Main.Network)
local Proflis   = require(_Packages.Proflis)

local Server = {}

-- Optional hard gate: return false to drop a message before delivery.
Server.OnMessage = nil :: ((any, Player?) -> (boolean | nil))?

-- Fetch the profanity word list (HttpService, server-only) and expose it to
-- clients. Fail-safe: without HTTP the local backstop is simply empty.
Proflis.Start()

-- ─── Recent-message registry (for reactions + edits) ─────────────────────────

local _registry: { [string]: any } = {}
local _order: { string } = {}
local REGISTRY_LIMIT = 400

local function remember(message: any)
	local id = message.metadata and message.metadata.id
	if not id then return end
	if _registry[id] == nil then
		table.insert(_order, id)
	end
	_registry[id] = message
	while #_order > REGISTRY_LIMIT do
		local oldest = table.remove(_order, 1)
		if oldest then _registry[oldest] = nil end
	end
end

-- ─── Delivery ────────────────────────────────────────────────────────────────

local function audienceFilter(message: any): ((Player) -> boolean)?
	local meta = message.metadata
	local recipientId = meta and meta.recipient_id
	if not recipientId then return nil end
	local authorId = meta and meta.author_id
	-- whisper: only the recipient and the author (echo) see it
	return function(p: Player)
		return p.UserId == recipientId or p.UserId == authorId
	end
end

function Server.Broadcast(message: any)
	Substance.Broadcast(Network.DELIVER_CHANNEL, { Message = message })
end

function Server.Send(message: any, filter: (Player) -> boolean)
	Substance.Broadcast(Network.DELIVER_CHANNEL, { Message = message }, filter)
end

function Server.SendTo(message: any, player: Player)
	Server.Send(message, function(p) return p == player end)
end

local function deliver(message: any)
	local filter = audienceFilter(message)
	if filter then
		Server.Send(message, filter)
	else
		Server.Broadcast(message)
	end
end

local function deliverUpdate(message: any, patch: any)
	local payload = { Id = message.metadata.id, Patch = patch }
	local filter = audienceFilter(message)
	if filter then
		Substance.Broadcast(Network.UPDATE_CHANNEL, payload, filter)
	else
		Substance.Broadcast(Network.UPDATE_CHANNEL, payload)
	end
end

-- ─── Processing ──────────────────────────────────────────────────────────────

local function stamp(message: any, player: Player?)
	local meta = message.metadata
	if not meta then return end
	if player then
		meta.author_id   = player.UserId
		meta.author_name = player.Name
	end
	if not meta.timestamp or meta.timestamp == 0 then
		meta.timestamp = os.time()
	end
end

-- Returns a Promise resolving once the fast (authoritative) filter has been
-- applied to raw_text in place. PurgoMalum is NOT part of this -- it runs later.
local function fastFilter(message: any, player: Player?)
	if not Config.Filter.enabled then return Promise.resolve() end
	local content = message.content
	if not content or not content.raw_text or content.raw_text == "" then
		return Promise.resolve()
	end

	local original = content.raw_text
	return Filter.Fast(original, player):andThen(function(filtered)
		if filtered ~= original then
			content.raw_text = filtered
			message.filtered = true
			Events.FilterApplied:Fire(original, filtered, player)
		end
	end)
end

-- Schedule the non-blocking PurgoMalum refinement. Patches the message in place
-- and pushes an UPDATE only if it actually changes the (already delivered) text.
local function scheduleDeferred(message: any)
	if not (Config.Filter.enabled and Config.Filter.purgomalum) then return end
	local content = message.content
	if not content or not content.raw_text or content.raw_text == "" then return end

	local current = content.raw_text
	Filter.Deferred(current)
		:andThen(function(refined)
			if refined ~= current and message.content.raw_text == current then
				message.content.raw_text = refined
				message.metadata.edited = true
				deliverUpdate(message, { text = refined, edited = true })
			end
		end)
		:catch(function() end)
end

-- The unified path used by both client sends and server Dispatch.
local function process(message: any, player: Player?)
	stamp(message, player)
	Hooks:Fire("BeforeDeliver", message, player)

	if Server.OnMessage and Server.OnMessage(message, player) == false then
		Events.MessageDropped:Fire("on_message", player)
		return
	end

	fastFilter(message, player)
		:andThen(function()
			-- resolve @mentions against the *filtered* text so masked names don't ping
			message.metadata.mentions = Parser.ScanMentions(message.content.raw_text, Players:GetPlayers())
			message.reactions = message.reactions or {}
			remember(message)

			deliver(message)
			Hooks:Fire("AfterDeliver", message, player)

			scheduleDeferred(message)
		end)
		:catch(function(err)
			warn("[Bold.Server] filter failed, dropping message:", err)
			Events.MessageDropped:Fire("filter_error", player)
		end)
end

-- ─── Reactions ───────────────────────────────────────────────────────────────

local MAX_EMOJI_BYTES = 16

local function handleReact(payload: any, player: Player?)
	if not player then return end
	local id = payload.Id
	local emoji = payload.Emoji
	if type(id) ~= "string" or type(emoji) ~= "string" then return end
	if emoji == "" or #emoji > MAX_EMOJI_BYTES then return end

	local message = _registry[id]
	if not message then return end

	message.reactions = message.reactions or {}
	local r = message.reactions[emoji] or { count = 0, users = {} }
	local uid = player.UserId
	local idx = table.find(r.users, uid)

	if idx then
		table.remove(r.users, idx)
		r.count = #r.users
		if r.count <= 0 then
			message.reactions[emoji] = nil
		else
			message.reactions[emoji] = r
		end
		Events.ReactionRemoved:Fire(id, emoji, uid)
	else
		table.insert(r.users, uid)
		r.count = #r.users
		message.reactions[emoji] = r
		Events.ReactionAdded:Fire(id, emoji, uid)
	end

	deliverUpdate(message, { reactions = message.reactions })
end

-- ─── Public ──────────────────────────────────────────────────────────────────

function Server.Start()
	Substance.Subscribe(Network.SEND_CHANNEL, function(payload, player)
		local message = payload.Message
		if not message or not message.metadata then return end
		process(message, player)
	end)

	Substance.Subscribe(Network.REACT_CHANNEL, handleReact)
end

-- Server-originated message (skips the SEND channel).
function Server.Dispatch(message: any, target: Player?)
	if target then
		message.metadata.recipient_id = target.UserId
	end
	process(message, nil)
end

return Server
