local Types = {}

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

export type ElementType = "text" | "mention" | "emoji_unicode" | "emoji_custom" | "code"

export type Element = {
	type: ElementType,
	content: string,
	formatting: TextFormatting?,
	data: {
		mention_name: string?,
		mention_id: number?,
		emoji_name: string?,
		emoji_asset: string?,
	}?,
}

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
	title: string,
	action_id: string,
	button_text: string,
	style: ("primary" | "danger" | "ghost")?,
}

export type Embed = ImageEmbed | GifEmbed | StickerEmbed | RichTextEmbed | ActionEmbed

export type MessageKind = "chat" | "system" | "announcement" | "whisper" | "team" | string

export type MessageMetadata = {
	id: string,
	source: string,
	timestamp: number,
	author_id: number?,
	author_name: string?,
	author_color: Color3?,
	recipient_id: number?,
	channel: string?,
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
}

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
	code_bg: Color3?,
	code_text: Color3?,
	link_text: Color3?,

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

export type InterfaceConfig = {
	theme: Theme?,
	density: LayoutDensity?,
	window_size: UDim2?,
	window_position: UDim2?,
	window_anchor: Vector2?,
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
}

export type BoldConfig = {
	interface: InterfaceConfig?,
	parsing: {
		enabled: boolean?,
		markdown: boolean?,
		mentions: boolean?,
		emoji: boolean?,
		filter: boolean?,
	}?,
}

export type ImageAsset = {
	Name: string,
	AssetId: number,
	AssetVersionId: number,
	CreatorName: string,
}

return Types