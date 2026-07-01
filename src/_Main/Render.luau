-- Bold
-- _Main/Render
-- Plinko Labs

-- The rendering engine. Owns the message list: parses each message at render
-- time (from already-filtered text), builds the card, and keeps a registry so
-- updates (deferred-filter edits, reactions) can patch a card in place.

local Players = game:GetService("Players")

local _Main     = script.Parent
local _Utility  = _Main.Parent._Utility
local _Patterns = _Main.Parent._Patterns

local Config    = require(_Utility.Config)
local Skin      = require(_Utility.Skin)
local Motion    = require(_Utility.Motion)
local Events    = require(_Utility.Events)
local ImageWrap = require(_Utility.ImageWrap)
local Parser    = require(_Patterns.Parser)
local Types     = require(_Main.Parent.Types)

local LocalPlayer = Players.LocalPlayer

local Render = {}

Render.Renderers      = {} :: { [string]: (any, any) -> Frame }
Render.Panels         = {} :: { [string]: (any, any, any) -> Frame }
Render.LineDecorators = {} :: { (any) -> string? }

-- wired by Interface/init so Render stays decoupled from Client/Compose
Render.ReactHandler = nil :: ((id: string, emoji: string) -> ())?
Render.ReplyHandler = nil :: ((message: any) -> ())?

local KIND_STYLE: { [string]: { prefix: string?, text_key: string, bold: boolean? } } = {
	chat         = { prefix = nil,    text_key = "text" },
	me           = { prefix = "* ",   text_key = "system_text" },
	system       = { prefix = "* ",   text_key = "system_text" },
	announcement = { prefix = "[!] ", text_key = "announcement_text", bold = true },
	whisper      = { prefix = "→ ",   text_key = "whisper_text" },
	team         = { prefix = "[T] ", text_key = "team_text" },
	error        = { prefix = "[x] ", text_key = "error_text" },
}

local KIND_OVERRIDE: { [string]: { bg_key: string?, text_key: string } } = {}

local _container: ScrollingFrame? = nil
local _registry: { [string]: { message: any, row: GuiObject, order: number, revealed: boolean, grouped: boolean } } = {}
local _rendered: { string } = {} -- ids in render order, for trimming
local _seq = 0
local _lastAuthorId: number? = nil
local _lastAuthorTime: number = 0
local _lastGrouped = false -- grouping decision for the most recent buildRow

function Render.SetContainer(frame: ScrollingFrame)
	_container = frame
end

-- ─── helpers ─────────────────────────────────────────────────────────────────

local tk      = Skin.tk
local density = Skin.density
local rgb     = Skin.rgb
local escape  = Skin.escape

local function ensureElements(message: any): { any }
	local c = message.content
	if not c then return {} end
	if c.elements and #c.elements > 0 then return c.elements end
	if c.raw_text and c.raw_text ~= "" then
		c.elements = Parser.Parse(c.raw_text, {
			markdown = Config.Parsing.markdown,
			mentions = Config.Parsing.mentions,
			emoji    = Config.Parsing.emoji,
			panels   = Config.Parsing.panels,
			links    = Config.Parsing.links,
			player_list = Players:GetPlayers(),
		})
	end
	return c.elements or {}
end

-- ─── inline rich text ────────────────────────────────────────────────────────

type InlineCtx = { mentions: { any }, links: { string }, hasSpoiler: boolean }

local function inlineRich(elems: { any }, revealed: boolean, ctx: InlineCtx): string
	local parts: { string } = {}

	for _, el in elems do
		local t = el.type
		if t == "text" then
			local s = escape(el.content)
			local f = el.formatting
			if f then
				if f.bold          then s = "<b>" .. s .. "</b>" end
				if f.italic        then s = "<i>" .. s .. "</i>" end
				if f.underline     then s = "<u>" .. s .. "</u>" end
				if f.strikethrough then s = "<s>" .. s .. "</s>" end
				if f.color         then s = ('<font color="%s">%s</font>'):format(rgb(f.color), s) end
			end
			table.insert(parts, s)

		elseif t == "emoji_unicode" then
			table.insert(parts, el.content)

		elseif t == "emoji_custom" then
			table.insert(parts, "[:" .. (el.data and el.data.emoji_name or "?") .. ":]")

		elseif t == "code" then
			table.insert(parts, ('<font color="%s" face="RobotoMono">%s</font>'):format(rgb(tk("code_text")), escape(el.content)))

		elseif t == "color" then
			local color = (el.data and el.data.color) or tk("text")
			table.insert(parts, ('<font color="%s">%s</font>'):format(rgb(color), escape(el.content)))

		elseif t == "link" then
			if el.data and el.data.link_url then table.insert(ctx.links, el.data.link_url) end
			table.insert(parts, ('<u><font color="%s">%s</font></u>'):format(rgb(tk("link_text")), escape(el.content)))

		elseif t == "mention" then
			if el.data then table.insert(ctx.mentions, el.data) end
			local name = (el.data and el.data.mention_name) or el.content:sub(2)
			table.insert(parts, ('<font color="%s"><b>@%s</b></font>'):format(rgb(tk("mention_text")), escape(name)))

		elseif t == "spoiler" then
			ctx.hasSpoiler = true
			if revealed then
				table.insert(parts, ('<font color="%s">%s</font>'):format(rgb(tk("spoiler_text")), escape(el.content)))
			else
				local blocks = string.rep("█", math.clamp(#el.content, 2, 40))
				table.insert(parts, ('<font color="%s">%s</font>'):format(rgb(tk("spoiler_bg")), blocks))
			end
		end
	end

	return table.concat(parts)
end

-- ─── block elements (blockquote, panel) ──────────────────────────────────────

local function buildBlockquote(el: any, lo: number): Frame
	local outer = Instance.new("Frame")
	outer.AutomaticSize = Enum.AutomaticSize.Y
	outer.Size = UDim2.new(1, 0, 0, 0)
	outer.BackgroundTransparency = 1
	outer.LayoutOrder = lo
	Skin.pad(outer, 8, 0, 0, 0)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 3, 1, 0)
	bar.Position = UDim2.fromOffset(0, 0)
	bar.BackgroundColor3 = tk("quote_bar")
	bar.BorderSizePixel = 0
	bar.Parent = outer
	Skin.corner(bar, 2)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(8, 0)
	lbl.Size = UDim2.new(1, -8, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.Font = tk("font")
	lbl.TextSize = density().text_size
	lbl.TextColor3 = tk("quote_text")
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.RichText = true
	lbl.Text = escape(el.content)
	lbl.Parent = outer

	return outer
end

local function buildPanelFallback(el: any, lo: number): Frame
	local outer = Instance.new("Frame")
	outer.AutomaticSize = Enum.AutomaticSize.Y
	outer.Size = UDim2.new(1, 0, 0, 0)
	outer.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	outer.BackgroundTransparency = 0.15
	outer.BorderSizePixel = 0
	outer.LayoutOrder = lo
	Skin.corner(outer, 6)
	Skin.pad(outer, 8, 8, 6, 6)

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.Font = tk("font")
	lbl.TextSize = density().text_size - 1
	lbl.TextColor3 = tk("subtext")
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = ("[panel :%s:]"):format(el.data and el.data.panel_name or "?")
	lbl.Parent = outer

	return outer
end

local function buildPanel(el: any, message: any, lo: number): Frame
	local name = el.data and el.data.panel_name
	local fn = name and Render.Panels[name]
	if fn then
		local ok, frame = pcall(fn, el.data.panel_args or {}, message, Config.Interface.theme)
		if ok and typeof(frame) == "Instance" and frame:IsA("GuiObject") then
			frame.LayoutOrder = lo
			return frame
		else
			warn("[Bold.Render] panel '" .. tostring(name) .. "' renderer failed:", frame)
		end
	end
	return buildPanelFallback(el, lo)
end

-- ─── embeds (ported, lightly tidied) ─────────────────────────────────────────

local function buildEmbed(embed: any, lo: number): Frame?
	if not embed or not embed.type then return nil end

	local outer = Instance.new("Frame")
	outer.Name = "Embed_" .. embed.type
	outer.AutomaticSize = Enum.AutomaticSize.Y
	outer.Size = UDim2.new(1, 0, 0, 0)
	outer.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	outer.BackgroundTransparency = 0.15
	outer.BorderSizePixel = 0
	outer.LayoutOrder = lo
	Skin.corner(outer, 6)

	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 3, 1, 0)
	stripe.BackgroundColor3 = embed.color or tk("accent")
	stripe.BorderSizePixel = 0
	stripe.Parent = outer
	Skin.corner(stripe, 2)

	local inner = Instance.new("Frame")
	inner.AutomaticSize = Enum.AutomaticSize.Y
	inner.Size = UDim2.new(1, -12, 0, 0)
	inner.Position = UDim2.fromOffset(12, 0)
	inner.BackgroundTransparency = 1
	inner.Parent = outer
	Skin.list(inner, nil, 4)
	Skin.pad(inner, 6, 6, 6, 8)

	local iLo = 0
	local d = density()

	if embed.type == "Image" then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(1, 0, 0, 140)
		img.BackgroundColor3 = Color3.new(0, 0, 0)
		img.BackgroundTransparency = 0.4
		img.Image = embed.image_id or ""
		img.ScaleType = Enum.ScaleType.Fit
		img.LayoutOrder = iLo; iLo += 1
		img.Parent = inner
		Skin.corner(img, 4)
		if embed.caption and embed.caption ~= "" then
			local cap = Instance.new("TextLabel")
			cap.BackgroundTransparency = 1
			cap.Size = UDim2.new(1, 0, 0, 0); cap.AutomaticSize = Enum.AutomaticSize.Y
			cap.Text = embed.caption; cap.Font = tk("font")
			cap.TextSize = d.text_size - 2; cap.TextColor3 = tk("subtext")
			cap.TextWrapped = true; cap.TextXAlignment = Enum.TextXAlignment.Left
			cap.LayoutOrder = iLo; iLo += 1; cap.Parent = inner
		end

	elseif embed.type == "Gif" then
		local vf = Instance.new("VideoFrame")
		vf.Size = UDim2.new(1, 0, 0, 140)
		vf.BackgroundColor3 = Color3.new(0, 0, 0)
		vf.Video = embed.video_id or ""
		vf.Looped = embed.loop ~= false
		vf.LayoutOrder = iLo; iLo += 1
		vf.Parent = inner
		Skin.corner(vf, 4)
		if embed.autoplay ~= false then vf:Play() end

	elseif embed.type == "Sticker" then
		local sz = embed.size or 80
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromOffset(sz, sz)
		img.BackgroundTransparency = 1
		img.Image = ImageWrap.WrapId(embed.sticker_id or "")
		img.ScaleType = Enum.ScaleType.Fit
		img.LayoutOrder = iLo; iLo += 1
		img.Parent = inner

	elseif embed.type == "RichText" then
		if embed.title and embed.title ~= "" then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(1, 0, 0, 0); t.AutomaticSize = Enum.AutomaticSize.Y
			t.Text = embed.title; t.Font = tk("font_bold")
			t.TextSize = d.text_size + 1; t.TextColor3 = tk("text")
			t.TextWrapped = true; t.TextXAlignment = Enum.TextXAlignment.Left
			t.LayoutOrder = iLo; iLo += 1; t.Parent = inner
		end
		if embed.description and embed.description ~= "" then
			local desc = Instance.new("TextLabel")
			desc.BackgroundTransparency = 1
			desc.Size = UDim2.new(1, 0, 0, 0); desc.AutomaticSize = Enum.AutomaticSize.Y
			desc.Text = embed.description; desc.Font = tk("font")
			desc.TextSize = d.text_size - 1; desc.TextColor3 = tk("subtext")
			desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.LayoutOrder = iLo; iLo += 1; desc.Parent = inner
		end
		if embed.fields then
			for _, field in embed.fields do
				local n = Instance.new("TextLabel")
				n.BackgroundTransparency = 1
				n.Size = UDim2.new(1, 0, 0, 0); n.AutomaticSize = Enum.AutomaticSize.Y
				n.Text = field.name; n.Font = tk("font_bold")
				n.TextSize = d.text_size - 2; n.TextColor3 = tk("text")
				n.TextWrapped = true; n.TextXAlignment = Enum.TextXAlignment.Left
				n.LayoutOrder = iLo; iLo += 1; n.Parent = inner
				local v = Instance.new("TextLabel")
				v.BackgroundTransparency = 1
				v.Size = UDim2.new(1, 0, 0, 0); v.AutomaticSize = Enum.AutomaticSize.Y
				v.Text = field.value; v.Font = tk("font")
				v.TextSize = d.text_size - 2; v.TextColor3 = tk("subtext")
				v.TextWrapped = true; v.TextXAlignment = Enum.TextXAlignment.Left
				v.LayoutOrder = iLo; iLo += 1; v.Parent = inner
			end
		end

	elseif embed.type == "Action" then
		if embed.title and embed.title ~= "" then
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.new(1, 0, 0, 0); t.AutomaticSize = Enum.AutomaticSize.Y
			t.Text = embed.title; t.Font = tk("font")
			t.TextSize = d.text_size - 1; t.TextColor3 = tk("text")
			t.TextWrapped = true; t.TextXAlignment = Enum.TextXAlignment.Left
			t.LayoutOrder = iLo; iLo += 1; t.Parent = inner
		end
		local btnColor = (embed.style == "danger" and Color3.fromRGB(220, 60, 60))
			or (embed.style == "ghost" and Color3.fromRGB(70, 70, 75))
			or tk("accent")
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(140, 30)
		btn.BackgroundColor3 = btnColor
		btn.BorderSizePixel = 0
		btn.Text = embed.button_text or "Action"
		btn.Font = tk("font_bold")
		btn.TextSize = d.text_size - 2
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.LayoutOrder = iLo
		btn.ZIndex = 3
		btn.Parent = inner
		Skin.corner(btn, 6)
		btn.MouseButton1Click:Connect(function()
			Events.EmbedActionFired:Fire(embed.action_id, message)
		end)
	end

	return outer
end

-- ─── reply quote + reactions + tags ──────────────────────────────────────────

local function buildReplyBar(message: any, lo: number): Frame
	local ref = message.metadata.reply_to
	local outer = Instance.new("TextButton")
	outer.AutomaticSize = Enum.AutomaticSize.Y
	outer.Size = UDim2.new(1, 0, 0, 0)
	outer.BackgroundTransparency = 1
	outer.Text = ""
	outer.AutoButtonColor = false
	outer.LayoutOrder = lo
	outer.ZIndex = 3
	Skin.pad(outer, 8, 0, 0, 2)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 2, 1, -2)
	bar.BackgroundColor3 = tk("quote_bar")
	bar.BorderSizePixel = 0
	bar.Parent = outer

	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position = UDim2.fromOffset(8, 0)
	lbl.Size = UDim2.new(1, -8, 0, 0)
	lbl.AutomaticSize = Enum.AutomaticSize.Y
	lbl.Font = tk("font")
	lbl.TextSize = density().text_size - 3
	lbl.TextColor3 = tk("subtext")
	lbl.TextWrapped = true
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.RichText = true
	lbl.Text = ('<b>%s</b>  %s'):format(escape(ref.author_name or "?"), escape(ref.preview or ""))
	lbl.Parent = outer

	outer.MouseButton1Click:Connect(function()
		Events.ReplyClicked:Fire(ref.id, message)
		local target = _registry[ref.id]
		if target and _container then
			Motion.tween(_container, 0.25, { CanvasPosition = Vector2.new(0, target.row.AbsolutePosition.Y) })
		end
	end)

	return outer
end

local function buildReactions(message: any, lo: number): Frame?
	local reactions = message.reactions
	if not reactions or next(reactions) == nil then return nil end

	local row = Instance.new("Frame")
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.Size = UDim2.fromOffset(0, 0)
	row.BackgroundTransparency = 1
	row.LayoutOrder = lo
	local l = Skin.list(row, Enum.FillDirection.Horizontal, 4)
	l.Wraps = true

	local uid = LocalPlayer and LocalPlayer.UserId
	for emoji, data in reactions do
		local mine = uid and table.find(data.users, uid) ~= nil
		local pill = Instance.new("TextButton")
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.fromOffset(0, 20)
		pill.BackgroundColor3 = mine and tk("reaction_active") or tk("reaction_bg")
		pill.BackgroundTransparency = mine and 0.2 or 0.35
		pill.BorderSizePixel = 0
		pill.AutoButtonColor = true
		pill.Font = tk("font")
		pill.TextSize = density().text_size - 3
		pill.TextColor3 = tk("text")
		pill.Text = ("%s %d"):format(emoji, data.count)
		pill.ZIndex = 3
		pill.Parent = row
		Skin.corner(pill, 10)
		Skin.pad(pill, 6, 6, 0, 0)
		pill.MouseButton1Click:Connect(function()
			if Render.ReactHandler then Render.ReactHandler(message.metadata.id, emoji) end
		end)
	end

	return row
end

local function buildTags(message: any, lo: number): Frame
	local tagRow = Instance.new("Frame")
	tagRow.AutomaticSize = Enum.AutomaticSize.XY
	tagRow.Size = UDim2.fromOffset(0, 0)
	tagRow.BackgroundTransparency = 1
	tagRow.LayoutOrder = lo
	local l = Skin.list(tagRow, Enum.FillDirection.Horizontal, 4)
	l.Wraps = true

	for _, tag in message.tags do
		local pill = Instance.new("Frame")
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.fromOffset(0, 16)
		pill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		pill.BackgroundTransparency = 0.88
		pill.BorderSizePixel = 0
		pill.Parent = tagRow
		Skin.corner(pill, 4)
		Skin.pad(pill, 5, 5, 0, 0)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromOffset(0, 16)
		t.Text = tag; t.Font = tk("font")
		t.TextSize = density().text_size - 4; t.TextColor3 = tk("subtext")
		t.Parent = pill
	end

	return tagRow
end

-- ─── hover toolbar (react + reply) ───────────────────────────────────────────

local function buildToolbar(row: TextButton, message: any)
	local cfg = Config.Interface
	if not (cfg.reactions or cfg.reply_enabled) then return end

	local bar = Instance.new("Frame")
	bar.Name = "Toolbar"
	bar.AnchorPoint = Vector2.new(1, 0)
	bar.Position = UDim2.new(1, -2, 0, 2)
	bar.AutomaticSize = Enum.AutomaticSize.X
	bar.Size = UDim2.fromOffset(0, 22)
	bar.BackgroundColor3 = tk("reaction_bg")
	bar.BackgroundTransparency = 0.15
	bar.Visible = false
	bar.ZIndex = 20
	bar.Parent = row
	Skin.corner(bar, 6)
	Skin.pad(bar, 4, 4, 0, 0)
	local l = Skin.list(bar, Enum.FillDirection.Horizontal, 4)
	l.VerticalAlignment = Enum.VerticalAlignment.Center

	local function iconButton(glyph: string, order: number): TextButton
		local b = Instance.new("TextButton")
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, 18)
		b.BackgroundTransparency = 1
		b.Font = tk("font")
		b.TextSize = 14
		b.TextColor3 = tk("text")
		b.Text = glyph
		b.LayoutOrder = order
		b.ZIndex = 21
		b.Parent = bar
		return b
	end

	if cfg.reactions then
		local quick = iconButton("☺", 1)
		local picker: Frame? = nil
		quick.MouseButton1Click:Connect(function()
			if picker then picker:Destroy(); picker = nil; return end
			picker = Instance.new("Frame")
			picker.AnchorPoint = Vector2.new(1, 0)
			picker.Position = UDim2.new(1, 0, 1, 4)
			picker.AutomaticSize = Enum.AutomaticSize.X
			picker.Size = UDim2.fromOffset(0, 26)
			picker.BackgroundColor3 = tk("reaction_bg")
			picker.BackgroundTransparency = 0.1
			picker.ZIndex = 30
			picker.Parent = bar
			Skin.corner(picker, 8)
			Skin.pad(picker, 4, 4, 2, 2)
			local pl = Skin.list(picker, Enum.FillDirection.Horizontal, 2)
			pl.VerticalAlignment = Enum.VerticalAlignment.Center
			for i, emoji in (cfg.quick_reactions or {}) do
				local e = Instance.new("TextButton")
				e.AutomaticSize = Enum.AutomaticSize.X
				e.Size = UDim2.fromOffset(0, 22)
				e.BackgroundTransparency = 1
				e.Font = tk("font"); e.TextSize = 16; e.TextColor3 = tk("text")
				e.Text = emoji; e.LayoutOrder = i; e.ZIndex = 31; e.Parent = picker
				e.MouseButton1Click:Connect(function()
					if Render.ReactHandler then Render.ReactHandler(message.metadata.id, emoji) end
					if picker then picker:Destroy(); picker = nil end
				end)
			end
		end)
	end

	if cfg.reply_enabled then
		local reply = iconButton("↩", 2)
		reply.MouseButton1Click:Connect(function()
			if Render.ReplyHandler then Render.ReplyHandler(message) end
		end)
	end

	row.MouseEnter:Connect(function() bar.Visible = true end)
	row.MouseLeave:Connect(function() bar.Visible = false end)
end

-- ─── grouping + header ───────────────────────────────────────────────────────

local function shouldGroup(message: any): boolean
	if not Config.Interface.message_grouping then return false end
	local meta = message.metadata
	if not meta or not meta.author_id then return false end
	if meta.author_id ~= _lastAuthorId then return false end
	if (meta.timestamp or 0) - _lastAuthorTime > Config.Interface.grouping_window then return false end
	return true
end

local function headerParts(message: any, style: any, grouped: boolean): { string }
	local parts: { string } = {}
	local meta = message.metadata
	local cfg = Config.Interface
	local kind = message.kind or "chat"

	if cfg.show_timestamps and meta and meta.timestamp and meta.timestamp > 0 then
		table.insert(parts, ('<font color="%s">[%s]</font> '):format(rgb(tk("timestamp_text")), os.date("%H:%M", meta.timestamp)))
	end

	if grouped then return parts end

	local authorName = (meta and meta.author_name) or (meta and meta.source) or "System"
	if style.prefix then table.insert(parts, style.prefix) end

	if kind == "chat" then
		local color = Skin.authorColor(meta and meta.author_id, authorName, meta and meta.author_color)
		table.insert(parts, ('<font color="%s"><b>%s</b></font>: '):format(rgb(color), escape(authorName)))
	elseif kind == "me" then
		table.insert(parts, ('<i>%s</i> '):format(escape(authorName)))
	elseif style.bold then
		table.insert(parts, ('<b>%s</b> '):format(escape(authorName)))
	end

	return parts
end

-- ─── row builder ─────────────────────────────────────────────────────────────

local function buildRow(message: any, revealed: boolean, groupedOverride: boolean?): GuiObject
	local kind = message.kind or "chat"
	if Render.Renderers[kind] then
		return Render.Renderers[kind](message, Config.Interface.theme)
	end

	local cfg = Config.Interface
	local style = KIND_STYLE[kind] or KIND_STYLE.chat
	local override = KIND_OVERRIDE[kind]
	local d = density()
	local grouped = if groupedOverride ~= nil then groupedOverride else shouldGroup(message)
	_lastGrouped = grouped

	-- rows are Frames (Active = false) so plain messages don't sink clicks meant for
	-- game UI behind the panel; interactive messages get a hit overlay lower down.
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Size = UDim2.new(1, 0, 0, 0)
	row.Active = false
	row.BorderSizePixel = 0

	local bgKey = override and override.bg_key
	local cardBg = message.background -- optional per-message Color3
	local carded = false
	if bgKey then
		row.BackgroundColor3 = tk(bgKey)
		row.BackgroundTransparency = 0.75
	elseif cardBg then
		row.BackgroundColor3 = cardBg
		row.BackgroundTransparency = message.background_transparency or 0
	elseif cfg.message_background then
		row.BackgroundColor3 = tk("message_bg")
		row.BackgroundTransparency = tk("message_bg_transparency")
		carded = true
	else
		row.BackgroundColor3 = Color3.new(0, 0, 0)
		row.BackgroundTransparency = 1
	end

	Skin.corner(row, 4)
	Skin.pad(row, 6, 6, d.row_pad, d.row_pad)
	Skin.list(row, nil, 2)

	if carded then
		row.MouseEnter:Connect(function()
			row.BackgroundColor3 = tk("message_hover")
			row.BackgroundTransparency = tk("message_hover_transparency")
		end)
		row.MouseLeave:Connect(function()
			row.BackgroundColor3 = tk("message_bg")
			row.BackgroundTransparency = tk("message_bg_transparency")
		end)
	end

	local lo = 0

	if message.pinned then
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0, 2)
		bar.BackgroundColor3 = tk("pinned_indicator")
		bar.BorderSizePixel = 0
		bar.LayoutOrder = lo; lo += 1
		bar.Parent = row
	end

	if message.metadata.reply_to then
		buildReplyBar(message, lo).Parent = row; lo += 1
	end

	-- split elements into inline runs and block frames
	local elements = ensureElements(message)
	local style_text_key = (override and override.text_key) or style.text_key

	local blocks: { { kind: string, data: any } } = {}
	local cur: { any } = {}
	for _, el in elements do
		if el.type == "panel" or el.type == "blockquote" then
			if #cur > 0 then table.insert(blocks, { kind = "inline", data = cur }); cur = {} end
			table.insert(blocks, { kind = "block", data = el })
		else
			table.insert(cur, el)
		end
	end
	if #cur > 0 then table.insert(blocks, { kind = "inline", data = cur }) end

	local hParts = headerParts(message, style, grouped)
	local headerUsed = false
	local ctx: InlineCtx = { mentions = {}, links = {}, hasSpoiler = false }

	local function inlineLabel(rich: string)
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.new(1, 0, 0, 0)
		lbl.AutomaticSize = Enum.AutomaticSize.Y
		lbl.Font = tk("font")
		lbl.TextSize = d.text_size
		lbl.TextColor3 = tk(style_text_key)
		lbl.TextWrapped = true
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextYAlignment = Enum.TextYAlignment.Top
		lbl.RichText = true
		lbl.Text = rich
		lbl.LayoutOrder = lo; lo += 1
		lbl.Parent = row
	end

	for _, block in blocks do
		if block.kind == "inline" then
			local prefix = ""
			if not headerUsed then prefix = table.concat(hParts); headerUsed = true end
			local rich = inlineRich(block.data, revealed, ctx)
			for _, decorate in Render.LineDecorators do
				local extra = decorate(message)
				if extra then rich ..= " " .. extra end
			end
			if prefix ~= "" or rich ~= "" then inlineLabel(prefix .. rich) end
		else
			local el = block.data
			if el.type == "blockquote" then
				buildBlockquote(el, lo).Parent = row; lo += 1
			elseif el.type == "panel" then
				buildPanel(el, message, lo).Parent = row; lo += 1
			end
		end
	end

	-- header-only line when there is no inline content (e.g. embed/panel only)
	if not headerUsed and #hParts > 0 then
		inlineLabel(table.concat(hParts))
	end

	-- interactive overlay ONLY when there's something to click (spoilers/mentions/
	-- links); otherwise the row stays a click-through Frame. Interactive children
	-- below (reactions, reply bar, embed buttons, toolbar) sit above it via ZIndex.
	if ctx.hasSpoiler or #ctx.mentions > 0 or #ctx.links > 0 then
		local hit = Instance.new("TextButton")
		hit.Name = "Hit"
		hit.Size = UDim2.new(1, 0, 1, 0)
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.AutoButtonColor = false
		hit.ZIndex = 2
		hit.Parent = row
		hit.MouseButton1Click:Connect(function()
			Events.CardClicked:Fire(message, row)
			for _, m in ctx.mentions do
				Events.MentionClicked:Fire(m.mention_id or 0, m.mention_name or "", message)
			end
			for _, url in ctx.links do
				Events.LinkClicked:Fire(url, message)
			end
			if ctx.hasSpoiler then
				local entry = _registry[message.metadata.id]
				if entry then
					entry.revealed = not entry.revealed
					Render.RebuildRow(message.metadata.id)
					Events.SpoilerRevealed:Fire(message)
				end
			end
		end)
	end

	if message.tags and #message.tags > 0 then
		buildTags(message, lo).Parent = row; lo += 1
	end

	if message.content and message.content.embeds then
		for _, embed in message.content.embeds do
			local ef = buildEmbed(embed, lo)
			if ef then ef.Parent = row; lo += 1 end
		end
	end

	local reactionRow = buildReactions(message, lo)
	if reactionRow then reactionRow.Parent = row; lo += 1 end

	buildToolbar(row, message)

	-- self-mention highlight
	local meta = message.metadata
	if meta.mentions and LocalPlayer and table.find(meta.mentions, LocalPlayer.UserId) then
		local accent = Instance.new("Frame")
		accent.Size = UDim2.new(0, 2, 1, 0)
		accent.BackgroundColor3 = tk("mention_self_bg")
		accent.BorderSizePixel = 0
		accent.ZIndex = 2
		accent.Parent = row
		local overlay = Instance.new("Frame")
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.BackgroundColor3 = tk("mention_self_bg")
		overlay.BackgroundTransparency = 1
		overlay.BorderSizePixel = 0
		overlay.ZIndex = 1
		overlay.Parent = row
		Skin.corner(overlay, 4)
		Motion.FlashCard(overlay)
		Events.Mentioned:Fire(message)
	end

	if meta and groupedOverride == nil then
		_lastAuthorId = meta.author_id
		_lastAuthorTime = meta.timestamp or os.time()
	end

	return row
end

-- ─── list management ─────────────────────────────────────────────────────────

local function nearBottom(): boolean
	if not _container then return true end
	local remaining = _container.AbsoluteCanvasSize.Y - _container.CanvasPosition.Y - _container.AbsoluteWindowSize.Y
	return remaining <= 60
end

local function trim()
	if not _container then return end
	local excess = #_rendered - Config.Interface.max_messages
	for _ = 1, excess do
		local id = table.remove(_rendered, 1)
		local entry = id and _registry[id]
		if entry then
			if entry.row.Parent then entry.row:Destroy() end
			_registry[id] = nil
		end
	end
end

-- rebuild a card in place (spoiler reveal, edits, reaction changes)
function Render.RebuildRow(id: string)
	local entry = _registry[id]
	if not entry or not _container then return end
	local old = entry.row
	local order = entry.order
	-- reuse the original grouping decision so a rebuild can't drop the header
	local newRow = buildRow(entry.message, entry.revealed, entry.grouped)
	newRow.LayoutOrder = order
	newRow.Parent = _container
	entry.row = newRow
	if old.Parent then old:Destroy() end
end

function Render.Render(message: any): GuiObject?
	if not _container then return nil end

	local stick = nearBottom()
	_seq += 1

	local ok, result = pcall(buildRow, message, false)
	if not ok then
		warn("[Bold.Render] row build failed:", result)
		return nil
	end
	local row: GuiObject = result
	row.LayoutOrder = _seq

	local id = message.metadata and message.metadata.id
	if id then
		_registry[id] = { message = message, row = row, order = _seq, revealed = false, grouped = _lastGrouped }
		table.insert(_rendered, id)
	end

	row.Parent = _container
	Motion.RowIn(row)
	Motion.FadeOld(row)
	row.MouseEnter:Connect(function() Motion.Wake(row) end)

	trim()
	if stick then Motion.ScrollToBottom(_container, true) end

	Events.MessageRendered:Fire(message, row)
	return row
end

function Render.ApplyUpdate(id: string, patch: any)
	local entry = _registry[id]
	if not entry then return end
	local msg = entry.message

	if patch.text ~= nil then
		msg.content.raw_text = patch.text
		msg.content.elements = nil
		if patch.edited then msg.metadata.edited = true end
	end
	if patch.reactions ~= nil then
		msg.reactions = patch.reactions
	end

	Render.RebuildRow(id)
end

function Render.Clear()
	if not _container then return end
	for _, c in _container:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	table.clear(_registry)
	table.clear(_rendered)
	_lastAuthorId = nil
	_lastAuthorTime = 0
end

function Render.SystemMessage(text: string)
	Render.Render({
		metadata = { id = "sys_" .. tostring(_seq + 1), source = "System", timestamp = os.time() },
		content = { raw_text = text, elements = {} },
		kind = "system",
	})
end

-- ─── registries ──────────────────────────────────────────────────────────────

function Render.RegisterRenderer(kind: string, fn: (any, any) -> Frame)
	Render.Renderers[kind] = fn
end

function Render.RegisterPanel(name: string, fn: (any, any, any) -> Frame)
	Render.Panels[name] = fn
end

function Render.RegisterLineDecorator(fn: (any) -> string?)
	table.insert(Render.LineDecorators, fn)
end

function Render.SetKindStyle(kind: string, textKey: string, prefix: string?, bold: boolean?)
	KIND_STYLE[kind] = { text_key = textKey, prefix = prefix, bold = bold }
end

function Render.SetKindOverride(kind: string, bgKey: string, textKey: string)
	KIND_OVERRIDE[kind] = { bg_key = bgKey, text_key = textKey }
end

return Render
