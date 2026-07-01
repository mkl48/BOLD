-- Bold
-- Types
-- Plinko Labs

local Types = {}

-- ─── Inline formatting ───────────────────────────────────────────────────────

export type TextFormatting = {
	font: Enum.Font?,
	text_size: number?,
	italic: boolean?,
	bold: boolean?,
	underline: boolean?,
	strikethrough: boolean?,
	color: Color3?,
	code: boolean?,
}

export type ElementType =
	"text"
	| "mention"
	| "emoji_unicode"
	| "emoji_custom"
	| "code"
	| "spoiler"
	| "color"
	| "link"
	| "blockquote"
	| "header"
	| "panel"

export type Element = {
	type: ElementType,
	content: string,
	formatting: TextFormatting?,
	data: {
		mention_name: string?,
		mention_id: number?,
		emoji_name: string?,
		emoji_asset: string?,
		link_url: string?,
		color: Color3?,
		level: number?, -- header level (1-3)
		-- panel elements
		panel_name: string?,
		panel_args: { [string]: any }?,
		panel_body: string?,
	}?,
}

-- ─── Embeds ──────────────────────────────────────────────────────────────────

export type BaseEmbed = {
	color: Color3?,
	timestamp: number?,
}

export type ImageEmbed = BaseEmbed & {
	type: "Image",
	image_id: string,
	aspect_ratio: number?,
	caption: string?,
}

export type GifEmbed = BaseEmbed & {
	type: "Gif",
	video_id: string,
	loop: boolean?,
	autoplay: boolean?,
}

export type StickerEmbed = BaseEmbed & {
	type: "Sticker",
	sticker_id: string,
	size: number?,
}

export type RichTextEmbed = BaseEmbed & {
	type: "RichText",
	title: string,
	description: string?,
	thumbnail: string?,
	fields: { { name: string, value: string, inline: boolean? } }?,
}

export type ActionEmbed = BaseEmbed & {
	type: "Action",
	title: string?,
	action_id: string,
	button_text: string,
	style: ("primary" | "danger" | "ghost")?,
}

export type ButtonSpec = {
	text: string,
	action_id: string,
	style: ("primary" | "danger" | "ghost")?,
}

export type ButtonsEmbed = BaseEmbed & {
	type: "Buttons",
	title: string?,
	buttons: { ButtonSpec },
}

export type ProgressEmbed = BaseEmbed & {
	type: "Progress",
	value: number, -- 0..1
	label: string?,
}

export type Embed = ImageEmbed | GifEmbed | StickerEmbed | RichTextEmbed | ActionEmbed | ButtonsEmbed | ProgressEmbed

-- ─── Message ─────────────────────────────────────────────────────────────────

export type MessageKind = "chat" | "system" | "announcement" | "whisper" | "team" | string

export type ReplyRef = {
	id: string,
	author_name: string?,
	preview: string?,
}

export type Reaction = {
	count: number,
	users: { number },
}

export type MessageMetadata = {
	id: string,
	source: string,
	timestamp: number,
	author_id: number?,
	author_name: string?,
	author_color: Color3?,
	recipient_id: number?,
	channel: string?,
	-- userIds resolved from @mentions in the (filtered) text, set server-side
	mentions: { number }?,
	reply_to: ReplyRef?,
	edited: boolean?,
}

export type MessageClass = {
	metadata: MessageMetadata,
	content: {
		raw_text: string?,
		elements: { Element },
		embeds: { Embed }?,
	},
	kind: MessageKind?,
	tags: { string }?,
	pinned: boolean?,
	filtered: boolean?,
	-- emoji -> tally, kept authoritative on the server
	reactions: { [string]: Reaction }?,
	-- optional custom card background for this one message
	background: Color3?,
	background_transparency: number?,
}

-- ─── Theme ───────────────────────────────────────────────────────────────────

export type Theme = {
	-- surfaces
	background: Color3?,
	background_transparency: number?,
	header: Color3?,
	header_transparency: number?,
	input_bg: Color3?,
	input_transparency: number?,

	-- text
	text: Color3?,
	subtext: Color3?,
	timestamp_text: Color3?,
	placeholder_text: Color3?,

	-- name colors (cycled per-author when no explicit color is given)
	name_palette: { Color3 }?,

	-- accents
	accent: Color3?,
	mention_bg: Color3?,
	mention_text: Color3?,
	mention_self_bg: Color3?,
	code_bg: Color3?,
	code_text: Color3?,
	link_text: Color3?,
	spoiler_bg: Color3?,
	spoiler_text: Color3?,
	quote_bar: Color3?,
	quote_text: Color3?,
	reaction_bg: Color3?,
	reaction_active: Color3?,
	message_bg: Color3?,
	message_bg_transparency: number?,
	message_hover: Color3?,
	message_hover_transparency: number?,

	-- autocomplete popup
	autocomplete_bg: Color3?,
	autocomplete_hover: Color3?,
	autocomplete_border: Color3?,

	-- semantic kinds
	system_text: Color3?,
	announcement_bg: Color3?,
	announcement_text: Color3?,
	whisper_text: Color3?,
	team_text: Color3?,
	error_text: Color3?,

	pinned_indicator: Color3?,

	-- typography + shape
	font: Enum.Font?,
	font_bold: Enum.Font?,
	text_size: number?,
	corner_radius: number?,

	-- fade behavior (default Roblox chat dims old messages, fully hides after a timeout)
	fade_enabled: boolean?,
	fade_after: number?,
	hide_after: number?,
}

export type LayoutDensity = "compact" | "cozy" | "comfortable"

-- ─── Config sections ─────────────────────────────────────────────────────────

export type ParsingConfig = {
	enabled: boolean?,
	markdown: boolean?,
	mentions: boolean?,
	emoji: boolean?,
	panels: boolean?,
	links: boolean?,
	filter: boolean?,
}

export type FilterConfig = {
	enabled: boolean?,
	-- run PurgoMalum as a deferred, non-blocking refinement after delivery
	purgomalum: boolean?,
	-- client-side hard-block backstop at render time
	client_backstop: boolean?,
}

export type KeysConfig = {
	-- KeyCodes; set false to disable a bind entirely
	focus: (Enum.KeyCode | false)?,
	toggle: (Enum.KeyCode | false)?,
	accept: { Enum.KeyCode }?,
	up: { Enum.KeyCode }?,
	down: { Enum.KeyCode }?,
	close: { Enum.KeyCode }?,
	use_switch: boolean?,
}

export type AnimationConfig = {
	enabled: boolean?,
	in_style: ("slide" | "fade" | "none")?,
	in_time: number?,
	stagger: number?,
	flash_time: number?,
	reveal_time: number?,
	smooth_scroll: boolean?,
}

export type SoundConfig = {
	enabled: boolean?,
	message: string?,
	mention: string?,
	send: string?,
	volume: number?,
}

export type InterfaceConfig = {
	theme: Theme?,
	density: LayoutDensity?,
	window_size: UDim2?,
	window_position: UDim2?,
	window_anchor: Vector2?,
	min_list_height: number?,
	max_list_height: number?,
	header_height: number?,
	input_height: number?,
	max_messages: number?,
	visible: boolean?,
	show_header: boolean?,
	show_input: boolean?,
	show_timestamps: boolean?,
	show_scrollbar: boolean?,
	channel_name: string?,
	animate_in: boolean?,
	draggable: boolean?,
	resizable: boolean?,
	message_grouping: boolean?,
	grouping_window: number?,
	reactions: boolean?,
	reply_enabled: boolean?,
	quick_reactions: { string }?,
	backdrop: boolean?,
	message_background: boolean?,
	collapsible: boolean?,
	collapse_lines: number?,
	open_animation: boolean?,
	show_friend_badge: boolean?,
	show_blocked: boolean?,
}

export type BoldConfig = {
	interface: InterfaceConfig?,
	parsing: ParsingConfig?,
	filter: FilterConfig?,
	keys: KeysConfig?,
	animation: AnimationConfig?,
	sounds: SoundConfig?,
}

-- ─── Misc ────────────────────────────────────────────────────────────────────

export type ImageAsset = {
	Name: string,
	AssetId: number,
	AssetVersionId: number,
	CreatorName: string,
}

export type CommandSpec = {
	description: string?,
	args: string?,
	-- when true, the first argument autocompletes to players (e.g. /incog, /ignore)
	player_arg: boolean?,
	-- handler runs on the client; return a compose payload to send, or nil for a
	-- purely local command. ctx exposes { args, rest, raw, localPlayer, actions }.
	handler: (ctx: any) -> any?,
	server: boolean?,
}

return Types
