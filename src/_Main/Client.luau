local StarterGui = game:GetService("StarterGui")
local _Main     = script.Parent
local _Utility  = _Main.Parent._Utility
local _Packages = _Main.Parent._Packages
local _Pat      = _Main.Parent._Patterns
local Substance  = require(_Packages.Substance)
local Events     = require(_Utility.Events)
local Hooks      = require(_Utility.Hooks)
local Network    = require(_Main.Network)
local Interface  = require(_Main.Interface)
local MsgPattern = require(_Pat.Message)
local RefPattern = require(_Pat.Ref)

local Client = {}

Client.OnMessage = nil :: ((any) -> (boolean | nil))?
Client.AutoSendFromInputBar = true

function Client.Start()
	Interface.Build()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)

	if Client.AutoSendFromInputBar then
		Interface.SubmitText.Event:Connect(function(text: string, embeds: {any}?)
			local message = MsgPattern.Construct({
				content = {
					raw_text = text,
					embeds = embeds or {},
				},
			})
			Client.Send(message)
		end)
	end
	
	Substance.Subscribe(Network.DELIVER_CHANNEL, function(payload)
		local message = payload.Message
		if not message then return end
		Hooks:Fire("AfterDeliver", message)
		Events.MessageReceived:Fire(message)
		if Client.OnMessage then
			if Client.OnMessage(message) == false then return end
		end
		Hooks:Fire("BeforeRender", message)
		Interface.Render(message)
		Hooks:Fire("AfterRender", message)
	end)
end

function Client.Send(message: any)
	Hooks:Fire("BeforeSend", message)
	Events.MessageSent:Fire(message)
	
	Substance.Post(Network.SEND_CHANNEL, { Message = message })
		:Throw(function(err)
			warn("[Bold.Client] Send failed:", err)
		end)
	Hooks:Fire("AfterSend", message)
end
return Client