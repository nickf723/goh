extends "res://scripts/soul/soul_duplicate_actor_final.gd"
class_name SoulDuplicateActorCombatSynced

const ScaleControllerScriptDuplicate = preload(
	"res://scripts/player/player_scale_controller.gd"
)

var last_mirrored_attack_forward: Vector3 = Vector3.FORWARD
var mirrored_attack_count: int = 0
var jump_release_multiplier: float = 0.52


func configure(source: CharacterBody3D, index: int = 0) -> void:
	super.configure(source, index)
	_sync_motion_constants_from_source()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if (
		Input.is_action_just_released("jump")
		and velocity.y > 0.0
	):
		velocity.y = maxf(
			velocity.y * jump_release_multiplier,
			0.45
		)


func apply_source_state_spell(spell_id: String, cast_direction: Vector3) -> void:
	if spell_id == "scale":
		_activate_live_scale(cast_direction)
		mirrored_spell_count += 1
		duplicate_spell_mirrored.emit(spell_id)
		return
	super.apply_source_state_spell(spell_id, cast_direction)


func _activate_live_scale(cast_direction: Vector3) -> void:
	var controller: Node = get_node_or_null("ScaleController")
	if controller == null:
		controller = ScaleControllerScriptDuplicate.new()
		controller.name = "ScaleController"
		add_child(controller)
	if controller.has_method("activate_scale"):
		controller.call("activate_scale", cast_direction)


func mirror_weapon_attack_with_forward(
	attack: WeaponAttackDefinition,
	weapon: WeaponDefinition,
	attack_forward: Vector3
) -> void:
	var forward: Vector3 = attack_forward
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = -global_transform.basis.z
		forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	last_mirrored_attack_forward = forward.normalized()
	mirrored_attack_count += 1
	_mirror_weapon_attack_internal(attack, weapon, last_mirrored_attack_forward)


func mirror_weapon_attack(
	attack: WeaponAttackDefinition,
	weapon: WeaponDefinition
) -> void:
	var fallback: Vector3 = -global_transform.basis.z
	fallback.y = 0.0
	mirror_weapon_attack_with_forward(attack, weapon, fallback)


func _mirror_weapon_attack_internal(
	attack: WeaponAttackDefinition,
	weapon: WeaponDefinition,
	attack_forward: Vector3
) -> void:
	if attack == null:
		return
	attack_serial += 1
	var serial: int = attack_serial
	duplicate_attack_started.emit(attack.attack_id)
	var startup: float = maxf(attack.get_startup_duration(), 0.0)
	var timer: SceneTreeTimer = get_tree().create_timer(startup)
	timer.timeout.connect(
		func() -> void:
			if not is_inside_tree() or serial > attack_serial:
				return
			_resolve_weapon_attack_with_forward(attack, weapon, attack_forward)
	)


func _resolve_weapon_attack_with_forward(
	attack: WeaponAttackDefinition,
	weapon: WeaponDefinition,
	attack_forward: Vector3
) -> void:
	var payload: DamagePayload = attack.build_payload(weapon)
	if payload == null:
		return
	for tag: String in ["soul", "duplicate", "live_clone"]:
		if not payload.tags.has(tag):
			payload.tags.append(tag)

	var damage_multiplier: float = 1.0
	var stance_multiplier: float = 1.0
	var range_multiplier: float = 1.0
	match current_form:
		"grown":
			damage_multiplier = 1.5
			stance_multiplier = 1.6
			range_multiplier = 1.2
		"shrunk":
			damage_multiplier = 0.72
			stance_multiplier = 0.72
			range_multiplier = 0.82
	payload.amount = maxi(roundi(float(payload.amount) * damage_multiplier), 0)
	payload.stance_damage = maxi(roundi(float(payload.stance_damage) * stance_multiplier), 0)

	var forward: Vector3 = attack_forward
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = -global_transform.basis.z
		forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD

	var attack_range: float = maxf(attack.attack_range * range_multiplier, 0.2)
	var origin: Vector3 = global_position + Vector3.UP * maxf(0.72 * form_scale, 0.25)
	var center: Vector3 = (
		origin
		+ forward * attack.attack_center_forward_offset * range_multiplier
	)
	var shape := SphereShape3D.new()
	shape.radius = attack_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]
	var minimum_dot: float = cos(
		deg_to_rad(clampf(attack.cone_angle_degrees, 1.0, 360.0) * 0.5)
	)
	var seen: Dictionary = {}
	var target_count: int = 0
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var raw: Variant = hit.get("collider")
		if not raw is Node:
			continue
		var target: Node = _find_payload_target(raw as Node)
		if target == null or target == source_actor or target == self:
			continue
		if target.is_in_group("soul_duplicates") or target.is_in_group("repeat_echoes"):
			continue
		var id: int = target.get_instance_id()
		if seen.has(id):
			continue
		var target_position: Vector3 = _target_position(target)
		var offset: Vector3 = target_position - origin
		offset.y = 0.0
		if offset.length_squared() > 0.001 and forward.dot(offset.normalized()) < minimum_dot:
			continue
		seen[id] = true
		_send_payload(target, payload)
		target_count += 1
		if target_count >= attack.max_targets:
			break
	duplicate_attack_resolved.emit(attack.attack_id, target_count)


func _sync_motion_constants_from_source() -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		return
	var source_move_speed: Variant = source_actor.get("move_speed")
	var source_jump_velocity: Variant = source_actor.get("jump_velocity")
	var source_gravity: Variant = source_actor.get("gravity")
	if source_move_speed != null:
		move_speed = float(source_move_speed)
	if source_jump_velocity != null:
		jump_velocity = float(source_jump_velocity)
	if source_gravity != null:
		gravity = float(source_gravity)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["combat_aim_synced"] = true
	data["last_attack_forward"] = last_mirrored_attack_forward
	data["mirrored_attacks"] = mirrored_attack_count
	data["source_jump_velocity_synced"] = (
		source_actor != null
		and is_equal_approx(jump_velocity, float(source_actor.get("jump_velocity")))
	)
	data["jump_release_multiplier"] = jump_release_multiplier
	data["scale_live_source_state"] = true
	return data
