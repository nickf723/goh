extends "res://scripts/weapons/whip_weapon_rig_3d.gd"
class_name WhipWeaponRigV2

const FlexibleContactSampler = preload(
	"res://scripts/weapons/flexible_weapon_contact_sampler.gd"
)

@export_range(8.0, 64.0, 1.0) var endpoint_max_speed: float = 46.0
@export_range(2.0, 40.0, 1.0) var endpoint_response: float = 22.0
@export_range(0.1, 1.0, 0.01) var body_contact_radius_scale: float = 0.72

var _desired_tip_position: Vector3 = Vector3.ZERO
var _tip_drive_velocity: Vector3 = Vector3.ZERO
var _last_physics_delta: float = 1.0 / 60.0
var _contact_strengths: Dictionary = {}
var _line_peak_speed: float = 0.0
var _line_straightness: float = 0.0


func _ready() -> void:
	super._ready()
	process_physics_priority = -12
	if tether != null:
		# The previous near-lossless Verlet chain preserved too much oscillation
		# while its scripted endpoint changed direction rapidly. More damping and
		# constraint passes keep the wave readable without making it rigid.
		tether.verlet_damping = 0.91
		tether.constraint_iterations = 14
		tether.gravity_scale = 0.14
		tether.debug_tension_color = false
	_desired_tip_position = tip_endpoint.global_position if tip_endpoint != null else global_position


func configure_weapon(new_weapon: WeaponDefinition, new_controller: WeaponController) -> void:
	super.configure_weapon(new_weapon, new_controller)
	if tip_endpoint != null:
		_desired_tip_position = tip_endpoint.global_position
	_tip_drive_velocity = Vector3.ZERO


func _process(delta: float) -> void:
	if controller == null or tip_endpoint == null:
		return
	if _wrap_latch_timer > 0.0:
		_wrap_latch_timer = maxf(_wrap_latch_timer - delta, 0.0)
		if is_instance_valid(_latched_target):
			_desired_tip_position = _get_target_position(_latched_target)
		else:
			_clear_latch()
	elif _latched_target != null:
		_clear_latch()
	if not is_attacking and _wrap_latch_timer <= 0.0:
		_desired_tip_position = (
			_get_handle_position()
			+ _get_forward() * 0.38
			+ Vector3.DOWN * 0.72
		)
	_update_wave_marker()


func _physics_process(delta: float) -> void:
	_last_physics_delta = maxf(delta, 0.001)
	if controller == null or tip_endpoint == null:
		return
	_update_handle()
	_drive_tip(_desired_tip_position, delta)
	_update_tip_kinematics(delta)
	_line_peak_speed = FlexibleContactSampler.get_peak_speed(tether, delta, 0.22)
	_line_straightness = FlexibleContactSampler.get_straightness(tether)
	is_cracking = (
		is_attacking
		and _line_peak_speed >= crack_speed_threshold
		and current_attack_supports_crack()
	)
	_update_wave_marker()
	_update_materials()


func begin_attack(attack: WeaponAttackDefinition, attack_speed: float) -> void:
	super.begin_attack(attack, attack_speed)
	_tip_drive_velocity *= 0.35
	_contact_strengths.clear()
	_desired_tip_position = tip_endpoint.global_position


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or tip_endpoint == null:
		return
	_update_handle()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active_end: float = startup + attack.get_active_duration(attack_speed)
	var total: float = attack.get_total_duration(attack_speed)
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _get_forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()

	if _wrap_latch_timer > 0.0 and is_instance_valid(_latched_target):
		_desired_tip_position = _get_target_position(_latched_target)
	elif elapsed <= startup:
		var normalized_time: float = clampf(elapsed / maxf(startup, 0.01), 0.0, 1.0)
		wave_progress = smoothstep(0.0, 1.0, normalized_time)
		_desired_tip_position = _sample_attack_tip(
			attack,
			handle,
			forward,
			right,
			wave_progress
		)
		_desired_tip_position += _sample_airflow_offset(
			_desired_tip_position,
			wave_progress
		)
	elif elapsed <= active_end:
		wave_progress = 1.0
	else:
		var recovery_weight: float = smoothstep(
			0.0,
			1.0,
			clampf(
				(elapsed - active_end) / maxf(total - active_end, 0.01),
				0.0,
				1.0
			)
		)
		var idle_target: Vector3 = handle + forward * 0.38 + Vector3.DOWN * 0.72
		_desired_tip_position = _desired_tip_position.lerp(idle_target, recovery_weight)
		wave_progress = 1.0 - recovery_weight


func end_attack() -> void:
	super.end_attack()
	_contact_strengths.clear()
	_tip_drive_velocity *= 0.45
	if tip_endpoint != null:
		_desired_tip_position = tip_endpoint.global_position


func find_weapon_targets(
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int
) -> Array[Node]:
	var targets: Array[Node] = []
	_contact_strengths.clear()
	if weapon_controller == null or attack == null or tether == null:
		return targets
	var actor: Node3D = weapon_controller.get_actor()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(contact_radius * body_contact_radius_scale, 0.12)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var seen: Dictionary = {}
	var samples: Array[Dictionary] = FlexibleContactSampler.sample_tether(
		tether,
		_last_physics_delta,
		0.18,
		true
	)
	for sample: Dictionary in samples:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), sample.get("position", Vector3.ZERO) as Vector3)
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		if actor is CollisionObject3D:
			query.exclude = [(actor as CollisionObject3D).get_rid()]
		for result: Dictionary in space_state.intersect_shape(query, 18):
			var collider: Node = result.get("collider") as Node
			if collider == null:
				continue
			var target: Node = weapon_controller.find_payload_target(collider)
			if target == null or target == actor:
				continue
			var fraction: float = clampf(float(sample.get("fraction", 0.0)), 0.0, 1.0)
			var speed: float = maxf(float(sample.get("speed", 0.0)), 0.0)
			var distal_weight: float = 0.28 + 0.72 * pow(fraction, 1.45)
			var speed_weight: float = clampf(
				speed / maxf(crack_speed_threshold * 0.62, 1.0),
				0.28,
				1.25
			)
			var contact_strength: float = clampf(distal_weight * speed_weight, 0.2, 1.2)
			var target_id: int = target.get_instance_id()
			_contact_strengths[target_id] = maxf(
				float(_contact_strengths.get(target_id, 0.0)),
				contact_strength
			)
			if not seen.has(target_id):
				seen[target_id] = true
				targets.append(target)
				if targets.size() >= maxi(attack.max_targets, 1):
					return targets
	return targets


func modify_attack_payload(payload: DamagePayload, attack: WeaponAttackDefinition) -> void:
	if payload == null or attack == null:
		return
	var speed_ratio: float = clampf(
		_line_peak_speed / maxf(crack_speed_threshold, 1.0),
		0.28,
		1.5
	)
	var line_energy: float = lerpf(0.72, 1.35, speed_ratio / 1.5)
	# A straighter whip transfers a little more energy, while a coiled line can
	# still slap nearby targets instead of becoming harmless decoration.
	line_energy *= lerpf(0.88, 1.08, _line_straightness)
	payload.amount = maxi(1, roundi(float(payload.amount) * line_energy))
	payload.stance_damage = maxi(
		0,
		roundi(float(payload.stance_damage) * lerpf(0.72, 1.0, speed_ratio / 1.5))
	)
	payload.knockback_strength *= lerpf(0.52, 0.92, speed_ratio / 1.5)
	_append_payload_tag(payload, "flexible_weapon")
	_append_payload_tag(payload, "whip")
	_append_payload_tag(payload, "line_simulated")
	if is_cracking:
		_append_payload_tag(payload, "whip_crack")
		_append_payload_tag(payload, "sonic")


func modify_payload_for_target(
	payload: DamagePayload,
	target: Node,
	_attack: WeaponAttackDefinition
) -> void:
	if payload == null or target == null:
		return
	var strength: float = clampf(
		float(_contact_strengths.get(target.get_instance_id(), 0.55)),
		0.2,
		1.2
	)
	payload.amount = maxi(1, roundi(float(payload.amount) * lerpf(0.62, 1.08, strength)))
	payload.stance_damage = maxi(
		0,
		roundi(float(payload.stance_damage) * lerpf(0.58, 1.0, strength))
	)
	payload.knockback_strength *= lerpf(0.5, 1.0, strength)
	_append_payload_tag(payload, "whip_line_contact")
	if strength >= 0.92:
		_append_payload_tag(payload, "whip_tip_contact")
	else:
		_append_payload_tag(payload, "whip_body_contact")


func current_attack_supports_crack() -> bool:
	if controller == null or controller.current_attack == null:
		return false
	var attack: WeaponAttackDefinition = controller.current_attack
	return attack.extra_tags.has("crack") or attack.extra_tags.has("snap")


func _drive_tip(target: Vector3, delta: float) -> void:
	if tip_endpoint == null or delta <= 0.0:
		return
	var offset: Vector3 = target - tip_endpoint.global_position
	var desired_velocity: Vector3 = offset / maxf(delta, 0.001)
	var maximum_speed: float = endpoint_max_speed if is_attacking else minf(endpoint_max_speed, 12.0)
	if desired_velocity.length() > maximum_speed:
		desired_velocity = desired_velocity.normalized() * maximum_speed
	var response: float = endpoint_response if is_attacking else 10.0
	var blend: float = 1.0 - exp(-response * delta)
	_tip_drive_velocity = _tip_drive_velocity.lerp(desired_velocity, clampf(blend, 0.0, 1.0))
	tip_endpoint.global_position += _tip_drive_velocity * delta


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "line_whip_v2"
	data["line_peak_speed"] = snappedf(_line_peak_speed, 0.1)
	data["line_straightness"] = snappedf(_line_straightness, 0.01)
	data["contact_targets"] = _contact_strengths.size()
	data["endpoint_drive_speed"] = snappedf(_tip_drive_velocity.length(), 0.1)
	data["body_contact_enabled"] = true
	return data
