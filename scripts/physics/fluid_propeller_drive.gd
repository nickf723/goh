extends Node3D
class_name FluidPropellerDrive

@export var enabled: bool = true
@export var propeller_local_position: Vector3 = Vector3(0.0, -0.35, 1.8)
@export var thrust_newtons_per_1000_rpm: float = 24.0
@export var maximum_thrust_newtons: float = 42.0
@export var minimum_effective_rpm: float = 80.0
@export var thrust_direction_local: Vector3 = Vector3.FORWARD
@export var visual_path: NodePath
@export var emit_churn_visuals: bool = true
@export var churn_strength_scale: float = 1.0

var shaft: RotationalShaftState
var body: FieldResponsiveBody
var buoyancy_receiver: BuoyancyReceiver
var force_receiver: ForceReceiver
var visual: Node3D
var submerged: bool = false
var last_thrust_newtons: float = 0.0
var last_direction_world: Vector3 = Vector3.ZERO
var total_impulse_newton_seconds: float = 0.0
var churn_timer: float = 0.0
var churn_event_count: int = 0


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	if not visual_path.is_empty():
		visual = get_node_or_null(visual_path) as Node3D


func _physics_process(delta: float) -> void:
	step_propeller(delta)


func configure(
	next_shaft: RotationalShaftState,
	next_body: FieldResponsiveBody,
	next_buoyancy_receiver: BuoyancyReceiver
) -> void:
	shaft = next_shaft
	body = next_body
	buoyancy_receiver = next_buoyancy_receiver
	force_receiver = body.get_node_or_null("ForceReceiver") as ForceReceiver if body != null else null


func step_propeller(delta: float = 0.0) -> float:
	churn_timer = max(churn_timer - max(delta, 0.0), 0.0)
	if not enabled or shaft == null or body == null or buoyancy_receiver == null or force_receiver == null:
		clear_thrust()
		return 0.0

	var propeller_world_position: Vector3 = body.global_transform * propeller_local_position
	var volume: FluidForceVolume = buoyancy_receiver.active_volume
	submerged = (
		volume != null
		and volume.contains_point(propeller_world_position, 0.12)
	)
	var rpm: float = shaft.current_rpm
	if not submerged or absf(rpm) < minimum_effective_rpm:
		clear_thrust()
		rotate_visual(delta, rpm)
		return 0.0

	var local_direction: Vector3 = thrust_direction_local.normalized()
	if local_direction.length() <= 0.001:
		local_direction = Vector3.FORWARD
	last_direction_world = (body.global_transform.basis * local_direction).normalized() * signf(rpm)
	last_thrust_newtons = min(
		absf(rpm) / 1000.0 * max(thrust_newtons_per_1000_rpm, 0.0),
		max(maximum_thrust_newtons, 0.0)
	)
	force_receiver.set_continuous_force(
		get_force_source_id(),
		last_direction_world * last_thrust_newtons
	)
	if delta > 0.0:
		total_impulse_newton_seconds += last_thrust_newtons * delta
		emit_churn(volume, propeller_world_position, rpm)
	rotate_visual(delta, rpm)
	return last_thrust_newtons


func emit_churn(volume: FluidForceVolume, world_position: Vector3, rpm: float) -> void:
	if not emit_churn_visuals or volume == null or churn_timer > 0.0:
		return
	var profile: FluidPresentationProfile = volume.get_presentation_profile()
	var interval: float = profile.churn_interval_seconds if profile != null else 0.12
	churn_timer = max(interval, 0.06)
	var rpm_ratio: float = clampf(absf(rpm) / max(shaft.maximum_abs_rpm, 1.0), 0.0, 1.0)
	var thrust_ratio: float = clampf(last_thrust_newtons / max(maximum_thrust_newtons, 0.01), 0.0, 1.0)
	var strength: float = clampf(
		(0.45 + rpm_ratio * 1.6 + thrust_ratio * 1.2) * max(churn_strength_scale, 0.0),
		0.35,
		4.0
	)
	volume.emit_disturbance(
		FluidDisturbanceEvent.KIND_CHURN,
		world_position,
		last_direction_world,
		last_direction_world * last_thrust_newtons,
		strength,
		0.28 + rpm_ratio * 0.42,
		"fluid_propeller:" + str(get_instance_id()),
		["water", "propeller", "rotation_driven"],
		{
			"rpm": rpm,
			"thrust_newtons": last_thrust_newtons,
			"body_name": body.name,
		}
	)
	churn_event_count += 1


func rotate_visual(delta: float, rpm: float) -> void:
	if visual == null or delta <= 0.0 or absf(rpm) <= 0.01:
		return
	visual.rotate(Vector3.FORWARD, TAU * rpm / 60.0 * delta)


func clear_thrust() -> void:
	submerged = false
	last_thrust_newtons = 0.0
	last_direction_world = Vector3.ZERO
	if force_receiver != null:
		force_receiver.clear_continuous_force(get_force_source_id())


func get_force_source_id() -> String:
	return "fluid_propeller:" + str(get_instance_id())


func reset_target() -> void:
	clear_thrust()
	total_impulse_newton_seconds = 0.0
	churn_timer = 0.0
	churn_event_count = 0


func get_debug_data() -> Dictionary:
	return {
		"fluid_propeller": true,
		"enabled": enabled,
		"submerged": submerged,
		"rpm": snapped(shaft.current_rpm, 0.1) if shaft != null else 0.0,
		"thrust_newtons": snapped(last_thrust_newtons, 0.01),
		"direction": last_direction_world,
		"total_impulse": snapped(total_impulse_newton_seconds, 0.01),
		"churn_events": churn_event_count,
	}
