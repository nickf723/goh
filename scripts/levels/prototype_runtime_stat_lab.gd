extends Node3D
class_name PrototypeRuntimeStatLab

const StatCatalogScript = preload("res://scripts/systems/stat_catalog.gd")
const StatStationScene: PackedScene = preload("res://scenes/actors/interactables/stat_lab_station.tscn")
const PracticeSword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")

const SELECTABLE_STAT_IDS: Array[String] = [
	"health",
	"stamina",
	"mana",
	"stance",
	"power",
	"dexterity",
	"arcana",
	"intelligence",
	"defense",
	"resilience",
	"constitution",
	"evasion",
	"focus",
	"charisma",
	"skill",
	"luck",
	"water",
	"earth",
	"fire",
	"air",
	"ice",
	"metal",
	"lightning",
	"poison",
	"life",
	"death",
	"body",
	"soul",
	"dreams",
	"sound",
	"space",
	"time",
	"light",
	"darkness",
	"void",
]

@export var opening_objective: String = "Use the stat stations. Overcharge Stamina or enable Infinite Stamina to stress-test every weapon combo."
@export var opening_message: String = "Runtime Stat Laboratory online. INTERACT changes a temporary stat snapshot; RESET restores entry values."
@export var exit_scene_path: String = "res://scenes/levels/prototypes/church_trial_room_v1.tscn"
@export var enable_editor_f8_reset: bool = true
@export var hud_refresh_interval: float = 0.05

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var session: RuntimeStatLabSession = get_node_or_null("RuntimeStatLabSession") as RuntimeStatLabSession
@onready var station_container: Node3D = get_node_or_null("StatStations") as Node3D
@onready var gallery_root: Node3D = get_node_or_null("GalleryRoot") as Node3D
@onready var focus_demo: Node = get_node_or_null("FocusMotionDemo")
@onready var weapon_controller: Node = get_node_or_null("Player/WeaponController")
@onready var ability_caster: Node = get_node_or_null("Player/AbilityCaster")
@onready var resource_label: Label = get_node_or_null("StatHUD/Panel/Margin/VBox/ResourceLabel") as Label
@onready var telemetry_label: Label = get_node_or_null("StatHUD/Panel/Margin/VBox/TelemetryLabel") as Label
@onready var selected_label: Label = get_node_or_null("StatHUD/Panel/Margin/VBox/SelectedLabel") as Label
@onready var controls_label: Label = get_node_or_null("StatHUD/Panel/Margin/VBox/ControlsLabel") as Label

var initial_player_transform: Transform3D
var stations: Array[StatLabStation] = []
var gallery_panels: Array[Dictionary] = []
var selected_stat_index: int = 0
var previous_stat_values: Dictionary = {}
var suppress_telemetry: bool = false
var reset_count: int = 0
var hud_refresh_timer: float = 0.0
var exiting_lab: bool = false

var weapon_attack_count: int = 0
var declared_weapon_stamina_cost: int = 0
var last_weapon_attack: String = "none"
var spell_cast_count: int = 0
var total_stamina_spent: int = 0
var total_mana_spent: int = 0
var total_focus_spent: int = 0
var last_spell: String = "none"
var was_casting: bool = false


func _ready() -> void:
	add_to_group("runtime_stat_lab_director")
	add_to_group("debuggable")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if player != null:
		initial_player_transform = player.global_transform

	if session != null:
		session.begin_session()
		session.session_changed.connect(_on_session_changed)

	if not GameState.stat_changed.is_connected(_on_stat_changed):
		GameState.stat_changed.connect(_on_stat_changed)

	if weapon_controller != null:
		weapon_controller.set("show_debug_hitboxes", true)
		if weapon_controller.has_signal("attack_started"):
			weapon_controller.connect("attack_started", Callable(self, "_on_weapon_attack_started"))
		if weapon_controller.has_signal("weapon_changed"):
			weapon_controller.connect("weapon_changed", Callable(self, "_on_weapon_changed"))

	previous_stat_values = GameState.get_stat_snapshot()
	create_stations()
	build_gallery()
	refresh_all_displays()
	set_objective(opening_objective)
	show_message(opening_message)


func _process(delta: float) -> void:
	track_cast_transition()
	hud_refresh_timer -= delta

	if hud_refresh_timer > 0.0:
		return

	hud_refresh_timer = max(hud_refresh_interval, 0.02)
	refresh_dashboard()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		reset_lab()


func create_stations() -> void:
	if station_container == null:
		return

	var stamina_color: Color = Color(1.0, 0.58, 0.18, 1.0)
	var mana_color: Color = Color(0.18, 0.82, 1.0, 1.0)
	var health_color: Color = Color(0.3, 1.0, 0.46, 1.0)
	var stance_color: Color = Color(1.0, 0.82, 0.24, 1.0)
	var focus_color: Color = Color(0.72, 0.42, 1.0, 1.0)
	var selector_color: Color = Color(1.0, 0.42, 0.72, 1.0)
	var system_color: Color = Color(0.95, 0.82, 1.0, 1.0)

	spawn_station("STAMINA BASE", "stamina", "baseline", 0, Vector3(-12.0, 0.0, -8.0), stamina_color)
	spawn_station("STAMINA 1000", "stamina", "overcharge", 1000, Vector3(-9.0, 0.0, -8.0), stamina_color)
	spawn_station("STAMINA ∞", "stamina", "infinite", 0, Vector3(-6.0, 0.0, -8.0), stamina_color)

	spawn_station("MANA BASE", "mana", "baseline", 0, Vector3(6.0, 0.0, -8.0), mana_color)
	spawn_station("MANA 1000", "mana", "overcharge", 1000, Vector3(9.0, 0.0, -8.0), mana_color)
	spawn_station("MANA ∞", "mana", "infinite", 0, Vector3(12.0, 0.0, -8.0), mana_color)

	spawn_station("HEALTH 1", "health", "minimum", 1, Vector3(-12.0, 0.0, 5.0), health_color)
	spawn_station("HEALTH 1000", "health", "overcharge", 1000, Vector3(-9.0, 0.0, 5.0), health_color)
	spawn_station("PHYSICAL HIT", "health", "damage", 2, Vector3(-6.0, 0.0, 5.0), health_color, "physical")
	spawn_station("MAGICAL HIT", "health", "damage", 2, Vector3(-3.0, 0.0, 5.0), health_color, "magical")
	spawn_station("FULL HEAL", "health", "full", 0, Vector3(0.0, 0.0, 5.0), health_color)

	spawn_station("STANCE 1", "stance", "minimum", 1, Vector3(3.0, 0.0, 5.0), stance_color)
	spawn_station("STANCE 1000", "stance", "overcharge", 1000, Vector3(6.0, 0.0, 5.0), stance_color)
	spawn_station("STANCE HIT", "stance", "damage", 2, Vector3(9.0, 0.0, 5.0), stance_color, "stance")
	spawn_station("FULL STANCE", "stance", "full", 0, Vector3(12.0, 0.0, 5.0), stance_color)

	spawn_station("FOCUS 0", "focus", "set", 0, Vector3(-12.0, 0.0, 12.0), focus_color, "preset")
	spawn_station("FOCUS 5", "focus", "set", 5, Vector3(-9.0, 0.0, 12.0), focus_color, "preset")
	spawn_station("FOCUS 10", "focus", "set", 10, Vector3(-6.0, 0.0, 12.0), focus_color, "preset")
	spawn_station("FOCUS 1000", "focus", "overcharge", 1000, Vector3(-3.0, 0.0, 12.0), focus_color)

	spawn_station("PREVIOUS STAT", get_selected_stat_id(), "select_previous", 0, Vector3(4.0, 0.0, 10.0), selector_color)
	spawn_station("NEXT STAT", get_selected_stat_id(), "select_next", 0, Vector3(7.0, 0.0, 10.0), selector_color)
	spawn_station("SELECT BASE", get_selected_stat_id(), "selected_baseline", 0, Vector3(10.0, 0.0, 10.0), selector_color)
	spawn_station("SELECT 10", get_selected_stat_id(), "selected_boost", 10, Vector3(5.5, 0.0, 13.0), selector_color)
	spawn_station("SELECT 1000", get_selected_stat_id(), "selected_overcharge", 1000, Vector3(8.5, 0.0, 13.0), selector_color)

	spawn_station("RESET ALL", "health", "reset_all", 0, Vector3(-12.0, 0.0, -13.0), system_color)
	spawn_station("EXIT LAB", "health", "exit", 0, Vector3(12.0, 0.0, -13.0), Color(1.0, 0.72, 0.28, 1.0))


func spawn_station(
	station_name: String,
	stat_id: String,
	action: String,
	value: int,
	local_position: Vector3,
	color: Color,
	context: String = ""
) -> void:
	var station: StatLabStation = StatStationScene.instantiate() as StatLabStation
	if station == null:
		return

	station.name = station_name.replace(" ", "")
	station.display_name = station_name
	station.stat_id = stat_id
	station.action = action
	station.action_value = value
	station.action_context = context
	station.accent_color = color
	station.prompt_text = "Activate " + station_name
	station.position = local_position
	station_container.add_child(station)
	stations.append(station)


func activate_station(station: StatLabStation) -> Dictionary:
	if station == null or session == null:
		return {"message": "Station unavailable.", "objective": opening_objective}

	match station.action:
		"reset_all":
			reset_lab()
			return {
				"message": "Entry snapshot restored. Infinite modes, counters, targets, and action locks reset.",
				"objective": opening_objective,
			}
		"exit":
			call_deferred("exit_lab")
			return {
				"message": "Restoring the entry snapshot before leaving the laboratory.",
				"objective": "Return to the prototype title flow.",
			}
		"select_previous":
			select_stat(-1)
			return selector_result("Selected previous stat: ")
		"select_next":
			select_stat(1)
			return selector_result("Selected next stat: ")

	var target_stat: String = station.stat_id
	var resolved_action: String = station.action

	match station.action:
		"selected_baseline":
			target_stat = get_selected_stat_id()
			resolved_action = "baseline"
		"selected_boost":
			target_stat = get_selected_stat_id()
			resolved_action = "boost"
		"selected_overcharge":
			target_stat = get_selected_stat_id()
			resolved_action = "overcharge"

	suppress_telemetry = true
	var result: Dictionary = session.apply_station_action(
		target_stat,
		resolved_action,
		station.action_value,
		station.action_context
	)
	previous_stat_values = GameState.get_stat_snapshot()
	suppress_telemetry = false
	refresh_all_displays()
	return result


func selector_result(prefix: String) -> Dictionary:
	refresh_all_displays()
	var stat_id: String = get_selected_stat_id()
	return {
		"message": prefix + stat_id.capitalize() + " [" + session.get_implementation_status(stat_id) + "].",
		"objective": "Use SELECT BASE, SELECT 10, or SELECT 1000 to mutate the highlighted stat.",
	}


func select_stat(direction: int) -> void:
	if SELECTABLE_STAT_IDS.is_empty():
		return

	selected_stat_index = (
		selected_stat_index
		+ direction
		+ SELECTABLE_STAT_IDS.size()
	) % SELECTABLE_STAT_IDS.size()


func get_selected_stat_id() -> String:
	if SELECTABLE_STAT_IDS.is_empty():
		return "focus"

	selected_stat_index = clamp(selected_stat_index, 0, SELECTABLE_STAT_IDS.size() - 1)
	return SELECTABLE_STAT_IDS[selected_stat_index]


func reset_lab() -> void:
	if session == null:
		return

	reset_count += 1
	suppress_telemetry = true
	session.restore_entry_snapshot(true)
	reset_player()
	reset_training_targets()
	reset_focus_demo()
	reset_telemetry()
	previous_stat_values = GameState.get_stat_snapshot()
	suppress_telemetry = false
	set_objective(opening_objective)
	refresh_all_displays()


func reset_player() -> void:
	if player == null:
		return

	player.global_transform = initial_player_transform
	player.velocity = Vector3.ZERO

	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")
	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")

	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null and action_state.has_method("reset_for_respawn"):
		action_state.call("reset_for_respawn")

	if weapon_controller != null:
		if weapon_controller.has_method("equip_weapon"):
			weapon_controller.call("equip_weapon", PracticeSword)
		if weapon_controller.has_method("reset_combo_chain"):
			weapon_controller.call("reset_combo_chain")


func reset_training_targets() -> void:
	for target: Node in get_tree().get_nodes_in_group("combat_arena_resettable"):
		if target != null and is_instance_valid(target) and target.has_method("reset_target"):
			target.call("reset_target")


func reset_focus_demo() -> void:
	Engine.time_scale = 1.0
	if focus_demo != null and focus_demo.has_method("reset_demo"):
		focus_demo.call("reset_demo")


func reset_telemetry() -> void:
	weapon_attack_count = 0
	declared_weapon_stamina_cost = 0
	last_weapon_attack = "none"
	spell_cast_count = 0
	total_stamina_spent = 0
	total_mana_spent = 0
	total_focus_spent = 0
	last_spell = "none"
	was_casting = false


func exit_lab() -> void:
	if exiting_lab:
		return

	exiting_lab = true
	Engine.time_scale = 1.0
	if session != null:
		session.prepare_exit()

	if exit_scene_path != "":
		get_tree().change_scene_to_file(exit_scene_path)


func track_cast_transition() -> void:
	if player == null:
		return

	var action_state: Node = player.get_node_or_null("PlayerActionState")
	var is_casting: bool = false
	if action_state != null:
		is_casting = bool(action_state.get("is_casting"))

	if is_casting and not was_casting:
		spell_cast_count += 1
		if ability_caster != null and ability_caster.has_method("get_debug_data"):
			var data: Dictionary = ability_caster.call("get_debug_data")
			last_spell = str(data.get("current_ability", "unknown"))

	was_casting = is_casting


func _on_stat_changed(stat_name: String, value: int) -> void:
	var previous_value: int = int(previous_stat_values.get(stat_name, value))
	previous_stat_values[stat_name] = value

	if suppress_telemetry or value >= previous_value:
		refresh_all_displays()
		return

	var spent: int = previous_value - value
	match stat_name:
		"stamina":
			total_stamina_spent += spent
		"mana":
			total_mana_spent += spent
		"focus":
			total_focus_spent += spent

	refresh_all_displays()


func _on_weapon_attack_started(attack: WeaponAttackDefinition) -> void:
	weapon_attack_count += 1
	if attack != null:
		last_weapon_attack = attack.display_name
		declared_weapon_stamina_cost += attack.stamina_cost
	refresh_dashboard()


func _on_weapon_changed(_weapon: WeaponDefinition) -> void:
	refresh_dashboard()


func _on_session_changed(_debug_data: Dictionary) -> void:
	refresh_all_displays()


func refresh_all_displays() -> void:
	refresh_stations()
	refresh_gallery()
	refresh_dashboard()


func refresh_stations() -> void:
	if session == null:
		return

	var selected_stat: String = get_selected_stat_id()
	for station: StatLabStation in stations:
		if station == null or not is_instance_valid(station):
			continue
		if station.action.begins_with("select"):
			station.stat_id = selected_stat
		station.refresh_from_session(session)


func refresh_dashboard() -> void:
	if session == null:
		return

	if resource_label != null:
		resource_label.text = (
			"HEALTH " + format_resource("health")
			+ "    STAMINA " + format_resource("stamina")
			+ "    MANA " + format_resource("mana")
			+ "    STANCE " + format_resource("stance")
		)

	var weapon_name: String = "none"
	var attack_name: String = "none"
	if weapon_controller != null and weapon_controller.has_method("get_debug_data"):
		var weapon_data: Dictionary = weapon_controller.call("get_debug_data")
		weapon_name = str(weapon_data.get("weapon", "none"))
		attack_name = str(weapon_data.get("attack", "none"))

	var ability_name: String = "none"
	var ability_cost: int = 0
	if ability_caster != null and ability_caster.has_method("get_debug_data"):
		var ability_data: Dictionary = ability_caster.call("get_debug_data")
		ability_name = str(ability_data.get("current_ability", "none"))
		ability_cost = int(ability_data.get("mana_cost", 0))

	if telemetry_label != null:
		telemetry_label.text = (
			"WEAPON  " + weapon_name + "  |  CURRENT " + attack_name
			+ "\nATTACKS " + str(weapon_attack_count)
			+ "  |  DECLARED COST " + str(declared_weapon_stamina_cost)
			+ "  |  STAMINA SPENT " + str(total_stamina_spent)
			+ "\nSPELL  " + ability_name + " (" + str(ability_cost) + " mana)"
			+ "  |  CASTS " + str(spell_cast_count)
			+ "  |  MANA SPENT " + str(total_mana_spent)
			+ "\nFOCUS " + str(GameState.get_stat("focus"))
			+ "  |  FOCUS SPENT " + str(total_focus_spent)
			+ "  |  WORLD SPEED " + str(snapped(Engine.time_scale, 0.01))
			+ "\nLAST  " + session.last_mutation
		)

	if selected_label != null:
		var selected_stat: String = get_selected_stat_id()
		selected_label.text = (
			"SELECTED STAT  " + selected_stat.to_upper()
			+ "  [" + session.get_implementation_status(selected_stat) + "]"
			+ "  VALUE " + session.get_stat_value_text(selected_stat)
			+ "\n" + session.get_status_explanation(selected_stat)
		)

	if controls_label != null:
		controls_label.text = (
			"CONTROLLER-FIRST ACTIONS  •  INTERACT  •  LIGHT  •  HEAVY  •  FOCUS  •  CAST  •  DODGE  •  RESET"
			+ "\nLaboratory values are temporary and never autosaved."
		)


func format_resource(resource_id: String) -> String:
	var suffix: String = " ∞" if session.is_infinite(resource_id) else ""
	return session.get_stat_value_text(resource_id) + suffix


func build_gallery() -> void:
	if gallery_root == null:
		return

	create_gallery_panel("OFFENSE", ["power", "dexterity", "arcana", "intelligence"], Vector3(-12.0, 2.7, 18.6), 5.8)
	create_gallery_panel("PROTECTION", ["defense", "resilience", "constitution", "evasion"], Vector3(-6.0, 2.7, 18.6), 5.8)
	create_gallery_panel("UTILITY", ["focus", "charisma", "skill", "luck"], Vector3(0.0, 2.7, 18.6), 5.8)
	create_gallery_panel("AFFINITY A", ["water", "earth", "fire", "air", "ice", "metal", "lightning", "poison"], Vector3(6.0, 2.7, 18.6), 5.8)
	create_gallery_panel("AFFINITY B", ["life", "death", "body", "soul", "dreams", "sound", "space", "time", "light", "darkness", "void"], Vector3(12.0, 2.7, 18.6), 5.8)


func create_gallery_panel(title: String, stat_ids: Array, panel_position: Vector3, width: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = title.replace(" ", "") + "Panel"
	root.position = panel_position
	gallery_root.add_child(root)

	var backdrop: MeshInstance3D = MeshInstance3D.new()
	var backdrop_mesh: BoxMesh = BoxMesh.new()
	backdrop_mesh.size = Vector3(width, 4.8, 0.16)
	backdrop.mesh = backdrop_mesh
	backdrop.material_override = create_panel_material()
	root.add_child(backdrop)

	var label: Label3D = Label3D.new()
	label.position = Vector3(0.0, 0.0, -0.12)
	label.font_size = 25
	label.pixel_size = 0.006
	label.billboard = 1
	label.outline_size = 5
	label.modulate = Color(0.88, 0.9, 1.0, 1.0)
	root.add_child(label)

	gallery_panels.append({
		"title": title,
		"stat_ids": stat_ids.duplicate(),
		"label": label,
	})


func create_panel_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.055, 0.04, 0.09, 0.94)
	material.metallic = 0.15
	material.roughness = 0.58
	return material


func refresh_gallery() -> void:
	if session == null:
		return

	for panel: Dictionary in gallery_panels:
		var label: Label3D = panel.get("label") as Label3D
		if label == null:
			continue

		var lines: Array[String] = [str(panel.get("title", "STATS"))]
		var stat_ids: Array = panel.get("stat_ids", [])

		for stat_variant: Variant in stat_ids:
			var stat_id: String = str(stat_variant)
			lines.append(
				stat_id.to_upper()
				+ "  [" + session.get_implementation_status(stat_id) + "]  "
				+ session.get_stat_value_text(stat_id)
			)

		label.text = "\n".join(lines)


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text)


func get_debug_data() -> Dictionary:
	return {
		"lab": "runtime_stats_v0_7",
		"resets": reset_count,
		"selected_stat": get_selected_stat_id(),
		"session": session.get_debug_data() if session != null else {},
		"attacks": weapon_attack_count,
		"casts": spell_cast_count,
		"stamina_spent": total_stamina_spent,
		"mana_spent": total_mana_spent,
	}


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if not exiting_lab and session != null and session.session_active:
		session.prepare_exit()
