-- Bold
-- _Classes/Builder
-- Plinko Labs

-- Fluent message builder behind Bold.Compose(). Accumulates a raw_text string in
-- Bold's own markdown plus structured embeds, then :Send() hands a lean payload
-- to the realm-appropriate sink wired up in init.

local Types = require(script.Parent.Parent.Types)

local Builder = {}
Builder.__index = Builder

local function hexOf(color: Color3): string
	return string.format("#%02x%02x%02x",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5))
end

function Builder.new(sink: ((payload: any) -> ())?)
	return setmetatable({
		_parts = {},
		_embeds = {},
		_kind = nil,
		_tags = nil,
		_reply = nil,
		_recipient = nil,
		_pinned = nil,
		_sink = sink,
	}, Builder)
end

local function push(self, s: string)
	table.insert(self._parts, s)
	return self
end

-- inline text
function Builder:Text(s: string) return push(self, s) end
function Builder:Bold(s: string) return push(self, "**" .. s .. "**") end
function Builder:Italic(s: string) return push(self, "*" .. s .. "*") end
function Builder:Underline(s: string) return push(self, "__" .. s .. "__") end
function Builder:Strike(s: string) return push(self, "~~" .. s .. "~~") end
function Builder:Code(s: string) return push(self, "`" .. s .. "`") end
function Builder:Spoiler(s: string) return push(self, "||" .. s .. "||") end
function Builder:Emoji(name: string) return push(self, ":" .. name .. ":") end
function Builder:Space() return push(self, " ") end
function Builder:Line() return push(self, "\n") end

function Builder:Color(color: Color3 | string, s: string)
	local spec = typeof(color) == "Color3" and hexOf(color) or tostring(color)
	return push(self, "{" .. spec .. "|" .. s .. "}")
end

function Builder:Link(label: string, url: string)
	return push(self, "[" .. label .. "](" .. url .. ")")
end

function Builder:Mention(playerOrName: Player | string)
	local name = typeof(playerOrName) == "Instance" and (playerOrName :: Player).Name or tostring(playerOrName)
	return push(self, "@" .. name .. " ")
end

function Builder:Quote(s: string)
	return push(self, "\n> " .. s .. "\n")
end

function Builder:Panel(name: string, args: { [string]: any }?, body: string?)
	local pieces = { ":::" .. name }
	if args then
		for k, v in args do
			if v == true then
				table.insert(pieces, k)
			else
				table.insert(pieces, ('%s="%s"'):format(k, tostring(v)))
			end
		end
	end
	local fence = table.concat(pieces, " ")
	if body and body ~= "" then fence ..= "\n" .. body end
	fence ..= "\n:::"
	return push(self, "\n" .. fence .. "\n")
end

-- embeds
function Builder:Embed(embed: Types.Embed)
	table.insert(self._embeds, embed)
	return self
end

function Builder:Image(image_id: string, config: Types.ImageEmbed?)
	local e = config and table.clone(config) or {}
	e.type = "Image"; e.image_id = image_id
	table.insert(self._embeds, e)
	return self
end

function Builder:Sticker(sticker_id: string, config: { size: number?, color: Color3? }?)
	local e = config and table.clone(config) or {}
	e.type = "Sticker"; e.sticker_id = sticker_id
	table.insert(self._embeds, e)
	return self
end

-- metadata
function Builder:Kind(kind: string) self._kind = kind; return self end
function Builder:Tag(...: string)
	self._tags = self._tags or {}
	for _, t in { ... } do table.insert(self._tags, t) end
	return self
end
function Builder:Reply(message: any)
	local meta = message.metadata
	local preview = (message.content and message.content.raw_text) or ""
	self._reply = { id = meta.id, author_name = meta.author_name, preview = preview:sub(1, 60) }
	return self
end
function Builder:To(player: Player) self._recipient = player.UserId; return self end
function Builder:Pin() self._pinned = true; return self end

-- output
function Builder:Payload(): any
	return {
		text = table.concat(self._parts),
		embeds = self._embeds,
		kind = self._kind,
		tags = self._tags,
		reply_to = self._reply,
		recipient_id = self._recipient,
		pinned = self._pinned,
	}
end

function Builder:Send()
	assert(self._sink, "[Bold] this builder has no sink; call Bold.Compose()")
	self._sink(self:Payload())
end

return Builder
