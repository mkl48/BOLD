-- Bold
-- _Utility/Social
-- Plinko Labs
--
-- Client-side social state: a cached friend lookup and a local ignore list.
-- Roblox does not let a game reliably read a player's block list, so "blocked"
-- is a Bold-side /ignore that hides someone's messages for you.

local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Social = {}

local _friendCache: { [number]: boolean } = {}
local _ignored: { [number]: boolean } = {}

-- Non-yielding: returns the cached answer (false until an async check resolves).
function Social.IsFriend(userId: number?): boolean
	if not userId or not LocalPlayer or userId == LocalPlayer.UserId then
		return false
	end
	local cached = _friendCache[userId]
	if cached ~= nil then
		return cached
	end
	_friendCache[userId] = false
	task.spawn(function()
		local ok, res = pcall(function()
			return LocalPlayer:IsFriendsWith(userId)
		end)
		if ok then _friendCache[userId] = res end
	end)
	return false
end

function Social.Ignore(userId: number?)
	if userId then _ignored[userId] = true end
end

function Social.Unignore(userId: number?)
	if userId then _ignored[userId] = nil end
end

function Social.IsIgnored(userId: number?): boolean
	return userId ~= nil and _ignored[userId] == true
end

function Social.Ignored(): { number }
	local out = {}
	for uid in _ignored do table.insert(out, uid) end
	return out
end

-- Resolve a name (or exact/prefix) to a userId among current players.
function Social.ResolveUserId(name: string): (number?, string?)
	local lower = name:lower()
	for _, p in Players:GetPlayers() do
		if p.Name:lower() == lower or p.DisplayName:lower() == lower then
			return p.UserId, p.Name
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Name:lower():sub(1, #lower) == lower then
			return p.UserId, p.Name
		end
	end
	return nil, nil
end

return Social
