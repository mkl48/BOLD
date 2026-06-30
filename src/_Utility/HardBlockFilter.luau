-- Case-insensitive word blocklist, used as a backstop layered on top of
-- Roblox's own TextService filter (not a replacement for it).

local HARD_BLOCK_WORDS = {
	"fuck"
	-- add more lowercase words here as needed; keep this list narrow
}

local function toCaseInsensitivePattern(word: string): string
	local pattern = {}
	for char in word:gmatch(".") do
		if char:match("%a") then
			table.insert(pattern, string.format("[%s%s]", char:lower(), char:upper()))
		else
			-- escape any pattern-special characters in non-letter chars
			table.insert(pattern, "%" .. char)
		end
	end
	return table.concat(pattern)
end

-- Precompute patterns once instead of rebuilding them on every call
local _compiledPatterns: { { word: string, pattern: string } } = {}
for _, word in HARD_BLOCK_WORDS do
	table.insert(_compiledPatterns, {
		word = word,
		pattern = toCaseInsensitivePattern(word),
	})
end

local HardBlockFilter = {}

function HardBlockFilter.Replace(text: string): string
	for _, entry in _compiledPatterns do
		text = text:gsub(entry.pattern, function(match)
			return string.rep("*", #match)
		end)
	end
	return text
end

function HardBlockFilter.ContainsBlockedWord(text: string): boolean
	for _, entry in _compiledPatterns do
		if text:find(entry.pattern) then
			return true
		end
	end
	return false
end

return HardBlockFilter