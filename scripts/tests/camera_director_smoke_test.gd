extends Node

const GreenScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var target: Node = GreenScene.instantiate()
	add_child(target)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var director: CameraDirector3D = target.get_node_or_null("CameraDirector") as CameraDirector3D
	var player: CharacterBody3D = target.get_node_or_null("Player") as CharacterBody3D
	_expect(director != null, "Green Grotto installs CameraDirector")
	_expect(player != null, "Green Grotto keeps production Grace player")
	if director != null and player != null:
		_validate_director_contract(director)
		_validate_exploration_framing(director, player)
		_validate_context_framing(director, player)
		_validate_camera_zones(target, director, player)
		_validate_landing_transient(director, player)
		_validate_ab_restore(director, player)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_director_contract(director: CameraDirector3D) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("camera_director", false)), "Director publishes camera contract")
	_expect(bool(data.get("initialized", false)), "Director initializes after Grace and level setup")
	_expect(bool(data.get("enabled", false)), "Director starts enabled")
	_expect(bool(data.get("debug_hotkeys", false)), "Green benchmark enables F6 comparison")
	_expect(str(data.get("profile_id", "")) == "grace_exploration", "Director owns Grace exploration profile")
	_expect(bool(data.get("non_authoritative_rotation", false)), "Director never owns camera rotation")
	_expect(not bool(data.get("owns_camera_offsets", true)), "Director leaves h/v impulse offsets to existing presentation code")
	_expect(director.camera_pivot != null, "Director resolves CameraPivot")
	_expect(director.spring_arm != null, "Director resolves SpringArm3D")
	_expect(director.camera != null, "Director resolves Camera3D")


func _validate_exploration_framing(
	director: CameraDirector3D,
	player: CharacterBody3D
) -> void:
	player.global_position = Vector3(0.0, 1.2, 16.0)
	player.velocity = Vector3.ZERO
	var idle: Dictionary = director.sample_targets()
	_expect(str(idle.get("context", "")) == "exploration", "standing camera uses exploration context")

	player.velocity = Vector3(0.0, 0.0, -director.profile.reference_run_speed)
	var running: Dictionary = director.sample_targets()
	_expect(float(running.get("distance", 0.0)) > float(idle.get("distance", 99.0)), "running gently pulls camera back")
	_expect(float(running.get("fov", 0.0)) > float(idle.get("fov", 99.0)), "running gently opens FOV")
	var running_pivot: Vector3 = running.get("pivot", Vector3.ZERO)
	_expect(running_pivot.z < director.authored_pivot_position.z, "forward movement creates subtle forward composition lead")


func _validate_context_framing(
	director: CameraDirector3D,
	player: CharacterBody3D
) -> void:
	player.global_position = Vector3(0.0, 1.2, 16.0)
	player.velocity = Vector3.ZERO
	player.set_meta("shared_placement_active", true)
	var aim: Dictionary = director.sample_targets()
	_expect(str(aim.get("context", "")) == "aim", "ground/spell placement selects aim framing")
	_expect(absf(float(aim.get("distance", 0.0)) - director.profile.aim_distance) < 0.08, "aim framing uses authored closer distance")
	_expect(absf(float(aim.get("fov", 0.0)) - director.profile.aim_fov) < 0.08, "aim framing uses authored focused FOV")
	player.remove_meta("shared_placement_active")

	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	if aerial != null:
		aerial.set("flight_active", true)
		var flight: Dictionary = director.sample_targets()
		_expect(str(flight.get("context", "")) == "flight", "flight selects open flight framing")
		_expect(float(flight.get("distance", 0.0)) >= director.profile.flight_distance - 0.05, "flight pulls camera farther back")
		aerial.set("flight_active", false)
	else:
		_expect(false, "Grace exposes AerialLocomotion for flight camera framing")

	var lock_target := Node3D.new()
	lock_target.name = "CameraLockTarget"
	lock_target.position = player.global_position + Vector3(0.0, 0.0, -14.0)
	add_child(lock_target)
	player.set("lock_on_target", lock_target)
	var lock_state: Dictionary = director.sample_targets()
	_expect(str(lock_state.get("context", "")) == "lock_on", "hard target selects lock-on framing")
	_expect(float(lock_state.get("distance", 0.0)) > director.profile.lock_on_min_distance, "distant lock target pulls framing back")
	player.set("lock_on_target", null)
	lock_target.queue_free()


func _validate_camera_zones(
	target: Node,
	director: CameraDirector3D,
	player: CharacterBody3D
) -> void:
	var expected: Array[String] = [
		"CausewayVistaCameraZone",
		"WaterfallCameraZone",
		"ShrineThresholdCameraZone",
	]
	for zone_name: String in expected:
		var zone: CameraZone3D = target.get_node_or_null(zone_name) as CameraZone3D
		_expect(zone != null, zone_name + " exists")
		if zone != null:
			_expect(zone.get_blend_weight(zone.global_position) >= 0.99, zone_name + " reaches full strength at center")
			_expect(zone.get_blend_weight(zone.global_position + Vector3(zone.zone_extents.x + 1.0, 0.0, 0.0)) == 0.0, zone_name + " falls to zero outside bounds")

	player.velocity = Vector3.ZERO
	player.global_position = Vector3(0.0, 2.8, 1.2)
	var vista: Dictionary = director.sample_targets()
	_expect(_active_zone(vista, "CausewayVistaCameraZone"), "causeway vista zone participates in framing")
	_expect(float(vista.get("distance", 0.0)) > director.profile.base_distance + 0.45, "causeway vista visibly opens camera distance")
	_expect(float(vista.get("fov", 0.0)) > director.profile.base_fov + 1.2, "causeway vista opens composition FOV")

	player.global_position = Vector3(0.0, 3.5, -14.5)
	var shrine: Dictionary = director.sample_targets()
	_expect(_active_zone(shrine, "ShrineThresholdCameraZone"), "shrine threshold zone participates in framing")
	_expect(float(shrine.get("distance", 99.0)) < director.profile.base_distance - 0.20, "shrine threshold gently tightens distance")
	_expect(float(shrine.get("fov", 99.0)) < director.profile.base_fov - 0.9, "shrine threshold gently narrows FOV")


func _validate_landing_transient(
	director: CameraDirector3D,
	player: CharacterBody3D
) -> void:
	player.global_position = Vector3(0.0, 1.2, 16.0)
	player.velocity = Vector3.ZERO
	var before: Dictionary = director.sample_targets()
	var feedback: Node = player.get_node_or_null("PlayerMotionFeedback")
	_expect(feedback != null, "Grace exposes PlayerMotionFeedback for landing camera response")
	if feedback == null:
		return
	feedback.emit_signal("landing_emitted", 1.0)
	var landed: Dictionary = director.sample_targets()
	_expect(director.landing_impulse > 0.95, "landing signal reaches CameraDirector")
	_expect(float(landed.get("distance", 99.0)) < float(before.get("distance", 0.0)), "landing briefly compresses camera distance")
	var before_pivot: Vector3 = before.get("pivot", Vector3.ZERO)
	var landed_pivot: Vector3 = landed.get("pivot", Vector3.ZERO)
	_expect(landed_pivot.y < before_pivot.y, "landing briefly drops framing pivot")


func _validate_ab_restore(
	director: CameraDirector3D,
	_player: CharacterBody3D
) -> void:
	if director.spring_arm == null or director.camera == null or director.camera_pivot == null:
		_expect(false, "A/B restore has complete camera rig")
		return
	director.spring_arm.spring_length = 4.25
	director.camera.fov = 61.0
	director.camera_pivot.position = Vector3(0.3, 0.9, -0.2)
	director.set_enabled(false)
	_expect(not director.enabled, "F6-equivalent disable turns Director off")
	_expect(absf(director.spring_arm.spring_length - director.authored_spring_length) < 0.001, "disable restores authored SpringArm distance")
	_expect(absf(director.camera.fov - director.authored_fov) < 0.001, "disable restores authored Camera3D FOV")
	_expect(director.camera_pivot.position.distance_to(director.authored_pivot_position) < 0.001, "disable restores authored camera pivot")
	director.set_enabled(true)
	_expect(director.enabled, "Director can be re-enabled after A/B comparison")


func _active_zone(state: Dictionary, zone_name: String) -> bool:
	var value: Variant = state.get("active_zones", [])
	if not value is Array:
		return false
	for raw_label: Variant in value as Array:
		if str(raw_label).begins_with(zone_name + ":"):
			return true
	return false


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("CAMERA_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CAMERA_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
