extends Node

const ReadyTrailScript = preload(
	"res://scripts/actions/curling_ice_trail_ready.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var floor := StaticBody3D.new()
	floor.name = "CurlingInteractionFloor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = 1
	floor.collision_mask = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20.0, 1.0, 20.0)
	floor_collision.shape = floor_shape
	floor.add_child(floor_collision)
	add_child(floor)

	var source := CharacterBody3D.new()
	source.name = "CurlingInteractionSource"
	add_child(source)
	var trail: CurlingIceTrailReady = (
		ReadyTrailScript.new() as CurlingIceTrailReady
	)
	trail.name = "CurlingInteractionTrail"
	add_child(trail)
	trail.configure(source, 701)
	trail.add_path_between(
		Vector3(-2.0, 0.0, 0.0),
		Vector3(2.0, 0.0, 0.0),
		Vector3.RIGHT
	)

	var trail_debug: Dictionary = trail.get_debug_data()
	_expect(
		bool(trail_debug.get("raised_interaction_volumes", false)),
		"production trails advertise raised interaction volumes"
	)
	_expect(
		float(trail_debug.get("interaction_height", 0.0)) >= 0.8,
		"slippery detection extends well above the thin support ice"
	)
	var static_height: float = _first_box_height(trail.get_static_body())
	var slippery_height: float = _first_box_height(trail.get_slippery_area())
	_expect(
		static_height > 0.0 and static_height <= 0.15,
		"physical support remains a thin ice strip"
	)
	_expect(
		slippery_height >= 0.8,
		"the slippery Area overlaps characters and rolling objects resting on the strip"
	)

	var original_material := PhysicsMaterial.new()
	original_material.friction = 0.86
	original_material.rough = true
	original_material.bounce = 0.04
	var rigid := RigidBody3D.new()
	rigid.name = "CurlingInteractionRigid"
	rigid.linear_damp = 0.42
	rigid.angular_damp = 0.3
	rigid.physics_material_override = original_material
	add_child(rigid)
	trail.get_slippery_area().register_body(rigid)
	var ice_material: PhysicsMaterial = rigid.physics_material_override
	_expect(
		rigid.linear_damp <= 0.05 and rigid.angular_damp <= 0.05,
		"ice lowers rigid-body damping while contact remains active"
	)
	_expect(
		ice_material != null
		and ice_material.friction <= 0.03
		and not ice_material.rough,
		"ice replaces a rough high-friction material with a true low-friction contact material"
	)
	trail.get_slippery_area().unregister_body(rigid)
	_expect(
		rigid.physics_material_override == original_material,
		"leaving the trail restores the original rigid-body material resource"
	)
	_expect(
		is_equal_approx(rigid.linear_damp, 0.42)
		and is_equal_approx(rigid.angular_damp, 0.3),
		"leaving the trail restores original damping"
	)

	trail.force_dissipate("interaction_contract_complete")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(
		get_tree().get_node_count_in_group("curling_ice_trails") == 0,
		"interaction cleanup removes the temporary trail"
	)

	for node: Node in [rigid, source, floor]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	if failures.is_empty():
		print("CURLING_PUCK_INTERACTION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CURLING_PUCK_INTERACTION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _first_box_height(parent: Node) -> float:
	if parent == null:
		return 0.0
	for child: Node in parent.get_children():
		if not child is CollisionShape3D:
			continue
		var collision := child as CollisionShape3D
		if collision.shape is BoxShape3D:
			return (collision.shape as BoxShape3D).size.y
	return 0.0


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("CURLING_PUCK_INTERACTION_SMOKE_TEST: " + label)
