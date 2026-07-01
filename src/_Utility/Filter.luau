-- Bold
-- _Utility/Filter
-- Plinko Labs

--[[
	Filter

	Layered text filtering, split into a fast path the delivery pipeline waits
	on, and a deferred path that never blocks delivery:

		Fast  : TextService:FilterStringAsync   (cached)
		        -> authoritative, instant; everything renders from this.
		           Advise does NOT mask here -- it is warn-only (the input pill).
		Deferred : PurgoMalum (https://www.purgomalum.com)            (best-effort)
		        -> runs AFTER the message is already on screen; if it catches
		           more, the server patches the message in place

	PurgoMalum is a free third-party service with no uptime guarantee, so it is
	treated as fail-open: any error/timeout returns the text unchanged.

	Requires the bundled Promise library.
]]

local HttpService = game:GetService("HttpService")
local TextService  = game:GetService("TextService")
local RunService   = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local Promise        = require(script.Parent.Parent._Packages.Promise)

local Filter = {}

local _cache: { [string]: string } = {}
local _cacheOrder: { string } = {}
local _inflight: { [string]: any } = {} -- key -> Promise, dedupes concurrent identical requests
local CACHE_LIMIT = 500

local PURGOMALUM_URL = "https://www.purgomalum.com/service/plain"

local function cacheKey(text: string, userId: number, scope: string): string
	return scope .. "|" .. tostring(userId) .. "|" .. text
end

local function store(key: string, value: string)
	if _cache[key] == nil then
		table.insert(_cacheOrder, key)
	end
	_cache[key] = value
	while #_cacheOrder > CACHE_LIMIT do
		local oldest = table.remove(_cacheOrder, 1)
		if oldest then _cache[oldest] = nil end
	end
end

-- Shared resolver: cache -> in-flight dedupe -> run `producer` (which returns the
-- filtered string synchronously inside the promise executor).
local function resolveCached(key: string, producer: (resolve: (string) -> ()) -> ())
	local cached = _cache[key]
	if cached then return Promise.resolve(cached) end

	local pending = _inflight[key]
	if pending then return pending end

	local promise = Promise.new(function(resolve)
		producer(function(out)
			store(key, out)
			_inflight[key] = nil
			resolve(out)
		end)
	end)
	_inflight[key] = promise
	return promise
end

-- ─── Fast path (blocking, authoritative) ─────────────────────────────────────

-- Broadcast-scoped: result is appropriate for ALL viewers.
function Filter.Fast(text: string, fromPlayer: Player?)
	if not IS_SERVER or text == "" then
		return Promise.resolve(text)
	end

	local uid = fromPlayer and fromPlayer.UserId or 0
	local key = cacheKey(text, uid, "broadcast")

	return resolveCached(key, function(resolve)
		local ok, result = pcall(function()
			local res = TextService:FilterStringAsync(text, uid)
			return res:GetNonChatStringForBroadcastAsync()
		end)
		local robloxFiltered = ok and result or text
		resolve(robloxFiltered)
	end)
end

-- Per-viewer scoped: result is appropriate for `toPlayer` specifically (whispers).
function Filter.FastForPlayer(text: string, fromPlayer: Player, toPlayer: Player)
	if not IS_SERVER or text == "" then
		return Promise.resolve(text)
	end

	local key = cacheKey(text, fromPlayer.UserId, "user:" .. tostring(toPlayer.UserId))

	return resolveCached(key, function(resolve)
		local ok, result = pcall(function()
			local res = TextService:FilterStringAsync(text, fromPlayer.UserId)
			return res:GetNonChatStringForUserAsync(toPlayer.UserId)
		end)
		local robloxFiltered = ok and result or text
		resolve(robloxFiltered)
	end)
end

-- ─── Deferred path (non-blocking, best-effort) ───────────────────────────────

-- Runs PurgoMalum on already-fast-filtered text. Resolves to the refined text
-- (or the input unchanged on any failure). Never call this before delivery.
function Filter.Deferred(text: string)
	if not IS_SERVER or text == "" then
		return Promise.resolve(text)
	end

	local key = cacheKey(text, 0, "purgo")

	return resolveCached(key, function(resolve)
		local url = PURGOMALUM_URL .. "?text=" .. HttpService:UrlEncode(text)
		local ok, response = pcall(function()
			return HttpService:RequestAsync({ Url = url, Method = "GET" })
		end)
		if not ok or not response.Success then
			resolve(text) -- fail open
			return
		end
		resolve(response.Body)
	end)
end

return Filter
