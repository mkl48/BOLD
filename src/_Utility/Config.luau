-- Bold
-- _Utility/Config
-- Plinko Labs

-- Single source of truth for every tunable in Bold. Holds the live config that
-- both realms read from, seeded with defaults and mutated through Apply().
-- Bold.Configure(config) funnels here, replacing the brittle per-field copying
-- the old Start() did by hand.

local Types = require(script.Parent.Parent.Types)

local Config = {}

-- ─── Default theme ───────────────────────────────────────────────────────────

local DARK: Types.Theme = {
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
	mention_text             = Color3.fromRGB(198, 178, 255),
	mention_self_bg          = Color3.fromRGB(255, 200, 50),
	code_bg                  = Color3.fromRGB(25,  25, 28),
	code_text                = Color3.fromRGB(186, 230, 126),
	link_text                = Color3.fromRGB(120, 170, 255),
	spoiler_bg               = Color3.fromRGB(30,  30, 34),
	spoiler_text             = Color3.fromRGB(220, 220, 225),
	quote_bar                = Color3.fromRGB(120, 120, 130),
	quote_text               = Color3.fromRGB(180, 180, 190),
	reaction_bg              = Color3.fromRGB(40,  40, 46),
	reaction_active          = Color3.fromRGB(108, 62, 244),

	-- per-message card background (used when interface.message_background is on)
	message_bg               = Color3.fromRGB(255, 255, 255),
	message_bg_transparency  = 0.94,
	message_hover            = Color3.fromRGB(255, 255, 255),
	message_hover_transparency = 0.97,

	autocomplete_bg          = Color3.fromRGB(43, 45, 49),
	autocomplete_hover       = Color3.fromRGB(64, 66, 73),
	autocomplete_border      = Color3.fromRGB(30, 31, 34),

	system_text              = Color3.fromRGB(170, 170, 170),
	announcement_bg          = Color3.fromRGB(108, 62, 244),
	announcement_text        = Color3.fromRGB(255, 255, 255),
	whisper_text             = Color3.fromRGB(210, 170, 255),
	team_text                = Color3.fromRGB(110, 230, 150),
	error_text               = Color3.fromRGB(255, 90, 90),

	pinned_indicator         = Color3.fromRGB(255, 200, 50),

	font                     = Enum.Font.SourceSans,
	font_bold                = Enum.Font.SourceSansBold,
	text_size                = 16,
	corner_radius            = 4,

	fade_enabled             = true,
	fade_after               = 8,
	hide_after               = 0,
}

-- ─── Density presets ─────────────────────────────────────────────────────────

Config.Density = {
	compact     = { row_pad = 1, text_size = 14, gap = 0 },
	cozy        = { row_pad = 3, text_size = 16, gap = 1 },
	comfortable = { row_pad = 6, text_size = 17, gap = 3 },
}

-- ─── deep merge ──────────────────────────────────────────────────────────────

-- Arrays (name_palette, key lists, quick_reactions) and Roblox datatypes
-- (Color3/UDim2/Vector2/EnumItem) are leaves: replaced wholesale. Only plain
-- string-keyed maps are merged recursively.
local function isArray(t: any): boolean
	return type(t) == "table" and (rawget(t, 1) ~= nil or next(t) == nil)
end

local function isMergeableMap(t: any): boolean
	return type(t) == "table" and typeof(t) == "table" and not isArray(t)
end

local function deepMerge(into: { [any]: any }, from: { [any]: any }): { [any]: any }
	for k, v in from do
		if isMergeableMap(v) and isMergeableMap(into[k]) then
			deepMerge(into[k], v)
		else
			into[k] = v
		end
	end
	return into
end

local function deepCopy(t: { [any]: any }): { [any]: any }
	local out = {}
	for k, v in t do
		out[k] = isMergeableMap(v) and deepCopy(v) or (isArray(v) and table.clone(v) or v)
	end
	return out
end

Config.deepMerge = deepMerge
Config.deepCopy = deepCopy

-- ─── Live config (mutable; both realms read this) ────────────────────────────

Config.Interface = {
	theme            = deepCopy(DARK),
	density          = "cozy" :: Types.LayoutDensity,
	window_size      = UDim2.fromOffset(460, 0), -- height auto-driven
	window_position  = UDim2.new(0, 12, 0, 12),  -- top-left
	window_anchor    = Vector2.new(0, 0),
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
	draggable        = false,
	resizable        = false,
	message_grouping = true,
	grouping_window  = 30,
	reactions        = true,
	reply_enabled    = true,
	quick_reactions  = { "👍", "❤️", "😂", "🔥", "🎉" },

	-- visuals
	backdrop            = true,  -- the panel behind the whole message list
	message_background  = false, -- a card behind each message (Discord-ish)
	collapsible         = true,  -- long messages get a show more/less toggle
	collapse_lines      = 6,     -- collapse threshold, in lines
	open_animation      = true,  -- animate the window opening/closing

	-- social indicators
	show_friend_badge   = false, -- a dot next to friends' names
	show_blocked        = false, -- mark/handle Roblox-blocked users
}

Config.Parsing = {
	enabled  = true,
	markdown = true,
	mentions = true,
	emoji    = true,
	panels   = true,
	links    = true,
	filter   = true,
}

Config.Filter = {
	enabled         = true,
	purgomalum      = true,
	client_backstop = true,
	-- anti-spam: at most `rate_limit` messages per `rate_window` seconds per
	-- player (server-enforced). Set either to 0 to disable.
	rate_limit      = 5,
	rate_window     = 4,
}

Config.Keys = {
	focus      = Enum.KeyCode.Slash,
	toggle     = false :: any,
	accept     = { Enum.KeyCode.Return, Enum.KeyCode.Tab },
	up         = { Enum.KeyCode.Up },
	down       = { Enum.KeyCode.Down },
	close      = { Enum.KeyCode.Escape },
	use_switch = true,
}

Config.Animation = {
	enabled       = true,
	in_style      = "slide" :: string,
	in_time       = 0.18,
	stagger       = 0.02,
	flash_time    = 0.5,
	reveal_time   = 0.2,
	smooth_scroll = true,
}

Config.Sounds = {
	enabled = false,
	message = nil :: string?,
	mention = nil :: string?,
	send    = nil :: string?,
	volume  = 0.5,
}

-- ─── Presets ─────────────────────────────────────────────────────────────────

Config.ThemePresets = {
	dark = deepCopy(DARK),
	light = deepMerge(deepCopy(DARK), {
		background = Color3.fromRGB(245, 245, 248), background_transparency = 0.05,
		header = Color3.fromRGB(235, 235, 240), header_transparency = 0,
		input_bg = Color3.fromRGB(255, 255, 255), input_transparency = 0,
		text = Color3.fromRGB(20, 20, 24), subtext = Color3.fromRGB(90, 90, 100),
		timestamp_text = Color3.fromRGB(140, 140, 150), placeholder_text = Color3.fromRGB(150, 150, 160),
		code_bg = Color3.fromRGB(235, 235, 240), code_text = Color3.fromRGB(40, 110, 40),
		spoiler_bg = Color3.fromRGB(210, 210, 216), spoiler_text = Color3.fromRGB(40, 40, 46),
		quote_text = Color3.fromRGB(90, 90, 100), reaction_bg = Color3.fromRGB(225, 225, 232),
	}),
	midnight = deepMerge(deepCopy(DARK), {
		background = Color3.fromRGB(12, 14, 24), background_transparency = 0.15,
		input_bg = Color3.fromRGB(18, 20, 32), input_transparency = 0.1,
		accent = Color3.fromRGB(96, 130, 255), mention_bg = Color3.fromRGB(96, 130, 255),
		code_text = Color3.fromRGB(130, 200, 255),
	}),
	neon = deepMerge(deepCopy(DARK), {
		background = Color3.fromRGB(8, 8, 12), background_transparency = 0.2,
		accent = Color3.fromRGB(0, 255, 170), mention_bg = Color3.fromRGB(0, 255, 170),
		mention_text = Color3.fromRGB(170, 255, 230), link_text = Color3.fromRGB(0, 255, 170),
		code_text = Color3.fromRGB(255, 90, 200), font = Enum.Font.Code, font_bold = Enum.Font.Code,
	}),
}

Config.LayoutPresets = {
	top_left     = { window_position = UDim2.new(0, 12, 0, 12),  window_anchor = Vector2.new(0, 0) },
	top_right    = { window_position = UDim2.new(1, -12, 0, 12), window_anchor = Vector2.new(1, 0) },
	bottom_left  = { window_position = UDim2.new(0, 12, 1, -12), window_anchor = Vector2.new(0, 1) },
	bottom_right = { window_position = UDim2.new(1, -12, 1, -12), window_anchor = Vector2.new(1, 1) },
	center       = { window_position = UDim2.fromScale(0.5, 0.5), window_anchor = Vector2.new(0.5, 0.5) },
}

-- ─── Apply ───────────────────────────────────────────────────────────────────

-- Deep-merge a BoldConfig into the live config. Section by section so each lands
-- in the right live table; theme/density nest under `interface`.
function Config.Apply(boldConfig: Types.BoldConfig?)
	if not boldConfig then return end
	local c = boldConfig :: any

	if c.interface then deepMerge(Config.Interface, c.interface) end
	if c.parsing   then deepMerge(Config.Parsing, c.parsing) end
	if c.filter    then deepMerge(Config.Filter, c.filter) end
	if c.keys      then deepMerge(Config.Keys, c.keys) end
	if c.animation then deepMerge(Config.Animation, c.animation) end
	if c.sounds    then deepMerge(Config.Sounds, c.sounds) end
end

function Config.ApplyThemePreset(name: string): boolean
	local preset = Config.ThemePresets[name]
	if not preset then return false end
	deepMerge(Config.Interface.theme, deepCopy(preset))
	return true
end

function Config.ApplyLayoutPreset(name: string): boolean
	local preset = Config.LayoutPresets[name]
	if not preset then return false end
	deepMerge(Config.Interface, deepCopy(preset))
	return true
end

return Config
