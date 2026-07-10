extends Node
class_name DevAuditManager

@export var run_on_ready: bool = true
@export var audit_delay: float = 0.4
@export var print_successes: bool = true
@export var print_paths: bool = true

var warning_count: int = 0
var error_count: int = 0


func _ready() -> void:
	add_to_group("debuggable")

	if run_on_ready:
		await get_tree().create_timer(audit_delay).timeout
		run_audit()

func run_audit() -> void:
	warning_count = 0
	error_count = 0

	print("")
	print("=== DEV AUDIT START ===")

	audit_player()
	audit_enemies()
	audit_controller_placements()

	print("---")
	print("Dev Audit complete. Errors: ", error_count, " Warnings: ", warning_count)
	print("=== DEV AUDIT END ===")
	print("")

func audit_player() -> void:
	print("")
	print("[Player]")

	var player: Node = find_player()

	if player == null:
		report_error("No player found. Add the player to group 'player' or give it PlayerActionState + AbilityCaster children.")
		return

	report_ok("Player found: " + describe_node(player))

	if not player.is_in_group("player"):
		report_warning("Player is not in group 'player'. EnemyBrain searches this group by default.")

	var required_components: Array[String] = [
		"PlayerActionState",
		"AbilityCaster",
		"WeaponController",
		"PlayerDodgeController",
	]

	for component_name: String in required_components:
		var component: Node = find_direct_child_by_script_name(player, component_name)

		if component == null:
			report_error("Player missing direct child component: " + component_name)
		else:
			report_ok(component_name + " found: " + describe_node(component))

	var weapon_controller: Node = find_direct_child_by_script_name(player, "WeaponController")

	if weapon_controller != null:
		var equipped_weapon: Variant = weapon_controller.get("equipped_weapon")

		if equipped_weapon == null:
			report_warning("WeaponController has no equipped_weapon assigned.")
		else:
			report_ok("WeaponController equipped weapon exists.")

	var dodge_controller: Node = find_direct_child_by_script_name(player, "PlayerDodgeController")

	if dodge_controller != null:
		var actor: Variant = dodge_controller.get("actor")

		if actor == null:
			report_warning("PlayerDodgeController actor is null. It may not be parented directly under Player.")
		else:
			report_ok("PlayerDodgeController actor linked.")

func audit_enemies() -> void:
	print("")
	print("[Enemies]")

	var enemies: Array[Node] = find_enemy_roots()

	if enemies.size() == 0:
		report_warning("No enemies found in current scene.")
		return

	for enemy: Node in enemies:
		print("")
		print("Enemy: ", describe_node(enemy))

		if not enemy.is_in_group("enemy"):
			report_warning(enemy.name + " is not in group 'enemy'.")

		var required_components: Array[String] = [
			"EnemyBrain",
			"PayloadReceiver",
			"HitReceiver",
			"StatusReceiver",
			"ForceReceiver",
			"TagComponent",
			"EnemyTelegraph",
		]

		for component_name: String in required_components:
			var component: Node = find_direct_child_by_script_name(enemy, component_name)

			if component == null:
				report_warning(enemy.name + " missing component: " + component_name)
			else:
				report_ok(component_name + " found.")

		var brain: Node = find_direct_child_by_script_name(enemy, "EnemyBrain")

		if brain != null:
			var enemy_definition: Variant = brain.get("enemy_definition")
			var default_attack: Variant = brain.get("default_attack")

			if enemy_definition == null:
				report_warning(enemy.name + " EnemyBrain has no enemy_definition.")
			else:
				report_ok("EnemyDefinition assigned.")

			if default_attack == null:
				report_warning(enemy.name + " EnemyBrain has no default_attack.")
			else:
				report_ok("Default attack assigned.")

		var hit_receiver: Node = find_direct_child_by_script_name(enemy, "HitReceiver")

		if hit_receiver != null:
			var max_health: Variant = hit_receiver.get("max_health")
			var current_health: Variant = hit_receiver.get("current_health")
			var max_stance: Variant = hit_receiver.get("max_stance")
			var current_stance: Variant = hit_receiver.get("current_stance")

			report_ok("Hit stats hp=" + str(current_health) + "/" + str(max_health) + " stance=" + str(current_stance) + "/" + str(max_stance))

func audit_controller_placements() -> void:
	print("")
	print("[Controller Placement]")

	var player: Node = find_player()
	var weapon_controllers: Array[Node] = find_nodes_by_script_name("WeaponController")
	var dodge_controllers: Array[Node] = find_nodes_by_script_name("PlayerDodgeController")

	if weapon_controllers.size() == 0:
		report_warning("No WeaponController found.")
	elif weapon_controllers.size() > 1:
		report_warning("Multiple WeaponControllers found: " + str(weapon_controllers.size()))

	for controller: Node in weapon_controllers:
		if controller.name != "WeaponController":
			report_warning("WeaponController script is on a node named '" + controller.name + "'. This may be accidental.")

		if player != null and controller.get_parent() != player:
			report_warning("WeaponController should usually be a direct child of Player. Found at: " + describe_node(controller))
		else:
			report_ok("WeaponController placement looks good.")

	if dodge_controllers.size() == 0:
		report_warning("No PlayerDodgeController found.")
	elif dodge_controllers.size() > 1:
		report_warning("Multiple PlayerDodgeControllers found: " + str(dodge_controllers.size()))

	for controller: Node in dodge_controllers:
		if player != null and controller.get_parent() != player:
			report_warning("PlayerDodgeController should usually be a direct child of Player. Found at: " + describe_node(controller))
		else:
			report_ok("PlayerDodgeController placement looks good.")

func find_player() -> Node:
	var grouped_player: Node = get_tree().get_first_node_in_group("player")

	if grouped_player != null:
		return grouped_player

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		return null

	var all_nodes: Array[Node] = get_all_nodes(scene_root)

	for node: Node in all_nodes:
		var has_action_state: bool = find_direct_child_by_script_name(node, "PlayerActionState") != null
		var has_ability_caster: bool = find_direct_child_by_script_name(node, "AbilityCaster") != null

		if has_action_state and has_ability_caster:
			return node

	return null

func find_enemy_roots() -> Array[Node]:
	var enemies: Array[Node] = []
	var seen_ids: Dictionary = {}

	for grouped_enemy: Node in get_tree().get_nodes_in_group("enemy"):
		add_unique_node(enemies, seen_ids, grouped_enemy)

	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		return enemies

	var all_nodes: Array[Node] = get_all_nodes(scene_root)

	for node: Node in all_nodes:
		if find_direct_child_by_script_name(node, "EnemyBrain") != null:
			add_unique_node(enemies, seen_ids, node)

	return enemies

func add_unique_node(nodes: Array[Node], seen_ids: Dictionary, node: Node) -> void:
	if node == null:
		return

	var node_id: int = node.get_instance_id()

	if seen_ids.has(node_id):
		return

	seen_ids[node_id] = true
	nodes.append(node)

func find_nodes_by_script_name(script_name: String) -> Array[Node]:
	var found: Array[Node] = []
	var scene_root: Node = get_tree().current_scene

	if scene_root == null:
		return found

	var all_nodes: Array[Node] = get_all_nodes(scene_root)

	for node: Node in all_nodes:
		if node_uses_script_name(node, script_name):
			found.append(node)

	return found

func find_direct_child_by_script_name(parent: Node, script_name: String) -> Node:
	if parent == null:
		return null

	for child: Node in parent.get_children():
		if node_uses_script_name(child, script_name):
			return child

	return null

func node_uses_script_name(node: Node, script_name: String) -> bool:
	if node == null:
		return false

	var script: Script = node.get_script() as Script

	if script == null:
		return false

	if script.has_method("get_global_name"):
		var global_name: String = script.get_global_name()

		if global_name == script_name:
			return true

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

func describe_node(node: Node) -> String:
	if node == null:
		return "none"

	if print_paths:
		return str(node.get_path())

	return node.name

func report_ok(message: String) -> void:
	if print_successes:
		print("  ✅ ", message)

func report_warning(message: String) -> void:
	warning_count += 1
	print("  ⚠️ ", message)

func report_error(message: String) -> void:
	error_count += 1
	print("  ❌ ", message)
