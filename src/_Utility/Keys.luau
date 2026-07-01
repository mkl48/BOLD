-- Bold
-- _Utility/Keys
-- Plinko Labs

-- Keybinds for the chat. Global binds (focus / toggle) go through Switch when it
-- is available -- that is exactly the contextual-global-hotkey job Switch is best
-- at -- and fall back to UserInputService otherwise. The in-field autocomplete
-- navigation always runs on UIS (gated to when the popup is open) because it has
-- to coexist with a focused TextBox.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local Keys = {}

-- Locate Switch without hard-depending on it (wally dep, resolved at runtime).
local function resolveSwitch(): any?
	local candidates: { Instance? } = {
		ReplicatedStorage:FindFirstChild("Packages"),
		script:FindFirstAncestor("Packages"),
		script.Parent.Parent:FindFirstChild("_Packages"),
	}
	for _, container in candidates do
		if container then
			local mod = container:FindFirstChild("Switch")
			if mod and mod:IsA("ModuleScript") then
				local ok, lib = pcall(require, mod)
				if ok and lib then return lib end
			end
		end
	end
	return nil
end

local function inList(list: { Enum.KeyCode }?, kc: Enum.KeyCode): boolean
	if not list then return false end
	for _, k in list do
		if k == kc then return true end
	end
	return false
end

type Handlers = {
	onFocus: (() -> ())?,
	onToggle: (() -> ())?,
	onUp: (() -> ())?,
	onDown: (() -> ())?,
	onAccept: (() -> ())?,
	onClose: (() -> ())?,
	isAutocompleteOpen: () -> boolean,
	isInputFocused: () -> boolean,
}

function Keys.Setup(h: Handlers)
	local Switch = (Config.Keys.use_switch ~= false) and resolveSwitch() or nil
	Keys.UsingSwitch = Switch ~= nil

	local function bindGlobal(name: string, key: any, fn: (() -> ())?)
		if not key or key == false or not fn then return end
		if Switch then
			local ok, action = pcall(function()
				return Switch.Define(name, { Bindings = { key } })
			end)
			if ok and action then
				action:Next(Switch.Enums.State.Pressed):Then(function()
					fn()
				end)
				return
			end
		end
		-- UIS fallback
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then return end
			if input.KeyCode == key then fn() end
		end)
	end

	bindGlobal("Bold_Focus", Config.Keys.focus, function()
		if not h.isInputFocused() and h.onFocus then h.onFocus() end
	end)

	bindGlobal("Bold_Toggle", Config.Keys.toggle, h.onToggle)

	-- autocomplete navigation: UIS, gated to an open popup + focused field
	UserInputService.InputBegan:Connect(function(input)
		if not h.isAutocompleteOpen() or not h.isInputFocused() then return end
		local kc = input.KeyCode
		if inList(Config.Keys.up, kc) then
			if h.onUp then h.onUp() end
		elseif inList(Config.Keys.down, kc) then
			if h.onDown then h.onDown() end
		elseif inList(Config.Keys.accept, kc) then
			if h.onAccept then h.onAccept() end
		elseif inList(Config.Keys.close, kc) then
			if h.onClose then h.onClose() end
		end
	end)
end

return Keys
