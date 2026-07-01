-- Bold
-- _Utility/Advise
-- Plinko Labs
--
-- Local case-insensitive blocklist backstop layered on top of Roblox's
-- TextService filter (not a replacement). The blocklist is sourced from Proflis
-- (fetched over HttpService on the server, relayed to clients) so no profane
-- string literals live in the scripts themselves.
--
-- Matching is done with a per-word Lua pattern built so that:
--   * separators between letters are tolerated (catches "f u c k", "f.u.c.k"),
--   * digit/symbol leet is folded to letters first (catches "f0ck"),
--   * INTERIOR vowels are optional (catches vowel-dropping like "fck"), while
--     the FIRST and LAST characters stay literal, and
--   * the match must sit on WORD BOUNDARIES (%f frontiers).
-- The word-boundary requirement is what keeps this from censoring everything --
-- "class" never matches "ass", "bus" never matches "abuse" -- while still
-- catching the standalone/obfuscated word. An allow-list handles the rare
-- Scunthorpe case. The list loads lazily on first use.

local _Utility  = script.Parent
local _Packages = _Utility.Parent._Packages
local Proflis   = require(_Packages.Proflis)

local AdviseFilter = {}

type Entry = { word: string, pattern: string }

-- digit/symbol leet folded to letters (applied in place, length-preserving)
local LEET: { [string]: string } = {
	["4"] = "a", ["@"] = "a", ["3"] = "e", ["1"] = "i", ["!"] = "i",
	["0"] = "o", ["5"] = "s", ["$"] = "s", ["7"] = "t", ["8"] = "b", ["9"] = "g",
}

local VOWELS: { [string]: boolean } = { a = true, e = true, i = true, o = true, u = true }

-- optional run of non-word characters allowed between letters of a blocked word
local INNER_SEP = "[^%w]*"

-- Lower-case + fold leet, preserving byte positions so matches map straight back.
local function leetLower(text: string): string
	local out = table.create(#text)
	for i = 1, #text do
		local ch = text:sub(i, i)
		out[i] = LEET[ch] or ch:lower()
	end
	return table.concat(out)
end

local function escapeLiteral(c: string): string
	if c:match("%w") then return c end
	return "%" .. c
end

-- Build the boundary-anchored, separator-tolerant, interior-vowel-optional pattern.
local function wordToPattern(word: string): string
	local n = #word
	local parts: { string } = { "%f[%w]" } -- must start at a word boundary
	for i = 1, n do
		local c = word:sub(i, i)
		local interior = i > 1 and i < n
		if interior and VOWELS[c] then
			table.insert(parts, "[aeiou]?")
		else
			table.insert(parts, escapeLiteral(c))
		end
		if i < n then
			table.insert(parts, INNER_SEP)
		end
	end
	table.insert(parts, "%f[%W]") -- ...and end at a word boundary
	return table.concat(parts)
end

local function makeEntry(word: string): Entry
	local lower = word:lower()
	return { word = lower, pattern = wordToPattern(lower) }
end

local _blocked: { Entry } = {}
local _allowed: { [string]: boolean } = {}

-- Lazily build the blocklist from Proflis the first time we filter anything, so
-- it doesn't matter whether Proflis.Start() (server fetch) has run yet. Fail-open.
local _loaded = false
local function ensureLoaded()
	if _loaded then return end
	_loaded = true
	local ok, list = pcall(Proflis.Get)
	if not ok or type(list) ~= "table" then return end
	for key in list do
		-- ignore very short words (too collision-prone) and non-strings
		if type(key) == "string" and #key >= 3 then
			table.insert(_blocked, makeEntry(key))
		end
	end
end

-- Expand a byte span out to the whole word/number run it sits in, for allow-list checks.
local function expandToEnclosingWord(text: string, s: number, e: number): (number, number)
	local len = #text
	local function isWordChar(c: string): boolean
		return c ~= "" and (c:match("%w") ~= nil or c == "'")
	end
	while s > 1 and isWordChar(text:sub(s - 1, s - 1)) do s -= 1 end
	while e < len and isWordChar(text:sub(e + 1, e + 1)) do e += 1 end
	return s, e
end

local function isAllowedAt(text: string, s: number, e: number): boolean
	if next(_allowed) == nil then return false end
	local ws, we = expandToEnclosingWord(text, s, e)
	return _allowed[text:sub(ws, we):lower()] == true
end

local function findSpans(text: string): { { start: number, stop: number, match: string } }
	ensureLoaded()
	local hay = leetLower(text)
	local spans = {}
	for _, entry in _blocked do
		local from = 1
		while true do
			local s, e = hay:find(entry.pattern, from)
			if not s then break end
			if not isAllowedAt(text, s, e) then
				table.insert(spans, { start = s, stop = e, match = text:sub(s, e) })
			end
			from = (e >= s) and (e + 1) or (s + 1)
		end
	end
	return spans
end

-- ─── Core API (drop-in for the old HardBlockFilter) ──────────────────────────

function AdviseFilter.Replace(text: string): string
	if text == "" then return text end
	local spans = findSpans(text)
	if #spans == 0 then return text end
	local masked = table.create(#text)
	for i = 1, #text do
		masked[i] = text:sub(i, i)
	end
	for _, span in spans do
		for i = span.start, span.stop do
			masked[i] = "*"
		end
	end
	return table.concat(masked)
end

function AdviseFilter.ContainsBlockedWord(text: string): boolean
	if text == "" then return false end
	ensureLoaded()
	local hay = leetLower(text)
	local hasAllow = next(_allowed) ~= nil
	for _, entry in _blocked do
		local s, e = hay:find(entry.pattern)
		if s then
			if not hasAllow or not isAllowedAt(text, s, e) then
				return true
			end
		end
	end
	return false
end

-- Extend the blocklist at runtime (surfaced as Bold.AddBlockedWords).
function AdviseFilter.Add(words: { string } | string)
	if type(words) == "string" then
		table.insert(_blocked, makeEntry(words :: string))
		return
	end
	for _, w in words :: { string } do
		table.insert(_blocked, makeEntry(w))
	end
end

function AdviseFilter.Remove(word: string)
	local lower = word:lower()
	for i, entry in _blocked do
		if entry.word == lower then
			table.remove(_blocked, i)
			break
		end
	end
end

-- ─── Allow list (Scunthorpe-style exceptions) ────────────────────────────────

function AdviseFilter.AddAllowed(words: { string } | string)
	if type(words) == "string" then
		_allowed[(words :: string):lower()] = true
		return
	end
	for _, w in words :: { string } do
		_allowed[w:lower()] = true
	end
end

function AdviseFilter.RemoveAllowed(word: string)
	_allowed[word:lower()] = nil
end

function AdviseFilter.IsAllowed(word: string): boolean
	return _allowed[word:lower()] == true
end

-- ─── Match reporting (logging / scoring / warning reasons) ───────────────────

function AdviseFilter.Detect(text: string): { string }
	local spans = findSpans(text)
	local matches = table.create(#spans)
	for _, span in spans do
		table.insert(matches, span.match)
	end
	return matches
end

function AdviseFilter.Count(text: string): number
	return #findSpans(text)
end

return AdviseFilter
