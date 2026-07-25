extends Node3D
class_name EnemyVisualShell

@export_enum("goblin", "gremlin") var profile: String = "goblin"

@export_group("Locomotion")
@export var idle_bob_amount: float = 0.025
@export var movement_bob_amount: float = 0.055
@export var movement_bob_speed: float = 10.0
@export var idle_bob_speed: float = 3.2
@export var movement_lean_degrees: float = 5.0
@export var head_twitch_degrees: float = 2.0
@export var locomotion_speed_reference: float = 3.0

@export_group("Combat Poses")
@export var windup_pose_time: float = 0.12
@export var active_pose_time: float = 0.07
@export var recover_pose_time: float = 0.18
@export var hit_pose_time: float = 0.16
@export var stagger_pose_time: float = 0.32
@export var defeat_pose_time: float = 0.42

@export_group("Response")
@export var pose_response: float = 13.0
@export var accessory_response: float = 9.0
@export_range(0.0, 1.0, 0.05) var target_tracking_strength: float = 0.65

var actor: CharacterBody3D
var brain: Node
var hit_receiver: Node
var elapsed: float = 0.0
var pose_tween: Tween
var presentation_locked: bool = false
var presentation_state: String = "idle"
var movement_weight: float = 0.0
var previous_health: int = -1
var previous_stance: int = -1

var pose_root: Node3D
var body_pivot: Node3D
var head_pivot: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var weapon_pivot: Node3D
var jaw_pivot: Node3D
var left_ear: Node3D
var right_ear: Node3D
var tail_base: Node3D
var tail_tip: Node3D
var left_hand: Node3D
var right_hand: Node3D

var head_anchor: Marker3D
var left_hand_anchor: Marker3D
var right_hand_anchor: Marker3D
var chest_vfx_anchor: Marker3D
var feet_vfx_anchor: Marker3D

var base_positions: Dictionary = {}
var base_rotations: Dictionary = {}


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor != null:
		brain = actor.get_node_or_null("EnemyBrain")
		hit_receiver = actor.get_node_or_null("HitReceiver")

	resolve_pose_nodes()
	cache_base_pose()
	connect_combat_feedback()
	add_to_group("debuggable")
	sync_animation_anchors()


func resolve_pose_nodes() -> void:
	pose_root = get_node_or_null("PoseRoot") as Node3D
	body_pivot = get_node_or_null("PoseRoot/BodyPivot") as Node3D
	head_pivot = get_node_or_null("PoseRoot/HeadPivot") as Node3D
	left_arm_pivot = get_node_or_null("PoseRoot/LeftArmPivot") as Node3D
	right_arm_pivot = get_node_or_null("PoseRoot/RightArmPivot") as Node3D
	left_leg_pivot = get_node_or_null("PoseRoot/LeftLegPivot") as Node3D
	right_leg_pivot = get_node_or_null("PoseRoot/RightLegPivot") as Node3D
	weapon_pivot = get_node_or_null("PoseRoot/RightArmPivot/WeaponPivot") as Node3D
	jaw_pivot = get_node_or_null("PoseRoot/HeadPivot/JawPivot") as Node3D
	left_ear = get_node_or_null("PoseRoot/HeadPivot/LeftEar") as Node3D
	right_ear = get_node_or_null("PoseRoot/HeadPivot/RightEar") as Node3D
	tail_base = get_node_or_null("PoseRoot/BodyPivot/TailBase") as Node3D
	tail_tip = get_node_or_null("PoseRoot/BodyPivot/TailTip") as Node3D
	left_hand = find_first_node([
		"PoseRoot/LeftArmPivot/Hand",
		"PoseRoot/LeftArmPivot/Wrist",
	])
	right_hand = find_first_node([
		"PoseRoot/RightArmPivot/Hand",
		"PoseRoot/RightArmPivot/Wrist",
	])
	head_anchor = get_node_or_null("HeadAnchor") as Marker3D
	left_hand_anchor = get_node_or_null("LeftHandAnchor") as Marker3D
	right_hand_anchor = get_node_or_null("RightHandAnchor") as Marker3D
	chest_vfx_anchor = get_node_or_null("ChestVFXAnchor") as Marker3D
	feet_vfx_anchor = get_node_or_null("FeetVFXAnchor") as Marker3D


func find_first_node(paths: Array[String]) -> Node3D:
	for path: String in paths:
		var found: Node3D = get_node_or_null(path) as Node3D
		if found != null:
			return found
	return null


func connect_combat_feedback() -> void:
	if hit_receiver == null:
		return

	previous_health = int(hit_receiver.get("current_health"))
	previous_stance = int(hit_receiver.get("current_stance"))

	if hit_receiver.has_signal("health_changed"):
		hit_receiver.connect("health_changed", Callable(self, "_on_health_changed"))
	if hit_receiver.has_signal("stance_changed"):
		hit_receiver.connect("stance_changed", Callable(self, "_on_stance_changed"))
	if hit_receiver.has_signal("stance_broken"):
		hit_receiver.connect("stance_broken", Callable(self, "_on_stance_broken"))
	if hit_receiver.has_signal("health_depleted"):
		hit_receiver.connect("health_depleted", Callable(self, "_on_health_depleted"))


func _process(delta: float) -> void:
	if pose_root == null:
		return

	elapsed += maxf(delta, 0.0)

	if not presentation_locked:
		sample_locomotion_pose(delta)

	sync_animation_anchors()


func sample_locomotion_pose(delta: float) -> void:
	var horizontal_velocity: Vector3 = Vector3.ZERO
	if actor != null:
		horizontal_velocity = Vector3(actor.velocity.x, 0.0, actor.velocity.z)

	var speed: float = horizontal_velocity.length()
	movement_weight = clampf(
		speed / maxf(locomotion_speed_reference, 0.1),
		0.0,
		1.0
	)
	presentation_state = resolve_passive_state()

	var frequency: float = lerpf(idle_bob_speed, movement_bob_speed, movement_weight)
	var phase: float = elapsed * frequency
	var step_wave: float = sin(phase)
	var footfall: float = abs(sin(phase))
	var bob: float = sin(elapsed * idle_bob_speed) * idle_bob_amount
	bob = lerpf(bob, footfall * movement_bob_amount, movement_weight)

	var root_position := Vector3(0.0, bob, 0.0)
	var root_rotation := Vector3.ZERO
	var body_rotation := Vector3.ZERO
	var head_rotation := Vector3.ZERO
	var left_arm_rotation := Vector3.ZERO
	var right_arm_rotation := Vector3.ZERO
	var left_leg_rotation := Vector3.ZERO
	var right_leg_rotation := Vector3.ZERO
	var jaw_rotation := Vector3.ZERO

	var local_velocity: Vector3 = horizontal_velocity
	if actor != null:
		local_velocity = actor.global_transform.basis.inverse() * horizontal_velocity

	root_rotation.x += deg_to_rad(
		clampf(
			local_velocity.z * 1.2,
			-movement_lean_degrees,
			movement_lean_degrees
		)
	)
	root_rotation.z += deg_to_rad(
		clampf(
			-local_velocity.x * 1.2,
			-movement_lean_degrees,
			movement_lean_degrees
		)
	)

	if profile == "gremlin":
		left_leg_rotation.x = step_wave * 0.72 * movement_weight
		right_leg_rotation.x = -step_wave * 0.72 * movement_weight
		left_arm_rotation.x = -step_wave * 0.58 * movement_weight
		right_arm_rotation.x = step_wave * 0.58 * movement_weight
		body_rotation.y = -step_wave * 0.1 * movement_weight
		body_rotation.x -= 0.08 * movement_weight
		head_rotation.z = sin(elapsed * 7.5) * deg_to_rad(1.5)
		jaw_rotation.x = maxf(step_wave, 0.0) * 0.08 * movement_weight
	else:
		left_leg_rotation.x = step_wave * 0.46 * movement_weight
		right_leg_rotation.x = -step_wave * 0.46 * movement_weight
		left_arm_rotation.x = -step_wave * 0.34 * movement_weight
		right_arm_rotation.x = step_wave * 0.34 * movement_weight
		body_rotation.y = -step_wave * 0.055 * movement_weight
		body_rotation.x -= 0.045 * movement_weight
		root_position.y += footfall * 0.012 * movement_weight

	var twitch_speed: float = 5.5 if profile == "gremlin" else 2.4
	head_rotation.y += deg_to_rad(
		sin(elapsed * twitch_speed) * head_twitch_degrees
	)
	head_rotation.y += get_target_tracking_yaw() * target_tracking_strength

	if presentation_state == "staggered":
		body_rotation += Vector3(0.18, 0.0, -0.12)
		head_rotation += Vector3(-0.12, 0.0, 0.1)
		left_arm_rotation += Vector3(0.32, 0.0, -0.28)
		right_arm_rotation += Vector3(0.46, 0.0, 0.34)
		root_position.y -= 0.055
	elif presentation_state == "alert":
		if profile == "gremlin":
			body_rotation.x -= 0.13
			left_arm_rotation.z -= 0.14
			right_arm_rotation.z += 0.14
			jaw_rotation.x += 0.08
		else:
			body_rotation.x -= 0.07
			right_arm_rotation.x -= 0.12
			head_rotation.x += 0.05

	pose_node(pose_root, root_rotation, root_position, delta, pose_response)
	pose_node(body_pivot, body_rotation, Vector3.ZERO, delta, pose_response)
	pose_node(head_pivot, head_rotation, Vector3.ZERO, delta, pose_response)
	pose_node(left_arm_pivot, left_arm_rotation, Vector3.ZERO, delta, pose_response)
	pose_node(right_arm_pivot, right_arm_rotation, Vector3.ZERO, delta, pose_response)
	pose_node(left_leg_pivot, left_leg_rotation, Vector3.ZERO, delta, pose_response)
	pose_node(right_leg_pivot, right_leg_rotation, Vector3.ZERO, delta, pose_response)
	pose_node(jaw_pivot, jaw_rotation, Vector3.ZERO, delta, pose_response)
	pose_accessories(delta, phase)


func resolve_passive_state() -> String:
	if brain == null:
		return "locomotion" if movement_weight > 0.05 else "idle"

	var state_id: int = int(brain.get("state"))
	match state_id:
		1:
			return "alert"
		4:
			return "staggered"
		5:
			return "defeated"
		_:
			return "locomotion" if movement_weight > 0.05 else "idle"


func pose_accessories(delta: float, phase: float) -> void:
	var sway: float = sin(phase * 0.72)
	var twitch: float = sin(elapsed * (8.5 if profile == "gremlin" else 3.8))

	if left_ear != null:
		pose_node(
			left_ear,
			Vector3(twitch * 0.04, sway * 0.045, -sway * 0.05),
			Vector3.ZERO,
			delta,
			accessory_response
		)
	if right_ear != null:
		pose_node(
			right_ear,
			Vector3(twitch * 0.04, -sway * 0.045, sway * 0.05),
			Vector3.ZERO,
			delta,
			accessory_response
		)
	if tail_base != null:
		pose_node(
			tail_base,
			Vector3(0.0, sway * 0.16, sway * 0.12),
			Vector3.ZERO,
			delta,
			accessory_response
		)
	if tail_tip != null:
		pose_node(
			tail_tip,
			Vector3(0.0, -sway * 0.26, -sway * 0.18),
			Vector3.ZERO,
			delta,
			accessory_response
		)


func get_target_tracking_yaw() -> float:
	if actor == null or brain == null:
		return 0.0
	var target: Node3D = brain.get("player") as Node3D
	if target == null or not is_instance_valid(target):
		return 0.0

	var direction: Vector3 = target.global_position - actor.global_position
	direction.y = 0.0
	if direction.length() <= 0.01:
		return 0.0

	var local_direction: Vector3 = actor.global_transform.basis.inverse() * direction.normalized()
	return clampf(atan2(-local_direction.x, -local_direction.z), -0.42, 0.42)


func start_windup() -> void:
	kill_pose_tween()
	presentation_locked = true
	presentation_state = "windup"
	restore_base_pose()
	pose_tween = create_tween()
	pose_tween.set_parallel(true)

	if profile == "gremlin":
		tween_rotation(body_pivot, Vector3(-24.0, -8.0, 0.0), windup_pose_time)
		tween_position(body_pivot, Vector3(0.0, -0.12, -0.08), windup_pose_time)
		tween_rotation(head_pivot, Vector3(-18.0, 0.0, 0.0), windup_pose_time)
		tween_rotation(left_arm_pivot, Vector3(-38.0, 0.0, -42.0), windup_pose_time)
		tween_rotation(right_arm_pivot, Vector3(-38.0, 0.0, 42.0), windup_pose_time)
		tween_rotation(left_leg_pivot, Vector3(24.0, 0.0, -10.0), windup_pose_time)
		tween_rotation(right_leg_pivot, Vector3(24.0, 0.0, 10.0), windup_pose_time)
		tween_rotation(jaw_pivot, Vector3(28.0, 0.0, 0.0), windup_pose_time)
		tween_rotation(tail_base, Vector3(-12.0, 18.0, 12.0), windup_pose_time)
		tween_rotation(tail_tip, Vector3(-18.0, -28.0, -16.0), windup_pose_time)
	else:
		tween_rotation(body_pivot, Vector3(-14.0, -18.0, 0.0), windup_pose_time)
		tween_position(body_pivot, Vector3(0.0, -0.05, 0.04), windup_pose_time)
		tween_rotation(head_pivot, Vector3(8.0, 10.0, 0.0), windup_pose_time)
		tween_rotation(left_arm_pivot, Vector3(-18.0, 0.0, -24.0), windup_pose_time)
		tween_rotation(right_arm_pivot, Vector3(-72.0, -10.0, 36.0), windup_pose_time)
		tween_rotation(weapon_pivot, Vector3(-38.0, 0.0, -18.0), windup_pose_time)
		tween_rotation(jaw_pivot, Vector3(12.0, 0.0, 0.0), windup_pose_time)


func start_active() -> void:
	kill_pose_tween()
	presentation_locked = true
	presentation_state = "active"
	pose_tween = create_tween()
	pose_tween.set_parallel(true)

	if profile == "gremlin":
		tween_rotation(pose_root, Vector3(-18.0, 0.0, 0.0), active_pose_time)
		tween_position(pose_root, Vector3(0.0, 0.05, -0.16), active_pose_time)
		tween_rotation(body_pivot, Vector3(18.0, 8.0, 0.0), active_pose_time)
		tween_rotation(head_pivot, Vector3(24.0, 0.0, 0.0), active_pose_time)
		tween_rotation(left_arm_pivot, Vector3(-96.0, 0.0, -20.0), active_pose_time)
		tween_rotation(right_arm_pivot, Vector3(-96.0, 0.0, 20.0), active_pose_time)
		tween_rotation(left_leg_pivot, Vector3(42.0, 0.0, -8.0), active_pose_time)
		tween_rotation(right_leg_pivot, Vector3(42.0, 0.0, 8.0), active_pose_time)
		tween_rotation(jaw_pivot, Vector3(36.0, 0.0, 0.0), active_pose_time)
	else:
		tween_rotation(body_pivot, Vector3(12.0, 34.0, 0.0), active_pose_time)
		tween_position(body_pivot, Vector3(0.0, 0.0, -0.08), active_pose_time)
		tween_rotation(head_pivot, Vector3(-6.0, -12.0, 0.0), active_pose_time)
		tween_rotation(left_arm_pivot, Vector3(28.0, 0.0, -34.0), active_pose_time)
		tween_rotation(right_arm_pivot, Vector3(-118.0, 18.0, -24.0), active_pose_time)
		tween_rotation(weapon_pivot, Vector3(72.0, 0.0, 24.0), active_pose_time)
		tween_rotation(jaw_pivot, Vector3(18.0, 0.0, 0.0), active_pose_time)


func start_hit_reaction(severity: float = 1.0) -> void:
	if presentation_state == "defeated":
		return
	kill_pose_tween()
	presentation_locked = true
	presentation_state = "hit"
	pose_tween = create_tween()
	pose_tween.set_parallel(true)

	var weight: float = clampf(severity, 0.55, 1.35)
	tween_rotation(pose_root, Vector3(10.0 * weight, 0.0, -11.0 * weight), hit_pose_time)
	tween_position(pose_root, Vector3(0.05 * weight, 0.02, 0.08 * weight), hit_pose_time)
	tween_rotation(body_pivot, Vector3(18.0 * weight, 0.0, -8.0 * weight), hit_pose_time)
	tween_rotation(head_pivot, Vector3(-14.0 * weight, 0.0, 12.0 * weight), hit_pose_time)
	tween_rotation(left_arm_pivot, Vector3(32.0 * weight, 0.0, -26.0), hit_pose_time)
	tween_rotation(right_arm_pivot, Vector3(44.0 * weight, 0.0, 34.0), hit_pose_time)
	tween_rotation(jaw_pivot, Vector3(18.0, 0.0, 0.0), hit_pose_time)
	pose_tween.finished.connect(Callable(self, "start_recover"))


func start_stagger() -> void:
	if presentation_state == "defeated":
		return
	kill_pose_tween()
	presentation_locked = true
	presentation_state = "stagger"
	pose_tween = create_tween()
	pose_tween.set_parallel(true)
	tween_rotation(pose_root, Vector3(8.0, 0.0, -16.0), stagger_pose_time)
	tween_position(pose_root, Vector3(0.08, -0.08, 0.12), stagger_pose_time)
	tween_rotation(body_pivot, Vector3(26.0, -12.0, -10.0), stagger_pose_time)
	tween_rotation(head_pivot, Vector3(-18.0, 8.0, 14.0), stagger_pose_time)
	tween_rotation(left_arm_pivot, Vector3(50.0, 0.0, -42.0), stagger_pose_time)
	tween_rotation(right_arm_pivot, Vector3(62.0, 0.0, 48.0), stagger_pose_time)
	tween_rotation(left_leg_pivot, Vector3(-16.0, 0.0, -8.0), stagger_pose_time)
	tween_rotation(right_leg_pivot, Vector3(24.0, 0.0, 10.0), stagger_pose_time)
	pose_tween.finished.connect(Callable(self, "_on_stagger_pose_finished"))


func start_defeat() -> void:
	kill_pose_tween()
	presentation_locked = true
	presentation_state = "defeated"
	pose_tween = create_tween()
	pose_tween.set_parallel(true)

	var fall_side: float = -1.0 if profile == "goblin" else 1.0
	tween_rotation(
		pose_root,
		Vector3(6.0, 0.0, 82.0 * fall_side),
		defeat_pose_time
	)
	tween_position(
		pose_root,
		Vector3(0.28 * fall_side, -0.34, 0.06),
		defeat_pose_time
	)
	tween_rotation(body_pivot, Vector3(18.0, 12.0 * fall_side, 0.0), defeat_pose_time)
	tween_rotation(head_pivot, Vector3(-16.0, -10.0 * fall_side, 12.0 * fall_side), defeat_pose_time)
	tween_rotation(left_arm_pivot, Vector3(36.0, 0.0, -52.0), defeat_pose_time)
	tween_rotation(right_arm_pivot, Vector3(-18.0, 0.0, 46.0), defeat_pose_time)
	tween_rotation(left_leg_pivot, Vector3(-18.0, 0.0, -12.0), defeat_pose_time)
	tween_rotation(right_leg_pivot, Vector3(24.0, 0.0, 14.0), defeat_pose_time)


func start_recover() -> void:
	kill_pose_tween()
	if presentation_state == "defeated":
		return
	presentation_locked = true
	presentation_state = "recover"
	pose_tween = create_tween()
	pose_tween.set_parallel(true)

	for node: Node3D in get_pose_nodes():
		if node == null:
			continue
		pose_tween.tween_property(
			node,
			"position",
			get_base_position(node),
			recover_pose_time
		)
		pose_tween.tween_property(
			node,
			"rotation",
			get_base_rotation(node),
			recover_pose_time
		)

	pose_tween.finished.connect(Callable(self, "_on_recover_finished"))


func reset_presentation() -> void:
	if presentation_state == "defeated":
		return
	kill_pose_tween()
	presentation_locked = false
	presentation_state = "idle"
	restore_base_pose()


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	if previous_health < 0:
		previous_health = maximum_health
	var damage: int = maxi(previous_health - current_health, 0)
	previous_health = current_health
	if damage > 0 and current_health > 0:
		start_hit_reaction(
			clampf(float(damage) / maxf(float(maximum_health) * 0.35, 1.0), 0.6, 1.3)
		)


func _on_stance_changed(current_stance: int, maximum_stance: int) -> void:
	if previous_stance < 0:
		previous_stance = maximum_stance
	var damage: int = maxi(previous_stance - current_stance, 0)
	previous_stance = current_stance
	if damage > 0 and current_stance > 0:
		start_hit_reaction(
			clampf(float(damage) / maxf(float(maximum_stance) * 0.45, 1.0), 0.55, 1.0)
		)


func _on_stance_broken() -> void:
	start_stagger()


func _on_health_depleted() -> void:
	start_defeat()


func _on_stagger_pose_finished() -> void:
	presentation_locked = false
	pose_tween = null


func cache_base_pose() -> void:
	base_positions.clear()
	base_rotations.clear()

	for node: Node3D in get_pose_nodes():
		if node == null:
			continue
		base_positions[node.get_instance_id()] = node.position
		base_rotations[node.get_instance_id()] = node.rotation


func restore_base_pose() -> void:
	for node: Node3D in get_pose_nodes():
		if node == null:
			continue
		node.position = get_base_position(node)
		node.rotation = get_base_rotation(node)


func get_pose_nodes() -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	for node: Node3D in [
		pose_root,
		body_pivot,
		head_pivot,
		left_arm_pivot,
		right_arm_pivot,
		left_leg_pivot,
		right_leg_pivot,
		weapon_pivot,
		jaw_pivot,
		left_ear,
		right_ear,
		tail_base,
		tail_tip,
	]:
		if node != null:
			nodes.append(node)
	return nodes


func get_base_position(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return base_positions.get(node.get_instance_id(), node.position)


func get_base_rotation(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return base_rotations.get(node.get_instance_id(), node.rotation)


func pose_node(
	node: Node3D,
	rotation_offset: Vector3,
	position_offset: Vector3,
	delta: float,
	response: float
) -> void:
	if node == null:
		return
	var target_rotation: Vector3 = get_base_rotation(node) + rotation_offset
	var target_position: Vector3 = get_base_position(node) + position_offset
	var weight: float = clampf(delta * response, 0.0, 1.0)
	node.rotation = Vector3(
		lerp_angle(node.rotation.x, target_rotation.x, weight),
		lerp_angle(node.rotation.y, target_rotation.y, weight),
		lerp_angle(node.rotation.z, target_rotation.z, weight)
	)
	node.position = node.position.lerp(target_position, weight)


func tween_position(node: Node3D, offset: Vector3, duration: float) -> void:
	if node == null or pose_tween == null:
		return
	pose_tween.tween_property(
		node,
		"position",
		get_base_position(node) + offset,
		duration
	)


func tween_rotation(
	node: Node3D,
	offset_degrees: Vector3,
	duration: float
) -> void:
	if node == null or pose_tween == null:
		return
	pose_tween.tween_property(
		node,
		"rotation",
		get_base_rotation(node) + degrees_to_radians(offset_degrees),
		duration
	)


func degrees_to_radians(value: Vector3) -> Vector3:
	return Vector3(
		deg_to_rad(value.x),
		deg_to_rad(value.y),
		deg_to_rad(value.z)
	)


func sync_animation_anchors() -> void:
	if head_pivot != null and head_anchor != null:
		head_anchor.global_position = head_pivot.global_position
	if left_hand != null and left_hand_anchor != null:
		left_hand_anchor.global_position = left_hand.global_position
	if right_hand != null and right_hand_anchor != null:
		right_hand_anchor.global_position = right_hand.global_position
	if body_pivot != null and chest_vfx_anchor != null:
		chest_vfx_anchor.global_position = body_pivot.to_global(Vector3(0.0, 0.18, -0.3))
	if pose_root != null and feet_vfx_anchor != null:
		feet_vfx_anchor.global_position = pose_root.to_global(Vector3(0.0, -0.48, 0.0))


func kill_pose_tween() -> void:
	if pose_tween != null:
		pose_tween.kill()
		pose_tween = null


func _on_recover_finished() -> void:
	presentation_locked = false
	presentation_state = "idle"
	pose_tween = null


func get_animation_debug_data() -> Dictionary:
	return {
		"profile": profile,
		"presentation_state": presentation_state,
		"movement_weight": snappedf(movement_weight, 0.01),
		"articulated_pivots": get_pose_nodes().size(),
		"presentation_locked": presentation_locked,
		"target_tracking": snappedf(get_target_tracking_yaw(), 0.01),
	}


func get_debug_data() -> Dictionary:
	return get_animation_debug_data()
