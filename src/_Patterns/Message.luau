-- Bold
-- _Patterns/Message
-- Plinko Labs

-- Builds a MessageClass shell from a config. Note: it deliberately does NOT
-- parse raw_text into elements -- parsing happens at render time on the
-- receiving client, from the already-filtered text, so the filter governs what
-- is displayed (see Render).

local _Patterns = script.Parent
local _Utility  = _Patterns.Parent._Utility
local _Classes  = _Patterns.Parent._Classes

local Types    = require(_Patterns.Parent.Types)
local MsgClass = require(_Classes.Message)
local IdUtil   = require(_Utility.Id)

local Message = {}

function Message.Construct(config: Types.MessageClass?): Types.MessageClass
	local template = MsgClass.template()

	if config then
		if config.metadata then
			for k, v in config.metadata do
				template.metadata[k] = v
			end
		end
		if config.content then
			if config.content.raw_text then template.content.raw_text = config.content.raw_text end
			if config.content.elements then template.content.elements = config.content.elements end
			if config.content.embeds   then template.content.embeds   = config.content.embeds end
		end
		if config.kind      then template.kind      = config.kind end
		if config.tags      then template.tags      = config.tags end
		if config.pinned    then template.pinned    = config.pinned end
		if config.reactions then template.reactions = config.reactions end
	end

	if not template.metadata.id or template.metadata.id == "" then
		template.metadata.id = IdUtil.Generate()
	end
	if not template.metadata.timestamp or template.metadata.timestamp == 0 then
		template.metadata.timestamp = os.time()
	end

	return MsgClass.new(template)
end

return Message
