extends Node
class_name DevSandboxDirector

const DevRuntimeEnemyFactoryScript: Script = preload("res://scripts/systems/dev_runtime_enemy_factory.gd")

@export var goblin_scene: PackedScene
@export var gremlin_scene: PackedScene
@export var spawn_runtime_zombie: bool = true

@export var spawn_wave_key: Key = KEY_F6
@export var clear_wave_key: Key = KEY_F7
@export var audit_key: Key = KEY_F12
@export var next_scenario_key: Key = KEY_F9
@export var previous_scenario_key: Key = KEY_F10

@export var spawn_relative_to_player: bool = true
@export var auto_clear_before_spawn: bool = true
@export var print_debug: bool = true

@export var current_scenario_index: int = 0
@export var scenario_ids: Array[String] = [
	"mixed_wave",
	"goblin_duel",
	"gremlin_duel",
	"zombie_duel",
	"zombie_pair",
	"poison_cloud_lab",
	"dodge_timing",
]

@export var spawn_offsets: Array[Vector3] = [
	Vector3(3.5, 0.0, 2.5),
	Vector3(-3.5, 0.0, 2.5),
	Vector3(0.0, 0.0, 5.0),
]

var spawned_enemies: Array[Node] = []


func _ready() -> void:
	add_to_group("debuggable")
	normalize_scenario_index()
	print_help()
	print_current_scenario()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	if key_event.keycode == spawn_wave_key:
		spawn_current_scenario()
		return

	if key_event.keycode == clear_wave_key:
		clear_spawned_enemies()
		return

	if key_event.keycode == audit_key:
		run_dev_audit()
		return

	if key_event.keycode == next_scenario_key:
		cycle_scenario(1)
		return

	if key_event.keycode == previous_scenario_key:
		cycle_scenario(-1)
		return


func print_help() -> void:
	if not print_debug:
		return

	print("")
	print("=== DEV SANDBOX DIRECTOR ===")
	print("F6: Spawn selected scenario")
	print("F7: Clear spawned enemies")
	print("F12: Run dev audit")
	print("F9: Next scenario")
	print("F10: Previous scenario")
	print("Runtime zombie enabled: ", spawn_runtime_zombie)
	print("============================")
	print("")


func print_current_scenario() -> void:
	if not print_debug:
		return

	print("Selected dev scenario: [", current_scenario_index + 1, "/", get_scenario_count(), "] ", get_current_scenario_name())


func cycle_scenario(direction: int) -> void:
	if get_scenario_count() <= 0:
		current_scenario_index = 0
		print("DevSandboxDirector: No scenarios configured.")
		return

	current_scenario_index += direction
	normalize_scenario_index()
	print_current_scenario()


func normalize_scenario_index() -> void:
	var scenario_count: int = get_scenario_count()

	if scenario_count <= 0:
		current_scenario_index = 0
		return

	while current_scenario_index < 0:
		current_scenario_index += scenario_count

	while current_scenario_index >= scenario_count:
		current_scenario_index -= scenario_count


func get_scenario_count() -> int:
	return scenario_ids.size()


func get_current_scenario_id() -> String:
	if scenario_ids.size() == 0:
		return "mixed_wave"

	normalize_scenario_index()
	return scenario_ids[current_scenario_index]


func get_current_scenario_name() -> String:
	return get_scenario_display_name(get_current_scenario_id())


func get_scenario_display_name(scenario_id: String) -> String:
	match scenario_id:
		"mixed_wave":
			return "Mixed Wave"
		"goblin_duel":
			return "Goblin Duel"
		"gremlin_duel":
			return "Gremlin Duel"
		"zombie_duel":
			return "Zombie Duel"
		"zombie_pair":
			return "Zombie Pair"
		"poison_cloud_lab":
			return "Poison Cloud Lab"
		"dodge_timing":
			return "Dodge Timing"
		_:
			return scenario_id.capitalize()


func spawn_test_wave() -> void:
	spawn_current_scenario()


func spawn_current_scenario() -> void:
	cleanup_dead_spawn_references()

	if auto_clear_before_spawn:
		clear_spawned_enemies()

	var player: Node3D = find_player() as Node3D
	var base_position: Vector3 = Vector3.ZERO

	if spawn_relative_to_player and player != null:
		base_position = player.global_position
	else:
		var parent_3d: Node3D = get_parent() as Node3D

		if parent_3d != null:
			base_position = parent_3d.global_position

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		print("DevSandboxDirector: No current scene root found.")
		return

	var scenario_id: String = get_current_scenario_id()
	var enemy_ids: Array[String] = get_enemy_ids_for_scenario(scenario_id)
	var spawned_count: int = 0

	print("DevSandboxDirector: spawning scenario: ", get_scenario_display_name(scenario_id))

	for enemy_id: String in enemy_ids:
		var spawned_enemy: Node = spawn_enemy_by_id(scene_root, enemy_id, base_position + get_spawn_offset(spawned_count))

		if spawned_enemy != null:
			spawned_count += 1

	if spawned_count == 0:
		print("DevSandboxDirector: No enemies spawned for scenario: ", scenario_id)
		return

	print("DevSandboxDirector: spawned ", spawned_count, " enemies for ", get_scenario_display_name(scenario_id), ".")


func get_enemy_ids_for_scenario(scenario_id: String) -> Array[String]:
	match scenario_id:
		"mixed_wave":
			return ["goblin", "gremlin", "zombie"]
		"goblin_duel":
			return ["goblin"]
		"gremlin_duel":
			return ["gremlin"]
		"zombie_duel":
			return ["zombie"]
		"zombie_pair":
			return ["zombie", "zombie"]
		"poison_cloud_lab":
			return ["goblin", "zombie"]
		"dodge_timing":
			return ["zombie"]
		_:
			print("DevSandboxDirector: Unknown scenario id: ", scenario_id, ". Falling back to Mixed Wave.")
			return ["goblin", "gremlin", "zombie"]


func spawn_enemy_by_id(scene_root: Node, enemy_id: String, spawn_position: Vector3) -> Node:
	match enemy_id:
		"goblin":
			return spawn_enemy_scene(scene_root, goblin_scene, spawn_position, "Goblin")
		"gremlin":
			return spawn_enemy_scene(scene_root, gremlin_scene, spawn_position, "Gremlin")
		"zombie":
			return spawn_runtime_zombie_enemy(scene_root, spawn_position)
		_:
			print("DevSandboxDirector: Unknown enemy id: ", enemy_id)
			return null


func spawn_runtime_zombie_enemy(scene_root: Node, spawn_position: Vector3) -> Node:
	if not spawn_runtime_zombie:
		print("DevSandboxDirector: Runtime zombie is disabled. Enable Spawn Runtime Zombie on DevSandboxDirector.")
		return null

	var zombie: Node = DevRuntimeEnemyFactoryScript.create_zombie()
	return spawn_enemy_node(scene_root, zombie, spawn_position)


func spawn_enemy_scene(scene_root: Node, enemy_scene: PackedScene, spawn_position: Vector3, enemy_label: String = "Enemy") -> Node:
	if enemy_scene == null:
		print("DevSandboxDirector: ", enemy_label, " scene is not assigned.")
		return null

	var enemy: Node = enemy_scene.instantiate()
	return spawn_enemy_node(scene_root, enemy, spawn_position)


func spawn_enemy_node(scene_root: Node, enemy: Node, spawn_position: Vector3) -> Node:
	if scene_root == null or enemy == null:
		return null

	scene_root.add_child(enemy)

	if enemy is Node3D:
		var enemy_3d: Node3D = enemy as Node3D
		enemy_3d.global_position = spawn_position

	enemy.add_to_group("dev_spawned")
	spawned_enemies.append(enemy)

	print("Spawned: ", enemy.name, " at ", enemy.get_path())
	return enemy


func get_spawn_offset(index: int) -> Vector3:
	if spawn_offsets.size() == 0:
		return Vector3.ZERO

	if index < spawn_offsets.size():
		return spawn_offsets[index]

	var ring_index: int = index - spawn_offsets.size() + 1
	var side: float = -1.0 if ring_index % 2 == 0 else 1.0
	var distance: float = 4.0 + float(ring_index) * 1.25
	return Vector3(side * distance, 0.0, distance)


func clear_spawned_enemies() -> void:
	cleanup_dead_spawn_references()

	var clear_count: int = 0

	for enemy: Node in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
			clear_count += 1

	spawned_enemies.clear()

	for enemy: Node in get_tree().get_nodes_in_group("dev_spawned"):
		if is_instance_valid(enemy):
			enemy.queue_free()
			clear_count += 1

	if print_debug or clear_count > 0:
		print("DevSandboxDirector: cleared spawned enemies: ", clear_count)


func cleanup_dead_spawn_references() -> void:
	var living_enemies: Array[Node] = []

	for enemy: Node in spawned_enemies:
		if is_instance_valid(enemy):
			living_enemies.append(enemy)

	spawned_enemies = living_enemies


func run_dev_audit() -> void:
	var audit_manager: Node = find_dev_audit_manager()

	if audit_manager == null:
		print("DevSandboxDirector: No DevAuditManager found.")
		return

	if not audit_manager.has_method("run_audit"):
		print("DevSandboxDirector: Found audit manager, but it has no run_audit().")
		return

	audit_manager.run_audit()


func find_player() -> Node:
	var grouped_player: Node = get_tree().get_first_node_in_group("player")

	if grouped_player != null:
		return grouped_player

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		return null

	for node: Node in get_all_nodes(scene_root):
		if has_direct_child_with_script_name(node, "PlayerActionState"):
			return node

	return null


func find_dev_audit_manager() -> Node:
	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		return null

	for node: Node in get_all_nodes(scene_root):
		if node_uses_script_name(node, "DevAuditManager"):
			return node

	return null


func has_direct_child_with_script_name(parent: Node, script_name: String) -> bool:
	if parent == null:
		return false

	for child: Node in parent.get_children():
		if node_uses_script_name(child, script_name):
			return true

	return false


func node_uses_script_name(node: Node, script_name: String) -> bool:
	if node == null:
		return false

	var script: Script = node.get_script() as Script

	if script == null:
		return false

	var script_path: String = script.resource_path

	if script_path == "":
		return false

	var file_name: String = script_path.get_file().get_basename().to_lower()
	var expected_snake_name: String = camel_to_snake(script_name)

	return file_name == expected_snake_name


func camel_to_snake(text: String) -> String:
	var result: String = ""

	for i: int in range(text.length()):
		var character: String = text.substr(i, 1)

		if i > 0 and character == character.to_upper() and character != character.to_lower():
			result += "_"

		result += character.to_lower()

	return result


func get_all_nodes(root: Node) -> Array[Node]:
	var nodes: Array[Node] = [root]

	for child: Node in root.get_children():
		nodes.append_array(get_all_nodes(child))

	return nodes


func get_debug_data() -> Dictionary:
	cleanup_dead_spawn_references()

	return {
		"scenario": get_current_scenario_name(),
		"spawned": spawned_enemies.size(),
		"goblin": goblin_scene != null,
		"gremlin": gremlin_scene != null,
		"zombie": spawn_runtime_zombie,
	}
