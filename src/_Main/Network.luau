local _Main     = script.Parent
local _Utility  = _Main.Parent._Utility
local _Classes  = _Main.Parent._Classes
local _Packages = _Main.Parent._Packages

local Substance = require(_Packages.Substance)
local Type      = Substance.Type
local RunService = game:GetService("RunService")

local Network = {}

local IS_SERVER = RunService:IsServer()

Network.SEND_CHANNEL    = "__Message"          -- client -> server
Network.DELIVER_CHANNEL = "__Message:Deliver"  -- server -> client

function Network.Start()
	Substance.Define(Network.SEND_CHANNEL, {
		Message = Type.table(),
	}):Compose(Network.SEND_CHANNEL, "Strict")

	Substance.Define(Network.DELIVER_CHANNEL, {
		Message = Type.table(),
	}):Compose(Network.DELIVER_CHANNEL, "Strict")
end

return Network