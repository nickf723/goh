extends Node
class_name DevSandboxDirector

const DevRuntimeEnemyFactoryScript: Script = preload("res://scripts/systems/dev_runtime_enemy_factory.gd")

@export var goblin_scene: PackedScene
@export var gremlin_scene: PackedScene
@export var spawn_runtime_zombie: bool = true

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
	print("Runtime zombie enabled: ", spawn_runtime_zombie)
	print("============================")
	print("")


func spawn_test_wave() -> void:
	cleanup_dead_spawn_references()

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

	var spawned_count: int = 0

	if goblin_scene != null:
		if spawn_enemy_scene(scene_root, goblin_scene, base_position + get_spawn_offset(spawned_count)) != null:
			spawned_count += 1

	if gremlin_scene != null:
		if spawn_enemy_scene(scene_root, gremlin_scene, base_position + get_spawn_offset(spawned_count)) != null:
			spawned_count += 1

	if spawn_runtime_zombie:
		var zombie: Node = DevRuntimeEnemyFactoryScript.create_zombie()
		if spawn_enemy_node(scene_root, zombie, base_position + get_spawn_offset(spawned_count)) != null:
			spawned_count += 1

	if spawned_count == 0:
		print("DevSandboxDirector: No enemies spawned. Assign enemy scenes or enable runtime zombie.")
		return

	print("DevSandboxDirector: spawned ", spawned_count, " test enemies.")


func spawn_enemy_scene(scene_root: Node, enemy_scene: PackedScene, spawn_position: Vector3) -> Node:
	if enemy_scene == null:
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
		"zombie": spawn_runtime_zombie,
	}
