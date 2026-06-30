local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local InsertService    = game:GetService("InsertService")

local _Main    = script.Parent
local _Utility = _Main.Parent._Utility
local _Pat     = _Main.Parent._Patterns

local Events = require(_Utility.Events)
local ImageWrap = require(_Utility.ImageWrap)
local Types  = require(_Main.Parent.Types)

local InputFilter = require(_Pat.InputFilter)
local Ref = require(_Pat.Ref)

local Interface = {}

-- ------------------------------------------------------------------------
-- THEME
-- ------------------------------------------------------------------------

local DEFAULTS: Types.Theme = {
	background               = Color3.fromRGB(0, 0, 0),
	background_transparency  = 0.5,
	header                   = Color3.fromRGB(0, 0, 0),
	header_transparency      = 0.4,
	input_bg                 = Color3.fromRGB(0, 0, 0),
	input_transparency       = 0.3,

	text                     = Color3.fromRGB(255, 255, 255),
	subtext                  = Color3.fromRGB(190, 190, 190),
	timestamp_text           = Color3.fromRGB(150, 150, 150),
	placeholder_text         = Color3.fromRGB(170, 170, 170),

	name_palette = {
		Color3.fromRGB(253, 41,  67),
		Color3.fromRGB(1,   162, 232),
		Color3.fromRGB(2,   184, 87),
		Color3.fromRGB(255, 174, 23),
		Color3.fromRGB(178, 49,  238),
		Color3.fromRGB(255, 102, 170),
		Color3.fromRGB(0,   200, 200),
		Color3.fromRGB(255, 132, 56),
	},

	accent                   = Color3.fromRGB(108, 62, 244),
	mention_bg               = Color3.fromRGB(108, 62, 244),
	mention_text             = Color3.fromRGB(255, 255, 255),
	code_bg                  = Color3.fromRGB(25,  25, 28),
	code_text                = Color3.fromRGB(186, 230, 126),
	link_text                = Color3.fromRGB(120, 170, 255),

	system_text              = Color3.fromRGB(170, 170, 170),
	announcement_bg          = Color3.fromRGB(108, 62, 244),
	announcement_text        = Color3.fromRGB(255, 255, 255),
	whisper_text             = Color3.fromRGB(210, 170, 255),
	team_text                = Color3.fromRGB(110, 230, 150),
	error_text               = Color3.fromRGB(255, 90, 90),

	pinned_indicator         = Color3.fromRGB(255, 200, 50),

	-- Autocomplete Additions
	autocomplete_bg          = Color3.fromRGB(43, 45, 49),
	autocomplete_hover       = Color3.fromRGB(64, 66, 73),
	autocomplete_border      = Color3.fromRGB(30, 31, 34),

	font                     = Enum.Font.SourceSans,
	font_bold                = Enum.Font.SourceSansBold,
	text_size                = 16,
	corner_radius            = 4,

	fade_enabled             = true,
	fade_after                = 8,
	hide_after               = 0,
}

local DENSITY = {
	compact     = { row_pad = 1, text_size = 14, gap = 0 },
	cozy        = { row_pad = 3, text_size = 16, gap = 1 },
	comfortable = { row_pad = 6, text_size = 17, gap = 3 },
}

local KIND_STYLE: { [string]: { prefix: string?, text_key: string, bold: boolean? } } = {
	chat         = { prefix = nil,    text_key = "text" },
	system       = { prefix = "* ",   text_key = "system_text" },
	announcement = { prefix = "[!] ", text_key = "announcement_text", bold = true },
	whisper      = { prefix = "-> ",  text_key = "whisper_text" },
	team         = { prefix = "[T] ", text_key = "team_text" },
	error        = { prefix = "[x] ", text_key = "error_text" },
}

Interface.Config = {
	theme            = DEFAULTS,
	density          = "cozy",
	window_size      = UDim2.fromOffset(460, 0), -- Height auto-driven
	window_pos       = UDim2.new(0, 12, 0, 12),  -- Top-Left
	window_anchor    = Vector2.new(0, 0),        -- Top-Left
	min_list_height  = 0,
	max_list_height  = 400,
	header_height    = 0,
	input_height     = 34,
	max_messages     = 200,
	visible          = true,
	show_header      = false,
	show_input       = true,
	show_timestamps  = false,
	show_scrollbar   = false,
	channel_name     = "All",
	animate_in       = true,
	message_grouping = true,
	grouping_window  = 30,
}

Interface.Renderers = {} :: { [string]: (any, any) -> Frame }
Interface.LineDecorators = {} :: { (any) -> string? }
Interface.SubmitText = Instance.new("BindableEvent")

local _gui: ScreenGui?
local _window: Frame?
local _container: ScrollingFrame?
local _header: Frame?
local _inputBar: Frame?
local _inputBox: TextBox?
local _lastAuthorId: number? = nil
local _lastAuthorTime: number = 0
local _nameColorCache: { [string]: Color3 } = {}

-- Autocomplete State
local _autocompleteFrame: Frame?
local _autocompleteList: ScrollingFrame?
local _suggestions: {any} = {}
local _selectedIndex: number = 1
local _activeTrigger: string? = nil
local _triggerStart: number = 0
local _pendingEmbeds = {}

-- ------------------------------------------------------------------------
-- helpers
-- ------------------------------------------------------------------------

local function tk(key: string): any
	local v = Interface.Config.theme[key]
	if v ~= nil then return v end
	return DEFAULTS[key]
end

local function density(): { row_pad: number, text_size: number, gap: number }
	return DENSITY[Interface.Config.density] or DENSITY.cozy
end

local function rgbStr(c: Color3): string
	return string.format("rgb(%d,%d,%d)", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function escapeRich(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function corner(parent: Instance, r: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or tk("corner_radius"))
	c.Parent = parent
	return c
end

local function pad(parent: Instance, left: number?, right: number?, top: number?, bottom: number?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft   = UDim.new(0, left or 0)
	p.PaddingRight  = UDim.new(0, right or left or 0)
	p.PaddingTop    = UDim.new(0, top or 0)
	p.PaddingBottom = UDim.new(0, bottom or top or 0)
	p.Parent = parent
	return p
end

local function listLayout(parent: Instance, dir: Enum.FillDirection?, gap: number?, sort: Enum.SortOrder?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.SortOrder     = sort or Enum.SortOrder.LayoutOrder
	l.Padding       = UDim.new(0, gap or 0)
	l.Parent        = parent
	return l
end

local function colorForAuthor(id: number?, name: string?, explicit: Color3?): Color3
	if explicit then return explicit end
	local key = id and tostring(id) or (name or "?")
	if _nameColorCache[key] then return _nameColorCache[key] end
	local palette = tk("name_palette")
	local idx = (id or (name and #name) or 0) % #palette + 1
	local c = palette[idx]
	_nameColorCache[key] = c
	return c
end

-- ------------------------------------------------------------------------
-- rich text composition
-- ------------------------------------------------------------------------

local function elementsToRich(elements: { any }): (string, { any })
	local parts: { string } = {}
	local mentionData: { any } = {}

	for _, elem in elements do
		if elem.type == "text" then
			local c = escapeRich(elem.content)
			local fmt = elem.formatting
			if fmt then
				if fmt.bold          then c = "<b>" .. c .. "</b>" end
				if fmt.italic        then c = "<i>" .. c .. "</i>" end
				if fmt.underline     then c = "<u>" .. c .. "</u>" end
				if fmt.strikethrough then c = "<s>" .. c .. "</s>" end
				if fmt.color         then
					c = '<font color="' .. rgbStr(fmt.color) .. '">' .. c .. "</font>"
				end
			end
			table.insert(parts, c)
		elseif elem.type == "emoji_unicode" then
			table.insert(parts, elem.content)
		elseif elem.type == "emoji_custom" then
			table.insert(parts, "[:" .. (elem.data and elem.data.emoji_name or "?") .. ":]")
		elseif elem.type == "mention" then
			local name = (elem.data and elem.data.mention_name) or elem.content:sub(2)
			table.insert(parts, string.format(
				'<font color="%s"><b>@%s</b></font>',
				rgbStr(tk("mention_text")), name
				))
			table.insert(mentionData, elem.data)
		elseif elem.type == "code" then
			table.insert(parts, string.format(
				'<font color="%s" face="RobotoMono">%s</font>',
				rgbStr(tk("code_text")), escapeRich(elem.content)
				))
		end
	end
	return table.concat(parts), mentionData
end

-- ------------------------------------------------------------------------
-- autocomplete ui
-- ------------------------------------------------------------------------

local function buildAutocompleteGui()
	if _autocompleteFrame then return end

	_autocompleteFrame = Instance.new("Frame")
	_autocompleteFrame.Name = "AutocompletePopup"
	_autocompleteFrame.Size = UDim2.new(1, 0, 0, 250)
	_autocompleteFrame.AnchorPoint = Vector2.new(0, 1)
	_autocompleteFrame.Position = UDim2.new(0, 0, 0, -8)
	_autocompleteFrame.BackgroundColor3 = tk("autocomplete_bg")
	_autocompleteFrame.BorderSizePixel = 1
	_autocompleteFrame.BorderColor3 = tk("autocomplete_border")
	_autocompleteFrame.Visible = false
	_autocompleteFrame.ZIndex = 50
	corner(_autocompleteFrame, 8)

	_autocompleteList = Instance.new("ScrollingFrame")
	_autocompleteList.Size = UDim2.new(1, 0, 1, 0)
	_autocompleteList.BackgroundTransparency = 1
	_autocompleteList.ScrollBarThickness = 4
	_autocompleteList.CanvasSize = UDim2.new(0, 0, 0, 0)
	_autocompleteList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	_autocompleteList.Parent = _autocompleteFrame

	listLayout(_autocompleteList, Enum.FillDirection.Vertical, 0)
	pad(_autocompleteList, 8, 8, 8, 8)
end

local function renderSuggestions(query: string, items: {any})
	_suggestions = items
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
			header.Size = UDim2.new(1, 0, 0, 24)
			header.BackgroundTransparency = 1
			header.Text = string.upper(currentType .. " MATCHING :" .. query)
			header.Font = tk("font_bold")
			header.TextSize = 12
			header.TextColor3 = tk("subtext")
			header.TextXAlignment = Enum.TextXAlignment.Left
			header.LayoutOrder = i * 2 - 1
			header.Parent = _autocompleteList
		end

		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = i == _selectedIndex and tk("autocomplete_hover") or tk("autocomplete_bg")
		row.BackgroundTransparency = i == _selectedIndex and 0 or 1
		row.BorderSizePixel = 0
		row.AutoButtonColor = false
		row.Text = ""
		row.LayoutOrder = i * 2
		row.Parent = _autocompleteList
		corner(row, 4)

		-- Clicking a suggestion directly selects it, same as pressing Enter/Tab.
		row.MouseButton1Click:Connect(function()
			_selectedIndex = i
			local selectedItem = _suggestions[_selectedIndex]
			if selectedItem and _inputBox then
				local text = _inputBox.Text
				local before = text:sub(1, _triggerStart - 1)
				local after = text:sub(_inputBox.CursorPosition)

				_inputBox.Text = before .. selectedItem.insertText .. " " .. after
				_inputBox.CursorPosition = #before + #selectedItem.insertText + 2
				_autocompleteFrame.Visible = false
				_activeTrigger = nil
				_inputBox:CaptureFocus()
			end
		end)

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(20, 20)
		icon.Position = UDim2.new(0, 6, 0.5, -10)
		icon.BackgroundTransparency = 1
		icon.Image = item.icon or ""
		icon.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(0.5, -35, 1, 0)
		nameLbl.Position = UDim2.new(0, 35, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = item.name or ""
		nameLbl.Font = tk("font")
		nameLbl.TextSize = 14
		nameLbl.TextColor3 = tk("text")
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Parent = row

		if item.source then
			local sourceLbl = Instance.new("TextLabel")
			sourceLbl.Size = UDim2.new(0.5, -10, 1, 0)
			sourceLbl.Position = UDim2.new(0.5, 0, 0, 0)
			sourceLbl.BackgroundTransparency = 1
			sourceLbl.Text = item.source
			sourceLbl.Font = tk("font")
			sourceLbl.TextSize = 12
			sourceLbl.TextColor3 = tk("subtext")
			sourceLbl.TextXAlignment = Enum.TextXAlignment.Right
			sourceLbl.Parent = row
		end
	end

	_autocompleteFrame.Visible = true
end

-- ------------------------------------------------------------------------
-- autocomplete data sources (emoji search + sticker/image search + mentions)
-- ------------------------------------------------------------------------

local AUTOCOMPLETE_DEBOUNCE = 0.2 -- seconds between keystroke and firing a search
local _searchToken = 0            -- increments on every new query; guards against stale async results

-- '@' triggers -> player mentions
-- ':' triggers -> emoji first, then stickers appended below (both share the ':' namespace,
--                  same as Discord-style clients: typing ":fire" can surface both an emoji
--                  and a sticker pack hit)

-- --- Emoji (via Parser.SearchEmoji, built-in + custom registered emoji) -----

local function mapEmojiNameToItem(name: string)
	-- Parser.SearchEmoji returns plain emoji names (Bold.SearchEmoji : (string) -> {string}).
	-- If Parser exposes a real per-emoji asset/icon lookup (e.g. Parser.GetEmojiAsset(name)),
	-- swap the `icon` line below to use it instead of the placeholder.
	local Parser = Ref.Req(_Pat.Parser)
	local icon = ""
	if Parser.GetEmojiAsset then
		local ok, assetId = pcall(Parser.GetEmojiAsset, name)
		if ok and assetId then icon = assetId end
	end

	return {
		type       = "emoji",
		name       = ":" .. name .. ":",
		icon       = icon,
		source     = "Emoji",
		insertText = ":" .. name .. ":",
	}
end

local function runEmojiSearch(query: string, token: number, intoItems: {any})
	local Parser = Ref.Req(_Pat.Parser)
	local ok, results = pcall(Parser.SearchEmoji, query)
	if token ~= _searchToken then return end
	if not ok or not results then
		warn("[Bold.Interface] Parser.SearchEmoji failed:", results)
		return
	end
	for _, name in results do
		table.insert(intoItems, mapEmojiNameToItem(name))
	end
end

-- --- Stickers (via ImageSearch, the Patterns page-based search class) ------

-- NOTE: field names below are inferred from common ImageAsset shapes
-- (Name/Image/Source/Id). If Types.ImageAsset uses different field names,
-- adjust the right-hand side of each line to match your real definition.
local function mapImageAssetToStickerItem(asset: Types.ImageAsset)
	local name = asset.Name or asset.name or "?"
	local id   = asset.AssetId
	return {
		type       = "sticker",
		name       = name,
		icon       = (id and ImageWrap.WrapId(id)) or "",
		source     = asset.Source or asset.source or "Stickers",
		insertText = ":" .. tostring(id) .. ":",
	}
end

local function runStickerSearch(query: string, token: number, intoItems: {any})
	if query == "" then return end

	local ImageSearch = Ref.Req(_Pat.ImageSearch)
	local ok, search = pcall(ImageSearch.InquireTopic, query)
	if not ok or not search then
		warn("[Bold.Interface] ImageSearch.InquireTopic failed:", search)
		return
	end

	local ok2, err = pcall(function()
		search:ForContentsInPage(1, function(asset)
			table.insert(intoItems, mapImageAssetToStickerItem(asset))
		end)
	end)

	if token ~= _searchToken then return end
	if not ok2 then
		warn("[Bold.Interface] ImageSearch enumeration failed:", err)
	end
end

-- --- Combined ':' handler: emoji results first, stickers appended ---------

local function runColonSearch(query: string, token: number)
	if query == "" then
		if token == _searchToken then
			_autocompleteFrame.Visible = false
		end
		return
	end

	local items = {}

	-- Emoji are synchronous/local (Parser lookups), so they always populate first.
	runEmojiSearch(query, token, items)
	if token ~= _searchToken then return end

	-- Stickers go through ImageSearch's paged lookup; can be slower, so it's
	-- wrapped the same as emoji but kept as its own step in case you want to
	-- stagger rendering (render emoji immediately, then append stickers) later.
	runStickerSearch(query, token, items)
	if token ~= _searchToken then return end

	renderSuggestions(query, items)
end

-- --- '@' handler: player mentions ------------------------------------------

local function runMentionSearch(query: string, token: number)
	local items = {}
	local lowerQuery = query:lower()
	for _, plr in Players:GetPlayers() do
		if query == "" or plr.Name:lower():sub(1, #lowerQuery) == lowerQuery then
			table.insert(items, {
				type       = "user",
				name       = plr.Name,
				icon       = ("rbxassetid://2795572803"),
				source     = "Players",
				insertText = "@" .. plr.Name,
				data       = { mention_id = plr.UserId, mention_name = plr.Name },
			})
		end
	end

	if token ~= _searchToken then return end
	renderSuggestions(query, items)
end

-- ------------------------------------------------------------------------
-- input gui
-- ------------------------------------------------------------------------

local function buildWarningPill(parent: TextBox)
	local cfg = Interface.Config

	-- CanvasGroup lets us fade the icon + background + text together as
	-- one unit with a single GroupTransparency tween, instead of having
	-- to animate three separate transparencies in lockstep.
	local pill = Instance.new("CanvasGroup")
	pill.Name                 = "WarningPill"
	pill.AutomaticSize         = Enum.AutomaticSize.X
	pill.Size                  = UDim2.new(0, 0, 0, 22)
	pill.AnchorPoint           = Vector2.new(0, 1)
	pill.Position              = UDim2.new(0, 0, 0, -6) -- sits just above the input bar
	pill.BackgroundColor3      = Color3.fromRGB(64, 42, 12)
	pill.BackgroundTransparency = 0.1
	pill.GroupTransparency     = 1 -- starts fully hidden
	pill.ZIndex                = 5
	pill.Parent                = parent.Parent -- sibling of the TextBox, inside _inputBar
	corner(pill, 999) -- full pill shape; adjust if your `corner()` helper takes a fixed radius arg

	local stroke = Instance.new("UIStroke")
	stroke.Color       = Color3.fromRGB(255, 195, 95)
	stroke.Transparency = 1
	stroke.Thickness    = 1
	stroke.Parent        = pill

	local layout = Instance.new("UIListLayout")
	layout.FillDirection       = Enum.FillDirection.Horizontal
	layout.VerticalAlignment   = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding             = UDim.new(0, 4)
	layout.Parent               = pill
	pad(pill, 8, 8, 3, 3)

	local icon = Instance.new("TextLabel")
	icon.Name             = "Icon"
	icon.AutomaticSize     = Enum.AutomaticSize.X
	icon.Size              = UDim2.new(0, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Font              = Enum.Font.GothamBold
	icon.TextSize           = density().text_size - 2
	icon.TextColor3         = Color3.fromRGB(255, 195, 95)
	icon.Text               = "⚠"
	icon.Parent              = pill

	local label = Instance.new("TextLabel")
	label.Name             = "Label"
	label.AutomaticSize     = Enum.AutomaticSize.X
	label.Size              = UDim2.new(0, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font              = tk("font")
	label.TextSize           = density().text_size - 2
	label.TextColor3         = Color3.fromRGB(255, 224, 173)
	label.Text               = ""
	label.Parent              = pill

	pill:GetPropertyChangedSignal("GroupTransparency"):Connect(function(t)
		stroke.Transparency = pill.GroupTransparency
	end)

	return pill, label
end

local function buildInputBar()
	local cfg = Interface.Config

	_inputBar = Instance.new("Frame")
	_inputBar.Name             = "InputBar"
	_inputBar.Size             = UDim2.new(1, 0, 0, cfg.input_height)
	_inputBar.BackgroundColor3 = tk("input_bg")
	_inputBar.BackgroundTransparency = tk("input_transparency")
	_inputBar.BorderSizePixel  = 0
	_inputBar.LayoutOrder      = 2
	_inputBar.Parent           = _window
	corner(_inputBar)
	pad(_inputBar, 10, 10, 4, 4)

	_inputBox = Instance.new("TextBox")
	_inputBox.Name                 = "Input"
	_inputBox.Size                 = UDim2.new(1, 0, 1, 0)
	_inputBox.BackgroundTransparency = 1
	_inputBox.Font                 = tk("font")
	_inputBox.TextSize             = density().text_size
	_inputBox.TextColor3           = tk("text")
	_inputBox.PlaceholderText      = "Click here to chat"
	_inputBox.PlaceholderColor3    = tk("placeholder_text")
	_inputBox.TextXAlignment       = Enum.TextXAlignment.Left
	_inputBox.ClearTextOnFocus     = false
	_inputBox.Text                 = ""
	_inputBox.Parent               = _inputBar

	-- buildWarningPill returns the CanvasGroup pill + the inner TextLabel;
	-- InputFilter.Attach wires up the live local check + fade animation.
	local warningPill, warningLabel = buildWarningPill(_inputBox)
	InputFilter.Attach(_inputBox, warningPill, warningLabel, "This text may be flagged")
	
	buildAutocompleteGui()
	_autocompleteFrame.Parent = _inputBar

	_inputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed and _autocompleteFrame.Visible then
			_inputBox:CaptureFocus() -- Keep focus so they can keep typing
			return
		end

		if not enterPressed then return end

		local text = _inputBox.Text

		local cleanedText = text:gsub(":%d+:", ""):gsub("%s+", " ")

		local embedsToSend = _pendingEmbeds
		_pendingEmbeds = {} 

		_inputBox.Text = ""
		_autocompleteFrame.Visible = false
		_activeTrigger = nil
		_searchToken += 1

		if (cleanedText and cleanedText:match("%S")) or (#embedsToSend > 0) then
			warn("SENDING")
			Interface.SubmitText:Fire(cleanedText, embedsToSend)
		end

	end)

	_inputBox:GetPropertyChangedSignal("CursorPosition"):Connect(function()
		local text = _inputBox.Text
		local cursorPos = _inputBox.CursorPosition
		if cursorPos == -1 then return end

		local precedingText = text:sub(1, cursorPos - 1)
		local matchStart, _matchEnd, trigger, query = precedingText:find("([@:])([%w_]*)$")

		if matchStart then
			_activeTrigger = trigger
			_triggerStart = matchStart

			_searchToken += 1
			local token = _searchToken

			task.delay(AUTOCOMPLETE_DEBOUNCE, function()
				if token ~= _searchToken then return end -- superseded by a newer keystroke
				if not _inputBox or not _inputBox.Parent or not _inputBox:IsFocused() then return end

				if trigger == ":" then
					runColonSearch(query, token)
				elseif trigger == "@" then
					runMentionSearch(query, token)
				end
			end)
		else
			_activeTrigger = nil
			_searchToken += 1 -- invalidate any in-flight search
			_autocompleteFrame.Visible = false
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not _autocompleteFrame.Visible or not _inputBox:IsFocused() then return end

		if input.KeyCode == Enum.KeyCode.Up then
			_selectedIndex = math.max(1, _selectedIndex - 1)
			renderSuggestions(_inputBox.Text:sub(_triggerStart + 1, _inputBox.CursorPosition - 1), _suggestions)
		elseif input.KeyCode == Enum.KeyCode.Down then
			_selectedIndex = math.min(#_suggestions, _selectedIndex + 1)
			renderSuggestions(_inputBox.Text:sub(_triggerStart + 1, _inputBox.CursorPosition - 1), _suggestions)
		elseif input.KeyCode == Enum.KeyCode.Escape then
			_autocompleteFrame.Visible = false
			_activeTrigger = nil
			_searchToken += 1
		elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Tab then
			local selectedItem = _suggestions[_selectedIndex]
			if selectedItem then
				local text = _inputBox.Text
				local before = text:sub(1, _triggerStart - 1)
				local after = text:sub(_inputBox.CursorPosition)

				table.insert(_pendingEmbeds, {
					type = "Sticker",
					sticker_id = selectedItem.insertText:gsub(":", "") -- Clean up the colon
				})

				_inputBox.Text = before .. selectedItem.insertText .. " " .. after
				_inputBox.CursorPosition = #before + #selectedItem.insertText + 2
				_autocompleteFrame.Visible = false
				_activeTrigger = nil
				_searchToken += 1
			end
		end
	end)
end

-- Replace the old inline `warningLabel` block in buildInputBar with this.
-- Everything else in buildInputBar stays the same.



local function buildGui()
	if _gui then return end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local cfg = Interface.Config

	_gui = Instance.new("ScreenGui")
	_gui.Name           = "BoldUI"
	_gui.ResetOnSpawn   = false
	_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_gui.Enabled        = cfg.visible
	_gui.Parent         = playerGui

	_window = Instance.new("Frame")
	_window.Name             = "Window"
	_window.Size             = cfg.window_size
	_window.AutomaticSize    = Enum.AutomaticSize.Y
	_window.Position         = cfg.window_pos
	_window.AnchorPoint      = cfg.window_anchor
	_window.BackgroundTransparency = 1
	_window.Parent           = _gui

	listLayout(_window, nil, 2)

	if cfg.show_header and cfg.header_height > 0 then
		_header = Instance.new("Frame")
		_header.Name              = "Header"
		_header.Size              = UDim2.new(1, 0, 0, cfg.header_height)
		_header.BackgroundColor3  = tk("header")
		_header.BackgroundTransparency = tk("header_transparency")
		_header.BorderSizePixel   = 0
		_header.LayoutOrder       = 0
		_header.Parent            = _window
		corner(_header)
		pad(_header, 10)

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size           = UDim2.new(1, 0, 1, 0)
		lbl.Text           = cfg.channel_name
		lbl.Font           = tk("font_bold")
		lbl.TextSize       = density().text_size - 1
		lbl.TextColor3     = tk("text")
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent         = _header
	end

	local listWrapper = Instance.new("Frame")
	listWrapper.Name = "ListWrapper"
	listWrapper.BackgroundTransparency = 1
	listWrapper.Size = UDim2.new(1, 0, 0, cfg.min_list_height or 0)
	listWrapper.LayoutOrder = 1
	listWrapper.Parent = _window

	_container = Instance.new("ScrollingFrame")
	_container.Name                   = "Messages"
	_container.Size                   = UDim2.new(1, 0, 1, 0)
	_container.BackgroundColor3       = tk("background")
	_container.BackgroundTransparency = tk("background_transparency")
	_container.BorderSizePixel        = 0
	_container.ScrollBarThickness     = cfg.show_scrollbar and 4 or 0
	_container.ScrollBarImageColor3   = tk("subtext")
	_container.CanvasSize             = UDim2.new(0, 0, 0, 0)
	_container.AutomaticCanvasSize    = Enum.AutomaticSize.Y
	_container.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	_container.Parent                 = listWrapper
	corner(_container)

	local layout = listLayout(_container, nil, density().gap)
	pad(_container, 8, 8, 6, 6)

	local function syncWrapperHeight()
		local contentHeight = layout.AbsoluteContentSize.Y + 12
		local clamped = math.clamp(contentHeight, cfg.min_list_height or 0, cfg.max_list_height or 400)
		listWrapper.Size = UDim2.new(1, 0, 0, clamped)
	end

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(syncWrapperHeight)
	syncWrapperHeight()

	_container:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		Events.UIScrolled:Fire(_container.CanvasPosition.Y)
	end)

	if cfg.show_input then
		buildInputBar()
	end
end

-- ------------------------------------------------------------------------
-- embeds
-- ------------------------------------------------------------------------

local function buildEmbed(embed: any, parent: Instance, lo: number): Frame?
	if not embed or not embed.type then return nil end

	local outer = Instance.new("Frame")
	outer.Name             = "Embed_" .. embed.type
	outer.AutomaticSize    = Enum.AutomaticSize.Y
	outer.Size             = UDim2.new(1, 0, 0, 0)
	outer.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	outer.BackgroundTransparency = 0.15
	outer.BorderSizePixel  = 0
	outer.LayoutOrder      = lo
	corner(outer, 6)

	local stripe = Instance.new("Frame")
	stripe.Size             = UDim2.new(0, 3, 1, 0)
	stripe.BackgroundColor3 = embed.color or tk("accent")
	stripe.BorderSizePixel  = 0
	stripe.Parent           = outer
	corner(stripe, 2)

	local inner = Instance.new("Frame")
	inner.AutomaticSize    = Enum.AutomaticSize.Y
	inner.Size             = UDim2.new(1, -12, 0, 0)
	inner.Position         = UDim2.fromOffset(12, 0)
	inner.BackgroundTransparency = 1
	inner.Parent           = outer
	listLayout(inner, nil, 4)
	pad(inner, 6, 6, 6, 8)

	local iLo = 0

	if embed.type == "Image" then
		local img = Instance.new("ImageLabel")
		img.Size              = UDim2.new(1, 0, 0, 140)
		img.BackgroundColor3  = Color3.new(0, 0, 0)
		img.BackgroundTransparency = 0.4
		img.Image             = embed.image_id or ""
		img.ScaleType         = Enum.ScaleType.Fit
		img.LayoutOrder       = iLo; iLo += 1
		img.Parent            = inner
		corner(img, 4)

		if embed.caption and embed.caption ~= "" then
			local cap = Instance.new("TextLabel")
			cap.BackgroundTransparency = 1
			cap.Size           = UDim2.new(1, 0, 0, 0)
			cap.AutomaticSize  = Enum.AutomaticSize.Y
			cap.Text           = embed.caption
			cap.Font           = tk("font")
			cap.TextSize       = density().text_size - 2
			cap.TextColor3     = tk("subtext")
			cap.TextWrapped    = true
			cap.TextXAlignment = Enum.TextXAlignment.Left
			cap.LayoutOrder    = iLo; iLo += 1
			cap.Parent         = inner
		end

	elseif embed.type == "Gif" then
		local vf = Instance.new("VideoFrame")
		vf.Size             = UDim2.new(1, 0, 0, 140)
		vf.BackgroundColor3 = Color3.new(0, 0, 0)
		vf.Video            = embed.video_id or ""
		vf.Looped           = embed.loop ~= false
		vf.LayoutOrder      = iLo; iLo += 1
		vf.Parent           = inner
		corner(vf, 4)
		if embed.autoplay ~= false then vf:Play() end

	elseif embed.type == "Sticker" then
		local Parser = Ref.Req(_Pat.Parser)
		local asset = Parser.GetStickerAsset(embed.sticker_id or "")
		local sz    = embed.size or 80
		--warn(embed)
		local img = Instance.new("ImageLabel")
		img.Size              = UDim2.fromOffset(sz, sz)
		img.BackgroundTransparency = 1
		img.Image             = ImageWrap.WrapId(embed.sticker_id or "")
		img.ScaleType         = Enum.ScaleType.Fit
		img.LayoutOrder       = iLo; iLo += 1
		img.Parent            = inner

	elseif embed.type == "RichText" then
		if embed.title and embed.title ~= "" then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size           = UDim2.new(1, 0, 0, 0)
			t.AutomaticSize  = Enum.AutomaticSize.Y
			t.Text           = embed.title
			t.Font           = tk("font_bold")
			t.TextSize       = density().text_size + 1
			t.TextColor3     = tk("text")
			t.TextWrapped    = true
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.LayoutOrder    = iLo; iLo += 1
			t.Parent         = inner
		end
		if embed.description and embed.description ~= "" then
			local desc = Instance.new("TextLabel")
			desc.BackgroundTransparency = 1
			desc.Size           = UDim2.new(1, 0, 0, 0)
			desc.AutomaticSize  = Enum.AutomaticSize.Y
			desc.Text           = embed.description
			desc.Font           = tk("font")
			desc.TextSize       = density().text_size - 1
			desc.TextColor3     = tk("subtext")
			desc.TextWrapped    = true
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.LayoutOrder    = iLo; iLo += 1
			desc.Parent         = inner
		end
		if embed.fields then
			for _, field in embed.fields do
				local fRow = Instance.new("Frame")
				fRow.AutomaticSize    = Enum.AutomaticSize.Y
				fRow.Size             = UDim2.new(1, 0, 0, 0)
				fRow.BackgroundTransparency = 1
				fRow.LayoutOrder      = iLo; iLo += 1
				fRow.Parent           = inner
				listLayout(fRow, nil, 1)

				local n = Instance.new("TextLabel")
				n.BackgroundTransparency = 1
				n.Size = UDim2.new(1, 0, 0, 0); n.AutomaticSize = Enum.AutomaticSize.Y
				n.Text = field.name; n.Font = tk("font_bold")
				n.TextSize = density().text_size - 2; n.TextColor3 = tk("text")
				n.TextWrapped = true; n.TextXAlignment = Enum.TextXAlignment.Left
				n.LayoutOrder = 0; n.Parent = fRow

				local v = Instance.new("TextLabel")
				v.BackgroundTransparency = 1
				v.Size = UDim2.new(1, 0, 0, 0); v.AutomaticSize = Enum.AutomaticSize.Y
				v.Text = field.value; v.Font = tk("font")
				v.TextSize = density().text_size - 2; v.TextColor3 = tk("subtext")
				v.TextWrapped = true; v.TextXAlignment = Enum.TextXAlignment.Left
				v.LayoutOrder = 1; v.Parent = fRow
			end
		end

	elseif embed.type == "Action" then
		if embed.title and embed.title ~= "" then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size           = UDim2.new(1, 0, 0, 0)
			t.AutomaticSize  = Enum.AutomaticSize.Y
			t.Text           = embed.title
			t.Font           = tk("font")
			t.TextSize       = density().text_size - 1
			t.TextColor3     = tk("text")
			t.TextWrapped    = true
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.LayoutOrder    = iLo; iLo += 1
			t.Parent         = inner
		end

		local btnColor = embed.style == "danger" and Color3.fromRGB(220, 60, 60)
			or embed.style == "ghost" and Color3.fromRGB(70, 70, 75)
			or tk("accent")

		local btn = Instance.new("TextButton")
		btn.Size             = UDim2.fromOffset(140, 30)
		btn.BackgroundColor3 = btnColor
		btn.BorderSizePixel  = 0
		btn.Text             = embed.button_text or "Action"
		btn.Font             = tk("font_bold")
		btn.TextSize         = density().text_size - 2
		btn.TextColor3       = Color3.new(1, 1, 1)
		btn.LayoutOrder      = iLo
		btn.Parent           = inner
		corner(btn, 6)
		btn.MouseButton1Click:Connect(function()
			Events.EmbedActionFired:Fire(embed.action_id, nil)
		end)
	end

	outer.Parent = parent
	return outer
end

-- ------------------------------------------------------------------------
-- row building
-- ------------------------------------------------------------------------

local function shouldGroup(message: any): boolean
	if not Interface.Config.message_grouping then return false end
	local meta = message.metadata
	if not meta or not meta.author_id then return false end
	if meta.author_id ~= _lastAuthorId then return false end
	if (meta.timestamp or 0) - _lastAuthorTime > Interface.Config.grouping_window then return false end
	return true
end

local function buildRow(message: any): TextButton
	local kind = message.kind or "chat"

	if Interface.Renderers[kind] then
		return Interface.Renderers[kind](message, Interface.Config.theme)
	end

	local style    = KIND_STYLE[kind] or KIND_STYLE.chat
	local d        = density()
	local grouped  = shouldGroup(message)

	local row = Instance.new("TextButton")
	row.Name             = "Row"
	row.AutomaticSize    = Enum.AutomaticSize.Y
	row.Size             = UDim2.new(1, 0, 0, 0)
	row.BackgroundTransparency = 1
	row.BackgroundColor3 = Color3.new(0, 0, 0)
	row.Text             = ""
	row.AutoButtonColor  = false
	corner(row, 4)
	pad(row, 2, 2, d.row_pad, d.row_pad)
	listLayout(row, nil, 2)

	row.MouseButton1Click:Connect(function()
		Events.CardClicked:Fire(message, row)
	end)

	local lo = 0

	if message.pinned then
		local bar = Instance.new("Frame")
		bar.Size             = UDim2.new(1, 0, 0, 2)
		bar.BackgroundColor3 = tk("pinned_indicator")
		bar.BorderSizePixel  = 0
		bar.LayoutOrder      = lo; lo += 1
		bar.Parent           = row
	end

	local meta    = message.metadata
	local content = message.content
	local lineParts: { string } = {}

	if Interface.Config.show_timestamps and meta and meta.timestamp and meta.timestamp > 0 then
		table.insert(lineParts, string.format(
			'<font color="%s">[%s]</font> ',
			rgbStr(tk("timestamp_text")), os.date("%H:%M", meta.timestamp)
			))
	end

	if not grouped then
		local authorName = (meta and meta.author_name) or (meta and meta.source) or "System"
		if style.prefix then
			table.insert(lineParts, style.prefix)
		end
		if kind == "chat" then
			local color = colorForAuthor(meta and meta.author_id, authorName, meta and meta.author_color)
			table.insert(lineParts, string.format(
				'<font color="%s"><b>%s</b></font>: ',
				rgbStr(color), escapeRich(authorName)
				))
		elseif style.bold then
			table.insert(lineParts, string.format('<b>%s</b> ', escapeRich(authorName)))
		end
	end

	local mentionData: { any } = {}
	if content then
		if content.elements and #content.elements > 0 then
			local rich, mentions = elementsToRich(content.elements)
			table.insert(lineParts, rich)
			mentionData = mentions
		elseif content.raw_text and content.raw_text ~= "" then
			table.insert(lineParts, escapeRich(content.raw_text))
		end
	end

	for _, decorate in Interface.LineDecorators do
		local extra = decorate(message)
		if extra then table.insert(lineParts, " " .. extra) end
	end

	local fullLine = table.concat(lineParts)

	if fullLine ~= "" then
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size            = UDim2.new(1, 0, 0, 0)
		lbl.AutomaticSize   = Enum.AutomaticSize.Y
		lbl.Font            = tk("font")
		lbl.TextSize        = d.text_size
		lbl.TextColor3      = tk(style.text_key)
		lbl.TextWrapped     = true
		lbl.TextXAlignment  = Enum.TextXAlignment.Left
		lbl.TextYAlignment  = Enum.TextYAlignment.Top
		lbl.RichText        = true
		lbl.Text            = fullLine
		lbl.LayoutOrder     = lo; lo += 1
		lbl.Parent          = row

		if #mentionData > 0 then
			local btn = Instance.new("TextButton")
			btn.Size                 = UDim2.new(1, 0, 1, 0)
			btn.BackgroundTransparency = 1
			btn.Text                 = ""
			btn.ZIndex               = lbl.ZIndex + 1
			btn.Parent               = lbl
			btn.MouseButton1Click:Connect(function()
				for _, m in mentionData do
					Events.MentionClicked:Fire(m.mention_id or 0, m.mention_name or "", message)
				end
			end)
		end
	end

	if message.tags and #message.tags > 0 then
		local tagRow = Instance.new("Frame")
		tagRow.AutomaticSize    = Enum.AutomaticSize.XY
		tagRow.Size             = UDim2.fromOffset(0, 0)
		tagRow.BackgroundTransparency = 1
		tagRow.LayoutOrder      = lo; lo += 1
		tagRow.Parent           = row
		listLayout(tagRow, Enum.FillDirection.Horizontal, 4)

		for _, tag in message.tags do
			local pill = Instance.new("Frame")
			pill.AutomaticSize    = Enum.AutomaticSize.X
			pill.Size             = UDim2.fromOffset(0, 16)
			pill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			pill.BackgroundTransparency = 0.88
			pill.BorderSizePixel  = 0
			pill.Parent           = tagRow
			corner(pill, 4)
			pad(pill, 5, 5, 0, 0)

			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.AutomaticSize          = Enum.AutomaticSize.X
			t.Size                   = UDim2.fromOffset(0, 16)
			t.Text                   = tag
			t.Font                   = tk("font")
			t.TextSize               = d.text_size - 4
			t.TextColor3             = tk("subtext")
			t.Parent                 = pill
		end
	end

	if content and content.embeds then
		for _, embed in content.embeds do
			local ef = buildEmbed(embed, row, lo)
			if ef then lo += 1 end
		end
	end

	if meta then
		_lastAuthorId   = meta.author_id
		_lastAuthorTime = meta.timestamp or os.time()
	end

	return row
end

-- ------------------------------------------------------------------------
-- fade behavior
-- ------------------------------------------------------------------------

local function applyFadeBehavior(row: GuiObject)
	if not tk("fade_enabled") then return end

	local fadeAfter = tk("fade_after")
	local hideAfter = tk("hide_after")

	task.delay(fadeAfter, function()
		if not row.Parent then return end
		for _, child in row:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.6), { TextTransparency = 0.55 }):Play()
			end
		end
	end)

	if hideAfter and hideAfter > 0 then
		task.delay(hideAfter, function()
			if row.Parent then row:Destroy() end
		end)
	end
end

local function wakeRow(row: GuiObject)
	for _, child in row:GetDescendants() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
		end
	end
end

local function wireHoverWake(row: GuiObject)
	row.MouseEnter:Connect(function() wakeRow(row) end)
end

-- ------------------------------------------------------------------------
-- public api
-- ------------------------------------------------------------------------

local function scrollToBottom()
	task.defer(function()
		if _container then
			_container.CanvasPosition = Vector2.new(0, math.huge)
		end
	end)
end

local function trimMessages()
	if not _container then return end
	local rows: { GuiObject } = {}
	for _, c in _container:GetChildren() do
		if c:IsA("TextButton") then table.insert(rows, c) end
	end
	local excess = #rows - Interface.Config.max_messages
	if excess <= 0 then return end
	for i = 1, excess do
		rows[i]:Destroy()
	end
end

function Interface.Build()
	buildGui()
end

function Interface.Render(message: any)
	if not _container then buildGui() end

	local ok, result = pcall(buildRow, message)
	if not ok then
		warn("[Bold.Interface] Row build failed:", result)
		return
	end

	local row: TextButton = result
	warn("BUILDING")

	if Interface.Config.animate_in then
		for _, child in row:GetDescendants() do
			if child:IsA("TextLabel") then child.TextTransparency = 1 end
		end
		row.Parent = _container
		for _, child in row:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()
			end
		end
	else
		row.Parent = _container
	end

	wireHoverWake(row)
	applyFadeBehavior(row)
	trimMessages()
	scrollToBottom()
	Events.MessageRendered:Fire(message, row)
end

function Interface.SetTheme(theme: Types.Theme)
	for k, v in theme do
		Interface.Config.theme[k] = v
	end
	Events.ThemeChanged:Fire(Interface.Config.theme)
end

function Interface.SetDensity(d: Types.LayoutDensity)
	Interface.Config.density = d
end

function Interface.SetChannelName(name: string)
	local old = Interface.Config.channel_name
	Interface.Config.channel_name = name
	Events.ChannelChanged:Fire(name, old)
	if _header then
		local lbl = _header:FindFirstChildOfClass("TextLabel")
		if lbl then lbl.Text = name end
	end
end

function Interface.Toggle(visible: boolean?)
	if not _gui then return end
	local nextVal = if visible ~= nil then visible else not _gui.Enabled
	_gui.Enabled = nextVal
	Events.UIToggled:Fire(nextVal)
end

function Interface.Clear()
	if not _container then return end
	for _, c in _container:GetChildren() do
		if c:IsA("TextButton") then c:Destroy() end
	end
end

function Interface.RegisterRenderer(kind: string, fn: (any, any) -> Frame)
	Interface.Renderers[kind] = fn
end

function Interface.RegisterLineDecorator(fn: (any) -> string?)
	table.insert(Interface.LineDecorators, fn)
end

function Interface.SetKindStyle(kind: string, textKey: string, prefix: string?, bold: boolean?)
	KIND_STYLE[kind] = { text_key = textKey, prefix = prefix, bold = bold }
end

function Interface.GetInputBox(): TextBox?
	return _inputBox
end

function Interface.FocusInput()
	if _inputBox then _inputBox:CaptureFocus() end
end

return Interface