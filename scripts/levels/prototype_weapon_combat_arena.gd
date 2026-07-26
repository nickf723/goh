extends Node3D
class_name PrototypeWeaponCombatArena

const CombatArenaLoadoutScript = preload("res://scripts/systems/combat_arena_loadout.gd")
const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")
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
@export var hud_refresh_interval: float = 0.05

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var weapon_controller: Node = get_node_or_null("Player/WeaponController")
@onready var enemy_container: Node3D = get_node_or_null("EnemyContainer") as Node3D
@onready var goblin_spawn: Node3D = get_node_or_null("GoblinSpawn") as Node3D
@onready var gremlin_spawn: Node3D = get_node_or_null("GremlinSpawn") as Node3D
@onready var weapon_label: Label = get_node_or_null("CombatHUD/Panel/Margin/VBox/WeaponLabel") as Label
@onready var attack_label: Label = get_node_or_null("CombatHUD/Panel/Margin/VBox/AttackLabel") as Label
@onready var queue_label: Label = get_node_or_null("CombatHUD/Panel/Margin/VBox/QueueLabel") as Label
@onready var cancel_label: Label = get_node_or_null("CombatHUD/Panel/Margin/VBox/CancelLabel") as Label

var initial_player_transform: Transform3D
var entry_progression_snapshot: Dictionary = {}
var sandbox_summary: Dictionary = {}
var snapshot_restored: bool = false
var reset_count: int = 0
var hud_refresh_timer: float = 0.0

var sandbox_label: Label
var combo_guide_label: Label
var technique_guide_label: Label
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

	if weapon_controller != null:
		weapon_controller.set("show_debug_hitboxes", true)
		if weapon_controller.has_signal("combo_state_changed"):
			weapon_controller.connect("combo_state_changed", Callable(self, "_on_combo_state_changed"))
		if weapon_controller.has_signal("weapon_changed"):
			weapon_controller.connect("weapon_changed", Callable(self, "_on_weapon_changed"))
		if weapon_controller.has_signal("attack_finished"):
			weapon_controller.connect("attack_finished", Callable(self, "_on_attack_finished"))

	build_sandbox_hud()
	build_combo_target_cluster()
	refresh_arena_signage()
	set_objective(opening_objective)
	show_message(opening_message)
	call_deferred("reset_arena")


func _exit_tree() -> void:
	restore_entry_progression()


func _process(delta: float) -> void:
	CombatArenaLoadoutScript.refill_combat_resources()
	hud_refresh_timer -= delta
	if hud_refresh_timer > 0.0:
		return

	hud_refresh_timer = max(hud_refresh_interval, 0.02)
	refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return

	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		reset_arena()


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
	refresh_hud()


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
			weapon_controller.call("equip_weapon", preserved_weapon if preserved_weapon != null else PracticeSword)
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

	var cluster: Node3D = Node3D.new()
	cluster.name = "ComboTargetCluster"
	add_child(cluster)

	var title: Label3D = Label3D.new()
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


func spawn_combo_target(parent: Node3D, node_name: String, label_text: String, target_position: Vector3) -> void:
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


func build_sandbox_hud() -> void:
	var panel: PanelContainer = get_node_or_null("CombatHUD/Panel") as PanelContainer
	var vbox: VBoxContainer = get_node_or_null("CombatHUD/Panel/Margin/VBox") as VBoxContainer
	if panel == null or vbox == null:
		return

	panel.offset_right = maxf(panel.offset_right, 980.0)
	panel.offset_bottom = maxf(panel.offset_bottom, 470.0)

	sandbox_label = create_hud_label(
		vbox,
		"SandboxLabel",
		18,
		Color(1.0, 0.78, 0.34, 1.0)
	)
	combo_guide_label = create_hud_label(
		vbox,
		"ComboGuideLabel",
		15,
		Color(0.8, 0.9, 1.0, 1.0)
	)
	technique_guide_label = create_hud_label(
		vbox,
		"TechniqueGuideLabel",
		15,
		Color(0.78, 1.0, 0.78, 1.0)
	)


func create_hud_label(parent: VBoxContainer, node_name: String, font_size: int, color: Color) -> Label:
	var existing: Label = parent.get_node_or_null(node_name) as Label
	if existing != null:
		return existing
	var label: Label = Label.new()
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func refresh_arena_signage() -> void:
	var title: Label3D = get_node_or_null("ArenaTitle") as Label3D
	var subtitle: Label3D = get_node_or_null("ArenaSubtitle") as Label3D
	var instructions: Label3D = get_node_or_null("Instructions") as Label3D
	if title != null:
		title.text = "COMBAT COMBO LABORATORY"
	if subtitle != null:
		subtitle.text = "ALL MASTERY • ALL UPGRADES • AUTO-REFILL • TEMPORARY SANDBOX"
	if instructions != null:
		instructions.text = "RACKS SWITCH WEAPONS       TARGET CLUSTER TESTS LAUNCH / PURSUIT / CLEAVE       F8 RESETS"


func _on_combo_state_changed(debug_data: Dictionary) -> void:
	record_context_technique(debug_data)
	refresh_hud()


func _on_weapon_changed(_weapon: WeaponDefinition) -> void:
	rebuild_combo_guide()
	refresh_hud()


func _on_attack_finished(_attack_id: String) -> void:
	record_completed_combo()
	refresh_hud()


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

		var next_tokens: Array[String] = tokens.duplicate()
		next_tokens.append(input_token(input_kind))
		var next_attack_ids: Array[String] = attack_ids.duplicate()
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


func append_combo_route(tokens: Array[String], attack_ids: Array[String], final_name: String, loops: bool) -> void:
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
	var data: Dictionary = weapon_controller.call("get_debug_data") if weapon_controller.has_method("get_debug_data") else {}
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
	for attack_id_variant: Variant in chain_value as Array:
		var attack: WeaponAttackDefinition = moveset.get_attack(str(attack_id_variant))
		if attack == null:
			return
		tokens.append(input_token(attack.input_kind))

	var key: String = combo_route_key(current_weapon_class, tokens)
	if current_route_keys.has(key):
		completed_route_keys[key] = true


func record_context_technique(debug_data: Dictionary) -> void:
	var weapon_class: String = str(debug_data.get("class", current_weapon_class))
	var technique_id: String = str(debug_data.get("technique", "none"))
	if weapon_class == "" or technique_id == "none" or not TECHNIQUE_IDS.has(technique_id):
		return
	completed_technique_keys[weapon_class + ":" + technique_id] = true


func refresh_hud() -> void:
	if weapon_controller == null or not weapon_controller.has_method("get_debug_data"):
		return

	var data: Dictionary = weapon_controller.call("get_debug_data")
	var class_name: String = str(data.get("class", "none"))
	if class_name != current_weapon_class:
		rebuild_combo_guide()

	var chain_value: Variant = data.get("chain", [])
	var chain_text: String = "none"
	if chain_value is Array and (chain_value as Array).size() > 0:
		var chain_strings: Array[String] = []
		for entry: Variant in chain_value as Array:
			chain_strings.append(str(entry))
		chain_text = " → ".join(chain_strings)

	if weapon_label != null:
		var mastery_rank: int = GameState.get_weapon_mastery_rank(class_name)
		weapon_label.text = (
			"WEAPON  "
			+ str(data.get("weapon", "none"))
			+ "  ["
			+ class_name.to_upper()
			+ "]  •  "
			+ WeaponMasteryCatalogScript.get_rank_name(mastery_rank).to_upper()
		)

	if attack_label != null:
		attack_label.text = (
			"ATTACK  "
			+ str(data.get("attack", "none"))
			+ "  |  PHASE "
			+ str(data.get("phase", "idle")).to_upper()
			+ "  |  TECHNIQUE "
			+ str(data.get("technique", "none")).to_upper()
		)

	if queue_label != null:
		queue_label.text = (
			"CHAIN  "
			+ chain_text
			+ "\nBUFFER  "
			+ str(data.get("queued", "none")).to_upper()
			+ "  |  COMBO "
			+ str(data.get("combo_time", 0.0))
			+ "s"
		)

	if cancel_label != null:
		cancel_label.text = (
			"CANCEL WINDOW  Spell: "
			+ ("OPEN" if bool(data.get("cast_cancel", false)) else "closed")
			+ "  |  Dodge: "
			+ ("OPEN" if bool(data.get("dodge_cancel", false)) else "closed")
			+ "\nACTIONS  •  LIGHT  •  HEAVY  •  DODGE ATTACK  •  JUMP ATTACK  •  F8 RESET"
		)

	refresh_sandbox_hud(data)


func refresh_sandbox_hud(data: Dictionary) -> void:
	if sandbox_label != null:
		sandbox_label.text = (
			"SANDBOX  •  "
			+ str(sandbox_summary.get("mastery_total", 16))
			+ " WEAPON CLASSES MASTERED  •  ALL CATALOG UPGRADES  •  RESOURCES AUTO-REFILL\n"
			+ "Entry progression is restored automatically when this scene closes."
		)

	if combo_guide_label != null:
		var route_lines: Array[String] = []
		var completed_count: int = 0
		for route: Dictionary in current_combo_routes:
			var key: String = str(route.get("key", ""))
			var completed: bool = bool(completed_route_keys.get(key, false))
			if completed:
				completed_count += 1
			var tokens: Array = route.get("tokens", []) as Array
			var token_strings: Array[String] = []
			for token: Variant in tokens:
				token_strings.append(str(token))
			var suffix: String = " ↻" if bool(route.get("loops", false)) else ""
			route_lines.append(
				("✓" if completed else "□")
				+ " "
				+ " ".join(token_strings)
				+ "  →  "
				+ str(route.get("final_name", "Finisher"))
				+ suffix
			)
		combo_guide_label.text = (
			"GROUNDED ROUTES  "
			+ str(completed_count)
			+ "/"
			+ str(current_combo_routes.size())
			+ "\n"
			+ ("\n".join(route_lines) if not route_lines.is_empty() else "No authored moveset routes.")
		)

	if technique_guide_label != null:
		var weapon_class: String = str(data.get("class", current_weapon_class))
		var technique_lines: Array[String] = []
		for technique_id: String in TECHNIQUE_IDS:
			var completed: bool = bool(completed_technique_keys.get(weapon_class + ":" + technique_id, false))
			technique_lines.append(
				("✓" if completed else "□")
				+ " "
				+ get_technique_instruction(weapon_class, technique_id)
			)
		technique_guide_label.text = "CONTEXT TECHNIQUES\n" + "   ".join(technique_lines)


func get_technique_instruction(weapon_class: String, technique_id: String) -> String:
	match technique_id:
		WeaponTechniqueCatalogScript.CONTEXT_DASH:
			return WeaponTechniqueCatalogScript.get_dash_technique_name(weapon_class) + " [Dodge + Light/Heavy]"
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_NEUTRAL:
			return WeaponTechniqueCatalogScript.get_aerial_technique_name(weapon_class, technique_id) + " [Jump + neutral Light]"
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD:
			return WeaponTechniqueCatalogScript.get_aerial_technique_name(weapon_class, technique_id) + " [Jump + move + Light]"
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_DOWN:
			return WeaponTechniqueCatalogScript.get_aerial_technique_name(weapon_class, technique_id) + " [Jump + Heavy]"
		_:
			return technique_id.capitalize()


func input_token(input_kind: String) -> String:
	return "H" if input_kind == "heavy" else "L"


func combo_route_key(weapon_class: String, tokens: Array[String]) -> String:
	return weapon_class + ":" + "".join(tokens)


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
		"arena": "weapon_combat_v0_8",
		"resets": reset_count,
		"sandbox": sandbox_summary.duplicate(true),
		"snapshot_captured": not entry_progression_snapshot.is_empty(),
		"spawned_enemies": get_tree().get_nodes_in_group("combat_arena_spawned").size(),
		"combo_routes": current_combo_routes.size(),
		"completed_routes": completed_route_keys.size(),
		"completed_techniques": completed_technique_keys.size(),
		"weapon": weapon_controller.call("get_debug_data") if weapon_controller != null and weapon_controller.has_method("get_debug_data") else {},
	}
