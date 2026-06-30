local Types = require(script.Parent.Parent.Types)

local Message = {}
Message.__index = Message

local function deepCopy(t: {any}): {any}
	local copy = {}
	for k, v in t do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end
function Message.template(): Types.MessageClass
	return {
		metadata = {
			id = "",
			source = "System",
			timestamp = 0,
			author_id = nil,
			author_name = nil,
			recipient_id = nil,
		},
		content = {
			raw_text = "",
			elements = {},
			embeds = {},
		}
	}
end

function Message.new(config: Types.MessageClass): Types.MessageClass
	local self = setmetatable(deepCopy(config), Message) :: Types.MessageClass

	return self
end


return Message