extends Node3D
class_name PrototypeWhipWeaponLab

const TrainingWhip: WeaponDefinition = preload("res://data/weapons/training_whip.tres")

@export var opening_objective: String = "Build a Light crack chain, branch Light → Heavy to wrap and pull, then test the precision lane and crosswind."
@export var enable_editor_f8_reset: bool = true
@export var hud_refresh_interval: float = 0.05
@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var weapon_controller: WeaponController = get_node_or_null("Player/WeaponController") as WeaponController
@onready var weapon_label: Label = get_node_or_null("WhipHUD/Panel/Margin/VBox/WeaponLabel") as Label
@onready var attack_label: Label = get_node_or_null("WhipHUD/Panel/Margin/VBox/AttackLabel") as Label
@onready var physics_label: Label = get_node_or_null("WhipHUD/Panel/Margin/VBox/PhysicsLabel") as Label
@onready var interaction_label: Label = get_node_or_null("WhipHUD/Panel/Margin/VBox/InteractionLabel") as Label
@onready var route_label: Label = get_node_or_null("WhipHUD/Panel/Margin/VBox/RouteLabel") as Label

var initial_player_transform: Transform3D
var reset_count: int = 0
var hud_refresh_timer: float = 0.0


func _ready() -> void:
	add_to_group("whip_weapon_lab")
	add_to_group("debuggable")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player != null:
		initial_player_transform = player.global_transform
	if weapon_controller != null:
		weapon_controller.show_debug_hitboxes = false
		weapon_controller.combo_state_changed.connect(_on_combo_state_changed)
	set_objective(opening_objective)
	show_message("Whip Laboratory online. The violet bead is the damaging tip; the bright ring is the traveling wave front.")
	call_deferred("reset_lab")


func _process(delta: float) -> void:
	hud_refresh_timer -= delta
	if hud_refresh_timer <= 0.0:
		hud_refresh_timer = maxf(hud_refresh_interval, 0.02)
		refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F8:
			get_viewport().set_input_as_handled()
			reset_lab()


func reset_lab() -> void:
	reset_count += 1
	if player != null:
		player.global_transform = initial_player_transform
		player.velocity = Vector3.ZERO
		if player.has_method("cancel_combat_motion"):
			player.call("cancel_combat_motion")
		if player.has_method("clear_lock_on"):
			player.call("clear_lock_on")

	var action_state: Node = player.get_node_or_null("PlayerActionState") if player != null else null
	if action_state != null:
		if action_state.has_method("reset_for_respawn"):
			action_state.call("reset_for_respawn")
		elif action_state.has_method("clear_action_locks"):
			action_state.call("clear_action_locks")

	if weapon_controller != null:
		weapon_controller.equip_weapon(TrainingWhip)
		weapon_controller.reset_combo_chain()

	for target: Node in get_tree().get_nodes_in_group("combat_arena_resettable"):
		if is_ancestor_of(target) and target.has_method("reset_target"):
			target.call("reset_target")

	for resource_name: String in ["health", "stamina", "mana", "stance"]:
		GameState.set_stat(resource_name, GameState.get_stat("max_" + resource_name))

	set_objective(opening_objective)
	show_message("Whip lab reset #" + str(reset_count) + ". Crackwhip restored.")
	refresh_hud()


func _on_combo_state_changed(_debug_data: Dictionary) -> void:
	refresh_hud()


func refresh_hud() -> void:
	if weapon_controller == null:
		return
	var data: Dictionary = weapon_controller.get_debug_data()
	var rig: Dictionary = data.get("runtime_rig", {})
	if weapon_label != null:
		weapon_label.text = "WEAPON  " + str(data.get("weapon", "none")) + "  [WHIP]"
	if attack_label != null:
		attack_label.text = (
			"ATTACK  " + str(data.get("attack", "none"))
			+ "  |  " + str(data.get("phase", "idle")).to_upper()
			+ "  |  BUFFER " + str(data.get("queued", "none")).to_upper()
			+ "  |  STAMINA " + str(GameState.get_stat("stamina"))
			+ "/" + str(GameState.get_stat("max_stamina"))
		)
	if physics_label != null:
		physics_label.text = (
			"WAVE  " + str(rig.get("wave_front_meters", 0.0)) + " m"
			+ " @ " + str(rig.get("wave_speed", 0.0)) + " m/s"
			+ "  |  TIP " + str(rig.get("tip_speed", 0.0)) + " m/s"
			+ "  |  CRACK " + ("YES" if bool(rig.get("cracking", false)) else "NO")
		)
	if interaction_label != null:
		var airflow: Vector3 = rig.get("airflow", Vector3.ZERO)
		interaction_label.text = (
			"WRAPPED  " + str(rig.get("wrapped_target", "none"))
			+ "  |  TENSION " + str(rig.get("tension", 0.0)) + " N"
			+ "  |  AIR " + str(snapped(airflow.length(), 0.1)) + " m/s"
		)
	if route_label != null:
		route_label.text = (
			"LIGHT ×3: SNAP → RETURN → NEEDLE    LIGHT → HEAVY: WRAP & PULL\n"
			+ "J / LMB / L = LIGHT    K / M4 / R = HEAVY    F8 RESET"
		)


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
		"lab": "whip_weapon_v1",
		"resets": reset_count,
		"weapon": weapon_controller.get_debug_data() if weapon_controller != null else {},
	}
