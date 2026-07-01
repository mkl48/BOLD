-- Bold
-- _Packages/Proflis
-- Plinko Labs
--
-- Sources the profanity word list for Advise. The list lives as JSON data
-- (fetched over HttpService), NOT as string literals in any script, so Roblox's
-- automated moderation never flags Bold's source for the words it filters.
--
-- The server fetches the list once and relays it to clients through a
-- RemoteFunction created here at runtime (so no RemoteFunction instance has to
-- be committed to source). If HttpService is disabled the list is simply empty
-- and Bold leans entirely on Roblox's TextService filter -- everything still
-- works, just with a smaller local backstop. Enabling HTTP is recommended.

local RunService  = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local _Source = "https://raw.githubusercontent.com/mkl48/BOLD/refs/heads/main/scripts/proflis.json"
local EVENT_NAME = "Repl_List"

local Proflis = {}
Proflis._ls = {}

local _started = false

local function resolveEvent(): RemoteFunction?
	if RunService:IsServer() then
		local ev = script:FindFirstChild(EVENT_NAME)
		if not ev then
			ev = Instance.new("RemoteFunction")
			ev.Name = EVENT_NAME
			ev.Parent = script
		end
		return ev
	end
	return script:WaitForChild(EVENT_NAME, 10) :: RemoteFunction?
end

-- Server-only: fetch the list and expose it to clients. Safe to call more than once.
function Proflis.Start()
	if not RunService:IsServer() or _started then return end
	_started = true

	local event = resolveEvent()
	if event then
		event.OnServerInvoke = function()
			return Proflis._ls
		end
	end

	local ok, body = pcall(function()
		return HttpService:GetAsync(_Source)
	end)
	if not ok then
		warn(
			"[Bold.Proflis] Could not fetch the word list over HttpService — the local "
			.. "backstop will be empty and Bold will rely on Roblox's TextService filter "
			.. "only. Enable Game Settings → Security → Allow HTTP Requests for the full "
			.. "experience. (" .. tostring(body) .. ")"
		)
		return
	end

	local ok2, decoded = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not ok2 or type(decoded) ~= "table" then
		warn("[Bold.Proflis] Word list JSON could not be decoded.")
		return
	end

	Proflis._ls = decoded
end

-- Returns the word-list table (map of word -> value). On the client this invokes
-- the server the first time and returns whatever it has; fail-safe to {}.
function Proflis.Get(): { [string]: any }
	if RunService:IsServer() then
		return Proflis._ls
	end
	local event = resolveEvent()
	if not event then return {} end
	local ok, list = pcall(function()
		return event:InvokeServer()
	end)
	if ok and type(list) == "table" then
		return list
	end
	return {}
end

return Proflis
