extends "res://scripts/enemies/large_construct_enemy.gd"
class_name StonebackSalamanderEnemy

var wet_timer: float = 0.0
var overheated_timer: float = 0.0
var back_plate_visuals: Array[Node3D] = []
var creature_time: float = 0.0


func _ready() -> void:
	display_name = "Stoneback Salamander"
	maximum_health = 140
	maximum_stance = 36
	move_speed = 2.75
	attack_range = 6.6
	super._ready()
	add_to_group("creature")
	add_to_group("biological")
	remove_from_group("construct")
	remove_from_group("metal")


func _physics_process(delta: float) -> void:
	wet_timer = maxf(wet_timer - maxf(delta, 0.0), 0.0)
	overheated_timer = maxf(overheated_timer - maxf(delta, 0.0), 0.0)
	creature_time += maxf(delta, 0.0)
	super._physics_process(delta)
	_animate_living_body(delta)


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.4, 3.2, 8.4)
	collision.shape = shape
	collision.position = Vector3(0, 2.0, 0)
	add_child(collision)


func _build_visuals() -> void:
	body_material = _make_material(Color(0.20, 0.34, 0.25, 1.0), 0.05, 0.78)
	armor_material = _make_material(Color(0.34, 0.31, 0.25, 1.0), 0.12, 0.86)
	core_material = _make_emissive_material(Color(1.0, 0.28, 0.06, 1.0), 3.8)
	visual_root = Node3D.new()
	visual_root.name = "CreatureVisualRoot"
	add_child(visual_root)
	torso_root = Node3D.new()
	torso_root.name = "LivingBodyRoot"
	visual_root.add_child(torso_root)

	_add_box(torso_root, "Body", Vector3(4.7, 2.3, 6.5), Vector3(0, 2.35, 0.3), body_material)
	_add_box(torso_root, "Neck", Vector3(2.8, 1.8, 2.5), Vector3(0, 2.5, -3.35), body_material, Vector3(-8, 0, 0))
	_add_box(torso_root, "Head", Vector3(3.2, 1.75, 2.7), Vector3(0, 2.55, -5.15), body_material)
	_add_box(torso_root, "Jaw", Vector3(2.7, 0.72, 2.15), Vector3(0, 1.82, -5.65), body_material, Vector3(5, 0, 0))
	_add_box(torso_root, "TailA", Vector3(2.5, 1.45, 4.2), Vector3(0, 2.0, 4.55), body_material, Vector3(0, 8, 0))
	_add_box(torso_root, "TailB", Vector3(1.35, 1.0, 4.4), Vector3(0.65, 1.8, 8.25), body_material, Vector3(0, 15, 0))

	for side: float in [-1.0, 1.0]:
		_add_box(torso_root, ("Left" if side < 0.0 else "Right") + "Foreleg", Vector3(1.1, 2.1, 1.35), Vector3(side * 2.45, 1.1, -2.0), body_material, Vector3(0, 0, side * 18.0))
		_add_box(torso_root, ("Left" if side < 0.0 else "Right") + "Hindleg", Vector3(1.3, 2.2, 1.55), Vector3(side * 2.55, 1.1, 2.35), body_material, Vector3(0, 0, side * 20.0))
		_add_box(torso_root, ("Left" if side < 0.0 else "Right") + "Horn", Vector3(0.38, 1.65, 0.38), Vector3(side * 1.05, 3.75, -5.25), armor_material, Vector3(-24, 0, side * 22.0))

	back_plate_visuals.clear()
	for index: int in range(5):
		var plate: MeshInstance3D = _add_box(
			torso_root,
			"MineralPlate" + str(index + 1),
			Vector3(3.5 - float(index) * 0.18, 0.55, 1.15),
			Vector3(0, 3.75, 2.35 - float(index) * 1.15),
			armor_material,
			Vector3(0, 0, (-4.0 if index % 2 == 0 else 4.0))
		)
		back_plate_visuals.append(plate)

	_build_climb_anchors()


func _build_climb_anchors() -> void:
	climb_anchors.clear()
	_create_climb_anchor("TailGrip", Vector3(0.65, 2.35, 6.8))
	_create_climb_anchor("RearPlateGrip", Vector3(0.8, 3.75, 2.7))
	_create_climb_anchor("MidPlateGrip", Vector3(-0.75, 4.0, 0.35))
	_create_climb_anchor("ShoulderPlateGrip", Vector3(0.75, 3.9, -2.0))
	_create_climb_anchor("NeckGrip", Vector3(-0.65, 3.55, -3.85))
	_create_climb_anchor("HeatVentGrip", Vector3(0, 3.55, -0.25))


func _build_weak_points() -> void:
	_create_weak_point("shell_plate", "Mineral Back Plate", Vector3(0, 4.0, -0.25), 28, 0.78, Color(0.68, 0.55, 0.34), ["earth", "ice"], ["fire"])
	_create_weak_point("heat_vent", "Exposed Heat Organ", Vector3(0, 3.7, -0.25), 26, 0.66, Color(1.0, 0.26, 0.06), ["water", "ice", "poison"], ["fire"])
	_create_weak_point("horn", "Crown Horn", Vector3(1.0, 3.72, -5.25), 24, 0.58, Color(0.82, 0.74, 0.52), ["earth", "metal"], [])
	_create_weak_point("foreleg", "Left Foreleg", Vector3(-2.4, 1.35, -2.0), 30, 0.72, Color(0.42, 0.72, 0.48), ["ice"], [])
	var vent: LargeEnemyWeakPoint = get_weak_point("heat_vent")
	if vent != null:
		vent.set_targeting_enabled(false)


func _process_chase(delta: float) -> void:
	if player == null:
		state = State.IDLE
		return
	var offset: Vector3 = player.global_position - global_position
	var distance: float = Vector2(offset.x, offset.z).length()
	if distance <= attack_range and attack_cooldown <= 0.0:
		attack_counter += 1
		var next_attack: String = "tail_sweep" if attack_counter % 2 == 1 else "body_slam"
		if attack_counter % 4 == 0 and distance <= 4.6 and weapon_arm_enabled:
			next_attack = "bite_grab"
		_start_attack(next_attack)
		return
	if distance > detection_range * 1.35:
		state = State.IDLE
		return
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		_stop_horizontal()
		return
	var speed_scale: float = 0.62 if broken_legs > 0 else 1.0
	var direction: Vector3 = offset.normalized()
	velocity.x = direction.x * move_speed * speed_scale
	velocity.z = direction.z * move_speed * speed_scale
	_face_direction(direction, delta)


func _start_attack(attack_id: String) -> void:
	pending_attack = attack_id
	state = State.WINDUP
	state_timer = 1.08 if attack_id == "tail_sweep" else (1.22 if attack_id == "body_slam" else 0.95)
	_stop_horizontal()
	attack_flash = state_timer


func _perform_attack() -> void:
	if visual_root != null:
		visual_root.scale = Vector3.ONE
	if player == null:
		return
	if pending_attack == "bite_grab":
		if global_position.distance_to(player.global_position) <= 4.6:
			var traversal: Node = get_tree().get_first_node_in_group("large_enemy_traversal_controller")
			if traversal != null and traversal.has_method("start_enemy_grab"):
				traversal.call("start_enemy_grab", self)
		_spawn_impact_wave(4.6)
		return
	var radius: float = 7.0 if pending_attack == "tail_sweep" else 5.4
	if global_position.distance_to(player.global_position) > radius:
		return
	var payload := DamagePayload.new()
	payload.amount = 6 if pending_attack == "tail_sweep" else 8
	payload.stance_damage = 8 if pending_attack == "tail_sweep" else 11
	payload.element = "earth"
	payload.source_name = "Stoneback Tail Sweep" if pending_attack == "tail_sweep" else "Stoneback Body Slam"
	payload.hit_type = "enemy_attack"
	payload.tags = ["large_enemy", "creature", "telegraphed", pending_attack]
	payload.knockback_strength = 9.0
	payload.knockback_up_strength = 3.0
	var defense: Node = player.get_node_or_null("PlayerDefenseController")
	if defense != null and defense.has_method("resolve_incoming_attack"):
		defense.call("resolve_incoming_attack", payload, self)
	else:
		GameState.take_damage(payload.amount)
	_spawn_impact_wave(radius)


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	var element: String = payload.element.to_lower().strip_edges()
	if element == "water":
		wet_timer = 8.0
		_show_message("Water soaks the Stoneback. Lightning will now conduct through its body.")
	if element == "fire":
		overheated_timer = 7.0
		_show_message("Fire overheats the shell. Ice can now shock its stance.")
	var adjusted: DamagePayload = payload.duplicate(true) as DamagePayload
	if element == "lightning" and wet_timer > 0.0:
		adjusted.amount = maxi(adjusted.amount + 2, roundi(float(adjusted.amount) * 1.7))
		adjusted.stance_damage = maxi(adjusted.stance_damage + 4, roundi(float(adjusted.stance_damage) * 2.0))
		adjusted.source_name += " (Wet Conduction)"
	if element == "ice" and overheated_timer > 0.0:
		adjusted.stance_damage = maxi(adjusted.stance_damage + 5, roundi(float(adjusted.stance_damage) * 1.8))
		adjusted.source_name += " (Thermal Shock)"
	return super.receive_damage_payload(adjusted)


func receive_weak_point_payload(part_id: String, payload: DamagePayload, applied_damage: int, applied_stance: int) -> Dictionary:
	var adjusted_damage: int = applied_damage
	var adjusted_stance: int = applied_stance
	var element: String = payload.element.to_lower().strip_edges()
	if element == "lightning" and wet_timer > 0.0:
		adjusted_damage = roundi(float(adjusted_damage) * 1.55)
		adjusted_stance = roundi(float(adjusted_stance) * 1.8)
	if element == "ice" and overheated_timer > 0.0:
		adjusted_stance = roundi(float(adjusted_stance) * 1.7)
	return super.receive_weak_point_payload(part_id, payload, adjusted_damage, adjusted_stance)


func on_weak_point_broken(part_id: String) -> void:
	match part_id:
		"shell_plate":
			chest_open = true
			for plate: Node3D in back_plate_visuals:
				if plate != null:
					var break_tween := create_tween()
					break_tween.parallel().tween_property(plate, "position:y", plate.position.y + 1.5, 0.3)
					break_tween.parallel().tween_property(plate, "rotation_degrees:z", plate.rotation_degrees.z + 55.0, 0.3)
					break_tween.tween_callback(plate.hide)
			var vent: LargeEnemyWeakPoint = get_weak_point("heat_vent")
			if vent != null:
				vent.set_targeting_enabled(true)
			last_consequence = "heat organ exposed"
		"heat_vent":
			current_health = maxi(current_health - 48, 0)
			health_changed.emit(current_health, maximum_health)
			last_consequence = "heat organ ruptured"
			if current_health <= 0:
				_defeat()
			else:
				_trigger_kneel("The ruptured heat organ sends the Stoneback sprawling.")
		"horn":
			weapon_arm_enabled = false
			last_consequence = "bite grabs weakened"
		"foreleg":
			broken_legs = 1
			last_consequence = "charge speed reduced"
			_trigger_kneel("The wounded foreleg collapses beneath the Stoneback.")
	part_consequence.emit(part_id, last_consequence)


func can_player_climb() -> bool:
	return state == State.KNEEL and state_timer > 0.15


func get_enemy_display_name() -> String:
	return display_name


func get_grab_hold_point() -> Vector3:
	return global_position + Vector3.UP * 2.9 - global_transform.basis.z * 3.2


func get_failed_grab_payload() -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = 8
	payload.stance_damage = 9
	payload.element = "body"
	payload.source_name = "Stoneback Crushing Bite"
	payload.hit_type = "enemy_attack"
	payload.tags = ["large_enemy", "creature", "grab", "escape_failed"]
	return payload


func get_targeting_aim_point() -> Vector3:
	return global_position + Vector3.UP * 2.8


func get_lock_on_camera_distance_multiplier() -> float:
	return 1.55


func get_debug_data() -> Dictionary:
	var base: Dictionary = super.get_debug_data()
	base["creature"] = true
	base["wet"] = wet_timer > 0.0
	base["wet_time"] = snappedf(wet_timer, 0.1)
	base["overheated"] = overheated_timer > 0.0
	base["overheat_time"] = snappedf(overheated_timer, 0.1)
	base["shell_open"] = chest_open
	base["horn_intact"] = weapon_arm_enabled
	return base


func _animate_living_body(delta: float) -> void:
	if torso_root == null or state == State.DEFEATED:
		return
	var breathe: float = sin(creature_time * 2.4) * 0.035
	torso_root.scale.y = 1.0 + breathe
	if state == State.KNEEL:
		torso_root.rotation.z = sin(creature_time * 4.2) * 0.035
		torso_root.rotation.y = sin(creature_time * 2.0) * 0.055
	else:
		torso_root.rotation.z = lerpf(torso_root.rotation.z, 0.0, clampf(delta * 4.0, 0.0, 1.0))
		torso_root.rotation.y = lerpf(torso_root.rotation.y, 0.0, clampf(delta * 4.0, 0.0, 1.0))


func reset_target() -> void:
	super.reset_target()
	wet_timer = 0.0
	overheated_timer = 0.0
	for plate: Node3D in back_plate_visuals:
		if plate != null:
			plate.show()
