-- Bold
-- _Utility/HardBlockFilter
-- Plinko Labs

-- Local case-insensitive blocklist backstop layered on top of Roblox's
-- TextService filter (not a replacement). Detection runs over a *collapsed,
-- normalized* copy of the text -- spacing/punctuation dropped, digit-leet mapped
-- to letters -- while masking is applied back to the original via an index map.
-- That catches "f u c k", "f.u.c.k", "f0ck" and "fvck"-style obfuscation without
-- relying on TextService. The blocklist MUST stay narrow: matching is substring
-- based (no word boundary), which is only false-positive-safe for words that
-- never legitimately appear inside other words.

local HardBlockFilter = {}

local _blocked: { string } = {
	"fuck",
	"fvck",
}

-- separators dropped so obfuscating letters become adjacent
local SEP: { [string]: boolean } = {
	[" "] = true, ["."] = true, ["-"] = true, ["_"] = true,
	["*"] = true, [","] = true, ["'"] = true,
}

-- digit/symbol leet mapped to letters
local LEET: { [string]: string } = {
	["4"] = "a", ["@"] = "a", ["3"] = "e", ["1"] = "i", ["!"] = "i",
	["0"] = "o", ["5"] = "s", ["$"] = "s", ["7"] = "t", ["8"] = "b", ["9"] = "g",
}

local SENTINEL = "\1" -- non-letter boundary a blocked word can never cross

-- Build a collapsed normalized string plus a map from normalized position ->
-- original byte index, so a match can be projected back onto the source text.
local function normalize(text: string): (string, { number })
	local chars: { string } = {}
	local map: { number } = {}

	for i = 1, #text do
		local ch = text:sub(i, i)
		local low = ch:lower()
		if low:match("%a") then
			table.insert(chars, low)
			table.insert(map, i)
		elseif LEET[ch] then
			table.insert(chars, LEET[ch])
			table.insert(map, i)
		elseif SEP[ch] then
			-- dropped
		else
			table.insert(chars, SENTINEL)
			table.insert(map, i)
		end
	end

	return table.concat(chars), map
end

-- Original [startByte, endByte] spans to mask.
local function findSpans(text: string): { { number } }
	local norm, map = normalize(text)
	local spans: { { number } } = {}
	for _, word in _blocked do
		local from = 1
		while true do
			local s, e = norm:find(word, from, true)
			if not s then break end
			table.insert(spans, { map[s], map[e] })
			from = e + 1
		end
	end
	return spans
end

function HardBlockFilter.Replace(text: string): string
	if text == "" then return text end
	local spans = findSpans(text)
	if #spans == 0 then return text end

	local masked = table.create(#text)
	for i = 1, #text do
		masked[i] = text:sub(i, i)
	end
	for _, span in spans do
		for i = span[1], span[2] do
			masked[i] = "*"
		end
	end
	return table.concat(masked)
end

function HardBlockFilter.ContainsBlockedWord(text: string): boolean
	if text == "" then return false end
	return #findSpans(text) > 0
end

-- Extend the blocklist at runtime (surfaced as Bold.AddBlockedWords).
function HardBlockFilter.Add(words: { string } | string)
	if type(words) == "string" then
		table.insert(_blocked, (words :: string):lower())
		return
	end
	for _, w in words :: { string } do
		table.insert(_blocked, w:lower())
	end
end

return HardBlockFilter
