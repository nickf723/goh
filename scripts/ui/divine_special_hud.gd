extends CanvasLayer
class_name DivineSpecialHUD

@export var show_debug_controls: bool = true
@export_range(0.02, 1.0, 0.01) var refresh_interval: float = 0.08

var controller: PlayerDivineSpecialController
var panel: PanelContainer
var title_label: Label
var charge_bar: ProgressBar
var status_label: Label
var hint_label: Label
var charge_fill_style: StyleBoxFlat
var refresh_remaining: float = 0.0


func _ready() -> void:
	layer = 18
	_build_hud()
	call_deferred("_resolve_controller")
	add_to_group("divine_special_hud")


func _process(delta: float) -> void:
	refresh_remaining = maxf(
		refresh_remaining - maxf(delta, 0.0),
		0.0
	)
	if refresh_remaining > 0.0:
		return
	refresh_remaining = maxf(refresh_interval, 0.02)
	if controller == null or not is_instance_valid(controller):
		_resolve_controller()
	_update_hud()


func _resolve_controller() -> void:
	var player: Node = get_parent()
	if player != null:
		controller = player.get_node_or_null(
			"DivineSpecialController"
		) as PlayerDivineSpecialController
	_update_hud()


func _build_hud() -> void:
	panel = PanelContainer.new()
	panel.name = "DivineSpecialPanel"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# The quick-item belt occupies the lowest-right shelf. Divine Charge lives
	# immediately above it so both remain readable at ordinary window sizes.
	panel.offset_left = -360.0
	panel.offset_top = -246.0
	panel.offset_right = -24.0
	panel.offset_bottom = -150.0
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "DIVINE SPECIAL"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.63, 0.17, 1.0)
	)
	title_label.add_theme_font_size_override("font_size", 12)
	stack.add_child(title_label)

	charge_bar = ProgressBar.new()
	charge_bar.name = "Charge"
	charge_bar.min_value = 0.0
	charge_bar.max_value = 100.0
	charge_bar.value = 0.0
	charge_bar.show_percentage = false
	charge_bar.custom_minimum_size = Vector2(304.0, 14.0)
	charge_bar.add_theme_stylebox_override(
		"background",
		_make_charge_background()
	)
	charge_fill_style = _make_charge_fill()
	charge_bar.add_theme_stylebox_override("fill", charge_fill_style)
	stack.add_child(charge_bar)

	status_label = Label.new()
	status_label.name = "Status"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.text = "DIVINE CHARGE 0%"
	status_label.add_theme_font_size_override("font_size", 11)
	stack.add_child(status_label)

	hint_label = Label.new()
	hint_label.name = "Hints"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.text = "F11 ACTIVATE • SHIFT+F11 CYCLE • F6 REFILL"
	hint_label.visible = OS.is_debug_build() and show_debug_controls
	hint_label.add_theme_color_override(
		"font_color",
		Color(0.84, 0.72, 0.58, 0.86)
	)
	hint_label.add_theme_font_size_override("font_size", 9)
	stack.add_child(hint_label)


func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.02, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.34, 0.07, 0.48)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style


func _make_charge_background() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.045, 0.04, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.45, 0.16, 0.07, 0.74)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _make_charge_fill() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.28, 0.04, 0.96)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	return style


func _update_hud() -> void:
	if panel == null:
		return
	if controller == null or not is_instance_valid(controller):
		panel.visible = false
		return
	var debug: Dictionary = controller.get_debug_data()
	var selected_id: String = str(debug.get("selected_id", "none"))
	panel.visible = selected_id != "none"
	if not panel.visible:
		return
	var patron_name: String = str(
		debug.get("selected_patron", "divine")
	).capitalize()
	var selected_name: String = str(
		debug.get("selected_name", "Divine Special")
	)
	title_label.text = (
		patron_name.to_upper()
		+ " • "
		+ selected_name.to_upper()
	)
	var charge: float = float(debug.get("charge", 0.0))
	var maximum: float = maxf(
		float(debug.get("maximum_charge", 100.0)),
		0.01
	)
	var ratio: float = clampf(charge / maximum, 0.0, 1.0)
	charge_bar.max_value = maximum
	charge_bar.value = charge
	if charge_fill_style != null:
		charge_fill_style.bg_color = Color(1.0, 0.25, 0.035, 0.96).lerp(
			Color(1.0, 0.82, 0.16, 1.0),
			ratio
		)
	var state: String = "RECHARGING"
	if bool(debug.get("active", false)):
		state = "ACTIVE"
	elif bool(debug.get("ready", false)):
		state = "READY"
	status_label.text = (
		"DIVINE CHARGE "
		+ str(roundi(ratio * 100.0))
		+ "% • "
		+ state
	)
