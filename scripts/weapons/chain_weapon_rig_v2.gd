extends "res://scripts/weapons/chain_weapon_rig_3d.gd"
class_name ChainWeaponRigV2

const FlexibleContactSampler = preload(
	"res://scripts/weapons/flexible_weapon_contact_sampler.gd"
)

@export_range(6.0, 40.0, 1.0) var endpoint_max_speed: float = 24.0
@export_range(2.0, 30.0, 1.0) var endpoint_response: float = 12.0
@export_range(0.1, 1.0, 0.01) var body_contact_radius_scale: float = 0.7

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
		tether.verlet_damping = 0.925
		tether.constraint_iterations = 13
		tether.gravity_scale = 0.32
		tether.debug_tension_color = false
	_desired_tip_position = weighted_tip.global_position if weighted_tip != null else global_position


func configure_weapon(new_weapon: WeaponDefinition, new_controller: WeaponController) -> void:
	super.configure_weapon(new_weapon, new_controller)
	if weighted_tip != null:
		_desired_tip_position = weighted_tip.global_position
	_tip_drive_velocity = Vector3.ZERO


func _process(_delta: float) -> void:
	if controller == null or weighted_tip == null:
		return
	if not is_attacking:
		_desired_tip_position = (
			_get_handle_position()
			+ _get_forward() * 0.45
			+ Vector3.DOWN * 0.9
		)


func _physics_process(delta: float) -> void:
	_last_physics_delta = maxf(delta, 0.001)
	if controller == null or weighted_tip == null:
		return
	_update_handle()
	_drive_tip(_desired_tip_position, delta)
	_update_tip_kinematics(delta)
	_line_peak_speed = FlexibleContactSampler.get_peak_speed(tether, delta, 0.05)
	_line_straightness = FlexibleContactSampler.get_straightness(tether)


func begin_attack(attack: WeaponAttackDefinition, attack_speed: float) -> void:
	super.begin_attack(attack, attack_speed)
	_tip_drive_velocity *= 0.4
	_contact_strengths.clear()
	_desired_tip_position = weighted_tip.global_position


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or weighted_tip == null:
		return
	_update_handle()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active_end: float = startup + attack.get_active_duration(attack_speed)
	var total: float = attack.get_total_duration(attack_speed)
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _get_forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	if elapsed <= startup:
		var weight: float = smoothstep(
			0.0,
			1.0,
			clampf(elapsed / maxf(startup, 0.01), 0.0, 1.0)
		)
		if attack.extra_tags.has("slam"):
			_desired_tip_position = handle + forward * lerpf(0.72, chain_length * 1.02, weight)
			_desired_tip_position.y += lerpf(1.8, -0.45, weight)
		else:
			var reverse: bool = attack.extra_tags.has("reverse")
			var start_angle: float = deg_to_rad(105.0 if reverse else -105.0)
			var end_angle: float = deg_to_rad(-105.0 if reverse else 105.0)
			var angle: float = lerpf(start_angle, end_angle, weight)
			var radius: float = minf(
				chain_length * lerpf(0.72, 1.0, weight),
				maxf(attack.attack_range, 1.0)
			)
			_desired_tip_position = (
				handle
				+ forward * cos(angle) * radius
				+ right * sin(angle) * radius
				+ Vector3.UP * sin(weight * PI) * 0.18
			)
	elif elapsed <= active_end:
		pass
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
		var idle_target: Vector3 = handle + forward * 0.45 + Vector3.DOWN * 0.9
		_desired_tip_position = _desired_tip_position.lerp(idle_target, recovery_weight)


func end_attack() -> void:
	super.end_attack()
	_contact_strengths.clear()
	_tip_drive_velocity *= 0.5
	if weighted_tip != null:
		_desired_tip_position = weighted_tip.global_position


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
	sphere.radius = maxf(contact_radius * body_contact_radius_scale, 0.16)
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var seen: Dictionary = {}
	var samples: Array[Dictionary] = FlexibleContactSampler.sample_tether(
		tether,
		_last_physics_delta,
		0.04,
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
		for result: Dictionary in space_state.intersect_shape(query, 20):
			var collider: Node = result.get("collider") as Node
			if collider == null:
				continue
			var target: Node = weapon_controller.find_payload_target(collider)
			if target == null or target == actor:
				continue
			var fraction: float = clampf(float(sample.get("fraction", 0.0)), 0.0, 1.0)
			var speed: float = maxf(float(sample.get("speed", 0.0)), 0.0)
			var head_weight: float = 0.5 + 0.5 * pow(fraction, 1.3)
			var speed_weight: float = clampf(speed / 11.0, 0.42, 1.25)
			var contact_strength: float = clampf(head_weight * speed_weight, 0.28, 1.25)
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
	var head_momentum: float = maxf(current_tip_speed, peak_tip_speed) * tip_mass
	var line_momentum: float = _line_peak_speed * maxf(tip_mass * 0.3, 0.25)
	var momentum: float = maxf(head_momentum, line_momentum)
	var ratio: float = clampf(momentum / 20.0, 0.55, 1.5)
	payload.knockback_strength *= lerpf(0.72, 1.42, ratio / 1.5)
	payload.stance_damage = maxi(
		1,
		roundi(float(payload.stance_damage) * lerpf(0.82, 1.28, ratio / 1.5))
	)
	if not payload.tags.has("flexible_weapon"):
		payload.tags.append("flexible_weapon")
	if not payload.tags.has("chain"):
		payload.tags.append("chain")
	if not payload.tags.has("line_simulated"):
		payload.tags.append("line_simulated")


func modify_payload_for_target(
	payload: DamagePayload,
	target: Node,
	_attack: WeaponAttackDefinition
) -> void:
	if payload == null or target == null:
		return
	var strength: float = clampf(
		float(_contact_strengths.get(target.get_instance_id(), 0.62)),
		0.28,
		1.25
	)
	payload.amount = maxi(1, roundi(float(payload.amount) * lerpf(0.68, 1.1, strength)))
	payload.stance_damage = maxi(
		1,
		roundi(float(payload.stance_damage) * lerpf(0.7, 1.08, strength))
	)
	payload.knockback_strength *= lerpf(0.62, 1.08, strength)
	if strength >= 0.95:
		if not payload.tags.has("weighted_tip"):
			payload.tags.append("weighted_tip")
	else:
		if not payload.tags.has("chain_body_contact"):
			payload.tags.append("chain_body_contact")


func _drive_tip(target: Vector3, delta: float) -> void:
	if weighted_tip == null or delta <= 0.0:
		return
	var offset: Vector3 = target - weighted_tip.global_position
	var desired_velocity: Vector3 = offset / maxf(delta, 0.001)
	var maximum_speed: float = endpoint_max_speed if is_attacking else minf(endpoint_max_speed, 9.0)
	if desired_velocity.length() > maximum_speed:
		desired_velocity = desired_velocity.normalized() * maximum_speed
	var response: float = endpoint_response if is_attacking else 8.0
	var blend: float = 1.0 - exp(-response * delta)
	_tip_drive_velocity = _tip_drive_velocity.lerp(desired_velocity, clampf(blend, 0.0, 1.0))
	weighted_tip.global_position += _tip_drive_velocity * delta


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "full_line_chain_v2"
	data["line_peak_speed"] = snappedf(_line_peak_speed, 0.1)
	data["line_straightness"] = snappedf(_line_straightness, 0.01)
	data["contact_targets"] = _contact_strengths.size()
	data["endpoint_drive_speed"] = snappedf(_tip_drive_velocity.length(), 0.1)
	data["body_contact_enabled"] = true
	return data
