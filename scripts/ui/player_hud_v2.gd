extends CanvasLayer
class_name PlayerHUDV2


const PortraitMedallionScript = preload("res://scripts/ui/portrait_medallion.gd")
const GameplayEffectAccessScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)

@export_range(0.03, 0.5, 0.01) var refresh_interval: float = 0.08
@export var suppress_legacy_hud: bool = true
@export var show_control_hints: bool = true

var actor: CharacterBody3D
var action_state: PlayerActionState
var ability_caster: Node
var quick_item_controller: PlayerQuickItemController
var control_router: Node
var divine_controller: PlayerDivineSpecialController
var weapon_controller: WeaponController
var avatar_manager: Node
var status_receiver: PlayerStatusReceiver

var root: Control
var stats_panel: PanelContainer
var avatar_title_label: Label
var loadout_label: Label
var base_stats_label: Label
var stat_rows: Dictionary = {}

var quick_panel: PanelContainer
var quick_spell_panels: Array[PanelContainer] = []
var quick_spell_labels: Array[Label] = []
var quick_spell_detail_label: Label
var quick_item_label: Label
var divine_special_label: Label
var divine_charge_bar: ProgressBar
var divine_charge_label: Label
var quick_hint_label: Label

var portrait: PortraitMedallion
var portrait_name_label: Label
var portrait_state_label: Label
var status_stack: VBoxContainer
var status_rows: Array[PanelContainer] = []
var status_icon_labels: Array[Label] = []
var status_name_labels: Array[Label] = []
var status_timer_labels: Array[Label] = []

var dialogue_panel: PanelContainer
var npc_portrait: PortraitMedallion
var dialogue_speaker_label: Label
var dialogue_title_label: Label
var dialogue_body_label: RichTextLabel
var dialogue_choice_label: Label
var active_conversation: Node

var refresh_remaining: float = 0.0
var last_expression: String = "neutral"


func _ready() -> void:
	layer = 29
	process_mode = Node.PROCESS_MODE_ALWAYS
	actor = get_parent() as CharacterBody3D
	_build_hud()
	_resolve_bindings()
	call_deferred("_finish_setup")
	add_to_group("player_hud_v2")


func _finish_setup() -> void:
	_resolve_bindings()
	_suppress_legacy_hud()
	refresh_data(true)


func _process(delta: float) -> void:
	refresh_remaining = maxf(refresh_remaining - maxf(delta, 0.0), 0.0)
	if refresh_remaining > 0.0:
		return
	refresh_remaining = maxf(refresh_interval, 0.03)
	_resolve_bindings()
	_suppress_legacy_hud()
	refresh_data()


func refresh_data(_force: bool = false) -> void:
	_refresh_stats()
	_refresh_quick_loadout()
	_refresh_statuses_and_portrait()
	_refresh_dialogue()


func _build_hud() -> void:
	root = Control.new()
	root.name = "PlayerHUDV2Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_stats_panel()
	_build_quick_panel()
	_build_portrait_and_statuses()
	_build_dialogue_panel()


func _build_stats_panel() -> void:
	stats_panel = PanelContainer.new()
	stats_panel.name = "TopLeftStatsPanel"
	stats_panel.offset_left = 20.0
	stats_panel.offset_top = 20.0
	stats_panel.offset_right = 472.0
	stats_panel.offset_bottom = 242.0
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.012, 0.017, 0.027, 0.9),
			Color(0.9, 0.58, 0.18, 0.58),
			16,
			2
		)
	)
	root.add_child(stats_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	stats_panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	avatar_title_label = Label.new()
	avatar_title_label.text = "GRACE"
	avatar_title_label.add_theme_font_size_override("font_size", 17)
	avatar_title_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.78, 0.34, 1.0)
	)
	stack.add_child(avatar_title_label)

	loadout_label = Label.new()
	loadout_label.text = "Weapon: Practice Sword  •  Spell: Firebolt"
	loadout_label.add_theme_font_size_override("font_size", 11)
	loadout_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.79, 0.9, 0.92)
	)
	stack.add_child(loadout_label)

	var divider: HSeparator = HSeparator.new()
	stack.add_child(divider)

	_create_stat_row(
		stack,
		"health",
		"♥",
		"HEALTH",
		Color(0.94, 0.18, 0.27, 1.0)
	)
	_create_stat_row(
		stack,
		"mana",
		"◆",
		"MANA",
		Color(0.18, 0.58, 1.0, 1.0)
	)
	_create_stat_row(
		stack,
		"stamina",
		"✦",
		"STAMINA",
		Color(0.31, 0.82, 0.4, 1.0)
	)
	_create_stat_row(
		stack,
		"stance",
		"◇",
		"STANCE",
		Color(0.96, 0.71, 0.18, 1.0)
	)

	base_stats_label = Label.new()
	base_stats_label.text = "FOCUS 5   POWER 1   ARCANA 1"
	base_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	base_stats_label.add_theme_font_size_override("font_size", 10)
	base_stats_label.add_theme_color_override(
		"font_color",
		Color(0.64, 0.71, 0.82, 0.82)
	)
	stack.add_child(base_stats_label)


func _create_stat_row(
	parent: VBoxContainer,
	stat_id: String,
	icon: String,
	title: String,
	color: Color
) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 24.0)
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)

	var icon_label: Label = Label.new()
	icon_label.text = icon
	icon_label.custom_minimum_size = Vector2(20.0, 0.0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 14)
	icon_label.add_theme_color_override("font_color", color)
	row.add_child(icon_label)

	var title_label: Label = Label.new()
	title_label.text = title
	title_label.custom_minimum_size = Vector2(68.0, 0.0)
	title_label.add_theme_font_size_override("font_size", 10)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.87, 0.94, 0.92)
	)
	row.add_child(title_label)

	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0.0, 11.0)
	bar.add_theme_stylebox_override(
		"background",
		_make_bar_style(Color(0.045, 0.052, 0.07, 0.94), 6)
	)
	bar.add_theme_stylebox_override("fill", _make_bar_style(color, 6))
	row.add_child(bar)

	var value_label: Label = Label.new()
	value_label.text = "0 / 0"
	value_label.custom_minimum_size = Vector2(62.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.95, 1.0, 0.96)
	)
	row.add_child(value_label)

	stat_rows[stat_id] = {
		"bar": bar,
		"value": value_label,
	}


func _build_quick_panel() -> void:
	quick_panel = PanelContainer.new()
	quick_panel.name = "BottomLeftQuickPanel"
	quick_panel.anchor_top = 1.0
	quick_panel.anchor_bottom = 1.0
	quick_panel.offset_left = 20.0
	quick_panel.offset_top = -300.0
	quick_panel.offset_right = 532.0
	quick_panel.offset_bottom = -20.0
	quick_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quick_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.012, 0.017, 0.027, 0.91),
			Color(0.42, 0.61, 0.92, 0.54),
			18,
			2
		)
	)
	root.add_child(quick_panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	quick_panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	var heading: Label = Label.new()
	heading.text = "QUICK SPELLS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 11)
	heading.add_theme_color_override(
		"font_color",
		Color(0.73, 0.82, 1.0, 0.92)
	)
	stack.add_child(heading)

	var spell_row: HBoxContainer = HBoxContainer.new()
	spell_row.alignment = BoxContainer.ALIGNMENT_CENTER
	spell_row.add_theme_constant_override("separation", 7)
	stack.add_child(spell_row)

	var previous_label: Label = Label.new()
	previous_label.text = "◀"
	previous_label.add_theme_font_size_override("font_size", 18)
	previous_label.add_theme_color_override(
		"font_color",
		Color(0.55, 0.7, 1.0, 0.9)
	)
	spell_row.add_child(previous_label)

	for index: int in range(3):
		var slot_panel: PanelContainer = PanelContainer.new()
		slot_panel.custom_minimum_size = Vector2(126.0, 48.0)
		slot_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(
				Color(0.035, 0.045, 0.067, 0.94),
				Color(0.25, 0.35, 0.53, 0.72),
				10,
				1
			)
		)
		spell_row.add_child(slot_panel)
		quick_spell_panels.append(slot_panel)

		var slot_label: Label = Label.new()
		slot_label.text = "Empty"
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		slot_label.add_theme_font_size_override("font_size", 11)
		slot_label.add_theme_color_override(
			"font_color",
			Color(0.75, 0.82, 0.92, 0.9)
		)
		slot_panel.add_child(slot_label)
		quick_spell_labels.append(slot_label)

	var next_label: Label = Label.new()
	next_label.text = "▶"
	next_label.add_theme_font_size_override("font_size", 18)
	next_label.add_theme_color_override(
		"font_color",
		Color(0.55, 0.7, 1.0, 0.9)
	)
	spell_row.add_child(next_label)

	quick_spell_detail_label = Label.new()
	quick_spell_detail_label.text = "FIREBOLT  •  ZL CAST"
	quick_spell_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_spell_detail_label.add_theme_font_size_override("font_size", 12)
	quick_spell_detail_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.74, 0.28, 1.0)
	)
	stack.add_child(quick_spell_detail_label)

	var divider: HSeparator = HSeparator.new()
	stack.add_child(divider)

	var lower_row: HBoxContainer = HBoxContainer.new()
	lower_row.add_theme_constant_override("separation", 12)
	stack.add_child(lower_row)

	var item_panel: PanelContainer = PanelContainer.new()
	item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_panel.custom_minimum_size = Vector2(0.0, 61.0)
	item_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.025, 0.037, 0.056, 0.92),
			Color(0.3, 0.62, 0.92, 0.52),
			11,
			1
		)
	)
	lower_row.add_child(item_panel)

	quick_item_label = Label.new()
	quick_item_label.text = "▲ QUICK ITEM\nFlask ×3"
	quick_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_item_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quick_item_label.add_theme_font_size_override("font_size", 11)
	quick_item_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.88, 1.0, 1.0)
	)
	item_panel.add_child(quick_item_label)

	var special_panel: PanelContainer = PanelContainer.new()
	special_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	special_panel.custom_minimum_size = Vector2(0.0, 61.0)
	special_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.055, 0.027, 0.015, 0.92),
			Color(1.0, 0.43, 0.08, 0.62),
			11,
			1
		)
	)
	lower_row.add_child(special_panel)

	var special_stack: VBoxContainer = VBoxContainer.new()
	special_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	special_stack.add_theme_constant_override("separation", 2)
	special_panel.add_child(special_stack)

	divine_special_label = Label.new()
	divine_special_label.text = "▼ DIVINE SPECIAL\nHearth of the First Flame"
	divine_special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divine_special_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	divine_special_label.add_theme_font_size_override("font_size", 10)
	divine_special_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.68, 0.24, 1.0)
	)
	special_stack.add_child(divine_special_label)

	divine_charge_bar = ProgressBar.new()
	divine_charge_bar.show_percentage = false
	divine_charge_bar.custom_minimum_size = Vector2(0.0, 7.0)
	divine_charge_bar.min_value = 0.0
	divine_charge_bar.max_value = 100.0
	divine_charge_bar.add_theme_stylebox_override(
		"background",
		_make_bar_style(Color(0.12, 0.055, 0.025, 0.94), 4)
	)
	divine_charge_bar.add_theme_stylebox_override(
		"fill",
		_make_bar_style(Color(1.0, 0.47, 0.08, 1.0), 4)
	)
	special_stack.add_child(divine_charge_bar)

	divine_charge_label = Label.new()
	divine_charge_label.text = "0% RECHARGING"
	divine_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divine_charge_label.add_theme_font_size_override("font_size", 9)
	divine_charge_label.add_theme_color_override(
		"font_color",
		Color(0.86, 0.72, 0.58, 0.92)
	)
	special_stack.add_child(divine_charge_label)

	quick_hint_label = Label.new()
	quick_hint_label.text = "D-PAD ◀/▶ SPELLS   •   ▲ TAP CYCLE / HOLD USE   •   ▼ TAP ACTIVATE / HOLD SELECT"
	quick_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_hint_label.visible = show_control_hints
	quick_hint_label.add_theme_font_size_override("font_size", 9)
	quick_hint_label.add_theme_color_override(
		"font_color",
		Color(0.56, 0.65, 0.78, 0.88)
	)
	stack.add_child(quick_hint_label)


func _build_portrait_and_statuses() -> void:
	status_stack = VBoxContainer.new()
	status_stack.name = "StatusEffectStack"
	status_stack.anchor_left = 1.0
	status_stack.anchor_top = 1.0
	status_stack.anchor_right = 1.0
	status_stack.anchor_bottom = 1.0
	status_stack.offset_left = -342.0
	status_stack.offset_top = -515.0
	status_stack.offset_right = -22.0
	status_stack.offset_bottom = -228.0
	status_stack.alignment = BoxContainer.ALIGNMENT_END
	status_stack.add_theme_constant_override("separation", 5)
	status_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_stack)

	for _index: int in range(5):
		var effect_panel: PanelContainer = PanelContainer.new()
		effect_panel.custom_minimum_size = Vector2(0.0, 39.0)
		effect_panel.visible = false
		effect_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(
				Color(0.015, 0.021, 0.033, 0.9),
				Color(0.38, 0.55, 0.82, 0.46),
				10,
				1
			)
		)
		status_stack.add_child(effect_panel)
		status_rows.append(effect_panel)

		var effect_margin: MarginContainer = MarginContainer.new()
		effect_margin.add_theme_constant_override("margin_left", 9)
		effect_margin.add_theme_constant_override("margin_right", 9)
		effect_margin.add_theme_constant_override("margin_top", 4)
		effect_margin.add_theme_constant_override("margin_bottom", 4)
		effect_panel.add_child(effect_margin)

		var effect_row: HBoxContainer = HBoxContainer.new()
		effect_row.add_theme_constant_override("separation", 7)
		effect_margin.add_child(effect_row)

		var effect_icon: Label = Label.new()
		effect_icon.custom_minimum_size = Vector2(24.0, 0.0)
		effect_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		effect_icon.add_theme_font_size_override("font_size", 16)
		effect_row.add_child(effect_icon)
		status_icon_labels.append(effect_icon)

		var effect_name: Label = Label.new()
		effect_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		effect_name.add_theme_font_size_override("font_size", 11)
		effect_name.add_theme_color_override(
			"font_color",
			Color(0.9, 0.94, 1.0, 0.96)
		)
		effect_row.add_child(effect_name)
		status_name_labels.append(effect_name)

		var effect_timer: Label = Label.new()
		effect_timer.custom_minimum_size = Vector2(42.0, 0.0)
		effect_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		effect_timer.add_theme_font_size_override("font_size", 10)
		effect_row.add_child(effect_timer)
		status_timer_labels.append(effect_timer)

	var portrait_shell: PanelContainer = PanelContainer.new()
	portrait_shell.name = "GracePortraitShell"
	portrait_shell.anchor_left = 1.0
	portrait_shell.anchor_top = 1.0
	portrait_shell.anchor_right = 1.0
	portrait_shell.anchor_bottom = 1.0
	portrait_shell.offset_left = -225.0
	portrait_shell.offset_top = -225.0
	portrait_shell.offset_right = -20.0
	portrait_shell.offset_bottom = -20.0
	portrait_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_shell.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.012, 0.017, 0.027, 0.94),
			Color(1.0, 0.65, 0.22, 0.75),
			102,
			2
		)
	)
	root.add_child(portrait_shell)

	var portrait_margin: MarginContainer = MarginContainer.new()
	portrait_margin.add_theme_constant_override("margin_left", 10)
	portrait_margin.add_theme_constant_override("margin_right", 10)
	portrait_margin.add_theme_constant_override("margin_top", 8)
	portrait_margin.add_theme_constant_override("margin_bottom", 8)
	portrait_shell.add_child(portrait_margin)

	var portrait_stack: VBoxContainer = VBoxContainer.new()
	portrait_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	portrait_stack.add_theme_constant_override("separation", 1)
	portrait_margin.add_child(portrait_stack)

	portrait = PortraitMedallionScript.new() as PortraitMedallion
	portrait.name = "GracePortrait"
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.custom_minimum_size = Vector2(166.0, 166.0)
	portrait_stack.add_child(portrait)

	portrait_name_label = Label.new()
	portrait_name_label.text = "GRACE"
	portrait_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_name_label.add_theme_font_size_override("font_size", 11)
	portrait_name_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.78, 0.36, 1.0)
	)
	portrait_stack.add_child(portrait_name_label)

	portrait_state_label = Label.new()
	portrait_state_label.text = "READY"
	portrait_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_state_label.add_theme_font_size_override("font_size", 9)
	portrait_state_label.add_theme_color_override(
		"font_color",
		Color(0.64, 0.74, 0.88, 0.9)
	)
	portrait_stack.add_child(portrait_state_label)


func _build_dialogue_panel() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "PortraitDialogueStrip"
	dialogue_panel.anchor_left = 1.0
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_right = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.offset_left = -1135.0
	dialogue_panel.offset_top = -245.0
	dialogue_panel.offset_right = -205.0
	dialogue_panel.offset_bottom = -24.0
	dialogue_panel.visible = false
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.012, 0.017, 0.027, 0.965),
			Color(0.96, 0.63, 0.22, 0.72),
			24,
			2
		)
	)
	root.add_child(dialogue_panel)
	root.move_child(dialogue_panel, maxi(root.get_child_count() - 2, 0))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 13)
	dialogue_panel.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 15)
	margin.add_child(row)

	npc_portrait = PortraitMedallionScript.new() as PortraitMedallion
	npc_portrait.name = "NPCPortrait"
	npc_portrait.custom_minimum_size = Vector2(142.0, 142.0)
	npc_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(npc_portrait)

	var text_stack: VBoxContainer = VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 5)
	row.add_child(text_stack)

	var speaker_row: HBoxContainer = HBoxContainer.new()
	text_stack.add_child(speaker_row)

	dialogue_speaker_label = Label.new()
	dialogue_speaker_label.text = "TRAVELER"
	dialogue_speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_speaker_label.add_theme_font_size_override("font_size", 15)
	dialogue_speaker_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.73, 0.28, 1.0)
	)
	speaker_row.add_child(dialogue_speaker_label)

	dialogue_title_label = Label.new()
	dialogue_title_label.text = "Roadside Traveler"
	dialogue_title_label.add_theme_font_size_override("font_size", 10)
	dialogue_title_label.add_theme_color_override(
		"font_color",
		Color(0.55, 0.65, 0.78, 0.92)
	)
	speaker_row.add_child(dialogue_title_label)

	dialogue_body_label = RichTextLabel.new()
	dialogue_body_label.bbcode_enabled = true
	dialogue_body_label.fit_content = false
	dialogue_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_body_label.custom_minimum_size = Vector2(0.0, 82.0)
	dialogue_body_label.add_theme_font_size_override("normal_font_size", 17)
	dialogue_body_label.add_theme_color_override(
		"default_color",
		Color(0.92, 0.94, 0.98, 0.98)
	)
	text_stack.add_child(dialogue_body_label)

	dialogue_choice_label = Label.new()
	dialogue_choice_label.text = "A  Continue     B  Leave"
	dialogue_choice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_choice_label.add_theme_font_size_override("font_size", 12)
	dialogue_choice_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.76, 0.34, 0.96)
	)
	text_stack.add_child(dialogue_choice_label)


func _refresh_stats() -> void:
	var avatar_name: String = "Grace"
	var incarnated: bool = false
	if avatar_manager != null:
		if avatar_manager.has_method("get_active_avatar_display_name"):
			avatar_name = str(
				avatar_manager.call("get_active_avatar_display_name")
			)
		if avatar_manager.has_method("is_incarnated"):
			incarnated = bool(avatar_manager.call("is_incarnated"))
	avatar_title_label.text = (
		avatar_name.to_upper()
		+ ("  •  DIVINE INCARNATION" if incarnated else "  •  WAYFARER")
	)

	var weapon_name: String = "Unarmed"
	if weapon_controller != null and weapon_controller.equipped_weapon != null:
		weapon_name = weapon_controller.equipped_weapon.display_name
	var spell_name: String = "No Spell"
	if ability_caster != null and ability_caster.has_method("get_current_ability_name"):
		spell_name = str(ability_caster.call("get_current_ability_name"))
	loadout_label.text = "Weapon: " + weapon_name + "  •  Spell: " + spell_name

	_update_stat_row("health", "max_health")
	_update_stat_row("mana", "max_mana")
	_update_stat_row("stamina", "max_stamina")
	_update_stat_row("stance", "max_stance")
	base_stats_label.text = (
		"FOCUS "
		+ str(GameState.get_stat("focus"))
		+ "   POWER "
		+ str(GameState.get_stat("power"))
		+ "   ARCANA "
		+ str(GameState.get_stat("arcana"))
	)


func _update_stat_row(stat_id: String, maximum_id: String) -> void:
	if not stat_rows.has(stat_id):
		return
	var row: Dictionary = stat_rows[stat_id] as Dictionary
	var bar: ProgressBar = row.get("bar") as ProgressBar
	var value_label: Label = row.get("value") as Label
	var current: int = GameState.get_stat(stat_id)
	var maximum: int = maxi(GameState.get_stat(maximum_id), 1)
	if bar != null:
		bar.max_value = maximum
		bar.value = clampi(current, 0, maximum)
	if value_label != null:
		value_label.text = str(current) + " / " + str(maximum)


func _refresh_quick_loadout() -> void:
	var spell_names: Array[String] = []
	var spell_cursor: int = 0
	if control_router != null:
		if control_router.has_method("get_quick_spell_names"):
			var names_result: Variant = control_router.call(
				"get_quick_spell_names"
			)
			if names_result is Array:
				for name_value: Variant in names_result as Array:
					spell_names.append(str(name_value))
		if control_router.has_method("get_selected_quick_spell_cursor"):
			spell_cursor = int(
				control_router.call("get_selected_quick_spell_cursor")
			)

	for index: int in range(quick_spell_labels.size()):
		var name: String = spell_names[index] if index < spell_names.size() else "Empty"
		quick_spell_labels[index].text = name
		var selected: bool = index == spell_cursor and name != "Empty"
		quick_spell_panels[index].add_theme_stylebox_override(
			"panel",
			_make_panel_style(
				Color(0.085, 0.047, 0.025, 0.98)
				if selected
				else Color(0.035, 0.045, 0.067, 0.94),
				Color(1.0, 0.55, 0.12, 0.92)
				if selected
				else Color(0.25, 0.35, 0.53, 0.72),
				10,
				2 if selected else 1
			)
		)
		quick_spell_labels[index].add_theme_color_override(
			"font_color",
			Color(1.0, 0.74, 0.28, 1.0)
			if selected
			else Color(0.75, 0.82, 0.92, 0.9)
		)

	var current_spell: String = "No Spell"
	if ability_caster != null and ability_caster.has_method("get_current_ability_name"):
		current_spell = str(ability_caster.call("get_current_ability_name"))
	var hand_roles: Dictionary = _get_hand_role_summary()
	quick_spell_detail_label.text = (
		current_spell.to_upper()
		+ "  •  "
		+ str(hand_roles.get("cast", "ZL"))
		+ " CAST"
	)

	var selected_item_slot: int = 0
	if control_router != null and control_router.has_method(
		"get_selected_quick_item_slot"
	):
		selected_item_slot = int(
			control_router.call("get_selected_quick_item_slot")
		)
	var item_name: String = "Empty"
	var item_count: int = 0
	if quick_item_controller != null:
		var item: QuickItemDefinition = quick_item_controller.get_slot_item(
			selected_item_slot
		)
		if item != null:
			item_name = item.display_name
			item_count = quick_item_controller.get_slot_charges(
				selected_item_slot
			)
	quick_item_label.text = (
		"▲ QUICK ITEM\n" + item_name + " ×" + str(item_count)
	)

	var special_name: String = "No Divine Special"
	var charge: float = 0.0
	var maximum_charge: float = 100.0
	var ready: bool = false
	var active: bool = false
	if divine_controller != null:
		var debug: Dictionary = divine_controller.get_debug_data()
		special_name = str(debug.get("selected_name", special_name))
		charge = float(debug.get("charge", 0.0))
		maximum_charge = maxf(
			float(debug.get("maximum_charge", 100.0)),
			1.0
		)
		ready = bool(debug.get("ready", false))
		active = bool(debug.get("active", false))
	divine_special_label.text = "▼ DIVINE SPECIAL\n" + special_name
	divine_charge_bar.max_value = maximum_charge
	divine_charge_bar.value = charge
	var state: String = "ACTIVE" if active else ("READY" if ready else "RECHARGING")
	divine_charge_label.text = (
		str(roundi(charge / maximum_charge * 100.0)) + "% " + state
	)


func _refresh_statuses_and_portrait() -> void:
	var rows: Array[Dictionary] = _collect_status_rows()
	for index: int in range(status_rows.size()):
		var visible: bool = index < rows.size()
		status_rows[index].visible = visible
		if not visible:
			continue
		var row: Dictionary = rows[index]
		var status_id: String = str(row.get("id", "effect"))
		var color: Color = _status_color(status_id)
		status_icon_labels[index].text = _status_icon(status_id)
		status_icon_labels[index].add_theme_color_override("font_color", color)
		status_name_labels[index].text = str(
			row.get("name", status_id.capitalize())
		)
		var remaining: float = maxf(float(row.get("remaining", 0.0)), 0.0)
		status_timer_labels[index].text = (
			str(ceili(remaining)) + "s" if remaining > 0.0 else ""
		)
		status_timer_labels[index].add_theme_color_override("font_color", color)

	var expression: String = _resolve_portrait_expression(rows)
	if portrait != null:
		portrait.configure(
			"Grace",
			_get_portrait_accent(),
			expression,
			true
		)
	last_expression = expression

	var health: int = GameState.get_stat("health")
	var maximum_health: int = maxi(GameState.get_stat("max_health"), 1)
	portrait_name_label.text = "GRACE"
	portrait_state_label.text = _portrait_state_copy(
		expression,
		health,
		maximum_health
	)


func _collect_status_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	for effect_row: Dictionary in GameplayEffectAccessScript.get_active_source_rows(
		false
	):
		var effect_id: String = str(effect_row.get("id", "effect"))
		if seen.has(effect_id):
			continue
		seen[effect_id] = true
		rows.append(effect_row.duplicate(true))

	if status_receiver != null:
		for status_value: Variant in status_receiver.active_statuses.keys():
			var status_id: String = str(status_value)
			if seen.has(status_id):
				continue
			var status: Dictionary = (
				status_receiver.active_statuses[status_id] as Dictionary
			)
			seen[status_id] = true
			rows.append({
				"id": status_id,
				"name": status_id.capitalize(),
				"remaining": float(status.get("duration", 0.0)),
			})

	if divine_controller != null:
		var divine_debug: Dictionary = divine_controller.get_debug_data()
		if bool(divine_debug.get("ready", false)) and not seen.has(
			"divine_ready"
		):
			rows.push_front({
				"id": "divine_ready",
				"name": "Divine Special Ready",
				"remaining": 0.0,
			})
	return rows.slice(0, mini(rows.size(), 5))


func _resolve_portrait_expression(rows: Array[Dictionary]) -> String:
	if active_conversation != null:
		return "attentive"
	var status_ids: Array[String] = []
	for row: Dictionary in rows:
		status_ids.append(str(row.get("id", "")))
	if "burning" in status_ids:
		return "burning"
	if "poisoned" in status_ids:
		return "poisoned"
	if (
		"chill" in status_ids
		or "chilled" in status_ids
		or "frozen" in status_ids
	):
		return "chilled"
	var maximum_health: int = maxi(GameState.get_stat("max_health"), 1)
	if GameState.get_stat("health") <= ceili(float(maximum_health) * 0.25):
		return "low_health"
	if action_state != null and (
		action_state.is_casting or action_state.is_focus_menu_open
	):
		return "focused"
	return "neutral"


func _portrait_state_copy(
	expression: String,
	health: int,
	maximum_health: int
) -> String:
	match expression:
		"attentive":
			return "LISTENING"
		"burning":
			return "BURNING"
		"poisoned":
			return "POISONED"
		"chilled":
			return "CHILLED"
		"low_health":
			return "HURT  •  " + str(health) + "/" + str(maximum_health)
		"focused":
			return "FOCUSED"
		_:
			return "READY"


func _refresh_dialogue() -> void:
	var conversation: Node = _find_active_conversation()
	if conversation == null:
		active_conversation = null
		dialogue_panel.visible = false
		return
	active_conversation = conversation

	var legacy_layer: Variant = conversation.get("layer")
	if legacy_layer is CanvasLayer:
		(legacy_layer as CanvasLayer).visible = false
	var legacy_history: Variant = conversation.get("history_panel")
	if legacy_history is Control:
		(legacy_history as Control).visible = false

	var conversation_data_value: Variant = conversation.get("conversation_data")
	var conversation_data: Dictionary = (
		conversation_data_value as Dictionary
		if conversation_data_value is Dictionary
		else {}
	)
	var current_node_id: String = str(conversation.get("current_node_id"))
	var nodes_value: Variant = conversation_data.get("nodes", {})
	var nodes: Dictionary = nodes_value as Dictionary if nodes_value is Dictionary else {}
	if current_node_id == "" or not nodes.has(current_node_id):
		dialogue_panel.visible = false
		return
	var node_value: Variant = nodes[current_node_id]
	if not node_value is Dictionary:
		dialogue_panel.visible = false
		return
	var node: Dictionary = node_value as Dictionary
	var npc_name: String = str(conversation.get("display_name"))
	var speaker: String = str(node.get("speaker", npc_name))
	var title: String = str(conversation.get("title"))
	var body: String = str(node.get("text", "..."))
	var accent_value: Variant = conversation.get("portrait_color")
	var accent: Color = (
		accent_value as Color
		if accent_value is Color
		else Color(0.78, 0.58, 0.28, 1.0)
	)

	dialogue_panel.visible = true
	dialogue_speaker_label.text = speaker.to_upper()
	dialogue_title_label.text = title
	dialogue_body_label.text = body
	npc_portrait.configure(npc_name, accent, "neutral", false)

	var choices_value: Variant = conversation.get("visible_choices")
	var choices: Array = choices_value as Array if choices_value is Array else []
	var selected_choice: int = int(conversation.get("selected_choice"))
	if choices.is_empty():
		dialogue_choice_label.text = "A  Continue     B  Leave"
	else:
		selected_choice = clampi(selected_choice, 0, choices.size() - 1)
		var selected_value: Variant = choices[selected_choice]
		var selected_text: String = "Continue"
		if selected_value is Dictionary:
			selected_text = str(
				(selected_value as Dictionary).get("text", "Continue")
			)
		dialogue_choice_label.text = (
			"◆  "
			+ selected_text
			+ "     ▲/▼ Choose   A Confirm   B Leave"
		)


func show_dialogue_preview(data: Dictionary) -> void:
	active_conversation = self
	dialogue_panel.visible = true
	dialogue_speaker_label.text = str(
		data.get("speaker", "WAYFARER")
	).to_upper()
	dialogue_title_label.text = str(data.get("title", "Traveler"))
	dialogue_body_label.text = str(data.get("text", "..."))
	dialogue_choice_label.text = str(
		data.get("choice", "A  Continue     B  Leave")
	)
	var accent_value: Variant = data.get(
		"accent",
		Color(0.78, 0.58, 0.28, 1.0)
	)
	var accent: Color = (
		accent_value as Color
		if accent_value is Color
		else Color(0.78, 0.58, 0.28, 1.0)
	)
	npc_portrait.configure(
		str(data.get("name", "Traveler")),
		accent,
		"neutral",
		false
	)


func hide_dialogue_preview() -> void:
	if active_conversation == self:
		active_conversation = null
	dialogue_panel.visible = false


func _find_active_conversation() -> Node:
	for npc: Node in get_tree().get_nodes_in_group("conversation_npc"):
		if bool(npc.get("conversation_open")):
			return npc
	return null


func _suppress_legacy_hud() -> void:
	if not suppress_legacy_hud or actor == null:
		return
	for node_name: String in [
		"DivineSpecialHUD",
		"QuickItemBeltUI",
		"GameplayEffectStatusHUD",
		"WeaponMasteryHUD",
		"QuickLoadoutHUD",
	]:
		var legacy: Node = actor.get_node_or_null(node_name)
		if legacy is CanvasLayer:
			(legacy as CanvasLayer).visible = false
		elif legacy is Control:
			(legacy as Control).visible = false

	var game_ui: Node = get_tree().get_first_node_in_group("game_ui")
	if game_ui == null:
		return
	for child_name: String in [
		"ResourceHUD",
		"SpellMenuLabel",
		"DebugStatsLabel",
	]:
		var child: Node = game_ui.find_child(child_name, true, false)
		if child is Control:
			(child as Control).visible = false


func _resolve_bindings() -> void:
	if actor == null or not is_instance_valid(actor):
		actor = get_parent() as CharacterBody3D
	if actor == null:
		return
	action_state = actor.get_node_or_null(
		"PlayerActionState"
	) as PlayerActionState
	ability_caster = actor.get_node_or_null("AbilityCaster")
	quick_item_controller = actor.get_node_or_null(
		"PlayerQuickItemController"
	) as PlayerQuickItemController
	control_router = actor.get_node_or_null("PlayerControlRouter")
	divine_controller = actor.get_node_or_null(
		"DivineSpecialController"
	) as PlayerDivineSpecialController
	weapon_controller = actor.get_node_or_null(
		"WeaponController"
	) as WeaponController
	avatar_manager = actor.get_node_or_null("AvatarManager")
	status_receiver = actor.get_node_or_null(
		"StatusReceiver"
	) as PlayerStatusReceiver


func _get_hand_role_summary() -> Dictionary:
	if control_router != null and control_router.has_method(
		"get_hand_role_summary"
	):
		var result: Variant = control_router.call("get_hand_role_summary")
		if result is Dictionary:
			return result as Dictionary
	return {
		"focus": "L",
		"cast": "ZL",
		"light": "R",
		"heavy": "ZR",
	}


func _get_portrait_accent() -> Color:
	if avatar_manager != null and avatar_manager.has_method("is_incarnated"):
		if bool(avatar_manager.call("is_incarnated")):
			return Color(1.0, 0.34, 0.08, 1.0)
	return Color(0.94, 0.68, 0.26, 1.0)


func _status_icon(status_id: String) -> String:
	match status_id:
		"burning":
			return "🔥"
		"poisoned":
			return "☠"
		"chill", "chilled", "frozen":
			return "❄"
		"wet":
			return "●"
		"weakened":
			return "↓"
		"silenced":
			return "✕"
		"divine_ready":
			return "✺"
		"vital_restoration":
			return "♥"
		"resonant_focus":
			return "◉"
		_:
			return "◆"


func _status_color(status_id: String) -> Color:
	match status_id:
		"burning":
			return Color(1.0, 0.34, 0.1, 1.0)
		"poisoned":
			return Color(0.48, 0.94, 0.22, 1.0)
		"chill", "chilled", "frozen":
			return Color(0.36, 0.84, 1.0, 1.0)
		"wet":
			return Color(0.24, 0.62, 1.0, 1.0)
		"divine_ready":
			return Color(1.0, 0.75, 0.2, 1.0)
		"vital_restoration":
			return Color(1.0, 0.38, 0.5, 1.0)
		"resonant_focus":
			return Color(0.3, 0.8, 1.0, 1.0)
		_:
			return Color(0.72, 0.8, 0.94, 1.0)


func _make_panel_style(
	fill: Color,
	border: Color,
	radius: int,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _make_bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style


func get_debug_data() -> Dictionary:
	return {
		"stats_panel": stats_panel != null and stats_panel.visible,
		"quick_panel": quick_panel != null and quick_panel.visible,
		"portrait": portrait != null,
		"expression": last_expression,
		"status_count": _collect_status_rows().size(),
		"dialogue_visible": dialogue_panel != null and dialogue_panel.visible,
		"legacy_suppressed": suppress_legacy_hud,
	}
