-- Bold
-- _Main/Network
-- Plinko Labs

-- Substance channel definitions. Four channels:
--   SEND    client -> server : a compose intent
--   DELIVER server -> client : the authoritative, fast-filtered message
--   UPDATE  server -> client : an in-place patch (deferred filter, reactions, edits)
--   REACT   client -> server : add/remove a reaction

local _Main     = script.Parent
local _Packages = _Main.Parent._Packages

local Substance = require(_Packages.Substance)
local Type      = Substance.Type

local Network = {}

Network.SEND_CHANNEL    = "__Bold:Send"
Network.DELIVER_CHANNEL = "__Bold:Deliver"
Network.UPDATE_CHANNEL  = "__Bold:Update"
Network.REACT_CHANNEL   = "__Bold:React"

local _started = false

function Network.Start()
	if _started then return end
	_started = true

	Substance.Define(Network.SEND_CHANNEL, {
		Message = Type.table(),
	}):Compose(Network.SEND_CHANNEL, "Strict")

	Substance.Define(Network.DELIVER_CHANNEL, {
		Message = Type.table(),
	}):Compose(Network.DELIVER_CHANNEL, "Strict")

	Substance.Define(Network.UPDATE_CHANNEL, {
		Id    = Type.string(),
		Patch = Type.table(),
	}):Compose(Network.UPDATE_CHANNEL, "Strict")

	Substance.Define(Network.REACT_CHANNEL, {
		Id    = Type.string(),
		Emoji = Type.string(),
	}):Compose(Network.REACT_CHANNEL, "Strict")
end

return Network
