local Parser = {}

-- Built-in unicode emoji table
local UNICODE_EMOJI: { [string]: string } = {
	smile = "😀", grin = "😁", joy = "😂", rofl = "🤣", smiley = "😃",
	laughing = "😆", sweat_smile = "😅", wink = "😉", blush = "😊",
	yum = "😋", sunglasses = "😎", heart_eyes = "😍", thinking = "🤔",
	neutral = "😐", unamused = "😒", frowning = "😦", open_mouth = "😮",
	astonished = "😲", flushed = "😳", dizzy = "😵", rage = "😡",
	angry = "😠", cry = "😢", sob = "😭", fearful = "😨",
	sweat = "😰", heart = "❤️", broken_heart = "💔", fire = "🔥",
	star = "⭐", check = "✅", x = "❌", warning = "⚠️",
	question = "❓", exclamation = "❗", tada = "🎉", rocket = "🚀",
	trophy = "🏆", skull = "💀", ghost = "👻", robot = "🤖",
	wave = "👋", thumbsup = "👍", thumbsdown = "👎", clap = "👏",
	eyes = "👀", muscle = "💪", crown = "👑", gem = "💎",
	sword = "⚔️", shield = "🛡️", wrench = "🔧", bolt = "⚡",
	snowflake = "❄️", sun = "☀️", moon = "🌙", earth = "🌍",
	cat = "🐱", dog = "🐶", panda = "🐼", fox = "🦊", wolf = "🐺",
}

local _custom_emoji: { [string]: string } = {}
local _stickers: { [string]: string } = {}

Parser.UNICODE_EMOJI = UNICODE_EMOJI

function Parser.RegisterEmoji(name: string, assetId: string)
	_custom_emoji[name:lower()] = assetId
end

function Parser.RegisterSticker(id: string, assetId: string)
	_stickers[id] = assetId
end

function Parser.GetStickerAsset(id: string): string?
	return _stickers[id]
end

function Parser.SearchEmoji(query: string): { string }
	local q = query:lower()
	local results: { string } = {}

	for name in UNICODE_EMOJI do
		if name:find(q, 1, true) then
			table.insert(results, name)
		end
	end
	for name in _custom_emoji do
		if name:find(q, 1, true) then
			table.insert(results, name)
		end
	end

	table.sort(results)
	return results
end

type ParsedToken = {
	type: string,
	content: string,
	formatting: { [string]: any }?,
	data: { [string]: any }?,
}

local function resolveEmoji(name: string): ParsedToken?
	local n = name:lower()
	if UNICODE_EMOJI[n] then
		return {
			type = "emoji_unicode",
			content = UNICODE_EMOJI[n],
			data = { emoji_name = n },
		}
	end
	if _custom_emoji[n] then
		return {
			type = "emoji_custom",
			content = n,
			data = { emoji_name = n, emoji_asset = _custom_emoji[n] },
		}
	end
	return nil
end

export type ParseOptions = {
	markdown: boolean?,
	mentions: boolean?,
	emoji: boolean?,
	player_list: { Player }?,
}

function Parser.Parse(raw: string, opts: ParseOptions?): { ParsedToken }
	if not raw or raw == "" then return {} end

	local o = opts or {}
	local doMarkdown = o.markdown ~= false
	local doMentions = o.mentions ~= false
	local doEmoji    = o.emoji ~= false

	local playerMap: { [string]: Player } = {}
	if o.player_list then
		for _, p in o.player_list do
			playerMap[p.Name:lower()] = p
		end
	end

	local tokens: { ParsedToken } = {}
	local pending = ""
	local i = 1

	local function flush()
		if #pending > 0 then
			table.insert(tokens, { type = "text", content = pending })
			pending = ""
		end
	end

	while i <= #raw do
		local ch  = raw:sub(i, i)
		local ch2 = raw:sub(i, i + 1)

		-- :emoji:
		if doEmoji and ch == ":" then
			local _, e, name = raw:find("^:([%w_]+):", i)
			if e then
				local resolved = resolveEmoji(name)
				if resolved then
					flush()
					table.insert(tokens, resolved)
					i = e + 1
					continue
				end
			end
		end

		-- @mention
		if doMentions and ch == "@" then
			local _, e, name = raw:find("^@([%w_]+)", i)
			if e then
				flush()
				local player = playerMap[name:lower()]
				table.insert(tokens, {
					type    = "mention",
					content = "@" .. name,
					data    = {
						mention_name = name,
						mention_id   = player and player.UserId or nil,
					},
				})
				i = e + 1
				continue
			end
		end

		-- **bold**
		if doMarkdown and ch2 == "**" then
			local _, e, content = raw:find("^%*%*(.-)%*%*", i)
			if e and #content > 0 then
				flush()
				table.insert(tokens, { type = "text", content = content, formatting = { bold = true } })
				i = e + 1
				continue
			end
		end

		-- *italic*  (not **)
		if doMarkdown and ch == "*" and raw:sub(i + 1, i + 1) ~= "*" then
			local _, e, content = raw:find("^%*(.-)%*", i)
			if e and #content > 0 then
				flush()
				table.insert(tokens, { type = "text", content = content, formatting = { italic = true } })
				i = e + 1
				continue
			end
		end

		-- __underline__
		if doMarkdown and ch2 == "__" then
			local _, e, content = raw:find("^__(.-)__", i)
			if e and #content > 0 then
				flush()
				table.insert(tokens, { type = "text", content = content, formatting = { underline = true } })
				i = e + 1
				continue
			end
		end

		-- ~~strikethrough~~
		if doMarkdown and ch2 == "~~" then
			local _, e, content = raw:find("^~~(.-)~~", i)
			if e and #content > 0 then
				flush()
				table.insert(tokens, { type = "text", content = content, formatting = { strikethrough = true } })
				i = e + 1
				continue
			end
		end

		-- `code`
		if doMarkdown and ch == "`" then
			local _, e, content = raw:find("^`([^`]+)`", i)
			if e and #content > 0 then
				flush()
				table.insert(tokens, { type = "code", content = content, formatting = { code = true } })
				i = e + 1
				continue
			end
		end

		pending ..= ch
		i += 1
	end

	flush()
	return tokens
end

return Parser