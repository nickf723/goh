extends Node
class_name DevSandboxDirector

@export var goblin_scene: PackedScene
@export var gremlin_scene: PackedScene

@export var spawn_wave_key: Key = KEY_F6
@export var clear_wave_key: Key = KEY_F7
@export var audit_key: Key = KEY_F8

@export var spawn_relative_to_player: bool = true
@export var print_debug: bool = true

@export var spawn_offsets: Array[Vector3] = [
	Vector3(3.5, 0.0, 2.5),
	Vector3(-3.5, 0.0, 2.5),
	Vector3(0.0, 0.0, 5.0),
]

var spawned_enemies: Array[Node] = []

func _ready() -> void:
	add_to_group("debuggable")
	print_help()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	if key_event.keycode == spawn_wave_key:
		spawn_test_wave()
		return

	if key_event.keycode == clear_wave_key:
		clear_spawned_enemies()
		return

	if key_event.keycode == audit_key:
		run_dev_audit()
		return

func print_help() -> void:
	if not print_debug:
		return

	print("")
	print("=== DEV SANDBOX DIRECTOR ===")
	print("F6: Spawn test wave")
	print("F7: Clear spawned enemies")
	print("F8: Run dev audit")
	print("============================")
	print("")

func spawn_test_wave() -> void:
	cleanup_dead_spawn_references()

	var wave_scenes: Array[PackedScene] = []

	if goblin_scene != null:
		wave_scenes.append(goblin_scene)

	if gremlin_scene != null:
		wave_scenes.append(gremlin_scene)

	if wave_scenes.size() == 0:
		print("DevSandboxDirector: No enemy scenes assigned.")
		return

	var player: Node3D = find_player() as Node3D
	var base_position: Vector3 = Vector3.ZERO

	if spawn_relative_to_player and player != null:
		base_position = player.global_position

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		print("DevSandboxDirector: No current scene root found.")
		return

	var spawn_count: int = min(wave_scenes.size(), spawn_offsets.size())

	for i: int in range(spawn_count):
		var enemy_scene: PackedScene = wave_scenes[i]

		if enemy_scene == null:
			continue

		var enemy: Node = enemy_scene.instantiate()

		if enemy == null:
			continue

		scene_root.add_child(enemy)

		if enemy is Node3D:
			var enemy_3d: Node3D = enemy as Node3D
			enemy_3d.global_position = base_position + spawn_offsets[i]

		enemy.add_to_group("dev_spawned")
		spawned_enemies.append(enemy)

		print("Spawned: ", enemy.name, " at ", enemy.get_path())

	print("DevSandboxDirector: spawned ", spawn_count, " test enemies.")

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
		"spawned": spawned_enemies.size(),
		"goblin": goblin_scene != null,
		"gremlin": gremlin_scene != null,
	}
