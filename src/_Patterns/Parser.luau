-- Bold
-- _Patterns/Parser
-- Plinko Labs

-- Turns raw message text into a flat list of typed elements the renderer walks.
-- Block constructs (panels, blockquotes) are handled by an outer line loop;
-- everything else is an inline character scan.

local Parser = {}

-- ─── Emoji tables ────────────────────────────────────────────────────────────

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

function Parser.GetEmojiAsset(name: string): string?
	return _custom_emoji[name:lower()]
end

function Parser.SearchEmoji(query: string): { string }
	local q = query:lower()
	local results: { string } = {}
	for name in UNICODE_EMOJI do
		if name:find(q, 1, true) then table.insert(results, name) end
	end
	for name in _custom_emoji do
		if name:find(q, 1, true) then table.insert(results, name) end
	end
	table.sort(results)
	return results
end

-- ─── Colors ──────────────────────────────────────────────────────────────────

local NAMED_COLORS: { [string]: Color3 } = {
	red = Color3.fromRGB(255, 70, 70), green = Color3.fromRGB(80, 220, 100),
	blue = Color3.fromRGB(90, 150, 255), yellow = Color3.fromRGB(255, 220, 80),
	orange = Color3.fromRGB(255, 160, 50), purple = Color3.fromRGB(180, 100, 255),
	pink = Color3.fromRGB(255, 120, 200), cyan = Color3.fromRGB(80, 220, 230),
	teal = Color3.fromRGB(40, 200, 180), lime = Color3.fromRGB(170, 255, 90),
	white = Color3.fromRGB(255, 255, 255), black = Color3.fromRGB(20, 20, 20),
	gray = Color3.fromRGB(150, 150, 150), grey = Color3.fromRGB(150, 150, 150),
}

local function hexToColor(hex: string): Color3?
	hex = hex:gsub("#", "")
	if #hex == 3 then
		hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
	end
	if #hex ~= 6 then return nil end
	local r = tonumber(hex:sub(1, 2), 16)
	local g = tonumber(hex:sub(3, 4), 16)
	local b = tonumber(hex:sub(5, 6), 16)
	if not (r and g and b) then return nil end
	return Color3.fromRGB(r, g, b)
end

local function resolveColor(spec: string): Color3?
	spec = spec:gsub("^%s*(.-)%s*$", "%1")
	if spec:sub(1, 1) == "#" then return hexToColor(spec) end
	return NAMED_COLORS[spec:lower()]
end

-- ─── Token types ─────────────────────────────────────────────────────────────

type Token = {
	type: string,
	content: string,
	formatting: { [string]: any }?,
	data: { [string]: any }?,
}

local function resolveEmoji(name: string): Token?
	local n = name:lower()
	if UNICODE_EMOJI[n] then
		return { type = "emoji_unicode", content = UNICODE_EMOJI[n], data = { emoji_name = n } }
	end
	if _custom_emoji[n] then
		return { type = "emoji_custom", content = n, data = { emoji_name = n, emoji_asset = _custom_emoji[n] } }
	end
	return nil
end

export type ParseOptions = {
	markdown: boolean?,
	mentions: boolean?,
	emoji: boolean?,
	panels: boolean?,
	links: boolean?,
	player_list: { Player }?,
}

-- ─── Inline scan ─────────────────────────────────────────────────────────────

local function buildPlayerMap(opts: ParseOptions): { [string]: Player }
	local map: { [string]: Player } = {}
	if opts.player_list then
		for _, p in opts.player_list do
			map[p.Name:lower()] = p
			if p.DisplayName then map[p.DisplayName:lower()] = p end
		end
	end
	return map
end

local function parseInline(raw: string, opts: ParseOptions, playerMap: { [string]: Player }, tokens: { Token })
	local doMarkdown = opts.markdown ~= false
	local doMentions = opts.mentions ~= false
	local doEmoji    = opts.emoji ~= false
	local doLinks    = opts.links ~= false

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
					flush(); table.insert(tokens, resolved); i = e + 1; continue
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
					type = "mention", content = "@" .. name,
					data = { mention_name = name, mention_id = player and player.UserId or nil },
				})
				i = e + 1; continue
			end
		end

		-- ||spoiler||
		if doMarkdown and ch2 == "||" then
			local _, e, content = raw:find("^||(.-)||", i)
			if e and #content > 0 then
				flush(); table.insert(tokens, { type = "spoiler", content = content }); i = e + 1; continue
			end
		end

		-- {color|text}  ({#ff0000|hi} or {red|hi})
		if doMarkdown and ch == "{" then
			local _, e, spec, content = raw:find("^{([^|{}]+)|([^{}]*)}", i)
			if e and content and #content > 0 then
				local color = resolveColor(spec)
				if color then
					flush()
					table.insert(tokens, { type = "color", content = content, data = { color = color } })
					i = e + 1; continue
				end
			end
		end

		-- [label](url)
		if doLinks and ch == "[" then
			local _, e, label, url = raw:find("^%[([^%]]+)%]%(([^%s%)]+)%)", i)
			if e then
				flush()
				table.insert(tokens, { type = "link", content = label, data = { link_url = url } })
				i = e + 1; continue
			end
		end

		-- **bold**
		if doMarkdown and ch2 == "**" then
			local _, e, content = raw:find("^%*%*(.-)%*%*", i)
			if e and #content > 0 then
				flush(); table.insert(tokens, { type = "text", content = content, formatting = { bold = true } }); i = e + 1; continue
			end
		end

		-- *italic*  (not **)
		if doMarkdown and ch == "*" and raw:sub(i + 1, i + 1) ~= "*" then
			local _, e, content = raw:find("^%*(.-)%*", i)
			if e and #content > 0 then
				flush(); table.insert(tokens, { type = "text", content = content, formatting = { italic = true } }); i = e + 1; continue
			end
		end

		-- __underline__
		if doMarkdown and ch2 == "__" then
			local _, e, content = raw:find("^__(.-)__", i)
			if e and #content > 0 then
				flush(); table.insert(tokens, { type = "text", content = content, formatting = { underline = true } }); i = e + 1; continue
			end
		end

		-- ~~strikethrough~~
		if doMarkdown and ch2 == "~~" then
			local _, e, content = raw:find("^~~(.-)~~", i)
			if e and #content > 0 then
				flush(); table.insert(tokens, { type = "text", content = content, formatting = { strikethrough = true } }); i = e + 1; continue
			end
		end

		-- `code`
		if doMarkdown and ch == "`" then
			local _, e, content = raw:find("^`([^`]+)`", i)
			if e and #content > 0 then
				flush(); table.insert(tokens, { type = "code", content = content, formatting = { code = true } }); i = e + 1; continue
			end
		end

		pending ..= ch
		i += 1
	end

	flush()
end

-- ─── Panel argument parsing ──────────────────────────────────────────────────

-- `question="Best map?" options="A,B,C" compact foo=bar`
-- -> { question = "Best map?", options = "A,B,C", foo = "bar", compact = true,
--      _positional = {} }
local function parseArgs(str: string): { [string]: any }
	local args: { [string]: any } = { _positional = {} }
	local i = 1
	local n = #str
	while i <= n do
		-- skip whitespace
		local ws = str:find("%S", i)
		if not ws then break end
		i = ws

		-- key="quoted" or key=bare or bare flag
		local _, e, key, q, qval = str:find('^([%w_]+)=(["\'])(.-)%2', i)
		if e then
			args[key] = qval
			i = e + 1
		else
			local _, e2, k2, v2 = str:find("^([%w_]+)=([^%s]+)", i)
			if e2 then
				args[k2] = v2
				i = e2 + 1
			else
				local _, e3, flag = str:find("^([^%s]+)", i)
				if e3 then
					table.insert(args._positional, flag)
					-- bare word with no '=' reads as a boolean flag too
					if flag:match("^[%w_]+$") then args[flag] = true end
					i = e3 + 1
				else
					break
				end
			end
		end
	end
	return args
end

-- ─── Public parse ────────────────────────────────────────────────────────────

function Parser.Parse(raw: string?, opts: ParseOptions?): { Token }
	if not raw or raw == "" then return {} end
	local o = opts or {}
	local doPanels = o.panels ~= false
	local playerMap = buildPlayerMap(o)

	local tokens: { Token } = {}
	local lines = string.split(raw, "\n")
	local i = 1

	while i <= #lines do
		local line = lines[i]

		-- panel fence: :::name args ... :::
		local name, argstr = line:match("^:::([%w_]+)%s*(.*)$")
		if doPanels and name then
			local body = {}
			local j = i + 1
			while j <= #lines and lines[j]:match("^:::%s*$") == nil do
				table.insert(body, lines[j])
				j += 1
			end
			table.insert(tokens, {
				type = "panel",
				content = name,
				data = {
					panel_name = name,
					panel_args = parseArgs(argstr or ""),
					panel_body = table.concat(body, "\n"),
				},
			})
			i = j + 1
			continue
		end

		-- blockquote: > text
		local quote = line:match("^>%s?(.*)$")
		if quote ~= nil then
			table.insert(tokens, { type = "blockquote", content = quote })
			i += 1
			continue
		end

		parseInline(line, o, playerMap, tokens)
		if i < #lines then
			table.insert(tokens, { type = "text", content = "\n" })
		end
		i += 1
	end

	return tokens
end

-- Scan raw text for @mentions and return the resolved userIds. Server-side use:
-- attaches the audience so receiving clients know if they were pinged.
function Parser.ScanMentions(raw: string?, players: { Player }): { number }
	if not raw or raw == "" then return {} end
	local map: { [string]: Player } = {}
	for _, p in players do
		map[p.Name:lower()] = p
		if p.DisplayName then map[p.DisplayName:lower()] = p end
	end

	local ids: { number } = {}
	local seen: { [number]: boolean } = {}
	for name in raw:gmatch("@([%w_]+)") do
		local p = map[name:lower()]
		if p and not seen[p.UserId] then
			seen[p.UserId] = true
			table.insert(ids, p.UserId)
		end
	end
	return ids
end

return Parser
