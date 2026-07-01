-- Bold
-- _Main/Interface
-- Plinko Labs

-- Window orchestration + the public UI surface. Builds the frame/header/list,
-- owns visibility and theme/density, and wires Render (the message list) to
-- Compose (the input). Message rendering lives in Render; input lives in Compose.

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local _Main    = script.Parent
local _Utility = _Main.Parent._Utility

local Config = require(_Utility.Config)
local Skin   = require(_Utility.Skin)
local Events = require(_Utility.Events)
local Types  = require(_Main.Parent.Types)
local Render  = require(_Main.Render)
local Compose = require(_Main.Compose)

local Interface = {}

-- live config alias (back-compat for code that reads Interface.Config)
Interface.Config = Config.Interface

-- the input event consumers (Client) subscribe to
Interface.SubmitText = Compose.SubmitText

local tk = Skin.tk

local _gui: ScreenGui? = nil
local _window: Frame? = nil
local _container: ScrollingFrame? = nil
local _header: Frame? = nil

-- ─── build ───────────────────────────────────────────────────────────────────

local function enableDrag(handle: GuiObject, target: Frame)
	local dragging = false
	local dragStart, startPos
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local function buildGui()
	if _gui then return end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local cfg = Config.Interface

	_gui = Instance.new("ScreenGui")
	_gui.Name = "BoldUI"
	_gui.ResetOnSpawn = false
	_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_gui.Enabled = cfg.visible
	_gui.Parent = playerGui

	_window = Instance.new("Frame")
	_window.Name = "Window"
	_window.Size = cfg.window_size
	_window.AutomaticSize = Enum.AutomaticSize.Y
	_window.Position = cfg.window_position
	_window.AnchorPoint = cfg.window_anchor
	_window.BackgroundTransparency = 1
	_window.Parent = _gui
	Skin.list(_window, nil, 2)

	if cfg.show_header and cfg.header_height > 0 then
		_header = Instance.new("Frame")
		_header.Name = "Header"
		_header.Size = UDim2.new(1, 0, 0, cfg.header_height)
		_header.BackgroundColor3 = tk("header")
		_header.BackgroundTransparency = tk("header_transparency")
		_header.BorderSizePixel = 0
		_header.LayoutOrder = 0
		_header.Parent = _window
		Skin.corner(_header)
		Skin.pad(_header, 10)

		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.Text = cfg.channel_name
		lbl.Font = tk("font_bold")
		lbl.TextSize = Skin.density().text_size - 1
		lbl.TextColor3 = tk("text")
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Parent = _header

		if cfg.draggable then enableDrag(_header, _window) end
	end

	local listWrapper = Instance.new("Frame")
	listWrapper.Name = "ListWrapper"
	listWrapper.BackgroundTransparency = 1
	listWrapper.Size = UDim2.new(1, 0, 0, cfg.min_list_height or 0)
	listWrapper.LayoutOrder = 1
	listWrapper.Parent = _window

	_container = Instance.new("ScrollingFrame")
	_container.Name = "Messages"
	_container.Size = UDim2.new(1, 0, 1, 0)
	_container.BackgroundColor3 = tk("background")
	_container.BackgroundTransparency = tk("background_transparency")
	_container.BorderSizePixel = 0
	_container.ScrollBarThickness = cfg.show_scrollbar and 4 or 0
	_container.ScrollBarImageColor3 = tk("subtext")
	_container.CanvasSize = UDim2.new(0, 0, 0, 0)
	_container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	_container.VerticalScrollBarInset = Enum.ScrollBarInset.Always
	_container.Parent = listWrapper
	Skin.corner(_container)

	local layout = Skin.list(_container, nil, Skin.density().gap)
	Skin.pad(_container, 8, 8, 6, 6)

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

	Render.SetContainer(_container)

	if cfg.show_input then
		Compose.Build(_window)
		Render.ReplyHandler = Compose.SetReplyTarget
		Compose.ToggleHandler = Interface.Toggle
	end
end

-- ─── public ──────────────────────────────────────────────────────────────────

function Interface.Build()
	buildGui()
end

function Interface.Render(message: any): GuiObject?
	if not _container then buildGui() end
	return Render.Render(message)
end

function Interface.ApplyUpdate(id: string, patch: any)
	Render.ApplyUpdate(id, patch)
end

function Interface.Clear()
	Render.Clear()
end

function Interface.SystemMessage(text: string)
	Render.SystemMessage(text)
end

function Interface.SetTheme(theme: Types.Theme)
	for k, v in theme do
		Config.Interface.theme[k] = v
	end
	Events.ThemeChanged:Fire(Config.Interface.theme)
end

function Interface.SetDensity(d: Types.LayoutDensity)
	Config.Interface.density = d
end

function Interface.SetChannelName(name: string)
	local old = Config.Interface.channel_name
	Config.Interface.channel_name = name
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

function Interface.FocusInput()
	Compose.Focus()
end

function Interface.GetInputBox(): TextBox?
	return Compose.GetInputBox()
end

function Interface.SetReactHandler(fn: (id: string, emoji: string) -> ())
	Render.ReactHandler = fn
end

function Interface.RegisterRenderer(kind: string, fn: (any, any) -> Frame)
	Render.RegisterRenderer(kind, fn)
end

function Interface.RegisterPanel(name: string, fn: (any, any, any) -> Frame)
	Render.RegisterPanel(name, fn)
end

function Interface.RegisterLineDecorator(fn: (any) -> string?)
	Render.RegisterLineDecorator(fn)
end

function Interface.SetKindStyle(kind: string, textKey: string, prefix: string?, bold: boolean?)
	Render.SetKindStyle(kind, textKey, prefix, bold)
end

function Interface.SetKindOverride(kind: string, bgKey: string, textKey: string)
	Render.SetKindOverride(kind, bgKey, textKey)
end

return Interface
