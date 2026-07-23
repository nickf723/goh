extends Node3D
class_name PrototypeChainWeaponLab

const TrainingChain: WeaponDefinition = preload("res://data/weapons/training_chain.tres")

@export var opening_objective: String = "Use LIGHT to orbit the weighted chain. Branch to HEAVY for wide breakers and meteor slams."
@export var enable_editor_f8_reset: bool = true
@export var hud_refresh_interval: float = 0.05
@export_group("Practice Stamina")
@export_range(0.0, 20.0, 0.25) var stamina_regeneration_per_second: float = 4.0
@export_range(0.0, 5.0, 0.05) var stamina_regeneration_delay: float = 0.8

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var weapon_controller: WeaponController = get_node_or_null("Player/WeaponController") as WeaponController
@onready var weapon_label: Label = get_node_or_null("ChainHUD/Panel/Margin/VBox/WeaponLabel") as Label
@onready var attack_label: Label = get_node_or_null("ChainHUD/Panel/Margin/VBox/AttackLabel") as Label
@onready var physics_label: Label = get_node_or_null("ChainHUD/Panel/Margin/VBox/PhysicsLabel") as Label
@onready var route_label: Label = get_node_or_null("ChainHUD/Panel/Margin/VBox/RouteLabel") as Label

var initial_player_transform: Transform3D
var reset_count: int = 0
var hud_refresh_timer: float = 0.0
var stamina_regeneration_cooldown: float = 0.0
var stamina_regeneration_accumulator: float = 0.0
var last_stamina: int = 0


func _ready() -> void:
	add_to_group("chain_weapon_lab")
	add_to_group("debuggable")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player != null:
		initial_player_transform = player.global_transform
	if weapon_controller != null:
		weapon_controller.show_debug_hitboxes = false
		weapon_controller.combo_state_changed.connect(_on_combo_state_changed)
	last_stamina = GameState.get_stat("stamina")
	if not GameState.stat_changed.is_connected(_on_stat_changed):
		GameState.stat_changed.connect(_on_stat_changed)
	set_objective(opening_objective)
	show_message("Chain Weapon Laboratory online. The glowing meteor is the real swept contact point.")
	call_deferred("reset_lab")


func _process(delta: float) -> void:
	update_stamina_regeneration(delta)
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
		weapon_controller.equip_weapon(TrainingChain)
		weapon_controller.reset_combo_chain()

	for target: Node in get_tree().get_nodes_in_group("combat_arena_resettable"):
		if target.has_method("reset_target"):
			target.call("reset_target")

	for resource_name: String in ["health", "stamina", "mana", "stance"]:
		GameState.set_stat(resource_name, GameState.get_stat("max_" + resource_name))

	last_stamina = GameState.get_stat("stamina")
	stamina_regeneration_cooldown = 0.0
	stamina_regeneration_accumulator = 0.0
	set_objective(opening_objective)
	show_message("Chain lab reset #" + str(reset_count) + ". Meteor Chain restored.")
	refresh_hud()


func _on_combo_state_changed(_debug_data: Dictionary) -> void:
	refresh_hud()


func _on_stat_changed(stat_name: String, value: int) -> void:
	if stat_name != "stamina":
		return
	if value < last_stamina:
		stamina_regeneration_cooldown = stamina_regeneration_delay
		stamina_regeneration_accumulator = 0.0
	last_stamina = value


func update_stamina_regeneration(delta: float) -> void:
	if stamina_regeneration_per_second <= 0.0:
		return
	var current_stamina: int = GameState.get_stat("stamina")
	var maximum_stamina: int = GameState.get_stat("max_stamina")
	if current_stamina >= maximum_stamina:
		stamina_regeneration_accumulator = 0.0
		return
	if stamina_regeneration_cooldown > 0.0:
		stamina_regeneration_cooldown = maxf(stamina_regeneration_cooldown - delta, 0.0)
		return
	stamina_regeneration_accumulator += stamina_regeneration_per_second * delta
	var whole_points: int = floori(stamina_regeneration_accumulator)
	if whole_points <= 0:
		return
	stamina_regeneration_accumulator -= float(whole_points)
	GameState.restore_stamina(whole_points)


func refresh_hud() -> void:
	if weapon_controller == null:
		return
	var data: Dictionary = weapon_controller.get_debug_data()
	var rig: Dictionary = data.get("runtime_rig", {})
	if weapon_label != null:
		weapon_label.text = "WEAPON  " + str(data.get("weapon", "none")) + "  [CHAIN]"
	if attack_label != null:
		attack_label.text = (
			"ATTACK  "
			+ str(data.get("attack", "none"))
			+ "  |  "
			+ str(data.get("phase", "idle")).to_upper()
			+ "  |  BUFFER "
			+ str(data.get("queued", "none")).to_upper()
			+ "  |  STAMINA "
			+ str(GameState.get_stat("stamina"))
			+ "/"
			+ str(GameState.get_stat("max_stamina"))
		)
	if physics_label != null:
		physics_label.text = (
			"TIP SPEED  "
			+ str(rig.get("tip_speed", 0.0))
			+ " m/s  |  MOMENTUM "
			+ str(rig.get("momentum", 0.0))
			+ "  |  TENSION "
			+ str(rig.get("tension", 0.0))
			+ " N"
		)
	if route_label != null:
		route_label.text = (
			"LIGHT: ORBIT → RETURN → RECALL    HEAVY: METEOR DROP\n"
			+ "J / LMB / LB = LIGHT    K / RMB / RB = HEAVY    F8 RESET"
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
		"lab": "chain_weapon_v1",
		"resets": reset_count,
		"weapon": weapon_controller.get_debug_data() if weapon_controller != null else {},
	}
