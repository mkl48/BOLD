-- Bold
-- _Main/Client
-- Plinko Labs

local StarterGui = game:GetService("StarterGui")

local _Main     = script.Parent
local _Utility  = _Main.Parent._Utility
local _Patterns = _Main.Parent._Patterns
local _Packages = _Main.Parent._Packages

local Substance       = require(_Packages.Substance)
local Events          = require(_Utility.Events)
local Hooks           = require(_Utility.Hooks)
local Config          = require(_Utility.Config)
local Social          = require(_Utility.Social)
local Network         = require(_Main.Network)
local Interface       = require(_Main.Interface)
local MsgPattern      = require(_Patterns.Message)

local Client = {}

Client.OnMessage = nil :: ((any) -> (boolean | nil))?

function Client.Start()
	Interface.Build()

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
	end)

	-- compose -> send. Compose fires a payload table.
	Interface.SubmitText.Event:Connect(function(payload)
		Client.Send(payload)
	end)

	Substance.Subscribe(Network.DELIVER_CHANNEL, function(payload)
		local message = payload.Message
		if not message then return end

		-- locally ignored author: drop it silently
		if message.metadata and Social.IsIgnored(message.metadata.author_id) then return end

		Hooks:Fire("AfterDeliver", message)
		Events.MessageReceived:Fire(message)

		if Client.OnMessage and Client.OnMessage(message) == false then return end

		Hooks:Fire("BeforeRender", message)
		Interface.Render(message)
		Hooks:Fire("AfterRender", message)
	end)

	Substance.Subscribe(Network.UPDATE_CHANNEL, function(payload)
		if not payload.Id or not payload.Patch then return end

		Interface.ApplyUpdate(payload.Id, payload.Patch)
		Events.MessageUpdated:Fire(payload.Id, payload.Patch)
	end)
end

function Client.Send(payload: any)
	payload = payload or {}
	local text = payload.text or ""

	local meta: { [string]: any } = {}
	if payload.recipient_id then meta.recipient_id = payload.recipient_id end
	if payload.reply_to     then meta.reply_to     = payload.reply_to end

	local message = MsgPattern.Construct({
		metadata = meta :: any,
		content  = { raw_text = text, embeds = payload.embeds or {} },
		kind     = payload.kind,
		tags     = payload.tags,
		pinned   = payload.pinned,
	})

	Hooks:Fire("BeforeSend", message)
	Events.MessageSent:Fire(message)

	Substance.Post(Network.SEND_CHANNEL, { Message = message })
		:Throw(function(err)
			warn("[Bold.Client] send failed:", err)
		end)

	Hooks:Fire("AfterSend", message)
	return message
end

function Client.React(messageId: string, emoji: string)
	if not messageId or not emoji or emoji == "" then return end
	Substance.Post(Network.REACT_CHANNEL, { Id = messageId, Emoji = emoji })
		:Throw(function(err)
			warn("[Bold.Client] react failed:", err)
		end)
end

return Client
