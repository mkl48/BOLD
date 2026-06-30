local Players = game:GetService("Players")

local _Main     = script.Parent
local _Utility  = _Main.Parent._Utility
local _Packages = _Main.Parent._Packages

local Substance = require(_Packages.Substance)
local Promise   = require(_Packages.Promise)
local Events    = require(_Utility.Events)
local Hooks     = require(_Utility.Hooks)
local Filter    = require(_Utility.Filter)
local Network   = require(_Main.Network)

local Server = {}

Server.FilterEnabled = true

-- The only true gate left in the pipeline -- Hooks:Fire is fire-and-forget
-- and can't cancel, so dropping a message has to happen here.
-- Return false to drop the message before delivery.
Server.OnMessage = nil :: ((any, Player?) -> (boolean | nil))?

local function stamp(message: any, player: Player?)
	local meta = message.metadata
	if not meta then
		return
	end
	if player then
		meta.author_id   = player.UserId
		meta.author_name = player.Name
	end
	if not meta.timestamp or meta.timestamp == 0 then
		meta.timestamp = os.time()
	end
end

-- Returns a Promise that resolves once filtering (if any) has been applied
-- to message.content.raw_text in place.
local function applyFilter(message: any, player: Player?)
	if not Server.FilterEnabled then
		return Promise.resolve()
	end

	local content = message.content
	if not content or not content.raw_text or content.raw_text == "" then
		return Promise.resolve()
	end

	local original = content.raw_text

	return Filter.BroadcastAsync(original, player):andThen(function(filtered)
		warn(("FILTER CHECK -- original: %q  filtered: %q"):format(original, filtered))
		if filtered ~= original then
			content.raw_text = filtered
			message.filtered = true
			Events.FilterApplied:Fire(original, filtered, player)
		end
	end)
end

local function deliver(message: any, player: Player?)
	if Server.OnMessage then
		if Server.OnMessage(message, player) == false then
			Events.MessageDropped:Fire("on_message", player)
			return
		end
	end

	Hooks:Fire("AfterDeliver", message, player)

	local recipientId = message.metadata and message.metadata.recipient_id
	if recipientId then
		Server.Send(message, function(p)
			return p.UserId == recipientId
		end)
	else
		Server.Broadcast(message)
	end
end

function Server.Start()
	-- Receive client -> server sends
	Substance.Subscribe(Network.SEND_CHANNEL, function(payload, player)
		local message = payload.Message
		if not message then
			return
		end

		stamp(message, player)
		Hooks:Fire("BeforeDeliver", message, player)

		applyFilter(message, player)
			:andThen(function()
				deliver(message, player)
			end)
			:catch(function(err)
				warn("[Server] applyFilter failed, dropping message:", err)
				Events.MessageDropped:Fire("filter_error", player)
			end)
	end)
end

-- Broadcast to every connected client
function Server.Broadcast(message: any)
	Substance.Broadcast(Network.DELIVER_CHANNEL, { Message = message })
end

-- Broadcast with a player filter fn -- (player: Player) -> boolean
function Server.Send(message: any, filter: (Player) -> boolean)
	Substance.Broadcast(Network.DELIVER_CHANNEL, { Message = message }, filter)
end

-- Convenience: send to exactly one player
function Server.SendTo(message: any, player: Player)
	Server.Send(message, function(p)
		return p == player
	end)
end

-- Server-originated message -- skips the SEND channel entirely
function Server.Dispatch(message: any, target: Player?)
	stamp(message, nil)

	applyFilter(message, nil)
		:andThen(function()
			if target then
				Server.SendTo(message, target)
			else
				Server.Broadcast(message)
			end
		end)
		:catch(function(err)
			warn("[Server] applyFilter failed, dropping dispatched message:", err)
		end)
end

return Server