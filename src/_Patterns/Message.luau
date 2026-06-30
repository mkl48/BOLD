local _Patterns = script.Parent
local _Utility  = _Patterns.Parent._Utility
local _Classes  = _Patterns.Parent._Classes

local Types     = require(_Patterns.Parent.Types)
local MsgClass  = require(_Classes.Message)
local IdUtil    = require(_Utility.Id)
local Hooks     = require(_Utility.Hooks)

local Parser

local Message = {}

local _parseOpts = {
	enabled  = true,
	markdown = true,
	mentions = true,
	emoji    = true,
}

function Message.SetParseOptions(opts: { [string]: boolean })
	for k, v in opts do
		_parseOpts[k] = v
	end
end

function Message.Construct(config: Types.MessageClass?): Types.MessageClass
	local template = MsgClass.template()

	if config then
		if config.metadata then
			for k, v in config.metadata do
				template.metadata[k] = v
			end
		end
		if config.content then
			if config.content.raw_text  then template.content.raw_text = config.content.raw_text end
			if config.content.elements  then template.content.elements  = config.content.elements end
			if config.content.embeds    then template.content.embeds    = config.content.embeds end
		end
		if config.kind   then template.kind   = config.kind end
		if config.tags   then template.tags   = config.tags end
		if config.pinned then template.pinned = config.pinned end
	end

	if not template.metadata.id or template.metadata.id == "" then
		template.metadata.id = IdUtil.Generate()
	end
	if not template.metadata.timestamp or template.metadata.timestamp == 0 then
		template.metadata.timestamp = os.time()
	end

	local hasElements = template.content.elements and #template.content.elements > 0
	local hasRaw      = template.content.raw_text and template.content.raw_text ~= ""

	if _parseOpts.enabled and hasRaw and not hasElements then
		if not Parser then
			Parser = require(_Patterns.Parser)
		end

		Hooks:Fire("BeforeParse", template.content.raw_text)

		local players = game:GetService("Players"):GetPlayers()
		local elements = Parser.Parse(template.content.raw_text, {
			markdown    = _parseOpts.markdown,
			mentions    = _parseOpts.mentions,
			emoji       = _parseOpts.emoji,
			player_list = players,
		})
		template.content.elements = elements

		Hooks:Fire("AfterParse", elements)
	end

	return MsgClass.new(template)
end

return Message