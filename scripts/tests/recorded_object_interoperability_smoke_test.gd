extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_recorded_object_interoperability_lab_v1.tscn"
)
const Catalog = preload("res://scripts/objects/recorded_object_catalog.gd")

var failures: Array[String] = []
var old_inventory: Dictionary = {}
var old_story_flags: Dictionary = {}
var old_stats: Dictionary = {}
var lab: PrototypeRecordedObjectInteroperabilityLab
var manager: RecordedObjectManager


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_clear_blueprint_state()
	Engine.time_scale = 1.0
	lab = LabScene.instantiate() as PrototypeRecordedObjectInteroperabilityLab
	add_child(lab)
	for _index: int in range(24):
		await get_tree().process_frame
	await get_tree().physics_frame

	manager = get_tree().get_first_node_in_group(
		"recorded_object_manager"
	) as RecordedObjectManager
	assert_true(lab != null, "interoperability lab instantiates")
	assert_true(manager != null, "production recorded object manager is available")
	if lab == null or manager == null:
		_restore_state()
		_finish()
		return

	var lab_debug: Dictionary = lab.get_interoperability_debug_data()
	assert_equal(lab_debug.get("console_count"), 5, "five elemental consoles exist")
	assert_true(bool(lab_debug.get("has_water_basin", false)), "water basin exists")
	lab.record_all_for_debug()
	await get_tree().process_frame
	assert_equal(Catalog.get_recorded_blueprint_ids().size(), 4, "all blueprints are recorded")

	await _test_crate_reactions()
	await _test_spring_overcharge()
	await _test_platform_conduction()
	await _test_barrel_dampening_and_chain()
	await _test_crate_buoyancy()

	_restore_state()
	_finish()


func _place(blueprint_id: String, position: Vector3) -> RecordedObjectInstance:
	manager.select_blueprint(blueprint_id)
	return manager.place_selected_at(position, 0.0, true, true)


func _test_crate_reactions() -> void:
	manager.clear_spawned_objects()
	await get_tree().process_frame
	var crate: RecordedObjectInstance = _place("crate", Vector3(0.0, 0.0, 10.0))
	assert_true(crate != null, "crate can be placed on the interaction pad")
	if crate == null:
		return

	crate.receive_damage_payload(_make_payload("fire", 3, ["heat", "ignite"]))
	var state: Dictionary = _state(crate)
	assert_true(float(state.get("burning_remaining", 0.0)) > 0.0, "Fire ignites the recorded crate")
	assert_true(_has_discovery(crate, "crate_ignited"), "crate ignition becomes a discovery")

	crate.receive_damage_payload(_make_payload("water", 3, ["douse", "extinguish"]))
	state = _state(crate)
	assert_equal(state.get("burning_remaining"), 0.0, "Water extinguishes the crate")
	assert_true(float(state.get("wet_remaining", 0.0)) > 0.0, "Water leaves the crate wet")

	crate.receive_damage_payload(_make_payload("ice", 4, ["cold", "freeze"]))
	state = _state(crate)
	assert_true(float(state.get("frozen_progress", 0.0)) >= 0.95, "Ice fully freezes a wet crate")
	var force_payload := _make_payload("neutral", 4, ["heavy", "force", "impact"])
	force_payload.knockback_strength = 8.0
	crate.receive_damage_payload(force_payload)
	assert_true(crate.is_queued_for_deletion(), "Heavy force shatters a fully frozen crate")
	await get_tree().process_frame


func _test_spring_overcharge() -> void:
	manager.clear_spawned_objects()
	await get_tree().process_frame
	var spring: RecordedObjectInstance = _place("spring", Vector3(0.0, 0.0, 10.0))
	assert_true(spring != null, "spring can be placed")
	if spring == null:
		return

	spring.receive_damage_payload(_make_payload("lightning", 3, ["electrical", "conduct"]))
	var state: Dictionary = _state(spring)
	assert_equal(state.get("overcharge_charges"), 3, "Lightning grants three spring charges")
	assert_true(float(state.get("electrified_remaining", 0.0)) > 0.0, "spring becomes energized")

	var dummy := CharacterBody3D.new()
	dummy.name = "SpringLaunchDummy"
	lab.add_child(dummy)
	spring._on_spring_body_entered(dummy)
	assert_true(dummy.velocity.y > 15.0, "overcharged spring amplifies launch speed")
	assert_equal(_state(spring).get("overcharge_charges"), 2, "boosted launch consumes one charge")
	dummy.queue_free()
	await get_tree().process_frame


func _test_platform_conduction() -> void:
	manager.clear_spawned_objects()
	await get_tree().process_frame
	var platform: RecordedObjectInstance = _place("platform", Vector3(0.0, 0.0, 10.0))
	assert_true(platform != null, "platform can be placed")
	if platform == null:
		return
	platform.receive_damage_payload(_make_payload("lightning", 3, ["electrical", "conduct"]))
	var state: Dictionary = _state(platform)
	assert_true(float(state.get("electrified_remaining", 0.0)) > 0.0, "Lightning energizes the platform")
	assert_true(platform.contact_area != null, "conductive platform owns a contact field")
	assert_true(_has_discovery(platform, "platform_energized"), "platform energizing is recorded")


func _test_barrel_dampening_and_chain() -> void:
	manager.clear_spawned_objects()
	await get_tree().process_frame
	var dampened: RecordedObjectInstance = _place("blast_barrel", Vector3(0.0, 0.0, 10.0))
	assert_true(dampened != null, "blast barrel can be placed")
	if dampened == null:
		return
	dampened.receive_damage_payload(_make_payload("water", 3, ["douse", "extinguish"]))
	dampened.receive_damage_payload(_make_payload("fire", 4, ["heat", "ignite"]))
	assert_true(not dampened.detonation_started, "wet barrel refuses Fire detonation")
	assert_true(_has_discovery(dampened, "dampened_fuse"), "dampened fuse is recorded")

	manager.clear_spawned_objects()
	await get_tree().process_frame
	var first: Variant = _place("blast_barrel", Vector3(7.5, 0.0, -7.0))
	var second: Variant = _place("blast_barrel", Vector3(9.5, 0.0, -7.0))
	assert_true(first is RecordedObjectInstanceSafe, "initiating barrel uses safe actor")
	assert_true(second is RecordedObjectInstanceSafe, "chain barrel uses safe actor")
	if not first is RecordedObjectInstance or not second is RecordedObjectInstance:
		return

	(first as RecordedObjectInstance).detonate()
	var frames_advanced: int = 0
	for _index: int in range(16):
		await get_tree().process_frame
		frames_advanced += 1
		await get_tree().physics_frame
		if _is_gone(first) and _is_gone(second):
			break

	assert_true(frames_advanced > 0, "engine frames continue during the chain reaction")
	assert_true(_is_gone(first), "initiating barrel resolves safely")
	assert_true(_is_gone(second), "nearby barrel resolves through deferred chain reaction")
	assert_true(is_equal_approx(Engine.time_scale, 1.0), "barrel chain leaves global time running")


func _test_crate_buoyancy() -> void:
	manager.clear_spawned_objects()
	await get_tree().process_frame
	var crate: RecordedObjectInstance = lab.place_crate_in_water_basin()
	assert_true(crate != null, "crate can be dropped into the water basin")
	if crate == null:
		return
	for _index: int in range(8):
		await get_tree().physics_frame
	var state: Dictionary = _state(crate)
	assert_true(float(state.get("submerged_fraction", 0.0)) > 0.05, "crate detects shared fluid submersion")
	assert_true(str(state.get("active_fluid", "none")) != "none", "crate binds to FluidForceVolume")
	assert_true(str(state.get("buoyancy_state", "air")) in ["rising", "floating", "submerged"], "crate reports buoyancy")
	assert_true(float(state.get("wet_remaining", 0.0)) > 0.0, "water basin leaves the crate wet")
	assert_true(_has_discovery(crate, "crate_floats"), "crate flotation becomes a discovery")


func _is_gone(value: Variant) -> bool:
	return value == null or not is_instance_valid(value) or (value as Node).is_queued_for_deletion()


func _make_payload(element: String, amount: int, tags: Array[String]) -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = amount
	payload.stance_damage = amount
	payload.element = element
	payload.source_name = "Interoperability Smoke Test"
	payload.hit_type = "environment"
	payload.status_strength = 1.0
	payload.tags = tags.duplicate()
	return payload


func _state(object: RecordedObjectInstance) -> Dictionary:
	if object == null or not is_instance_valid(object):
		return {}
	var value: Variant = object.get_debug_data().get("interoperability", {})
	return value as Dictionary if value is Dictionary else {}


func _has_discovery(object: RecordedObjectInstance, interaction_id: String) -> bool:
	var discoveries: Variant = _state(object).get("discoveries", [])
	return discoveries is Array and (discoveries as Array).has(interaction_id)


func _capture_state() -> void:
	old_inventory = GameState.inventory.duplicate(true)
	old_story_flags = GameState.story_flags.duplicate(true)
	old_stats = GameState.stats.duplicate(true)


func _clear_blueprint_state() -> void:
	for blueprint_id: String in Catalog.BLUEPRINT_ORDER:
		GameState.inventory.erase(Catalog.get_item_id(blueprint_id))
	GameState.story_flags.erase(Catalog.SELECTED_BLUEPRINT_FLAG)
	GameState.set_stat("max_mana", maxi(GameState.get_stat("max_mana"), 30))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))


func _restore_state() -> void:
	Engine.time_scale = 1.0
	if manager != null and is_instance_valid(manager):
		manager.clear_spawned_objects()
	if lab != null and is_instance_valid(lab):
		lab.queue_free()
	GameState.inventory = old_inventory.duplicate(true)
	GameState.story_flags = old_story_flags.duplicate(true)
	GameState.stats = old_stats.duplicate(true)


func _finish() -> void:
	if failures.is_empty():
		print("RECORDED_OBJECT_INTEROPERABILITY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RECORDED_OBJECT_INTEROPERABILITY_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(label + " (expected " + str(expected) + ", got " + str(actual) + ")")
