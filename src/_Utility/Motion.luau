-- Bold
-- _Utility/Motion
-- Plinko Labs

-- Every tween in Bold lives here, driven by Config.Animation so the whole feel
-- is tunable from one place. Entrances use a fade + subtle UIScale "rise" that
-- works regardless of the UIListLayout the rows sit in.

local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Motion = {}

local EASE_OUT = Enum.EasingStyle.Quint
local EASE_IO  = Enum.EasingStyle.Quad

local function anim()
	return Config.Animation
end

function Motion.tween(obj: Instance, dur: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(
		obj,
		TweenInfo.new(dur, style or EASE_OUT, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- Collect the text/image descendants we fade, remembering each target opacity so
-- a fade-in restores whatever the element actually wanted (images aren't always 0).
local function fadeTargets(root: Instance): { { obj: Instance, prop: string, target: number } }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			table.insert(out, { obj = d, prop = "TextTransparency", target = (d :: any).TextTransparency })
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			table.insert(out, { obj = d, prop = "ImageTransparency", target = (d :: any).ImageTransparency })
		end
	end
	return out
end

-- Entrance animation for a freshly-parented message row.
function Motion.RowIn(row: GuiObject)
	local a = anim()
	if not a.enabled or a.in_style == "none" then return end

	local targets = fadeTargets(row)
	for _, t in targets do
		(t.obj :: any)[t.prop] = 1
	end

	local scale: UIScale? = nil
	if a.in_style == "slide" then
		scale = Instance.new("UIScale")
		scale.Scale = 0.97
		scale.Parent = row
		Motion.tween(scale, a.in_time, { Scale = 1 }, EASE_OUT)
	end

	for i, t in targets do
		local delay = a.stagger * (i - 1)
		task.delay(delay, function()
			if not (t.obj :: Instance).Parent then return end
			Motion.tween(t.obj, a.in_time, { [t.prop] = t.target }, EASE_IO)
		end)
	end

	if scale then
		task.delay(a.in_time + 0.05, function()
			if scale.Parent then scale:Destroy() end
		end)
	end
end

-- Hover wake: snap text back to full opacity (after fade-dimming).
function Motion.Wake(row: GuiObject)
	for _, t in fadeTargets(row) do
		Motion.tween(t.obj, 0.15, { [t.prop] = t.target }, EASE_IO)
	end
end

-- Old-message dimming, mirroring Roblox's default chat. Reads the fade tokens
-- off the active theme. Returns nothing; schedules itself.
function Motion.FadeOld(row: GuiObject)
	local theme = Config.Interface.theme
	if not theme.fade_enabled then return end

	local fadeAfter = theme.fade_after or 8
	local hideAfter = theme.hide_after or 0

	task.delay(fadeAfter, function()
		if not row.Parent then return end
		for _, t in fadeTargets(row) do
			Motion.tween(t.obj, 0.6, { [t.prop] = math.max(t.target, 0.55) }, EASE_IO)
		end
	end)

	if hideAfter and hideAfter > 0 then
		task.delay(hideAfter, function()
			if row.Parent then row:Destroy() end
		end)
	end
end

-- Reveal/conceal a CanvasGroup (spoilers, warning pills, panels).
function Motion.Reveal(group: CanvasGroup)
	Motion.tween(group, anim().reveal_time, { GroupTransparency = 0 }, EASE_IO)
end

function Motion.Conceal(group: CanvasGroup, to: number?)
	Motion.tween(group, anim().reveal_time, { GroupTransparency = to or 1 }, EASE_IO)
end

-- One-shot card highlight flash (used when the local player is mentioned).
-- `overlay` is a Frame sitting over the card; we pulse its transparency.
function Motion.FlashCard(overlay: Frame, peak: number?)
	local a = anim()
	overlay.BackgroundTransparency = 1
	Motion.tween(overlay, a.flash_time * 0.3, { BackgroundTransparency = peak or 0.75 }, EASE_IO)
	task.delay(a.flash_time * 0.3, function()
		if overlay.Parent then
			Motion.tween(overlay, a.flash_time * 0.7, { BackgroundTransparency = 1 }, EASE_IO)
		end
	end)
end

-- Reaction pop.
function Motion.Pop(obj: GuiObject)
	local s = Instance.new("UIScale")
	s.Scale = 0.6
	s.Parent = obj
	Motion.tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.3, function()
		if s.Parent then s:Destroy() end
	end)
end

-- Scroll a list to the bottom, optionally easing. Waits a frame so the
-- AutomaticCanvasSize has actually grown to include the new content before we
-- compute the target, otherwise we'd scroll to a stale (too-short) position.
function Motion.ScrollToBottom(frame: ScrollingFrame, smooth: boolean?)
	task.spawn(function()
		RunService.Heartbeat:Wait()
		if not frame.Parent then return end
		local target = math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y)
		if smooth and anim().smooth_scroll then
			Motion.tween(frame, 0.2, { CanvasPosition = Vector2.new(0, target) }, EASE_IO)
		else
			frame.CanvasPosition = Vector2.new(0, target)
		end
	end)
end

return Motion
