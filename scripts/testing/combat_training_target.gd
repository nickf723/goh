extends CharacterBody3D
class_name CombatTrainingTarget

const AirborneReactionControllerScript = preload("res://scripts/combat/airborne_reaction_controller.gd")
const AirbornePresentationControllerScript = preload("res://scripts/visuals/airborne_presentation_controller.gd")

@export var target_label: String = "Combat Totem"
@export var gravity: float = 18.0
@export var reset_if_below_y: float = -4.0
@export var airborne_presentation_profile: AirbornePresentationProfile

@export_group("Grounded Impact Feel")
@export_range(0.0, 1.0, 0.05) var grounded_knockback_scale: float = 0.56
@export_range(0.5, 8.0, 0.1) var grounded_speed_cap: float = 3.4
@export_range(2.0, 30.0, 0.5) var recoil_recovery_response: float = 11.0
@export_range(0.0, 2.0, 0.05) var recoil_visual_strength: float = 1.0

@onready var hit_receiver: Node = get_node_or_null("HitReceiver")
@onready var status_receiver: Node = get_node_or_null("StatusReceiver")
@onready var force_receiver: Node = get_node_or_null("ForceReceiver")
@onready var name_label: Label3D = get_node_or_null("NameLabel")
@onready var visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D

var initial_transform: Transform3D
var airborne_reaction_controller: Node
var airborne_presentation_controller: Node
var impact_visual_position: Vector3 = Vector3.ZERO
var impact_visual_rotation: Vector3 = Vector3.ZERO
var impact_visual_scale: Vector3 = Vector3.ONE
var last_impact_kind: String = "none"
var impact_count: int = 0


func _ready() -> void:
	initial_transform = global_transform
	add_to_group("enemy")
	add_to_group("combat_arena_resettable")
	add_to_group("airborne_presentation_target")
	add_to_group("debuggable")
	ensure_airborne_controllers()

	if name_label != null:
		name_label.text = target_label

	if hit_receiver != null:
		hit_receiver.set("target_name", target_label)


func ensure_airborne_controllers() -> void:
	airborne_reaction_controller = get_node_or_null("AirborneReactionController")
	if airborne_reaction_controller == null:
		airborne_reaction_controller = AirborneReactionControllerScript.new()
		airborne_reaction_controller.name = "AirborneReactionController"
		add_child(airborne_reaction_controller)

	airborne_presentation_controller = get_node_or_null("AirbornePresentationController")
	if airborne_presentation_controller == null:
		airborne_presentation_controller = AirbornePresentationControllerScript.new()
		airborne_presentation_controller.name = "AirbornePresentationController"
		airborne_presentation_controller.set("profile", airborne_presentation_profile)
		add_child(airborne_presentation_controller)


func _physics_process(delta: float) -> void:
	var external_velocity: Vector3 = Vector3.ZERO

	if force_receiver != null and force_receiver.has_method("consume_external_velocity"):
		external_velocity = force_receiver.call("consume_external_velocity", delta)

	# Ordinary grounded weapon hits should displace the target, not turn it into a
	# loose physics prop. Airborne/launcher state remains free to use the existing
	# airborne reaction stack.
	if is_on_floor() and absf(external_velocity.y) < 0.2:
		var planar := Vector3(external_velocity.x, 0.0, external_velocity.z)
		planar *= grounded_knockback_scale
		if planar.length() > grounded_speed_cap:
			planar = planar.normalized() * grounded_speed_cap
		external_velocity.x = planar.x
		external_velocity.z = planar.z

	velocity.x = external_velocity.x
	velocity.z = external_velocity.z

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	move_and_slide()
	_update_grounded_impact_presentation(delta)

	if global_position.y < reset_if_below_y:
		reset_target()


func receive_weapon_impact(
	payload: DamagePayload,
	direction: Vector3,
	attack: WeaponAttackDefinition
) -> void:
	if payload == null or visual_root == null:
		return
	var horizontal: Vector3 = direction
	horizontal.y = 0.0
	if horizontal.length_squared() <= 0.0001:
		horizontal = Vector3.FORWARD
	horizontal = horizontal.normalized()
	var local_direction: Vector3 = global_transform.basis.orthonormalized().inverse() * horizontal
	var heavy: bool = (
		attack != null
		and (
			attack.input_kind == "heavy"
			or attack.damage_multiplier >= 1.5
			or payload.tags.has("finisher")
		)
	)
	var launcher: bool = (
		payload.knockback_up_strength > 0.8
		or payload.tags.has("launcher")
		or payload.tags.has("ground_launcher")
	)
	var impact_weight: float = clampf(
		0.72
		+ float(maxi(payload.amount, 0)) * 0.08
		+ payload.knockback_strength * 0.055,
		0.72,
		1.55
	) * recoil_visual_strength
	if heavy:
		impact_weight *= 1.22
	if launcher:
		impact_weight *= 1.12

	# A hit reads first as a local body response. World-space knockback remains a
	# separate system, so force can be tuned without erasing contact readability.
	impact_visual_position = Vector3(
		-local_direction.x * 0.055,
		-0.035 * impact_weight,
		local_direction.z * 0.07
	) * impact_weight
	impact_visual_rotation = Vector3(
		deg_to_rad(-8.0 * impact_weight),
		deg_to_rad(local_direction.x * 4.0 * impact_weight),
		deg_to_rad(-local_direction.x * 11.0 * impact_weight)
	)
	impact_visual_scale = (
		Vector3(1.06, 0.9, 1.06)
		if heavy
		else Vector3(1.035, 0.955, 1.035)
	)
	if launcher:
		impact_visual_rotation.x -= deg_to_rad(4.0)
	last_impact_kind = "launcher" if launcher else ("heavy" if heavy else "light")
	impact_count += 1
	_apply_impact_visual_now()


func _update_grounded_impact_presentation(delta: float) -> void:
	if visual_root == null:
		return
	var blend: float = 1.0 - exp(-recoil_recovery_response * maxf(delta, 0.0))
	impact_visual_position = impact_visual_position.lerp(
		Vector3.ZERO,
		clampf(blend, 0.0, 1.0)
	)
	impact_visual_rotation = impact_visual_rotation.lerp(
		Vector3.ZERO,
		clampf(blend * 0.82, 0.0, 1.0)
	)
	impact_visual_scale = impact_visual_scale.lerp(
		Vector3.ONE,
		clampf(blend * 1.08, 0.0, 1.0)
	)
	_apply_impact_visual_now()


func _apply_impact_visual_now() -> void:
	if visual_root == null:
		return
	visual_root.position = impact_visual_position
	visual_root.rotation = impact_visual_rotation
	visual_root.scale = impact_visual_scale


func reset_target() -> void:
	global_transform = initial_transform
	velocity = Vector3.ZERO

	if hit_receiver != null:
		if hit_receiver.has_method("reset_health"):
			hit_receiver.call("reset_health")
		if hit_receiver.has_method("reset_stance"):
			hit_receiver.call("reset_stance")

	clear_statuses()

	if force_receiver != null:
		if force_receiver.has_method("reset_forces"):
			force_receiver.call("reset_forces")
		else:
			force_receiver.set("external_velocity", Vector3.ZERO)
			force_receiver.set("last_force_summary", "none")

	if airborne_reaction_controller != null and airborne_reaction_controller.has_method("reset_reaction"):
		airborne_reaction_controller.call("reset_reaction")
	if airborne_presentation_controller != null and airborne_presentation_controller.has_method("reset_presentation"):
		airborne_presentation_controller.call("reset_presentation")

	impact_visual_position = Vector3.ZERO
	impact_visual_rotation = Vector3.ZERO
	impact_visual_scale = Vector3.ONE
	last_impact_kind = "none"
	impact_count = 0
	_apply_impact_visual_now()


func clear_statuses() -> void:
	if status_receiver == null:
		return

	if status_receiver.has_method("clear_all_statuses"):
		status_receiver.call("clear_all_statuses")
		return

	var active_statuses: Variant = status_receiver.get("active_statuses")
	if active_statuses is Dictionary:
		var status_dictionary: Dictionary = active_statuses as Dictionary
		for status_name: Variant in status_dictionary.keys():
			if status_receiver.has_method("remove_status"):
				status_receiver.call("remove_status", str(status_name))


func get_debug_data() -> Dictionary:
	return {
		"target": target_label,
		"position": global_position,
		"health": hit_receiver.get("current_health") if hit_receiver != null else -1,
		"stance": hit_receiver.get("current_stance") if hit_receiver != null else -1,
		"air": airborne_reaction_controller.call("get_debug_data") if airborne_reaction_controller != null and airborne_reaction_controller.has_method("get_debug_data") else {},
		"presentation": airborne_presentation_controller.call("get_debug_data") if airborne_presentation_controller != null and airborne_presentation_controller.has_method("get_debug_data") else {},
		"grounded_impact_kind": last_impact_kind,
		"grounded_impact_count": impact_count,
		"grounded_recoil_position": impact_visual_position,
		"grounded_recoil_rotation": impact_visual_rotation,
	}
