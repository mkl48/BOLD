-- Bold
-- _Main/Compose
-- Plinko Labs

-- The input side of the chat: the text field, the @/ : / / autocomplete popup,
-- slash-command execution, reply targeting, the live filter warning pill, and
-- the keybinds (via Keys/Switch). Emits a compose payload on Compose.SubmitText.

local Players = game:GetService("Players")

local _Main     = script.Parent
local _Utility  = _Main.Parent._Utility
local _Patterns = _Main.Parent._Patterns

local Config      = require(_Utility.Config)
local Skin        = require(_Utility.Skin)
local Keys        = require(_Utility.Keys)
local ImageWrap   = require(_Utility.ImageWrap)
local Parser      = require(_Patterns.Parser)
local ImageSearch = require(_Patterns.ImageSearch)
local InputFilter = require(_Patterns.InputFilter)
local Commands    = require(_Patterns.Commands)
local Render      = require(_Main.Render)

local Compose = {}

Compose.SubmitText  = Instance.new("BindableEvent")
Compose.ToggleHandler = nil :: (() -> ())?

local tk = Skin.tk

local _window: Frame? = nil
local _inputBar: Frame? = nil
local _inputBox: TextBox? = nil
local _autocompleteFrame: Frame? = nil
local _autocompleteList: ScrollingFrame? = nil
local _replyBar: Frame? = nil

local _suggestions: { any } = {}
local _selectedIndex = 1
local _activeTrigger: string? = nil
local _activeQuery = ""
local _triggerStart = 0
local _pendingEmbeds: { any } = {}
local _replyTarget: any = nil

local AUTOCOMPLETE_DEBOUNCE = 0.18
local _searchToken = 0

-- ─── autocomplete ui ─────────────────────────────────────────────────────────

local function buildAutocompleteGui()
	if _autocompleteFrame then return end

	_autocompleteFrame = Instance.new("Frame")
	_autocompleteFrame.Name = "AutocompletePopup"
	_autocompleteFrame.Size = UDim2.new(1, 0, 0, 0)
	_autocompleteFrame.AnchorPoint = Vector2.new(0, 1)
	_autocompleteFrame.Position = UDim2.new(0, 0, 0, -8)
	_autocompleteFrame.BackgroundColor3 = tk("autocomplete_bg")
	_autocompleteFrame.BorderSizePixel = 1
	_autocompleteFrame.BorderColor3 = tk("autocomplete_border")
	_autocompleteFrame.Visible = false
	_autocompleteFrame.ZIndex = 50
	Skin.corner(_autocompleteFrame, 8)

	_autocompleteList = Instance.new("ScrollingFrame")
	_autocompleteList.Size = UDim2.new(1, 0, 1, 0)
	_autocompleteList.BackgroundTransparency = 1
	_autocompleteList.ScrollBarThickness = 4
	_autocompleteList.CanvasSize = UDim2.new(0, 0, 0, 0)
	_autocompleteList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	_autocompleteList.ZIndex = 51
	_autocompleteList.Parent = _autocompleteFrame
	local layout = Skin.list(_autocompleteList, Enum.FillDirection.Vertical, 0)
	Skin.pad(_autocompleteList, 8, 8, 8, 8)

	-- size the popup to its content, clamped to the room above the input so it
	-- never overflows the screen edge
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if not _autocompleteFrame then return end
		local content = layout.AbsoluteContentSize.Y
		local room = (_inputBar and _inputBar.AbsolutePosition.Y) or 300
		local maxH = math.clamp(room - 12, 60, 300)
		_autocompleteFrame.Size = UDim2.new(1, 0, 0, math.clamp(content + 16, 40, maxH))
	end)
end

local function closeAutocomplete()
	if _autocompleteFrame then _autocompleteFrame.Visible = false end
	_activeTrigger = nil
	_searchToken += 1
end

local function acceptSuggestion()
	if not _autocompleteFrame or not _autocompleteFrame.Visible then return end
	local item = _suggestions[_selectedIndex]
	if not item or not _inputBox then return end

	local text = _inputBox.Text
	local before = text:sub(1, _triggerStart - 1)
	local after = text:sub(_inputBox.CursorPosition)

	_inputBox.Text = before .. item.insertText .. after
	_inputBox.CursorPosition = #before + #item.insertText + 1

	if item.type == "sticker" and item.sticker_id then
		table.insert(_pendingEmbeds, { type = "Sticker", sticker_id = item.sticker_id })
	end

	closeAutocomplete()
	_inputBox:CaptureFocus()
end

local function renderSuggestions(query: string, items: { any })
	if not _autocompleteFrame or not _autocompleteList then return end
	_suggestions = items
	_activeQuery = query
	_selectedIndex = math.clamp(_selectedIndex, 1, math.max(1, #items))

	for _, child in _autocompleteList:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	if #items == 0 then
		_autocompleteFrame.Visible = false
		return
	end

	local currentType = ""
	for i, item in ipairs(items) do
		if item.type ~= currentType then
			currentType = item.type
			local header = Instance.new("TextLabel")
			header.Size = UDim2.new(1, 0, 0, 22)
			header.BackgroundTransparency = 1
			header.Text = string.upper(currentType)
			header.Font = tk("font_bold")
			header.TextSize = 12
			header.TextColor3 = tk("subtext")
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.LayoutOrder = i * 2 - 1
			header.ZIndex = 52
			header.Parent = _autocompleteList
		end

		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = tk("autocomplete_hover")
		row.BackgroundTransparency = i == _selectedIndex and 0 or 1
		row.BorderSizePixel = 0
		row.AutoButtonColor = false
		row.Text = ""
		row.LayoutOrder = i * 2
		row.ZIndex = 52
		row.Parent = _autocompleteList
		Skin.corner(row, 4)

		row.MouseButton1Click:Connect(function()
			_selectedIndex = i
			acceptSuggestion()
		end)

		local hasIcon = item.icon and item.icon ~= ""
		if hasIcon then
			local icon = Instance.new("ImageLabel")
			icon.Size = UDim2.fromOffset(20, 20)
			icon.Position = UDim2.new(0, 6, 0.5, -10)
			icon.BackgroundTransparency = 1
			icon.Image = item.icon
			icon.ZIndex = 53
			icon.Parent = row
		end

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.6, hasIcon and -35 or -10, 1, 0)
		nameLbl.Position = UDim2.new(0, hasIcon and 35 or 10, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = item.name or ""
		nameLbl.Font = tk("font")
		nameLbl.TextSize = 14
		nameLbl.TextColor3 = tk("text")
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.ZIndex = 53
		nameLbl.Parent = row

		if item.source and item.source ~= "" then
			local src = Instance.new("TextLabel")
			src.Size = UDim2.new(0.4, -10, 1, 0)
			src.Position = UDim2.new(0.6, 0, 0, 0)
			src.BackgroundTransparency = 1
			src.Text = item.source
			src.Font = tk("font")
			src.TextSize = 12
			src.TextColor3 = tk("subtext")
			src.TextXAlignment = Enum.TextXAlignment.Right
			src.TextTruncate = Enum.TextTruncate.AtEnd
			src.ZIndex = 53
			src.Parent = row
		end
	end

	_autocompleteFrame.Visible = true
end

-- ─── search sources ──────────────────────────────────────────────────────────

local function runEmojiSearch(query: string, token: number, into: { any })
	local ok, results = pcall(Parser.SearchEmoji, query)
	if token ~= _searchToken or not ok or not results then return end
	for _, name in results do
		local asset = Parser.GetEmojiAsset(name)
		table.insert(into, {
			type = "emoji", name = ":" .. name .. ":",
			icon = asset or "", source = "Emoji", insertText = ":" .. name .. ":",
		})
	end
end

local function runStickerSearch(query: string, token: number, into: { any })
	if query == "" then return end
	local ok, search = pcall(ImageSearch.InquireTopic, query)
	if not ok or not search then return end
	pcall(function()
		search:ForContentsInPage(1, function(asset)
			local id = asset.AssetId
			table.insert(into, {
				type = "sticker",
				name = asset.Name or "?",
				icon = (id and ImageWrap.WrapId(tostring(id))) or "",
				source = "Stickers",
				insertText = ":" .. tostring(id) .. ":",
				sticker_id = tostring(id),
			})
		end)
	end)
	if token ~= _searchToken then table.clear(into) end
end

local function runColonSearch(query: string, token: number)
	if query == "" then closeAutocomplete(); return end
	local items = {}
	runEmojiSearch(query, token, items)
	if token ~= _searchToken then return end
	runStickerSearch(query, token, items)
	if token ~= _searchToken then return end
	renderSuggestions(query, items)
end

local function runMentionSearch(query: string, token: number)
	local items = {}
	local lower = query:lower()
	for _, plr in Players:GetPlayers() do
		if query == "" or plr.Name:lower():sub(1, #lower) == lower or plr.DisplayName:lower():sub(1, #lower) == lower then
			table.insert(items, {
				type = "user", name = plr.DisplayName ~= plr.Name and (plr.DisplayName .. "  @" .. plr.Name) or plr.Name,
				icon = "rbxthumb://type=AvatarHeadShot&id=" .. plr.UserId .. "&w=48&h=48",
				source = "Players", insertText = "@" .. plr.Name,
			})
		end
	end
	if token ~= _searchToken then return end
	renderSuggestions(query, items)
end

local function runCommandSearch(query: string, token: number)
	local items = Commands.Search(query)
	if token ~= _searchToken then return end
	renderSuggestions(query, items)
end

-- ─── reply targeting ─────────────────────────────────────────────────────────

local function clearReply()
	_replyTarget = nil
	if _replyBar then _replyBar.Visible = false end
end

function Compose.SetReplyTarget(message: any)
	_replyTarget = message
	if not _replyBar then return end
	_replyBar.Visible = true
	local lbl = _replyBar:FindFirstChild("Label") :: TextLabel?
	if lbl then
		local meta = message.metadata
		local preview = (message.content and message.content.raw_text) or ""
		lbl.Text = ("Replying to %s: %s"):format(meta.author_name or "?", preview:sub(1, 40))
	end
end

local function buildReplyBar()
	_replyBar = Instance.new("Frame")
	_replyBar.Name = "ReplyBar"
	_replyBar.Size = UDim2.new(1, 0, 0, 20)
	_replyBar.BackgroundColor3 = tk("reaction_bg")
	_replyBar.BackgroundTransparency = 0.2
	_replyBar.BorderSizePixel = 0
	_replyBar.Visible = false
	_replyBar.LayoutOrder = 1
	_replyBar.Parent = _window
	Skin.corner(_replyBar, 4)
	Skin.pad(_replyBar, 8, 8, 0, 0)

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Label"
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, -24, 1, 0)
	lbl.Font = tk("font")
	lbl.TextSize = Skin.density().text_size - 3
	lbl.TextColor3 = tk("subtext")
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Text = ""
	lbl.Parent = _replyBar

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, 0, 0.5, 0)
	close.Size = UDim2.fromOffset(18, 18)
	close.BackgroundTransparency = 1
	close.Font = tk("font_bold")
	close.TextSize = 14
	close.TextColor3 = tk("subtext")
	close.Text = "✕"
	close.Parent = _replyBar
	close.MouseButton1Click:Connect(clearReply)
end

-- ─── warning pill ────────────────────────────────────────────────────────────

local function buildWarningPill(parent: TextBox): (CanvasGroup, TextLabel)
	local pill = Instance.new("CanvasGroup")
	pill.Name = "WarningPill"
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.new(0, 0, 0, 22)
	pill.AnchorPoint = Vector2.new(0, 1)
	pill.Position = UDim2.new(0, 0, 0, -6)
	pill.BackgroundColor3 = Color3.fromRGB(64, 42, 12)
	pill.BackgroundTransparency = 0.1
	pill.GroupTransparency = 1
	pill.ZIndex = 5
	pill.Parent = parent.Parent
	Skin.corner(pill, 999)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 195, 95)
	stroke.Transparency = 1
	stroke.Thickness = 1
	stroke.Parent = pill

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = pill
	Skin.pad(pill, 8, 8, 3, 3)

	local icon = Instance.new("TextLabel")
	icon.AutomaticSize = Enum.AutomaticSize.X
	icon.Size = UDim2.new(0, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = Skin.density().text_size - 2
	icon.TextColor3 = Color3.fromRGB(255, 195, 95)
	icon.Text = "⚠"
	icon.Parent = pill

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = tk("font")
	label.TextSize = Skin.density().text_size - 2
	label.TextColor3 = Color3.fromRGB(255, 224, 173)
	label.Text = ""
	label.Parent = pill

	pill:GetPropertyChangedSignal("GroupTransparency"):Connect(function()
		stroke.Transparency = pill.GroupTransparency
	end)

	return pill, label
end

-- ─── submit ──────────────────────────────────────────────────────────────────

local function resolvePlayer(name: string): Player?
	local lower = name:lower()
	for _, p in Players:GetPlayers() do
		if p.Name:lower() == lower or p.DisplayName:lower() == lower then return p end
	end
	for _, p in Players:GetPlayers() do
		if p.Name:lower():sub(1, #lower) == lower then return p end
	end
	return nil
end

local function replyRef(): any?
	if not _replyTarget then return nil end
	local meta = _replyTarget.metadata
	local preview = (_replyTarget.content and _replyTarget.content.raw_text) or ""
	return { id = meta.id, author_name = meta.author_name, preview = preview:sub(1, 60) }
end

local function fire(payload: any)
	payload.reply_to = replyRef()
	Compose.SubmitText:Fire(payload)
	clearReply()
end

local function submit()
	if not _inputBox then return end
	local raw = _inputBox.Text
	local embeds = _pendingEmbeds
	_pendingEmbeds = {}
	_inputBox.Text = ""
	closeAutocomplete()

	local trimmed = raw:gsub("^%s+", ""):gsub("%s+$", "")

	-- slash command?
	if trimmed:sub(1, 1) == "/" then
		local result = Commands.Execute(trimmed, {
			localPlayer = Players.LocalPlayer,
			actions = {
				clear = Render.Clear,
				system = Render.SystemMessage,
				resolvePlayer = resolvePlayer,
			},
		})
		if result.kind == "send" and result.payload then
			fire({
				text = result.payload.text,
				kind = result.payload.kind,
				recipient_id = result.payload.recipient and result.payload.recipient.UserId or nil,
				embeds = result.payload.embeds or embeds,
			})
		elseif result.kind == "unknown" then
			Render.SystemMessage("Unknown command: /" .. tostring(result.name))
		end
		return
	end

	-- normal message: strip only the sticker tokens we actually queued (their
	-- embeds are already attached), so real text like "3:30:00" is left alone
	local cleaned = trimmed
	for _, e in embeds do
		if e.type == "Sticker" and e.sticker_id then
			cleaned = cleaned:gsub(":" .. e.sticker_id .. ":", "")
		end
	end
	cleaned = cleaned:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if (cleaned ~= "" and cleaned:match("%S")) or #embeds > 0 then
		fire({ text = cleaned, embeds = embeds })
	end
end

-- ─── input bar ───────────────────────────────────────────────────────────────

function Compose.Focus()
	if _inputBox then _inputBox:CaptureFocus() end
end

function Compose.GetInputBox(): TextBox?
	return _inputBox
end

function Compose.IsInputFocused(): boolean
	return _inputBox ~= nil and _inputBox:IsFocused()
end

function Compose.IsAutocompleteOpen(): boolean
	return _autocompleteFrame ~= nil and _autocompleteFrame.Visible
end

local function onCursorMoved()
	if not _inputBox then return end
	local text = _inputBox.Text
	local cursor = _inputBox.CursorPosition
	if cursor == -1 then return end

	local preceding = text:sub(1, cursor - 1)
	local matchStart, _e, trigger, query = preceding:find("([@:/])([%w_]*)$")

	-- '/' only triggers commands at the very start of the field
	if trigger == "/" and matchStart ~= 1 then
		matchStart = nil
	end

	if matchStart then
		_activeTrigger = trigger
		_triggerStart = matchStart
		_searchToken += 1
		local token = _searchToken
		task.delay(AUTOCOMPLETE_DEBOUNCE, function()
			if token ~= _searchToken then return end
			if not _inputBox or not _inputBox:IsFocused() then return end
			if trigger == ":" then
				runColonSearch(query, token)
			elseif trigger == "@" then
				runMentionSearch(query, token)
			elseif trigger == "/" then
				runCommandSearch(query, token)
			end
		end)
	else
		closeAutocomplete()
	end
end

function Compose.Build(window: Frame)
	_window = window
	buildReplyBar()

	_inputBar = Instance.new("Frame")
	_inputBar.Name = "InputBar"
	_inputBar.Size = UDim2.new(1, 0, 0, Config.Interface.input_height)
	_inputBar.BackgroundColor3 = tk("input_bg")
	_inputBar.BackgroundTransparency = tk("input_transparency")
	_inputBar.BorderSizePixel = 0
	_inputBar.LayoutOrder = 2
	_inputBar.Parent = window
	Skin.corner(_inputBar)
	Skin.pad(_inputBar, 10, 10, 4, 4)

	_inputBox = Instance.new("TextBox")
	_inputBox.Name = "Input"
	_inputBox.Size = UDim2.new(1, 0, 1, 0)
	_inputBox.BackgroundTransparency = 1
	_inputBox.Font = tk("font")
	_inputBox.TextSize = Skin.density().text_size
	_inputBox.TextColor3 = tk("text")
	_inputBox.PlaceholderText = "Click here or press / to chat"
	_inputBox.PlaceholderColor3 = tk("placeholder_text")
	_inputBox.TextXAlignment = Enum.TextXAlignment.Left
	_inputBox.ClearTextOnFocus = false
	_inputBox.Text = ""
	_inputBox.Parent = _inputBar

	local warningPill, warningLabel = buildWarningPill(_inputBox)
	InputFilter.Attach(_inputBox, warningPill, warningLabel, "This text may be flagged")

	buildAutocompleteGui()
	if _autocompleteFrame then _autocompleteFrame.Parent = _inputBar end

	_inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed and Compose.IsAutocompleteOpen() then
			acceptSuggestion()
			if _inputBox then _inputBox:CaptureFocus() end
			return
		end
		if not enterPressed then return end
		submit()
	end)

	_inputBox:GetPropertyChangedSignal("CursorPosition"):Connect(onCursorMoved)

	Keys.Setup({
		onFocus  = Compose.Focus,
		onToggle = function() if Compose.ToggleHandler then Compose.ToggleHandler() end end,
		onUp     = function()
			_selectedIndex = math.max(1, _selectedIndex - 1)
			renderSuggestions(_activeQuery, _suggestions)
		end,
		onDown   = function()
			_selectedIndex = math.min(#_suggestions, _selectedIndex + 1)
			renderSuggestions(_activeQuery, _suggestions)
		end,
		onAccept = acceptSuggestion,
		onClose  = closeAutocomplete,
		isAutocompleteOpen = Compose.IsAutocompleteOpen,
		isInputFocused = Compose.IsInputFocused,
	})
end

return Compose
