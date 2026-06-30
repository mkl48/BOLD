--[[
	Filter

	Promise-based wrapper around TextService text filtering, with a local
	case-insensitive hard-block backstop layered on top (see HardBlockFilter).

	Requires the Promise library (https://github.com/evaera/roblox-lua-promise)
	to be present in your packages folder. Change the require path below to
	match wherever it lives in your project.

	Usage:

		Filter.BroadcastAsync(text, player):andThen(function(filtered)
			...
		end)

		Filter.ForPlayerAsync(text, fromPlayer, toPlayer):andThen(function(filtered)
			...
		end)
]]

--[[
	Filter

	Promise-based wrapper around TextService text filtering, layered with:
		1. Roblox's TextService:FilterStringAsync() (primary, authoritative)
		2. A local case-insensitive hard-block backstop (HardBlockFilter)
		3. PurgoMalum (https://www.purgomalum.com) as a supplementary
		   third-party profanity check

	PurgoMalum is a free third-party service with no uptime guarantee, so
	it's treated as fail-open: if the request errors, times out, or the
	service is down, we keep whatever text the pipeline already had instead
	of blocking message delivery on it.

	Requires the Promise library (https://github.com/evaera/roblox-lua-promise)
	to be present in your packages folder. Change the require path below to
	match wherever it lives in your project.

	Usage:

		Filter.BroadcastAsync(text, player):andThen(function(filtered)
			...
		end)

		Filter.ForPlayerAsync(text, fromPlayer, toPlayer):andThen(function(filtered)
			...
		end)
]]

local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

-- Adjust these paths to match your project structure.
local Promise = require(script.Parent.Parent._Packages.Promise)
local hardBlockCheck = require(script.Parent.HardBlockFilter)

local Filter = {}

local _cache: { [string]: string } = {}
local _cacheOrder: { string } = {} -- tracks insertion order so we can evict oldest entries
local CACHE_LIMIT = 500

local PURGOMALUM_URL = "https://www.purgomalum.com/service/plain"

local function cacheKey(text: string, userId: number): string
	return tostring(userId) .. "|" .. text
end

local function store(key: string, value: string)
	if _cache[key] == nil then
		table.insert(_cacheOrder, key)
	end
	_cache[key] = value

	-- Evict oldest entries one at a time until we're back under the limit,
	-- instead of wiping the whole cache.
	while #_cacheOrder > CACHE_LIMIT do
		local oldestKey = table.remove(_cacheOrder, 1)
		if oldestKey then
			_cache[oldestKey] = nil
		end
	end
end

-- Runs text through PurgoMalum. Fails open (returns the input unchanged)
-- on any error, since this is a best-effort supplementary layer, not the
-- source of truth.
local function purgoMalumCheck(text: string): string
	if text == "" then
		return text
	end

	local url = PURGOMALUM_URL .. "?text=" .. HttpService:UrlEncode(text)

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "GET",
		})
	end)

	if not ok or not response.Success then
		-- Don't let a flaky third-party service break filtering --
		-- fall back to whatever text we already had.
		return text
	end

	return response.Body
end

-- Runs the full layered pipeline: Roblox filter -> hard block -> PurgoMalum.
-- `robloxFilteredText` is the already-Roblox-filtered text (or the raw
-- original if that call failed).
local function applyLayers(robloxFilteredText: string): string
	local out = hardBlockCheck.Replace(robloxFilteredText)
	out = purgoMalumCheck(out)
	return out
end

-- Broadcast filter -- result is appropriate for ALL viewers (e.g. a sign,
-- a server-wide announcement, anything not scoped to a single recipient)
function Filter.BroadcastAsync(text: string, fromPlayer: Player?)
	if not IS_SERVER then
		return Promise.resolve(text)
	end

	local uid = fromPlayer and fromPlayer.UserId or 0
	local key = cacheKey(text, uid)

	local cached = _cache[key]
	if cached then
		return Promise.resolve(cached)
	end

	return Promise.new(function(resolve)
		local ok, result = pcall(function()
			local res = TextService:FilterStringAsync(text, uid)
			return res:GetNonChatStringForBroadcastAsync()
		end)

		local robloxFiltered = ok and result or text
		local out = applyLayers(robloxFiltered)
		store(key, out)
		resolve(out)
	end)
end

-- Chat filter -- result is appropriate for a specific viewer.
-- GetChatForUserAsync is deprecated; GetNonChatStringForUserAsync is the
-- correct replacement for custom (non-TextChatService) chat pipelines.
function Filter.ForPlayerAsync(text: string, fromPlayer: Player, toPlayer: Player)
	if not IS_SERVER then
		return Promise.resolve(text)
	end

	local key = cacheKey(text, fromPlayer.UserId) .. "|" .. tostring(toPlayer.UserId)

	local cached = _cache[key]
	if cached then
		return Promise.resolve(cached)
	end

	return Promise.new(function(resolve)
		local ok, result = pcall(function()
			local res = TextService:FilterStringAsync(text, fromPlayer.UserId)
			return res:GetNonChatStringForUserAsync(toPlayer.UserId)
		end)

		local robloxFiltered = ok and result or text
		local out = applyLayers(robloxFiltered)
		store(key, out)
		resolve(out)
	end)
end

return Filter