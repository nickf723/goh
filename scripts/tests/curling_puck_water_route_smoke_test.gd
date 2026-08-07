extends Node

const PuckScene: PackedScene = preload(
	"res://scenes/actions/curling_puck.tscn"
)
const PuckAbility: AbilityDefinition = preload(
	"res://data/abilities/curling_puck_ability.tres"
)
const WaterVolumeScript = preload(
	"res://scripts/water/swimming_water_volume.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var near_shore: StaticBody3D = _make_floor(
		"NearShore",
		Vector3(0.0, -0.5, 14.0),
		Vector3(12.0, 1.0, 4.0)
	)
	var pool_bottom: StaticBody3D = _make_floor(
		"PoolBottom",
		Vector3(0.0, -3.5, 23.0),
		Vector3(12.0, 1.0, 14.0)
	)
	var far_shore: StaticBody3D = _make_floor(
		"FarShore",
		Vector3(0.0, -0.5, 33.0),
		Vector3(12.0, 1.0, 6.0)
	)
	add_child(near_shore)
	add_child(pool_bottom)
	add_child(far_shore)
	var water: SwimmingWaterVolume = _make_water_volume()
	add_child(water)

	var source := CharacterBody3D.new()
	source.name = "CurlingWaterRouteSource"
	source.position = Vector3(0.0, 1.0, 13.6)
	add_child(source)
	await get_tree().process_frame
	await get_tree().physics_frame

	Input.action_release("move_left")
	Input.action_release("move_right")
	var puck: CurlingPuck = PuckScene.instantiate() as CurlingPuck
	puck.name = "GroundWaterGroundPuck"
	puck.set_payload(PuckAbility.get_action_payload())
	puck.set_source_actor(source)
	add_child(puck)
	puck.execute(source, Vector3.BACK)
	puck.set_physics_process(false)
	var trail: CurlingIceTrail = puck.get_trail()
	_expect(trail != null, "the route fixture creates one ice trail")

	# Stop once the puck is safely on the far shore. Inspecting before its
	# maximum-distance dissolve keeps the test focused on the support transition
	# instead of accidentally racing the puck's short visual cleanup.
	for _step: int in range(130):
		if not is_instance_valid(puck) or not puck.active:
			break
		puck.advance_puck(0.02)
		await get_tree().physics_frame
		if puck.distance_travelled >= 17.5:
			break

	_expect(is_instance_valid(puck), "the puck survives the complete transition route")
	if is_instance_valid(puck):
		var puck_debug: Dictionary = puck.get_debug_data()
		_expect(
			float(puck_debug.get("distance_travelled", 0.0)) >= 16.0,
			"the puck crosses the pool instead of stopping at the shoreline"
		)
		_expect(
			str(puck_debug.get("support_kind", "")) == "ground",
			"the puck reacquires solid ground on the far shore"
		)

	if trail != null and is_instance_valid(trail):
		var trail_debug: Dictionary = trail.get_debug_data()
		_expect(
			int(trail_debug.get("water_segments", 0)) >= 20,
			"the moving puck writes many frozen water segments"
		)
		_expect(
			int(trail_debug.get("ground_segments", 0)) >= 2,
			"the same trail also records its shore segments"
		)
		var route_kinds: Array[String] = []
		for row: Dictionary in trail.get_segment_rows():
			var kind: String = str(row.get("kind", "none"))
			if route_kinds.is_empty() or route_kinds.back() != kind:
				route_kinds.append(kind)
		_expect(
			route_kinds.size() >= 3
			and route_kinds[0] == "ground"
			and route_kinds.has("water")
			and route_kinds.back() == "ground",
			"one route transitions from shore to water and back to shore"
		)
		_expect(
			int(trail_debug.get("bridge_collision_shapes", 0))
			== int(trail_debug.get("water_segments", -1)),
			"only the water portion receives frozen-bridge handoff shapes"
		)

	if is_instance_valid(puck):
		puck.force_dissipate("water_route_test_complete")
	await _wait_frames(4)
	_expect(
		get_tree().get_node_count_in_group("curling_puck_effects") == 0
		and get_tree().get_node_count_in_group("curling_ice_trails") == 0,
		"the transition fixture cleans up both puck and bridge"
	)

	for node: Node in [source, water, far_shore, pool_bottom, near_shore]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	if failures.is_empty():
		print("CURLING_PUCK_WATER_ROUTE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CURLING_PUCK_WATER_ROUTE_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _make_floor(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	return body


func _make_water_volume() -> SwimmingWaterVolume:
	var volume: SwimmingWaterVolume = (
		WaterVolumeScript.new() as SwimmingWaterVolume
	)
	volume.name = "CurlingWaterRouteVolume"
	volume.position = Vector3(0.0, -1.5, 23.0)
	volume.surface_height_offset = 1.5
	volume.water_label = "Ground Water Ground Pool"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10.0, 3.0, 14.0)
	collision.shape = shape
	volume.add_child(collision)
	return volume


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("CURLING_PUCK_WATER_ROUTE_SMOKE_TEST: " + label)
