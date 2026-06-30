local TweenService = game:GetService("TweenService")

local _Patterns = script.Parent
local _Utility = _Patterns.Parent._Utility

local HardBlockFilter = require(_Utility.HardBlockFilter)

local InputFilter = {}

local DEFAULT_WARNING_TEXT = "This message may be flagged or filtered."

local SHOW_TWEEN_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HIDE_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- Attaches a live local check to `textBox`. Fades `warningPill` (a
-- CanvasGroup) in/out via GroupTransparency whenever the current input
-- contains a locally-known flagged word, and keeps `warningLabel.Text` in
-- sync. Returns the RBXScriptConnection so callers can disconnect it.
function InputFilter.Attach(
	textBox: TextBox,
	warningPill: CanvasGroup,
	warningLabel: TextLabel,
	warningText: string?
)
	warningLabel.Text = warningText or DEFAULT_WARNING_TEXT

	local visible = false
	local activeTween: Tween? = nil

	local function setVisible(shouldShow: boolean)
		if shouldShow == visible then
			return
		end
		visible = shouldShow

		if activeTween then
			activeTween:Cancel()
		end

		local info = shouldShow and SHOW_TWEEN_INFO or HIDE_TWEEN_INFO
		local targetTransparency = shouldShow and 0.1 or 1

		activeTween = TweenService:Create(warningPill, info, {
			GroupTransparency = targetTransparency,
		})
		
		activeTween:Play()
	end

	local function update()
		local flagged = HardBlockFilter.ContainsBlockedWord(textBox.Text)
		setVisible(flagged)
	end

	-- Reset state immediately in case textBox already has text
	update()

	local connection = textBox:GetPropertyChangedSignal("Text"):Connect(update)

	-- Clear the warning once the message is actually sent
	textBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			setVisible(false)
		end
	end)

	return connection
end

return InputFilter