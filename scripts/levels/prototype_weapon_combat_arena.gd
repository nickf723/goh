extends Node3D
class_name PrototypeWeaponCombatArena

const CombatArenaLoadoutScript = preload("res://scripts/systems/combat_arena_loadout.gd")
const WeaponTechniqueCatalogScript = preload("res://scripts/weapons/weapon_technique_catalog.gd")
const PracticeSword: WeaponDefinition = preload("res://data/weapons/practice_sword.tres")
const GoblinScene: PackedScene = preload("res://scenes/actors/enemies/goblin_drone.tscn")
const GremlinScene: PackedScene = preload("res://scenes/actors/enemies/gremlin_drone.tscn")
const CombatTrainingTargetScene: PackedScene = preload("res://scenes/actors/testing/combat_training_target.tscn")

const MAX_GUIDE_ROUTES: int = 10
const MAX_ROUTE_DEPTH: int = 6
const TECHNIQUE_IDS: Array[String] = [
	WeaponTechniqueCatalogScript.CONTEXT_DASH,
	WeaponTechniqueCatalogScript.CONTEXT_AERIAL_NEUTRAL,
	WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD,
	WeaponTechniqueCatalogScript.CONTEXT_AERIAL_DOWN,
]

@export var opening_objective: String = "Test every grounded branch, then complete the Dash, Aerial Sweep, Aerial Pursuit, and Plunging Heavy techniques."
@export var opening_message: String = "Combat Combo Laboratory online. All equipment, upgrades, and weapon mastery are temporarily unlocked; combat resources refill automatically."
@export var enable_editor_f8_reset: bool = true

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var weapon_controller: Node = get_node_or_null("Player/WeaponController")
@onready var enemy_container: Node3D = get_node_or_null("EnemyContainer") as Node3D
@onready var goblin_spawn: Node3D = get_node_or_null("GoblinSpawn") as Node3D
@onready var gremlin_spawn: Node3D = get_node_or_null("GremlinSpawn") as Node3D

var initial_player_transform: Transform3D
var entry_progression_snapshot: Dictionary = {}
var sandbox_summary: Dictionary = {}
var snapshot_restored: bool = false
var reset_count: int = 0

var current_weapon_class: String = ""
var current_combo_routes: Array[Dictionary] = []
var current_route_keys: Dictionary = {}
var completed_route_keys: Dictionary = {}
var completed_technique_keys: Dictionary = {}


func _ready() -> void:
	add_to_group("combat_arena_director")
	add_to_group("debuggable")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	entry_progression_snapshot = CombatArenaLoadoutScript.capture_state()
	sandbox_summary = CombatArenaLoadoutScript.apply_everything_unlocked()

	if player != null:
		initial_player_transform = player.global_transform

	connect_weapon_controller()
	build_combo_target_cluster()
	refresh_arena_signage()
	set_objective(opening_objective)
	show_message(opening_message)
	call_deferred("reset_arena")


func _exit_tree() -> void:
	restore_entry_progression()


func _process(_delta: float) -> void:
	CombatArenaLoadoutScript.refill_combat_resources()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		reset_arena()


func connect_weapon_controller() -> void:
	if weapon_controller == null:
		return

	weapon_controller.set("show_debug_hitboxes", true)
	connect_signal_if_available("combo_state_changed", "_on_combo_state_changed")
	connect_signal_if_available("weapon_changed", "_on_weapon_changed")
	connect_signal_if_available("attack_finished", "_on_attack_finished")


func connect_signal_if_available(signal_name: StringName, method_name: StringName) -> void:
	if weapon_controller == null or not weapon_controller.has_signal(signal_name):
		return
	var callback := Callable(self, method_name)
	if not weapon_controller.is_connected(signal_name, callback):
		weapon_controller.connect(signal_name, callback)


func reset_arena() -> void:
	reset_count += 1
	sandbox_summary = CombatArenaLoadoutScript.apply_everything_unlocked()
	reset_player()
	reset_training_targets()
	respawn_enemies()
	CombatArenaLoadoutScript.refill_combat_resources()
	set_objective(opening_objective)
	show_message(
		"Combo laboratory reset #"
		+ str(reset_count)
		+ ". Current weapon preserved; mastery and upgrades remain fully unlocked."
	)
	rebuild_combo_guide()


func reset_player() -> void:
	if player == null:
		return

	var preserved_weapon: WeaponDefinition = null
	if weapon_controller != null:
		var weapon_value: Variant = weapon_controller.get("equipped_weapon")
		if weapon_value is WeaponDefinition:
			preserved_weapon = weapon_value as WeaponDefinition

	player.global_transform = initial_player_transform
	player.velocity = Vector3.ZERO

	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")
	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")

	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null:
		if action_state.has_method("reset_for_respawn"):
			action_state.call("reset_for_respawn")
		elif action_state.has_method("clear_action_locks"):
			action_state.call("clear_action_locks")

	if weapon_controller != null:
		if weapon_controller.has_method("equip_weapon"):
			weapon_controller.call(
				"equip_weapon",
				preserved_weapon if preserved_weapon != null else PracticeSword
			)
		if weapon_controller.has_method("reset_combo_chain"):
			weapon_controller.call("reset_combo_chain")


func reset_training_targets() -> void:
	for target: Node in get_tree().get_nodes_in_group("combat_arena_resettable"):
		if target != null and is_instance_valid(target) and target.has_method("reset_target"):
			target.call("reset_target")


func respawn_enemies() -> void:
	if enemy_container == null:
		return

	for child: Node in enemy_container.get_children():
		enemy_container.remove_child(child)
		child.queue_free()

	spawn_enemy(GoblinScene, goblin_spawn, "ArenaGoblin")
	spawn_enemy(GremlinScene, gremlin_spawn, "ArenaGremlin")


func spawn_enemy(scene: PackedScene, marker: Node3D, enemy_name: String) -> void:
	if scene == null or marker == null or enemy_container == null:
		return

	var enemy: Node = scene.instantiate()
	if not enemy is Node3D:
		enemy.queue_free()
		return

	enemy.name = enemy_name
	enemy_container.add_child(enemy)
	(enemy as Node3D).global_transform = marker.global_transform
	enemy.add_to_group("combat_arena_spawned")


func build_combo_target_cluster() -> void:
	if get_node_or_null("ComboTargetCluster") != null:
		return

	var cluster := Node3D.new()
	cluster.name = "ComboTargetCluster"
	add_child(cluster)

	var title := Label3D.new()
	title.name = "ComboTargetTitle"
	title.position = Vector3(0.0, 2.8, 6.9)
	title.pixel_size = 0.007
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.82, 0.7, 1.0, 1.0)
	title.text = "LAUNCH • AERIAL • CLEAVE LAB"
	title.font_size = 42
	title.outline_size = 6
	cluster.add_child(title)

	spawn_combo_target(cluster, "CleaveLeftTarget", "CLEAVE LEFT", Vector3(-2.35, 0.0, 6.8))
	spawn_combo_target(cluster, "AerialTarget", "LAUNCH / AERIAL", Vector3(0.0, 0.0, 6.8))
	spawn_combo_target(cluster, "CleaveRightTarget", "CLEAVE RIGHT", Vector3(2.35, 0.0, 6.8))


func spawn_combo_target(
	parent: Node3D,
	node_name: String,
	label_text: String,
	target_position: Vector3
) -> void:
	if parent == null or CombatTrainingTargetScene == null:
		return

	var target: Node = CombatTrainingTargetScene.instantiate()
	if not target is Node3D:
		target.queue_free()
		return

	target.name = node_name
	(target as Node3D).position = target_position
	target.set("target_label", label_text)
	parent.add_child(target)


func refresh_arena_signage() -> void:
	var title: Label3D = get_node_or_null("ArenaTitle") as Label3D
	var subtitle: Label3D = get_node_or_null("ArenaSubtitle") as Label3D
	var instructions: Label3D = get_node_or_null("Instructions") as Label3D

	if title != null:
		title.text = "COMBAT COMBO LABORATORY"
	if subtitle != null:
		subtitle.text = "ALL MASTERY • ALL UPGRADES • AUTO-REFILL • TEMPORARY SANDBOX"
	if instructions != null:
		instructions.text = "RACKS SWITCH WEAPONS       TARGET CLUSTER TESTS LAUNCH / PURSUIT / CLEAVE       F7 GUIDE       F8 RESET"


func _on_combo_state_changed(debug_data: Dictionary) -> void:
	record_context_technique(debug_data)


func _on_weapon_changed(_weapon: WeaponDefinition) -> void:
	rebuild_combo_guide()


func _on_attack_finished(_attack_id: String) -> void:
	record_completed_combo()


func rebuild_combo_guide() -> void:
	current_combo_routes.clear()
	current_route_keys.clear()
	current_weapon_class = ""

	if weapon_controller == null:
		return

	var weapon_value: Variant = weapon_controller.get("equipped_weapon")
	if not weapon_value is WeaponDefinition:
		return

	var weapon: WeaponDefinition = weapon_value as WeaponDefinition
	current_weapon_class = weapon.weapon_class
	var moveset: WeaponMovesetDefinition = weapon.get_moveset()
	if moveset == null:
		return

	for input_kind: String in ["light", "heavy"]:
		var entry_attack: WeaponAttackDefinition = moveset.get_entry_attack(input_kind)
		if entry_attack == null:
			continue
		var tokens: Array[String] = [input_token(input_kind)]
		var attack_ids: Array[String] = [entry_attack.attack_id]
		var visited: Dictionary = {entry_attack.attack_id: true}
		collect_combo_routes(moveset, entry_attack, tokens, attack_ids, visited, 1)

	for route: Dictionary in current_combo_routes:
		current_route_keys[str(route.get("key", ""))] = true


func collect_combo_routes(
	moveset: WeaponMovesetDefinition,
	attack: WeaponAttackDefinition,
	tokens: Array[String],
	attack_ids: Array[String],
	visited: Dictionary,
	depth: int
) -> void:
	if moveset == null or attack == null or current_combo_routes.size() >= MAX_GUIDE_ROUTES:
		return

	var follow_ups: Array[Dictionary] = []
	for input_kind: String in ["light", "heavy"]:
		var next_attack: WeaponAttackDefinition = moveset.get_follow_up(attack, input_kind)
		if next_attack != null:
			follow_ups.append({"input": input_kind, "attack": next_attack})

	if follow_ups.is_empty() or depth >= MAX_ROUTE_DEPTH:
		append_combo_route(tokens, attack_ids, attack.display_name, depth >= MAX_ROUTE_DEPTH)
		return

	for follow_up: Dictionary in follow_ups:
		if current_combo_routes.size() >= MAX_GUIDE_ROUTES:
			return

		var input_kind: String = str(follow_up.get("input", "light"))
		var next_attack: WeaponAttackDefinition = follow_up.get("attack") as WeaponAttackDefinition
		if next_attack == null:
			continue

		var next_tokens: Array[String] = []
		next_tokens.assign(tokens)
		next_tokens.append(input_token(input_kind))

		var next_attack_ids: Array[String] = []
		next_attack_ids.assign(attack_ids)
		next_attack_ids.append(next_attack.attack_id)

		if visited.has(next_attack.attack_id):
			append_combo_route(next_tokens, next_attack_ids, next_attack.display_name, true)
			continue

		var next_visited: Dictionary = visited.duplicate(true)
		next_visited[next_attack.attack_id] = true
		collect_combo_routes(
			moveset,
			next_attack,
			next_tokens,
			next_attack_ids,
			next_visited,
			depth + 1
		)


func append_combo_route(
	tokens: Array[String],
	attack_ids: Array[String],
	final_name: String,
	loops: bool
) -> void:
	var key: String = combo_route_key(current_weapon_class, tokens)
	for route: Dictionary in current_combo_routes:
		if str(route.get("key", "")) == key:
			return

	current_combo_routes.append({
		"key": key,
		"tokens": tokens.duplicate(),
		"attack_ids": attack_ids.duplicate(),
		"final_name": final_name,
		"loops": loops,
	})


func record_completed_combo() -> void:
	if weapon_controller == null or current_weapon_class == "":
		return
	if not weapon_controller.has_method("get_debug_data"):
		return

	var data: Dictionary = weapon_controller.call("get_debug_data")
	var chain_value: Variant = data.get("chain", [])
	if not chain_value is Array:
		return

	var weapon_value: Variant = weapon_controller.get("equipped_weapon")
	if not weapon_value is WeaponDefinition:
		return

	var moveset: WeaponMovesetDefinition = (weapon_value as WeaponDefinition).get_moveset()
	if moveset == null:
		return

	var tokens: Array[String] = []
	for attack_id_value: Variant in chain_value as Array:
		var attack: WeaponAttackDefinition = moveset.get_attack(str(attack_id_value))
		if attack == null:
			return
		tokens.append(input_token(attack.input_kind))

	var key: String = combo_route_key(current_weapon_class, tokens)
	if current_route_keys.has(key):
		completed_route_keys[key] = true


func record_context_technique(debug_data: Dictionary) -> void:
	var weapon_class_id: String = str(debug_data.get("class", current_weapon_class))
	var technique_id: String = str(debug_data.get("technique", "none"))
	if weapon_class_id == "" or technique_id == "none" or not TECHNIQUE_IDS.has(technique_id):
		return
	completed_technique_keys[weapon_class_id + ":" + technique_id] = true


func get_technique_instruction(weapon_class_id: String, technique_id: String) -> String:
	match technique_id:
		WeaponTechniqueCatalogScript.CONTEXT_DASH:
			return WeaponTechniqueCatalogScript.get_dash_technique_name(weapon_class_id) + " [Dodge + Light/Heavy]"
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_NEUTRAL:
			return WeaponTechniqueCatalogScript.get_aerial_technique_name(weapon_class_id, technique_id) + " [Jump + neutral Light]"
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD:
			return WeaponTechniqueCatalogScript.get_aerial_technique_name(weapon_class_id, technique_id) + " [Jump + move + Light]"
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_DOWN:
			return WeaponTechniqueCatalogScript.get_aerial_technique_name(weapon_class_id, technique_id) + " [Jump + Heavy]"
		_:
			return technique_id.capitalize()


func input_token(input_kind: String) -> String:
	return "H" if input_kind == "heavy" else "L"


func combo_route_key(weapon_class_id: String, tokens: Array[String]) -> String:
	return weapon_class_id + ":" + "".join(tokens)


func restore_entry_progression() -> void:
	if snapshot_restored or entry_progression_snapshot.is_empty():
		return
	snapshot_restored = true
	CombatArenaLoadoutScript.restore_state(entry_progression_snapshot)


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
		"arena": "weapon_combat_v0_9",
		"resets": reset_count,
		"sandbox": sandbox_summary.duplicate(true),
		"snapshot_captured": not entry_progression_snapshot.is_empty(),
		"spawned_enemies": get_tree().get_nodes_in_group("combat_arena_spawned").size(),
		"combo_routes": current_combo_routes.size(),
		"completed_routes": completed_route_keys.size(),
		"completed_techniques": completed_technique_keys.size(),
		"weapon": weapon_controller.call("get_debug_data") if weapon_controller != null and weapon_controller.has_method("get_debug_data") else {},
	}
