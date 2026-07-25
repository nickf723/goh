extends CharacterBody3D
class_name LargeConstructEnemy

signal health_changed(current_health: int, maximum_health: int)
signal stance_changed(current_stance: int, maximum_stance: int)
signal part_consequence(part_id: String, consequence: String)
signal construct_defeated

enum State {
	IDLE,
	CHASE,
	WINDUP,
	RECOVER,
	KNEEL,
	DEFEATED,
}

const WeakPointScript = preload("res://scripts/enemies/large_enemy_weak_point.gd")

@export var display_name: String = "Foundry Colossus"
@export_range(20, 2000, 1) var maximum_health: int = 180
@export_range(10, 1000, 1) var maximum_stance: int = 90
@export_range(0.0, 8.0, 0.1) var move_speed: float = 2.15
@export_range(2.0, 60.0, 0.5) var detection_range: float = 28.0
@export_range(2.0, 15.0, 0.25) var attack_range: float = 6.2
@export var ai_enabled: bool = true

var current_health: int = 180
var current_stance: int = 90
var state: State = State.IDLE
var state_timer: float = 0.0
var attack_cooldown: float = 0.0
var pending_attack: String = ""
var player: Node3D = null
var visual_root: Node3D = null
var torso_root: Node3D = null
var hammer_root: Node3D = null
var body_material: StandardMaterial3D = null
var armor_material: StandardMaterial3D = null
var core_material: StandardMaterial3D = null
var weak_points: Dictionary = {}
var weapon_arm_enabled: bool = true
var chest_open: bool = false
var broken_legs: int = 0
var last_consequence: String = "none"
var attack_flash: float = 0.0


func _ready() -> void:
	current_health = maximum_health
	current_stance = maximum_stance
	add_to_group("enemy")
	add_to_group("combat_targetable")
	add_to_group("large_enemy")
	add_to_group("construct")
	add_to_group("metal")
	add_to_group("weather_exposed")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	_build_collision()
	_build_visuals()
	_build_weak_points()
	_refresh_player()


func _physics_process(delta: float) -> void:
	attack_flash = max(attack_flash - max(delta, 0.0), 0.0)
	_update_material_flash()
	if not ai_enabled or state == State.DEFEATED:
		_apply_gravity(delta)
		move_and_slide()
		return

	_refresh_player()
	attack_cooldown = max(attack_cooldown - delta, 0.0)
	match state:
		State.IDLE:
			_process_idle()
		State.CHASE:
			_process_chase(delta)
		State.WINDUP:
			_process_windup(delta)
		State.RECOVER:
			_process_recover(delta)
		State.KNEEL:
			_process_kneel(delta)
		State.DEFEATED:
			pass
	_apply_gravity(delta)
	move_and_slide()


func _process_idle() -> void:
	_stop_horizontal()
	if player != null and global_position.distance_to(player.global_position) <= detection_range:
		state = State.CHASE


func _process_chase(delta: float) -> void:
	if player == null:
		state = State.IDLE
		return
	var offset: Vector3 = player.global_position - global_position
	var distance: float = Vector2(offset.x, offset.z).length()
	if distance <= attack_range and attack_cooldown <= 0.0:
		_start_attack("hammer_sweep" if weapon_arm_enabled else "ground_stomp")
		return
	if distance > detection_range * 1.35:
		state = State.IDLE
		return
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		_stop_horizontal()
		return
	var speed_scale: float = 0.58 if broken_legs >= 2 else (0.78 if broken_legs == 1 else 1.0)
	var direction: Vector3 = offset.normalized()
	velocity.x = direction.x * move_speed * speed_scale
	velocity.z = direction.z * move_speed * speed_scale
	_face_direction(direction, delta)


func _start_attack(attack_id: String) -> void:
	pending_attack = attack_id
	state = State.WINDUP
	state_timer = 1.18 if attack_id == "hammer_sweep" else 0.92
	_stop_horizontal()
	attack_flash = state_timer


func _process_windup(delta: float) -> void:
	_stop_horizontal()
	if player != null:
		var direction: Vector3 = player.global_position - global_position
		direction.y = 0.0
		_face_direction(direction.normalized(), delta)
	state_timer -= delta
	var charge: float = 1.0 - clampf(state_timer / (1.18 if pending_attack == "hammer_sweep" else 0.92), 0.0, 1.0)
	if visual_root != null:
		visual_root.scale = Vector3(1.0 + charge * 0.08, 1.0 - charge * 0.05, 1.0 + charge * 0.08)
	if state_timer <= 0.0:
		_perform_attack()
		state = State.RECOVER
		state_timer = 1.05 if pending_attack == "hammer_sweep" else 0.72
		attack_cooldown = 2.2


func _perform_attack() -> void:
	if visual_root != null:
		visual_root.scale = Vector3.ONE
	if player == null:
		return
	var radius: float = 6.4 if pending_attack == "hammer_sweep" else 5.0
	if global_position.distance_to(player.global_position) > radius:
		return
	var payload := DamagePayload.new()
	payload.amount = 15 if pending_attack == "hammer_sweep" else 10
	payload.stance_damage = 22 if pending_attack == "hammer_sweep" else 16
	payload.element = "metal" if pending_attack == "hammer_sweep" else "earth"
	payload.source_name = "Colossus Hammer Sweep" if pending_attack == "hammer_sweep" else "Colossus Ground Stomp"
	payload.hit_type = "enemy_attack"
	payload.tags = ["large_enemy", "heavy", "telegraphed", "area", pending_attack]
	payload.knockback_strength = 10.0
	payload.knockback_up_strength = 2.8
	var defense: Node = player.get_node_or_null("PlayerDefenseController")
	if defense != null and defense.has_method("resolve_incoming_attack"):
		defense.call("resolve_incoming_attack", payload, self)
	else:
		GameState.take_damage(payload.amount)
	_spawn_impact_wave(radius)


func _process_recover(delta: float) -> void:
	_stop_horizontal()
	state_timer -= delta
	if state_timer <= 0.0:
		state = State.CHASE


func _process_kneel(delta: float) -> void:
	_stop_horizontal()
	state_timer -= delta
	if torso_root != null:
		torso_root.position.y = lerpf(torso_root.position.y, -1.35, clampf(delta * 7.0, 0.0, 1.0))
	if state_timer <= 0.0:
		if torso_root != null:
			var rise := create_tween()
			rise.set_trans(Tween.TRANS_BACK)
			rise.set_ease(Tween.EASE_OUT)
			rise.tween_property(torso_root, "position:y", 0.0, 0.48)
		current_stance = maximum_stance
		stance_changed.emit(current_stance, maximum_stance)
		state = State.CHASE


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null or state == State.DEFEATED:
		return {"message": display_name + " cannot receive that payload.", "objective": ""}
	var damage: int = max(payload.amount, 0)
	var stance_damage: int = max(payload.stance_damage, 0)
	if payload.element.to_lower().strip_edges() == "lightning":
		stance_damage = roundi(float(stance_damage) * 1.35)
	current_health = max(current_health - damage, 0)
	current_stance = max(current_stance - stance_damage, 0)
	health_changed.emit(current_health, maximum_health)
	stance_changed.emit(current_stance, maximum_stance)
	attack_flash = 0.18
	if current_health <= 0:
		_defeat()
	elif current_stance <= 0:
		_trigger_kneel("The colossus loses its footing under accumulated stance damage.")
	return {
		"message": payload.source_name + " deals " + str(damage) + " body damage to " + display_name + ".",
		"objective": "Hard-lock and switch toward the visible armor parts.",
	}


func receive_weather_payload(payload: DamagePayload) -> void:
	if payload == null:
		return
	if payload.element.to_lower().strip_edges() == "lightning":
		receive_damage_payload(payload)


func receive_weak_point_payload(
	part_id: String,
	payload: DamagePayload,
	applied_damage: int,
	applied_stance: int
) -> Dictionary:
	if state == State.DEFEATED:
		return {}
	var body_damage: int = max(1, roundi(float(applied_damage) * (1.35 if part_id == "core" else 0.32)))
	current_health = max(current_health - body_damage, 0)
	current_stance = max(current_stance - applied_stance, 0)
	health_changed.emit(current_health, maximum_health)
	stance_changed.emit(current_stance, maximum_stance)
	attack_flash = 0.18
	if current_health <= 0:
		_defeat()
	elif current_stance <= 0:
		_trigger_kneel("Targeted part damage topples the colossus.")
	return {
		"message": payload.source_name + " transfers " + str(body_damage) + " damage into the main frame.",
		"objective": "Break the chest plate to expose the core, disable the hammer arm, or attack a leg.",
	}


func on_weak_point_broken(part_id: String) -> void:
	match part_id:
		"chest_plate":
			chest_open = true
			var chest_visual: Node3D = torso_root.get_node_or_null("ChestPlate") as Node3D
			if chest_visual != null:
				var plate_break := create_tween()
				plate_break.parallel().tween_property(chest_visual, "position:z", -2.5, 0.28)
				plate_break.parallel().tween_property(chest_visual, "rotation_degrees:x", 72.0, 0.28)
				plate_break.finished.connect(chest_visual.hide)
			var core: LargeEnemyWeakPoint = get_weak_point("core")
			if core != null:
				core.set_targeting_enabled(true)
			last_consequence = "core exposed"
			part_consequence.emit(part_id, last_consequence)
		"core":
			current_health = max(current_health - 45, 0)
			health_changed.emit(current_health, maximum_health)
			last_consequence = "catastrophic core damage"
			part_consequence.emit(part_id, last_consequence)
			if current_health <= 0:
				_defeat()
			else:
				_trigger_kneel("The exposed core detonates and forces the construct to its knees.")
		"weapon_arm":
			weapon_arm_enabled = false
			_drop_hammer()
			last_consequence = "hammer disabled"
			part_consequence.emit(part_id, last_consequence)
		"left_leg", "right_leg":
			broken_legs += 1
			last_consequence = "mobility reduced"
			part_consequence.emit(part_id, last_consequence)
			_trigger_kneel("A shattered leg joint drops the colossus into a vulnerable kneel.")


func _trigger_kneel(message: String) -> void:
	if state == State.DEFEATED:
		return
	state = State.KNEEL
	state_timer = 3.8
	current_stance = 0
	pending_attack = ""
	if visual_root != null:
		visual_root.scale = Vector3.ONE
	last_consequence = message
	_show_message(message)


func _defeat() -> void:
	if state == State.DEFEATED:
		return
	state = State.DEFEATED
	_stop_horizontal()
	remove_from_group("enemy")
	remove_from_group("combat_targetable")
	collision_layer = 0
	for part_value: Variant in weak_points.values():
		var part: LargeEnemyWeakPoint = part_value as LargeEnemyWeakPoint
		if part != null:
			part.set_targeting_enabled(false)
	if visual_root != null:
		var collapse := create_tween()
		collapse.set_trans(Tween.TRANS_BACK)
		collapse.set_ease(Tween.EASE_IN)
		collapse.tween_property(visual_root, "rotation_degrees:x", 82.0, 0.72)
		collapse.parallel().tween_property(visual_root, "position:y", -2.4, 0.72)
	construct_defeated.emit()
	_show_message(display_name + " collapses into silent metal.")


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CapsuleShape3D.new()
	shape.radius = 1.65
	shape.height = 7.4
	collision.shape = shape
	collision.position.y = 3.7
	add_child(collision)


func _build_visuals() -> void:
	body_material = _make_material(Color(0.19, 0.22, 0.25, 1.0), 0.72, 0.48)
	armor_material = _make_material(Color(0.48, 0.55, 0.63, 1.0), 0.94, 0.24)
	core_material = _make_emissive_material(Color(0.20, 0.72, 1.0, 1.0), 3.8)
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	torso_root = Node3D.new()
	torso_root.name = "TorsoRoot"
	visual_root.add_child(torso_root)

	_add_box(torso_root, "Torso", Vector3(3.6, 3.2, 2.2), Vector3(0, 4.9, 0), body_material)
	_add_box(torso_root, "Shoulders", Vector3(5.2, 0.8, 2.5), Vector3(0, 6.0, 0), armor_material)
	_add_box(torso_root, "Head", Vector3(1.5, 1.3, 1.4), Vector3(0, 7.05, -0.1), armor_material)
	_add_box(torso_root, "LeftUpperArm", Vector3(1.0, 3.4, 1.1), Vector3(-2.45, 4.55, 0), body_material, Vector3(0, 0, -9))
	_add_box(torso_root, "RightUpperArm", Vector3(1.15, 3.7, 1.2), Vector3(2.55, 4.45, 0), body_material, Vector3(0, 0, 10))
	_add_box(torso_root, "LeftLeg", Vector3(1.25, 3.7, 1.45), Vector3(-1.0, 1.85, 0), body_material)
	_add_box(torso_root, "RightLeg", Vector3(1.25, 3.7, 1.45), Vector3(1.0, 1.85, 0), body_material)
	_add_box(torso_root, "LeftFoot", Vector3(1.6, 0.65, 2.25), Vector3(-1.0, 0.35, -0.32), armor_material)
	_add_box(torso_root, "RightFoot", Vector3(1.6, 0.65, 2.25), Vector3(1.0, 0.35, -0.32), armor_material)
	_add_box(torso_root, "ChestPlate", Vector3(2.6, 2.0, 0.38), Vector3(0, 5.05, -1.28), armor_material)

	hammer_root = Node3D.new()
	hammer_root.name = "HammerRoot"
	torso_root.add_child(hammer_root)
	_add_box(hammer_root, "HammerShaft", Vector3(0.32, 4.9, 0.32), Vector3(3.1, 3.15, 0), body_material, Vector3(0, 0, 8))
	_add_box(hammer_root, "HammerHead", Vector3(2.5, 1.25, 1.35), Vector3(3.65, 5.45, 0), armor_material, Vector3(0, 0, 8))


func _build_weak_points() -> void:
	_create_weak_point("chest_plate", "Chest Plate", Vector3(0, 5.05, -1.58), 30, 0.72, Color(0.82, 0.58, 0.22), ["earth"], [])
	_create_weak_point("core", "Exposed Arc Core", Vector3(0, 5.0, -1.42), 28, 0.62, Color(0.18, 0.78, 1.0), ["lightning", "metal"], [])
	_create_weak_point("weapon_arm", "Hammer Arm Joint", Vector3(2.45, 5.35, -0.15), 34, 0.68, Color(0.86, 0.44, 0.18), ["lightning"], ["earth"])
	_create_weak_point("left_leg", "Left Knee Joint", Vector3(-1.0, 2.35, -1.58), 32, 0.64, Color(0.54, 0.72, 0.88), ["ice"], [])
	_create_weak_point("right_leg", "Right Knee Joint", Vector3(1.0, 2.35, -1.58), 32, 0.64, Color(0.54, 0.72, 0.88), ["ice"], [])
	var core: LargeEnemyWeakPoint = get_weak_point("core")
	if core != null:
		core.set_targeting_enabled(false)


func _create_weak_point(
	id: String,
	label: String,
	local_position: Vector3,
	health: int,
	radius: float,
	color: Color,
	weaknesses: Array[String],
	resistances: Array[String]
) -> void:
	var part := Area3D.new()
	part.name = id.to_pascal_case()
	part.set_script(WeakPointScript)
	part.set("part_id", id)
	part.set("display_name", label)
	part.set("maximum_health", health)
	part.set("collision_radius", radius)
	part.set("part_color", color)
	part.set("weak_elements", weaknesses)
	part.set("resistant_elements", resistances)
	part.position = local_position
	add_child(part)
	weak_points[id] = part


func _drop_hammer() -> void:
	if hammer_root == null:
		return
	hammer_root.visible = false
	var dropped := RigidBody3D.new()
	dropped.name = "DroppedColossusHammer"
	dropped.mass = 18.0
	var hammer_head: Node3D = hammer_root.get_node_or_null("HammerHead") as Node3D
	var drop_position: Vector3 = (
		hammer_head.global_position if hammer_head != null else hammer_root.global_position
	)
	get_tree().current_scene.add_child(dropped)
	dropped.global_position = drop_position
	var head := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.5, 1.25, 1.35)
	head.mesh = mesh
	head.material_override = armor_material
	dropped.add_child(head)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	dropped.add_child(collision)
	dropped.apply_central_impulse(Vector3(3.0, 2.0, -1.0))


func _spawn_impact_wave(radius: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "ColossusImpactWave"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.05
	torus.rings = 28
	torus.ring_segments = 8
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.position = global_position + Vector3.UP * 0.08
	ring.material_override = _make_emissive_material(Color(1.0, 0.42, 0.12, 0.72), 3.2)
	get_tree().current_scene.add_child(ring)
	var tween := ring.create_tween()
	tween.parallel().tween_property(ring, "scale", Vector3.ONE * radius, 0.38)
	tween.parallel().tween_property(ring, "position:y", ring.position.y + 0.2, 0.38)
	tween.finished.connect(ring.queue_free)


func _add_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(color, 0.34, 0.24)
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy
	return material


func _update_material_flash() -> void:
	if armor_material == null:
		return
	var charge: float = 0.0
	if state == State.WINDUP:
		charge = 0.65 + sin(float(Time.get_ticks_msec()) * 0.018) * 0.25
	var hit: float = clampf(attack_flash / 0.18, 0.0, 1.0) if state != State.WINDUP else 0.0
	armor_material.emission_enabled = charge > 0.0 or hit > 0.0
	armor_material.emission = Color(1.0, 0.28, 0.08, 1.0) if charge > 0.0 else Color.WHITE
	armor_material.emission_energy_multiplier = max(charge * 3.5, hit * 4.0)


func _refresh_player() -> void:
	if player != null and is_instance_valid(player):
		return
	player = get_tree().get_first_node_in_group("player") as Node3D


func _face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() <= 0.001:
		return
	var target_angle: float = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_angle, clampf(delta * 3.4, 0.0, 1.0))


func _stop_horizontal() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * max(delta, 0.0)
	elif velocity.y < 0.0:
		velocity.y = -0.1


func get_weak_point(part_id: String) -> LargeEnemyWeakPoint:
	return weak_points.get(part_id) as LargeEnemyWeakPoint


func get_lock_on_weak_points() -> Array[Node3D]:
	var results: Array[Node3D] = []
	for part_value: Variant in weak_points.values():
		var part: LargeEnemyWeakPoint = part_value as LargeEnemyWeakPoint
		if part != null and part.is_targeting_enabled():
			results.append(part)
	return results


func get_targeting_aim_point() -> Vector3:
	return global_position + Vector3.UP * 4.35


func get_lock_on_camera_distance_multiplier() -> float:
	return 1.42


func is_target_defeated() -> bool:
	return state == State.DEFEATED or current_health <= 0


func reset_target() -> void:
	current_health = maximum_health
	current_stance = maximum_stance
	state = State.IDLE
	state_timer = 0.0
	attack_cooldown = 0.0
	weapon_arm_enabled = true
	chest_open = false
	broken_legs = 0
	last_consequence = "none"
	collision_layer = 1
	if not is_in_group("enemy"):
		add_to_group("enemy")
	if not is_in_group("combat_targetable"):
		add_to_group("combat_targetable")
	if visual_root != null:
		visual_root.position = Vector3.ZERO
		visual_root.rotation = Vector3.ZERO
		visual_root.scale = Vector3.ONE
	if torso_root != null:
		torso_root.position = Vector3.ZERO
	if hammer_root != null:
		hammer_root.visible = true
	var chest_visual: Node3D = null
	if torso_root != null:
		chest_visual = torso_root.get_node_or_null("ChestPlate") as Node3D
	if chest_visual != null:
		chest_visual.visible = true
		chest_visual.position = Vector3(0, 5.05, -1.28)
		chest_visual.rotation = Vector3.ZERO
	for part_value: Variant in weak_points.values():
		var part: LargeEnemyWeakPoint = part_value as LargeEnemyWeakPoint
		if part != null:
			part.reset_target()
	var core: LargeEnemyWeakPoint = get_weak_point("core")
	if core != null:
		core.set_targeting_enabled(false)


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var part_data: Dictionary = {}
	for part_id: String in weak_points:
		var part: LargeEnemyWeakPoint = get_weak_point(part_id)
		if part != null:
			part_data[part_id] = part.get_debug_data()
	return {
		"large_enemy": true,
		"name": display_name,
		"state": State.keys()[state],
		"health": current_health,
		"maximum_health": maximum_health,
		"stance": current_stance,
		"maximum_stance": maximum_stance,
		"weapon_arm": weapon_arm_enabled,
		"chest_open": chest_open,
		"broken_legs": broken_legs,
		"last_consequence": last_consequence,
		"parts": part_data,
	}
