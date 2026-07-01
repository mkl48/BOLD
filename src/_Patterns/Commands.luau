-- Bold
-- _Patterns/Commands
-- Plinko Labs

-- Slash-command registry. Commands run on the client when the input starts with
-- '/'. A handler either side-effects locally (via ctx.actions) and returns nil,
-- or returns a compose payload { text, kind?, recipient?, embeds? } to send.

local Types = require(script.Parent.Parent.Types)

local Commands = {}

local _registry: { [string]: Types.CommandSpec } = {}

function Commands.Register(name: string, spec: Types.CommandSpec)
	_registry[name:lower()] = spec
end

function Commands.Get(name: string): Types.CommandSpec?
	return _registry[name:lower()]
end

function Commands.List(): { { name: string, spec: Types.CommandSpec } }
	local out = {}
	for name, spec in _registry do
		table.insert(out, { name = name, spec = spec })
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Autocomplete source for '/'.
function Commands.Search(query: string): { any }
	local q = query:lower()
	local items = {}
	for _, entry in Commands.List() do
		if query == "" or entry.name:sub(1, #q) == q then
			table.insert(items, {
				type       = "command",
				name       = "/" .. entry.name,
				icon       = "",
				source     = entry.spec.description or "",
				insertText = "/" .. entry.name .. " ",
			})
		end
	end
	return items
end

-- "/incog Bob hi there" -> "incog", {"Bob","hi","there"}, "Bob hi there"
function Commands.Parse(text: string): (string?, { string }, string)
	local name = text:match("^/([%w_]+)")
	if not name then return nil, {}, "" end
	local rest = text:sub(#name + 2):gsub("^%s+", "")
	local args = {}
	for word in rest:gmatch("%S+") do
		table.insert(args, word)
	end
	return name, args, rest
end

export type ExecResult = {
	kind: "none" | "unknown" | "local" | "send",
	name: string?,
	payload: any?,
}

function Commands.Execute(text: string, ctx: any): ExecResult
	local name, args, rest = Commands.Parse(text)
	if not name then return { kind = "none" } end

	local spec = _registry[name:lower()]
	if not spec then return { kind = "unknown", name = name } end

	ctx.args = args
	ctx.rest = rest
	ctx.raw = text

	local result = spec.handler(ctx)
	if result then return { kind = "send", payload = result } end
	return { kind = "local" }
end

-- ─── Built-ins ───────────────────────────────────────────────────────────────

Commands.Register("me", {
	description = "Send an action, e.g. /me waves",
	args = "<action>",
	handler = function(ctx)
		if ctx.rest == "" then return nil end
		return { text = ctx.rest, kind = "me" }
	end,
})

Commands.Register("shrug", {
	description = "Append a shrug",
	handler = function(ctx)
		local body = ctx.rest ~= "" and (ctx.rest .. " ") or ""
		return { text = body .. "¯\\_(ツ)_/¯" }
	end,
})

Commands.Register("clear", {
	description = "Clear your chat locally",
	handler = function(ctx)
		ctx.actions.clear()
		return nil
	end,
})

Commands.Register("help", {
	description = "List available commands",
	handler = function(ctx)
		local lines = { "Commands:" }
		for _, entry in Commands.List() do
			local usage = entry.spec.args and (" " .. entry.spec.args) or ""
			table.insert(lines, ("/%s%s — %s"):format(entry.name, usage, entry.spec.description or ""))
		end
		ctx.actions.system(table.concat(lines, "\n"))
		return nil
	end,
})

Commands.Register("incog", {
	description = "Privately message a player",
	args = "<player> <message>",
	handler = function(ctx)
		local targetName = ctx.args[1]
		if not targetName then
			ctx.actions.system("Usage: /incog <player> <message>")
			return nil
		end

		local player = ctx.actions.resolvePlayer(targetName)
		if not player then
			ctx.actions.system("No player found matching '" .. targetName .. "'")
			return nil
		end

		-- message is everything after the first token
		local message = ctx.rest:sub(#targetName + 1):gsub("^%s+", "")
		if message == "" then
			ctx.actions.system("Say something to whisper to " .. player.Name)
			return nil
		end

		return { text = message, kind = "whisper", recipient = player }
	end,
})

return Commands
