extends CharacterBody3D
class_name GenericAnimalActor

signal action_changed(move_id: String, intention_id: String)
signal selected_changed(selected: bool)

@export var species_id: String = "sheep"
@export var animal_name: String = "Animal"
@export var personality_profile_id: String = "balanced"
@export var move_speed: float = 2.4
@export var turn_speed: float = 6.0
@export var wander_radius: float = 2.5
@export var gravity: float = 18.0
@export var decision_interval: float = 0.65

var brain: MobBrainComponent
var home_position: Vector3
var current_action_id: String = "idle"
var current_intention_id: String = "observe"
var action_time_remaining: float = 0.0
var decision_time_remaining: float = 0.0
var wander_target: Vector3
var wander_time_remaining: float = 0.0
var elapsed: float = 0.0
var selected: bool = false
var initial_position: Vector3
var visual_root: Node3D
var head_root: Node3D
var state_label: Label3D
var selection_marker: MeshInstance3D
var body_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var flash_time_remaining: float = 0.0


func _ready() -> void:
	initial_position = global_position
	home_position = global_position
	wander_target = home_position
	add_to_group("generic_animals")
	add_to_group("debuggable")
	_build_collision()
	_build_visual()
	_build_brain()
	decision_time_remaining = randf_range(0.1, decision_interval)


func _physics_process(delta: float) -> void:
	elapsed += delta
	flash_time_remaining = maxf(flash_time_remaining - delta, 0.0)
	action_time_remaining = maxf(action_time_remaining - delta, 0.0)
	decision_time_remaining -= delta
	wander_time_remaining -= delta
	if decision_time_remaining <= 0.0:
		decision_time_remaining = decision_interval
		force_decision()
	_execute_current_action(delta)
	_apply_gravity(delta)
	move_and_slide()
	_keep_inside_lab()
	_update_visual(delta)


func force_decision() -> Dictionary:
	if brain == null:
		return {}
	var decision: Dictionary = brain.request_decision(get_mob_decision_context())
	if str(decision.get("move_id", "")) != "":
		_on_move_selected(str(decision.get("move_id", "")), decision)
	return decision


func get_mob_decision_context() -> Dictionary:
	var lab: Node = get_parent()
	var threat: Node3D = _get_lab_node("get_animal_threat_target")
	var threat_mode: bool = _get_lab_bool("is_animal_threat_mode_enabled")
	var threat_distance: float = INF
	if threat != null:
		threat_distance = global_position.distance_to(threat.global_position)
	var threat_active: bool = threat_mode and threat != null and threat_distance <= 12.0
	var forage_position: Vector3 = _get_lab_position("get_animal_forage_position", home_position)
	var water_position: Vector3 = _get_lab_position("get_animal_water_position", home_position)
	var forage_distance: float = global_position.distance_to(forage_position)
	var water_distance: float = global_position.distance_to(water_position)
	var context_tags: Array[String] = []
	var target_distance: float = 0.0
	var enemy_count: int = 0
	if threat_active:
		target_distance = threat_distance
		enemy_count = 1
		context_tags.append("line_of_sight")
		if threat_distance <= 3.0:
			context_tags.append("target_close")
		if species_id == "wolf":
			context_tags.append("hostile")
			context_tags.append("hunting")
			if _same_species_ally_count() > 0:
				context_tags.append("protecting_pack")
		else:
			context_tags.append("threatened")
			context_tags.append("predator_near")
			if threat_distance <= 1.7:
				context_tags.append("cornered")
	else:
		context_tags.append("safe")
		if species_id == "sheep":
			target_distance = forage_distance
			if forage_distance <= 2.4:
				context_tags.append("lush_forage")
		elif species_id == "capybara":
			target_distance = minf(forage_distance, water_distance)
			context_tags.append("hot")
			if water_distance <= 12.0:
				context_tags.append("water_near")
			if forage_distance <= 2.4:
				context_tags.append("lush_forage")
		else:
			target_distance = 0.0
	return {
		"target_distance": target_distance,
		"self_health_ratio": 1.0,
		"target_health_ratio": 1.0,
		"ally_count": _same_species_ally_count(),
		"enemy_count": enemy_count,
		"context_tags": context_tags,
		"scalar_values": {
			"forage_distance": forage_distance,
			"water_distance": water_distance,
			"threat_distance": threat_distance if threat_distance < INF else 999.0,
		},
	}


func set_selected(value: bool) -> void:
	selected = value
	if selection_marker != null:
		selection_marker.visible = selected
	selected_changed.emit(selected)


func set_drive(drive_id: String, value: float) -> void:
	if brain != null:
		brain.set_drive(drive_id, value)
		brain.clear_memory()
		decision_time_remaining = 0.0


func add_drive(drive_id: String, delta: float) -> void:
	if brain != null:
		brain.add_drive(drive_id, delta)
		decision_time_remaining = 0.0


func get_drive(drive_id: String) -> float:
	return brain.get_drive(drive_id) if brain != null else 0.0


func reset_actor() -> void:
	global_position = initial_position
	velocity = Vector3.ZERO
	home_position = initial_position
	wander_target = home_position
	current_action_id = "idle"
	current_intention_id = "observe"
	action_time_remaining = 0.0
	decision_time_remaining = 0.1
	flash_time_remaining = 0.0
	if brain != null:
		brain.clear_cooldowns()
		brain.clear_memory()
		brain.reset_drives()


func get_debug_data() -> Dictionary:
	return {
		"species_id": species_id,
		"animal_name": animal_name,
		"action": current_action_id,
		"intention": current_intention_id,
		"selected": selected,
		"position": global_position,
		"brain": brain.get_debug_data() if brain != null else {},
	}


func _build_brain() -> void:
	brain = MobBrainComponent.new()
	brain.species_id = species_id
	brain.personality_profile_id = personality_profile_id
	brain.automatic_decisions = false
	brain.decision_interval = decision_interval
	brain.intention_commitment_seconds = 1.6
	brain.intention_score_tolerance = 0.35
	brain.context_provider_path = NodePath("..")
	add_child(brain)
	brain.move_selected.connect(_on_move_selected)


func _on_move_selected(move_id: String, decision: Dictionary) -> void:
	if move_id == "":
		return
	current_action_id = move_id
	current_intention_id = str(
		decision.get("intention_id", MobIntentionResolver.get_intention_id(decision))
	)
	var move_data: Dictionary = decision.get("move", {}) as Dictionary
	var effect: Dictionary = move_data.get("effect", {}) as Dictionary
	action_time_remaining = _action_duration(move_id, effect)
	brain.commit_move(move_id)
	if ["bite", "headbutt", "pounce", "tail_sweep"].has(move_id):
		flash_time_remaining = 0.22
	action_changed.emit(current_action_id, current_intention_id)


func _execute_current_action(delta: float) -> void:
	var direction: Vector3 = Vector3.ZERO
	match current_action_id:
		"graze":
			direction = _direction_to(_get_lab_position("get_animal_forage_position", home_position))
		"wade":
			direction = _direction_to(_get_lab_position("get_animal_water_position", home_position))
		"flee", "backstep":
			var threat: Node3D = _get_lab_node("get_animal_threat_target")
			if threat != null:
				direction = _flat_direction(global_position - threat.global_position)
		"bite", "headbutt", "pounce", "tail_sweep", "stone_gaze", "mire_spit":
			var target: Node3D = _get_lab_node("get_animal_threat_target")
			if target != null:
				direction = _direction_to(target.global_position)
		"howl":
			direction = Vector3.ZERO
		_:
			direction = _wander_direction()
	var speed_multiplier: float = 1.0
	if current_action_id == "flee":
		speed_multiplier = 1.55
	elif current_action_id == "pounce":
		speed_multiplier = 1.7
	elif current_action_id in ["graze", "wade", "idle"]:
		speed_multiplier = 0.72
	var target_velocity: Vector3 = direction * move_speed * speed_multiplier
	velocity.x = move_toward(velocity.x, target_velocity.x, move_speed * 4.0 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, move_speed * 4.0 * delta)
	if direction.length_squared() > 0.001:
		var target_yaw: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))
	if action_time_remaining <= 0.0:
		current_action_id = "idle"


func _wander_direction() -> Vector3:
	if wander_time_remaining <= 0.0 or global_position.distance_to(wander_target) < 0.35:
		wander_time_remaining = randf_range(1.4, 3.2)
		var angle: float = randf() * TAU
		var radius: float = randf_range(0.35, wander_radius)
		wander_target = home_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	return _direction_to(wander_target)


func _direction_to(target_position: Vector3) -> Vector3:
	return _flat_direction(target_position - global_position)


func _flat_direction(offset: Vector3) -> Vector3:
	offset.y = 0.0
	return offset.normalized() if offset.length_squared() > 0.01 else Vector3.ZERO


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1


func _keep_inside_lab() -> void:
	var lab: Node = get_parent()
	if lab != null and lab.has_method("clamp_animal_position"):
		global_position = lab.call("clamp_animal_position", global_position)


func _action_duration(move_id: String, effect: Dictionary) -> float:
	if effect.has("duration"):
		return clampf(float(effect.get("duration", 1.0)), 0.4, 3.0)
	match move_id:
		"graze": return 1.8
		"wade": return 2.2
		"howl": return 1.4
		"bite", "headbutt", "pounce", "tail_sweep": return 0.8
		_: return 1.0


func _same_species_ally_count() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("generic_animals"):
		if node == self or not node is GenericAnimalActor:
			continue
		if (node as GenericAnimalActor).species_id == species_id:
			count += 1
	return count


func _get_lab_node(method_name: String) -> Node3D:
	var lab: Node = get_parent()
	if lab != null and lab.has_method(method_name):
		var value: Variant = lab.call(method_name, self)
		if value is Node3D:
			return value as Node3D
	return null


func _get_lab_position(method_name: String, fallback: Vector3) -> Vector3:
	var lab: Node = get_parent()
	if lab != null and lab.has_method(method_name):
		var value: Variant = lab.call(method_name, self)
		if value is Vector3:
			return value as Vector3
	return fallback


func _get_lab_bool(method_name: String) -> bool:
	var lab: Node = get_parent()
	return bool(lab.call(method_name, self)) if lab != null and lab.has_method(method_name) else false


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.15
	collision.shape = shape
	collision.position.y = 0.58
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	body_material = StandardMaterial3D.new()
	accent_material = StandardMaterial3D.new()
	body_material.roughness = 0.82
	accent_material.roughness = 0.72
	match species_id:
		"sheep":
			body_material.albedo_color = Color(0.82, 0.84, 0.78)
			accent_material.albedo_color = Color(0.18, 0.16, 0.14)
			_build_quadruped(Vector3(0.62, 0.48, 0.84), 0.34, true, false)
		"capybara":
			body_material.albedo_color = Color(0.48, 0.28, 0.14)
			accent_material.albedo_color = Color(0.22, 0.11, 0.06)
			_build_quadruped(Vector3(0.58, 0.48, 0.9), 0.4, false, false)
		"wolf":
			body_material.albedo_color = Color(0.28, 0.34, 0.4)
			accent_material.albedo_color = Color(0.08, 0.1, 0.13)
			_build_quadruped(Vector3(0.54, 0.46, 0.86), 0.32, false, true)
		_:
			body_material.albedo_color = Color(0.45, 0.48, 0.5)
			accent_material.albedo_color = Color(0.12, 0.14, 0.16)
			_build_quadruped(Vector3(0.55, 0.48, 0.78), 0.34, false, false)
	selection_marker = MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.72
	marker_mesh.bottom_radius = 0.72
	marker_mesh.height = 0.035
	selection_marker.mesh = marker_mesh
	selection_marker.position.y = 0.04
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.78, 0.12, 0.7)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.emission_enabled = true
	marker_material.emission = Color(1.0, 0.52, 0.04)
	marker_material.emission_energy_multiplier = 1.8
	selection_marker.material_override = marker_material
	selection_marker.visible = false
	add_child(selection_marker)
	state_label = Label3D.new()
	state_label.position = Vector3(0.0, 2.05, 0.0)
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.font_size = 18
	state_label.pixel_size = 0.006
	state_label.outline_size = 7
	state_label.modulate = Color(0.96, 0.96, 0.9)
	add_child(state_label)


func _build_quadruped(
	body_scale: Vector3,
	head_radius: float,
	woolly: bool,
	pointed: bool
) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.58
	body_mesh.height = 1.16
	body.mesh = body_mesh
	body.scale = body_scale
	body.position = Vector3(0.0, 0.82, 0.0)
	body.material_override = body_material
	visual_root.add_child(body)
	if woolly:
		for offset: Vector3 in [Vector3(-0.28, 0.92, 0.0), Vector3(0.28, 0.92, 0.0), Vector3(0.0, 1.05, 0.2)]:
			var puff := MeshInstance3D.new()
			var puff_mesh := SphereMesh.new()
			puff_mesh.radius = 0.33
			puff_mesh.height = 0.66
			puff.mesh = puff_mesh
			puff.position = offset
			puff.material_override = body_material
			visual_root.add_child(puff)
	head_root = Node3D.new()
	head_root.position = Vector3(0.0, 1.02, -0.72)
	visual_root.add_child(head_root)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = head_radius
	head_mesh.height = head_radius * 2.0
	head.mesh = head_mesh
	head.scale = Vector3(0.82, 0.9, 1.0)
	head.material_override = accent_material if species_id == "sheep" else body_material
	head_root.add_child(head)
	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := PrismMesh.new()
		ear_mesh.size = Vector3(0.16, 0.1, 0.3 if pointed else 0.2)
		ear.mesh = ear_mesh
		ear.position = Vector3(side * head_radius * 0.72, head_radius * 0.45, 0.0)
		ear.rotation_degrees = Vector3(0.0, 0.0, side * -24.0)
		ear.material_override = accent_material
		head_root.add_child(ear)
	for x: float in [-0.3, 0.3]:
		for z: float in [-0.38, 0.38]:
			var leg := MeshInstance3D.new()
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.075
			leg_mesh.bottom_radius = 0.09
			leg_mesh.height = 0.62
			leg.mesh = leg_mesh
			leg.position = Vector3(x, 0.36, z)
			leg.material_override = accent_material
			visual_root.add_child(leg)
	if pointed:
		var tail := MeshInstance3D.new()
		var tail_mesh := PrismMesh.new()
		tail_mesh.size = Vector3(0.18, 0.18, 0.6)
		tail.mesh = tail_mesh
		tail.position = Vector3(0.0, 0.9, 0.72)
		tail.rotation_degrees.x = -20.0
		tail.material_override = body_material
		visual_root.add_child(tail)


func _update_visual(delta: float) -> void:
	if visual_root != null:
		var movement_amount: float = Vector2(velocity.x, velocity.z).length()
		visual_root.position.y = absf(sin(elapsed * 8.0)) * movement_amount * 0.018
	if head_root != null:
		var target_pitch: float = 0.0
		if current_action_id == "graze":
			target_pitch = 48.0 + sin(elapsed * 5.0) * 8.0
		elif current_action_id == "howl":
			target_pitch = -28.0
		head_root.rotation_degrees.x = lerpf(head_root.rotation_degrees.x, target_pitch, clampf(delta * 6.0, 0.0, 1.0))
	if body_material != null:
		body_material.emission_enabled = flash_time_remaining > 0.0
		body_material.emission = Color(1.0, 0.18, 0.08)
		body_material.emission_energy_multiplier = 2.4
	if state_label != null:
		state_label.text = (
			animal_name
			+ "\n"
			+ current_intention_id.capitalize()
			+ " • "
			+ current_action_id.replace("_", " ").capitalize()
			+ "\nH " + _percent(get_drive("hunger"))
			+ "  F " + _percent(get_drive("fear"))
			+ "  S " + _percent(get_drive("social_need"))
		)
		state_label.modulate = Color(1.0, 0.82, 0.28) if selected else Color(0.96, 0.96, 0.9)


func _percent(value: float) -> String:
	return str(int(round(clampf(value, 0.0, 1.0) * 100.0)))
