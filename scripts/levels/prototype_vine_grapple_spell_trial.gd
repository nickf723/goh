extends Node3D
class_name PrototypeVineGrappleSpellTrial

signal trial_reset

var player: CharacterBody3D = null
var goblin_target: CharacterBody3D = null
var environment_root: Node3D = null
var initial_player_transform: Transform3D
var initial_goblin_transform: Transform3D
var pullable_bodies: Array[RigidBody3D] = []
var pullable_transforms: Dictionary = {}

var floor_material: StandardMaterial3D
var vine_material: StandardMaterial3D
var wood_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var warning_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("vine_grapple_spell_trial")
	add_to_group("spell_trials")
	add_to_group("debuggable")

	player = get_node_or_null("Player") as CharacterBody3D
	goblin_target = get_node_or_null("GoblinTarget") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	if goblin_target != null:
		initial_goblin_transform = goblin_target.transform

	_build_materials()
	_build_environment()
	_restore_resources()
	call_deferred("_equip_spell", "vine_grapple")
	_set_objective(
		"Hold Cast on a crate or goblin to pull it to Grace. The rooted weight is intentionally too heavy."
	)
	_show_message(
		"Vine Grapple trial: the Life vine brings targets to Grace. Aim, hold Cast, and keep moving while it reels."
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_materials() -> void:
	floor_material = _make_material(Color(0.035, 0.055, 0.04), 0.0, 0.92)
	vine_material = _make_emissive(
		Color(0.12, 0.42, 0.1, 0.95),
		Color(0.12, 0.78, 0.08),
		2.1
	)
	wood_material = _make_material(Color(0.34, 0.19, 0.075), 0.0, 0.78)
	stone_material = _make_material(Color(0.18, 0.2, 0.2), 0.05, 0.9)
	warning_material = _make_emissive(
		Color(0.48, 0.16, 0.055, 0.95),
		Color(0.95, 0.22, 0.04),
		1.8
	)


func _build_environment() -> void:
	environment_root = Node3D.new()
	environment_root.name = "VineGrappleTrialEnvironment"
	add_child(environment_root)

	_create_static_box(
		"TrialFloor",
		Vector3(0.0, -0.5, -2.0),
		Vector3(24.0, 1.0, 28.0),
		floor_material
	)
	_create_static_box(
		"Backstop",
		Vector3(0.0, 2.0, -14.0),
		Vector3(24.0, 5.0, 0.8),
		stone_material
	)

	_create_label(
		"LIFE • VINE GRAPPLE",
		Vector3(0.0, 4.8, -11.8),
		Color(0.42, 1.0, 0.34),
		34
	)
	_create_label(
		"BRING THE WORLD TO GRACE",
		Vector3(0.0, 4.05, -11.75),
		Color(0.72, 0.92, 0.68),
		20
	)

	var light_crate: RigidBody3D = _create_pullable_box(
		"LightCrate",
		Vector3(-4.0, 0.8, -3.0),
		Vector3(1.35, 1.35, 1.35),
		18.0,
		wood_material
	)
	var medium_crate: RigidBody3D = _create_pullable_box(
		"HeavyCrate",
		Vector3(4.0, 1.0, -4.5),
		Vector3(1.7, 1.7, 1.7),
		72.0,
		stone_material
	)
	var rooted_weight: RigidBody3D = _create_pullable_box(
		"RootedWeight",
		Vector3(7.0, 1.3, -8.0),
		Vector3(2.2, 2.2, 2.2),
		220.0,
		warning_material
	)

	light_crate.add_to_group("vine_grapple_target")
	medium_crate.add_to_group("vine_grapple_target")
	# Intentionally do not add the overweight body to the explicit target group.
	# Its RigidBody mass therefore exercises the spell's normal resistance rule.
	rooted_weight.add_to_group("vine_grapple_trial_heavy")

	_create_label(
		"LIGHT CRATE • 18 kg",
		Vector3(-4.0, 2.45, -3.0),
		Color(0.72, 1.0, 0.64),
		18
	)
	_create_label(
		"HEAVY CRATE • 72 kg",
		Vector3(4.0, 2.9, -4.5),
		Color(0.72, 1.0, 0.64),
		18
	)
	_create_label(
		"ROOTED WEIGHT • 220 kg • RESISTS",
		Vector3(7.0, 3.75, -8.0),
		Color(1.0, 0.46, 0.2),
		18
	)
	_create_label(
		"MOVING TARGET",
		Vector3(0.0, 3.0, -9.5),
		Color(0.5, 1.0, 0.38),
		18
	)

	_create_vine_lane(Vector3(-4.0, 0.03, 1.5), Vector3(-4.0, 0.03, -3.0))
	_create_vine_lane(Vector3(4.0, 0.03, 1.5), Vector3(4.0, 0.03, -4.5))
	_create_vine_lane(Vector3(0.0, 0.03, 1.5), Vector3(0.0, 0.03, -9.0))


func _create_static_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	environment_root.add_child(body)
	return body


func _create_pullable_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	mass_value: float,
	material: Material
) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = node_name
	body.position = position_value
	body.mass = mass_value
	body.collision_layer = 1
	body.collision_mask = 1
	body.linear_damp = 1.2
	body.angular_damp = 2.4

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)

	environment_root.add_child(body)
	pullable_bodies.append(body)
	pullable_transforms[body.get_instance_id()] = body.transform
	return body


func _create_vine_lane(start: Vector3, finish: Vector3) -> void:
	var midpoint: Vector3 = start.lerp(finish, 0.5)
	var distance: float = start.distance_to(finish)
	var strip := MeshInstance3D.new()
	strip.position = midpoint
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.025, distance)
	strip.mesh = mesh
	strip.material_override = vine_material
	environment_root.add_child(strip)


func _create_label(
	text_value: String,
	position_value: Vector3,
	color: Color,
	size_value: int
) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	environment_root.add_child(label)


func _make_material(
	color: Color,
	metallic: float,
	roughness: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _make_emissive(
	color: Color,
	emission: Color,
	energy: float
) -> StandardMaterial3D:
	var material := _make_material(color, 0.0, 0.72)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func reset_trial() -> void:
	for runtime_vine: Node in get_tree().get_nodes_in_group("vine_grapple_runtime"):
		if runtime_vine.has_method("release_grapple"):
			runtime_vine.call("release_grapple", "trial reset", false)

	if player != null:
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO

	if goblin_target != null and is_instance_valid(goblin_target):
		goblin_target.transform = initial_goblin_transform
		goblin_target.velocity = Vector3.ZERO
		var goblin_force: Node = goblin_target.get_node_or_null("ForceReceiver")
		if goblin_force != null and goblin_force.has_method("reset_forces"):
			goblin_force.call("reset_forces")

	for body: RigidBody3D in pullable_bodies:
		if not is_instance_valid(body):
			continue
		var stored_transform: Variant = pullable_transforms.get(body.get_instance_id())
		if stored_transform is Transform3D:
			body.transform = stored_transform as Transform3D
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false

	_restore_resources()
	call_deferred("_equip_spell", "vine_grapple")
	_set_objective(
		"Hold Cast on a crate or goblin to pull it to Grace. The rooted weight is intentionally too heavy."
	)
	trial_reset.emit()


func _equip_spell(spell_id: String) -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null:
		return
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout := loadout_value as AbilityLoadout
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			caster.call("select_ability", index, false)
			return


func _restore_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _set_objective(text_value: String) -> void:
	if GameState.has_method("set_objective"):
		GameState.call("set_objective", text_value)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text_value)
	elif ui != null and ui.has_method("set_objective_text"):
		ui.call("set_objective_text", text_value)


func _show_message(text_value: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text_value)
	else:
		print(text_value)


func get_debug_data() -> Dictionary:
	return {
		"vine_grapple_trial": true,
		"pullable_count": pullable_bodies.size(),
		"goblin_present": goblin_target != null and is_instance_valid(goblin_target),
		"player_position": player.global_position if player != null else Vector3.ZERO,
	}
