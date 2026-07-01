-- Bold
-- _Utility/Skin
-- Plinko Labs

-- Shared theming + instance helpers used by Interface, Render and Compose, so
-- the look of a control is defined once. Reads the live theme/density off Config.

local Config = require(script.Parent.Config)

local Skin = {}

local FALLBACK = Config.ThemePresets.dark

-- theme token lookup with a hard default fallback
function Skin.tk(key: string): any
	local v = Config.Interface.theme[key]
	if v ~= nil then return v end
	return FALLBACK[key]
end

function Skin.density(): { row_pad: number, text_size: number, gap: number }
	return Config.Density[Config.Interface.density] or Config.Density.cozy
end

function Skin.rgb(c: Color3): string
	return string.format("rgb(%d,%d,%d)", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function Skin.escape(s: string): string
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

function Skin.corner(parent: Instance, r: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or Skin.tk("corner_radius"))
	c.Parent = parent
	return c
end

function Skin.pad(parent: Instance, left: number?, right: number?, top: number?, bottom: number?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingLeft   = UDim.new(0, left or 0)
	p.PaddingRight  = UDim.new(0, right or left or 0)
	p.PaddingTop    = UDim.new(0, top or 0)
	p.PaddingBottom = UDim.new(0, bottom or top or 0)
	p.Parent = parent
	return p
end

function Skin.list(parent: Instance, dir: Enum.FillDirection?, gap: number?, sort: Enum.SortOrder?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.SortOrder     = sort or Enum.SortOrder.LayoutOrder
	l.Padding       = UDim.new(0, gap or 0)
	l.Parent        = parent
	return l
end

local _nameCache: { [string]: Color3 } = {}

function Skin.authorColor(id: number?, name: string?, explicit: Color3?): Color3
	if explicit then return explicit end
	local key = id and tostring(id) or (name or "?")
	if _nameCache[key] then return _nameCache[key] end
	local palette = Skin.tk("name_palette")
	local idx = (id or (name and #name) or 0) % #palette + 1
	local c = palette[idx]
	_nameCache[key] = c
	return c
end

return Skin
