extends Node

const MaterialProfileScript = preload("res://scripts/flexible/flexible_material_profile.gd")
const TetherScript = preload("res://scripts/flexible/flexible_tether_3d.gd")
const HempRopeProfile: Resource = preload("res://data/flexible_materials/hemp_rope.tres")
const IronChainProfile: Resource = preload("res://data/flexible_materials/iron_chain.tres")
const LabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_flexible_tether_lab_v1.tscn")

var failures: Array[String] = []


func _ready() -> void:
	_test_material_profiles()
	await _test_tension_and_breakage()
	await _test_lab_contract()

	if failures.is_empty():
		print("FLEXIBLE_TETHER_FOUNDATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FLEXIBLE_TETHER_FOUNDATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _test_material_profiles() -> void:
	if str(HempRopeProfile.get("material_id")) != "hemp_rope" or not bool(HempRopeProfile.get("burnable")):
		failures.append("Hemp rope resource must be a burnable flexible-material profile")
	if str(IronChainProfile.get("material_id")) != "iron_chain" or not bool(IronChainProfile.get("conductive")):
		failures.append("Iron chain resource must be a conductive flexible-material profile")
	var profile: FlexibleMaterialProfile = MaterialProfileScript.new()
	profile.stiffness = 100.0
	profile.break_strength = 1000.0
	profile.ignition_threshold = 0.5
	profile.frozen_stiffness_multiplier = 2.0
	profile.frozen_break_strength_multiplier = 0.4
	if not is_equal_approx(profile.effective_stiffness(1.0), 200.0):
		failures.append("Cold must increase authored tether stiffness")
	if not is_equal_approx(profile.effective_break_strength(0.0, 1.0, 0.0), 400.0):
		failures.append("Cold must lower authored rope failure strength")
	if profile.effective_break_strength(1.0, 0.0, 0.5) >= profile.break_strength:
		failures.append("Heat and burn progress must weaken burnable rope")


func _test_tension_and_breakage() -> void:
	var anchor := Node3D.new()
	anchor.name = "Anchor"
	add_child(anchor)
	var endpoint := RigidBody3D.new()
	endpoint.name = "Endpoint"
	endpoint.position = Vector3(0.0, -3.0, 0.0)
	endpoint.freeze = true
	add_child(endpoint)

	var profile: FlexibleMaterialProfile = MaterialProfileScript.new()
	profile.stiffness = 100.0
	profile.break_strength = 80.0
	var tether: FlexibleTether3D = TetherScript.new()
	tether.name = "TestTether"
	tether.endpoint_a_path = NodePath("../Anchor")
	tether.endpoint_b_path = NodePath("../Endpoint")
	tether.material_profile = profile
	tether.rest_length = 2.0
	tether.segment_count = 8
	tether.apply_endpoint_forces = false
	add_child(tether)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if tether.peak_tension < 99.0:
		failures.append("A stretched tether must calculate spring tension")
	if not tether.is_broken or tether.break_reason != "overload":
		failures.append("Tension above material strength must break the tether")

	tether.reset_tether()
	profile.break_strength = 1000.0
	endpoint.sleeping = true
	tether.cut()
	if endpoint.sleeping:
		failures.append("Releasing a tether must wake a sleeping RigidBody endpoint")

	tether.queue_free()
	endpoint.queue_free()
	anchor.queue_free()
	await get_tree().process_frame


func _test_lab_contract() -> void:
	if LabScene == null:
		failures.append("Flexible Physics Laboratory failed to load")
		return
	var lab := LabScene.instantiate()
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame

	var tethers: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group("flexible_tethers"):
		if lab.is_ancestor_of(node):
			tethers.append(node)
	var pulleys: Array[Node] = []
	for node: Node in get_tree().get_nodes_in_group("pulley_tethers"):
		if lab.is_ancestor_of(node):
			pulleys.append(node)
	if tethers.size() < 5:
		failures.append("Laboratory requires pendulum, overload, heat, frost, and slack-span tethers")
	if pulleys.size() < 1:
		failures.append("Laboratory requires a counterweight pulley")

	var found_rope := false
	var found_chain := false
	var found_conductor := false
	for node: Node in tethers:
		var tether := node as FlexibleTether3D
		if tether == null or tether.material_profile == null:
			continue
		found_rope = found_rope or tether.material_profile.visual_style == FlexibleMaterialProfile.VisualStyle.ROPE
		found_chain = found_chain or tether.material_profile.visual_style == FlexibleMaterialProfile.VisualStyle.CHAIN
		found_conductor = found_conductor or tether.material_profile.conductive
	if not found_rope or not found_chain:
		failures.append("Laboratory must compare shared rope and chain profiles")
	if not found_conductor:
		failures.append("At least one chain profile must advertise conductivity")

	lab.queue_free()
	await get_tree().process_frame
