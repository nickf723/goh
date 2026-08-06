extends RefCounted
class_name SpellIconFactory

# Temporary icon bridge. It will import authored PNG/SVG textures when they are
# present, while every existing spell still receives a readable flat badge from
# its spell metadata today.

const ELEMENT_COLORS: Dictionary = {
	"neutral": Color(0.46, 0.54, 0.68, 1.0),
	"water": Color(0.16, 0.48, 0.95, 1.0),
	"earth": Color(0.42, 0.78, 0.24, 1.0),
	"fire": Color(1.0, 0.28, 0.08, 1.0),
	"air": Color(0.95, 0.48, 0.72, 1.0),
	"ice": Color(0.5, 0.9, 1.0, 1.0),
	"metal": Color(0.96, 0.78, 0.18, 1.0),
	"lightning": Color(0.28, 0.46, 1.0, 1.0),
	"poison": Color(0.48, 0.92, 0.22, 1.0),
	"life": Color(0.1, 0.92, 0.5, 1.0),
	"death": Color(0.82, 0.08, 0.08, 1.0),
	"body": Color(0.92, 0.22, 0.72, 1.0),
	"soul": Color(0.1, 0.86, 0.92, 1.0),
	"dreams": Color(0.18, 0.28, 0.9, 1.0),
	"sound": Color(1.0, 0.52, 0.08, 1.0),
	"space": Color(0.58, 0.22, 1.0, 1.0),
	"time": Color(0.98, 0.66, 0.16, 1.0),
	"light": Color(1.0, 0.94, 0.62, 1.0),
	"darkness": Color(0.28, 0.2, 0.42, 1.0),
	"void": Color(0.5, 0.52, 0.58, 1.0),
}

const ELEMENT_GLYPHS: Dictionary = {
	"neutral": "✦",
	"water": "≋",
	"earth": "◆",
	"fire": "✹",
	"air": "↝",
	"ice": "❄",
	"metal": "⬡",
	"lightning": "ϟ",
	"poison": "☣",
	"life": "✤",
	"death": "☠",
	"body": "✺",
	"soul": "◎",
	"dreams": "☾",
	"sound": "◉",
	"space": "◇",
	"time": "⌛",
	"light": "✧",
	"darkness": "◐",
	"void": "○",
}

const SPELL_GLYPHS: Dictionary = {
	"firebolt": "✦",
	"fire_field": "▱",
	"flamethrower": "♨",
	"water_jet": "≋",
	"wave": "≈",
	"earth_spike": "▲",
	"gust": "↝",
	"wind_gust": "↝",
	"wind_well": "↑",
	"ice_lance": "△",
	"metal_tether": "⌁",
	"lightning_arc": "ϟ",
	"lightning_spark": "ϟ",
	"lightning_bolt": "↯",
	"poison_cloud": "☁",
	"life_thorn": "✣",
	"death_hex": "⌁",
	"body_burst": "✹",
	"soul_grip": "◎",
	"soul_thread": "⌇",
	"dream_snare": "☾",
	"sound_pulse": "◉",
	"space_blink": "◇",
	"time_snare": "⌛",
	"spectral_familiar": "♢",
	"recorded_object_summon": "▣",
	"artificer_assembly": "⚙",
	"deploy_contraption": "▰",
}

const FLAT_ICON_ROOTS: Array[String] = [
	"res://art/icons/spells/",
	"res://art/icons/flaticons/",
	"res://art/flaticons/",
	"res://assets/icons/spells/",
	"res://assets/icons/flaticons/",
	"res://assets/flaticons/",
	"res://icons/spells/",
]
const FLAT_ICON_EXTENSIONS: Array[String] = [".svg", ".png", ".webp"]

static var texture_cache: Dictionary = {}


static func entry_from_ability(
	ability: AbilityDefinition,
	global_index: int = -1,
	equipped: bool = false
) -> Dictionary:
	if ability == null:
		return {
			"name": "Empty",
			"spell_id": "",
			"element": "neutral",
			"icon_text": "·",
			"icon_path": "",
			"global_index": global_index,
			"equipped": equipped,
		}
	return {
		"name": ability.display_name,
		"spell_id": ability.get_spell_id(),
		"element": ability.element,
		"icon_text": ability.icon_text,
		"icon_path": _find_texture_path(ability.get_spell_id()),
		"global_index": global_index,
		"equipped": equipped,
	}


static func normalize_entry(
	value: Variant,
	fallback_element: String = "neutral"
) -> Dictionary:
	if value is AbilityDefinition:
		return entry_from_ability(value as AbilityDefinition)
	if value is Dictionary:
		var entry: Dictionary = (value as Dictionary).duplicate(true)
		entry["name"] = str(entry.get("name", entry.get("label", "Spell")))
		entry["spell_id"] = str(entry.get("spell_id", entry.get("id", "")))
		entry["element"] = str(entry.get("element", fallback_element))
		entry["icon_text"] = str(entry.get("icon_text", ""))
		entry["icon_path"] = str(entry.get("icon_path", ""))
		if str(entry.get("icon_path", "")) == "":
			entry["icon_path"] = _find_texture_path(str(entry.get("spell_id", "")))
		return entry
	return {
		"name": str(value),
		"spell_id": str(value).to_lower().replace(" ", "_"),
		"element": fallback_element,
		"icon_text": "",
		"icon_path": "",
		"global_index": -1,
		"equipped": false,
	}


static func create_badge(
	raw_entry: Variant,
	size: float = 34.0,
	highlighted: bool = false,
	equipped: bool = false
) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "SpellIconBadge"
	badge.custom_minimum_size = Vector2(size, size)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var holder := Control.new()
	holder.name = "IconHolder"
	holder.custom_minimum_size = Vector2(size, size)
	badge.add_child(holder)

	var texture_rect := TextureRect.new()
	texture_rect.name = "IconTexture"
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(texture_rect)

	var glyph := Label.new()
	glyph.name = "IconGlyph"
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", maxi(int(size * 0.52), 12))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(glyph)

	update_badge(badge, raw_entry, highlighted, equipped)
	return badge


static func update_badge(
	badge: PanelContainer,
	raw_entry: Variant,
	highlighted: bool = false,
	equipped: bool = false
) -> void:
	if badge == null:
		return
	var entry: Dictionary = normalize_entry(raw_entry)
	var element_color: Color = get_element_color(str(entry.get("element", "neutral")))
	var border_color: Color = Color(
		element_color.r,
		element_color.g,
		element_color.b,
		0.84
	)
	var border_width: int = 1
	if highlighted:
		border_color = Color(0.94, 0.98, 1.0, 1.0)
		border_width = 2
	if equipped:
		border_color = Color(1.0, 0.72, 0.22, 1.0)
		border_width = 3
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		element_color.r * 0.2,
		element_color.g * 0.2,
		element_color.b * 0.2,
		0.96
	)
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(9)
	badge.add_theme_stylebox_override("panel", style)

	var texture_rect: TextureRect = badge.get_node_or_null(
		"IconHolder/IconTexture"
	) as TextureRect
	var glyph_label: Label = badge.get_node_or_null(
		"IconHolder/IconGlyph"
	) as Label
	var texture: Texture2D = resolve_texture(entry)
	if texture_rect != null:
		texture_rect.texture = texture
		texture_rect.visible = texture != null
		texture_rect.modulate = Color.WHITE
	if glyph_label != null:
		glyph_label.text = get_glyph(entry)
		glyph_label.visible = texture == null
		glyph_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.9, 0.6, 1.0)
			if equipped
			else Color(0.94, 0.97, 1.0, 1.0)
		)
	badge.tooltip_text = str(entry.get("name", "Spell"))
	badge.set_meta("spell_icon_entry", entry)
	badge.set_meta("spell_icon_has_texture", texture != null)
	badge.set_meta("spell_icon_equipped", equipped)


static func resolve_texture(raw_entry: Variant) -> Texture2D:
	var entry: Dictionary = normalize_entry(raw_entry)
	var path: String = str(entry.get("icon_path", ""))
	if path == "":
		path = _find_texture_path(str(entry.get("spell_id", "")))
	if path == "":
		return null
	if texture_cache.has(path):
		return texture_cache[path] as Texture2D
	var loaded: Resource = load(path)
	var texture: Texture2D = loaded as Texture2D
	texture_cache[path] = texture
	return texture


static func get_glyph(raw_entry: Variant) -> String:
	var entry: Dictionary = normalize_entry(raw_entry)
	var spell_id: String = str(entry.get("spell_id", ""))
	if SPELL_GLYPHS.has(spell_id):
		return str(SPELL_GLYPHS[spell_id])
	var icon_text: String = str(entry.get("icon_text", "")).strip_edges()
	if icon_text.length() > 1:
		return icon_text.left(2)
	var element: String = str(entry.get("element", "neutral"))
	if ELEMENT_GLYPHS.has(element):
		return str(ELEMENT_GLYPHS[element])
	if icon_text != "":
		return icon_text
	var name: String = str(entry.get("name", "Spell"))
	return name.left(1).to_upper() if name != "" else "·"


static func get_element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, ELEMENT_COLORS["neutral"]) as Color


static func _find_texture_path(spell_id: String) -> String:
	var normalized: String = spell_id.strip_edges().to_lower()
	if normalized == "":
		return ""
	for root: String in FLAT_ICON_ROOTS:
		for extension: String in FLAT_ICON_EXTENSIONS:
			var candidate: String = root + normalized + extension
			if ResourceLoader.exists(candidate):
				return candidate
	return ""


static func get_debug_descriptor(raw_entry: Variant) -> Dictionary:
	var entry: Dictionary = normalize_entry(raw_entry)
	return {
		"name": str(entry.get("name", "Spell")),
		"spell_id": str(entry.get("spell_id", "")),
		"element": str(entry.get("element", "neutral")),
		"glyph": get_glyph(entry),
		"icon_path": str(entry.get("icon_path", "")),
		"texture_loaded": resolve_texture(entry) != null,
	}
