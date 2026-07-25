extends Area3D
class_name GrowthShrine

signal upgrade_applied(upgrade_id: String, new_value: int)

const UPGRADES: Array[Dictionary] = [
	{"id": "vitality", "name": "Vitality", "stat": "max_health", "current": "health", "amount": 2, "limit": 25, "icon": "♥", "description": "Increase maximum Health by 2 and restore the added capacity."},
	{"id": "endurance", "name": "Endurance", "stat": "max_stamina", "current": "stamina", "amount": 2, "limit": 25, "icon": "◆", "description": "Increase maximum Stamina by 2 and restore the added capacity."},
	{"id": "channeling", "name": "Channeling", "stat": "max_mana", "current": "mana", "amount": 2, "limit": 25, "icon": "✦", "description": "Increase maximum Mana by 2 and restore the added capacity."},
	{"id": "composure", "name": "Composure", "stat": "max_stance", "current": "stance", "amount": 2, "limit": 25, "icon": "⬟", "description": "Increase maximum Stance by 2 and restore the added capacity."},
	{"id": "focus", "name": "Focus", "stat": "focus", "current": "", "amount": 1, "limit": 15, "icon": "◉", "description": "Strengthen Focus and increase the control offered by planning menus."},
	{"id": "presence", "name": "Presence", "stat": "charisma", "current": "", "amount": 1, "limit": 10, "icon": "✧", "description": "Increase Charisma for dialogue, trust, bargaining, and social checks."},
]

@export var prompt_text: String = "Commune with Growth Shrine"

var menu_open: bool = false
var cursor_index: int = 0
var confirmation_pending: bool = false
var status_message: String = "Choose how Grace should grow."
var layer: CanvasLayer
var panel: PanelContainer
var points_label: Label
var progress_label: Label
var rows_box: VBoxContainer
var description_label: Label
var status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("interactable_target")
	add_to_group("growth_shrine")
	add_to_group("debuggable")
	build_world_visual()
	build_menu()


func interact() -> Dictionary:
	if not menu_open:
		call_deferred("open_menu")
	return {}


func open_menu() -> void:
	if menu_open:
		return
	menu_open = true
	cursor_index = 0
	confirmation_pending = false
	status_message = "Choose how Grace should grow."
	refresh_menu()
	layer.visible = true
	get_tree().paused = true


func close_menu() -> void:
	if not menu_open:
		return
	menu_open = false
	confirmation_pending = false
	layer.visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not menu_open or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_up"):
		cursor_index = wrapi(cursor_index - 1, 0, UPGRADES.size())
		confirmation_pending = false
		refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		cursor_index = wrapi(cursor_index + 1, 0, UPGRADES.size())
		confirmation_pending = false
		refresh_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		activate_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if confirmation_pending:
			confirmation_pending = false
			status_message = "Upgrade cancelled."
			refresh_menu()
		else:
			close_menu()
		get_viewport().set_input_as_handled()


func activate_selection() -> void:
	if cursor_index < 0 or cursor_index >= UPGRADES.size():
		return
	var upgrade: Dictionary = UPGRADES[cursor_index]
	if not can_apply_upgrade(upgrade):
		return
	if not confirmation_pending:
		confirmation_pending = true
		status_message = "Confirm " + str(upgrade.get("name", "upgrade")) + "? Press Confirm again."
		refresh_menu()
		return
	apply_upgrade(upgrade)


func can_apply_upgrade(upgrade: Dictionary) -> bool:
	if GameState.get_growth_points() <= 0:
		status_message = "Earn a Growth Point by leveling up first."
		refresh_menu()
		return false
	var stat_id: String = str(upgrade.get("stat", ""))
	var limit: int = int(upgrade.get("limit", 99))
	if GameState.get_stat(stat_id) >= limit:
		status_message = str(upgrade.get("name", "Upgrade")) + " is already at its current limit."
		refresh_menu()
		return false
	return true


func apply_upgrade(upgrade: Dictionary) -> bool:
	if not can_apply_upgrade(upgrade):
		confirmation_pending = false
		return false
	if not GameState.spend_growth_point():
		status_message = "No Growth Points remain."
		confirmation_pending = false
		refresh_menu()
		return false
	var stat_id: String = str(upgrade.get("stat", ""))
	var current_id: String = str(upgrade.get("current", ""))
	var amount: int = maxi(int(upgrade.get("amount", 1)), 1)
	var limit: int = int(upgrade.get("limit", 99))
	var before: int = GameState.get_stat(stat_id)
	var after: int = mini(before + amount, limit)
	GameState.set_stat(stat_id, after)
	if current_id != "":
		GameState.set_stat(current_id, mini(GameState.get_stat(current_id) + (after - before), after))
	confirmation_pending = false
	status_message = str(upgrade.get("name", "Upgrade")) + " increased: " + str(before) + " → " + str(after) + "."
	upgrade_applied.emit(str(upgrade.get("id", stat_id)), after)
	refresh_menu()
	return true


func refresh_menu() -> void:
	if rows_box == null:
		return
	points_label.text = "AVAILABLE GROWTH POINTS   " + str(GameState.get_growth_points())
	progress_label.text = "LEVEL " + str(GameState.get_stat("level")) + "     XP " + str(GameState.get_experience()) + " / " + str(GameState.get_experience_required())
	for child: Node in rows_box.get_children():
		child.free()
	for index: int in range(UPGRADES.size()):
		var upgrade: Dictionary = UPGRADES[index]
		var selected: bool = cursor_index == index
		var stat_id: String = str(upgrade.get("stat", ""))
		var current: int = GameState.get_stat(stat_id)
		var next: int = mini(current + int(upgrade.get("amount", 1)), int(upgrade.get("limit", 99)))
		var row := Label.new()
		row.custom_minimum_size = Vector2(0.0, 50.0)
		row.add_theme_font_size_override("font_size", 21)
		row.text = ("◆  " if selected else "    ") + str(upgrade.get("icon", "◇")) + "  " + str(upgrade.get("name", stat_id.capitalize()))
		row.text += "        " + str(current) + "  →  " + str(next)
		if current >= int(upgrade.get("limit", 99)):
			row.text += "   MAX"
		row.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36) if selected else Color(0.8, 0.87, 0.94))
		rows_box.add_child(row)
	var selected_upgrade: Dictionary = UPGRADES[cursor_index]
	description_label.text = str(selected_upgrade.get("description", ""))
	description_label.text += "\n\nCost: 1 Growth Point"
	status_label.text = status_message


func build_world_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.4
	shape.height = 2.8
	collision.shape = shape
	collision.position.y = 1.4
	add_child(collision)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 1.15
	base_mesh.bottom_radius = 1.5
	base_mesh.height = 0.75
	base.mesh = base_mesh
	base.position.y = 0.38
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.12, 0.2, 0.18)
	stone.roughness = 0.64
	base.material_override = stone
	add_child(base)
	for index: int in range(6):
		var petal := MeshInstance3D.new()
		var petal_mesh := SphereMesh.new()
		petal_mesh.radius = 0.27
		petal_mesh.height = 0.7
		petal.mesh = petal_mesh
		var angle: float = TAU * float(index) / 6.0
		petal.position = Vector3(cos(angle) * 0.72, 1.18, sin(angle) * 0.72)
		petal.rotation.z = angle
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.3, 0.9, 0.52)
		material.emission_enabled = true
		material.emission = Color(0.08, 0.5, 0.25)
		material.emission_energy_multiplier = 1.6
		petal.material_override = material
		add_child(petal)
	var core := OmniLight3D.new()
	core.position = Vector3(0.0, 1.3, 0.0)
	core.light_color = Color(0.3, 1.0, 0.55)
	core.light_energy = 2.2
	core.omni_range = 5.0
	add_child(core)
	var label := Label3D.new()
	label.text = "GROWTH SHRINE"
	label.position = Vector3(0.0, 2.65, 0.0)
	label.font_size = 31
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 7
	label.modulate = Color(0.56, 1.0, 0.7)
	add_child(label)


func build_menu() -> void:
	layer = CanvasLayer.new()
	layer.layer = 95
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.visible = false
	add_child(layer)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-570.0, -350.0)
	panel.custom_minimum_size = Vector2(1140.0, 700.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.035, 0.03, 0.99)
	style.border_color = Color(0.28, 0.88, 0.52)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var title := Label.new()
	title.text = "CHOOSE HOW GRACE GROWS"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.58, 1.0, 0.72))
	root.add_child(title)
	var top := HBoxContainer.new()
	root.add_child(top)
	points_label = Label.new()
	points_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	points_label.add_theme_font_size_override("font_size", 21)
	points_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
	top.add_child(points_label)
	progress_label = Label.new()
	progress_label.add_theme_color_override("font_color", Color(0.58, 0.75, 0.68))
	top.add_child(progress_label)
	root.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 30)
	root.add_child(columns)
	rows_box = VBoxContainer.new()
	rows_box.custom_minimum_size = Vector2(680.0, 0.0)
	rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(rows_box)
	description_label = Label.new()
	description_label.custom_minimum_size = Vector2(360.0, 0.0)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 19)
	description_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.77))
	columns.add_child(description_label)
	status_label = Label.new()
	status_label.custom_minimum_size = Vector2(0.0, 44.0)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.9, 0.94, 0.91))
	root.add_child(status_label)
	var hint := Label.new()
	hint.text = "Up / Down  Choose     Confirm twice  Apply     Cancel  Back / Close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color(0.46, 0.62, 0.54))
	root.add_child(hint)


func get_debug_data() -> Dictionary:
	return {
		"menu_open": menu_open,
		"growth_points": GameState.get_growth_points(),
		"level": GameState.get_stat("level"),
		"experience": GameState.get_experience(),
		"confirmation": confirmation_pending,
	}
