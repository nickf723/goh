extends Node3D


const TargetingCatalog = preload(
	"res://scripts/abilities/spell_targeting_catalog.gd"
)
const TargetingPreview = preload(
	"res://scripts/abilities/spell_targeting_preview.gd"
)
const GroundTargeting = preload(
	"res://scripts/abilities/ground_targeting_controller.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var floor := _make_floor()
	add_child(floor)
	var source := Node3D.new()
	source.name = "TargetingSource"
	source.position = Vector3(0.0, 0.96, 0.0)
	add_child(source)
	await get_tree().physics_frame

	_test_profile_inference()
	await _test_preview_shapes(source)
	await _test_ground_targeting(source)

	if is_instance_valid(source):
		source.queue_free()
	if is_instance_valid(floor):
		floor.queue_free()
	if failures.is_empty():
		print("SPELL_TARGETING_PROFILE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SPELL_TARGETING_PROFILE_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _test_profile_inference() -> void:
	var cases: Array[Dictionary] = [
		{"style": "ground_aoe", "delivery": "field", "shape": "circle"},
		{"style": "cone", "delivery": "instant", "shape": "cone"},
		{"style": "beam", "delivery": "beam", "shape": "line"},
		{"style": "trajectory", "delivery": "lob", "shape": "trajectory"},
		{"style": "self_aoe", "delivery": "instant", "shape": "self_burst"},
		{"style": "lock_on", "delivery": "projectile", "shape": "target_lock"},
	]
	for case: Dictionary in cases:
		var ability := AbilityDefinition.new()
		ability.spell_id = str(case.get("shape", "spell")) + "_test"
		ability.display_name = ability.spell_id.capitalize()
		ability.targeting_style = str(case.get("style", ""))
		ability.delivery_type = str(case.get("delivery", ""))
		var profile: SpellTargetingProfile = TargetingCatalog.build_profile(ability)
		_expect(
			profile.get_shape_name() == str(case.get("shape", "")),
			"Catalog infers " + str(case.get("shape", "")) + " previews"
		)
		_expect(
			profile.validate_profile().is_empty(),
			"Inferred " + str(case.get("shape", "")) + " profile validates"
		)

	var explicit: SpellTargetingProfile = TargetingCatalog.build_profile_from_config({
		"profile_id": "explicit_cone",
		"shape": "cone",
		"placement": "forward",
		"range": 9.0,
		"length": 7.5,
		"angle_degrees": 72.0,
	})
	_expect(explicit.get_shape_name() == "cone", "Explicit preview shape overrides inference")
	_expect(is_equal_approx(explicit.length, 7.5), "Explicit preview dimensions survive normalization")


func _test_preview_shapes(source: Node3D) -> void:
	var shapes: Array[String] = [
		"point",
		"circle",
		"cone",
		"line",
		"trajectory",
		"self_burst",
		"target_lock",
	]
	for shape: String in shapes:
		var profile: SpellTargetingProfile = TargetingCatalog.build_profile_from_config({
			"profile_id": shape + "_preview_test",
			"shape": shape,
			"placement": "free_ground" if shape == "circle" else "forward",
			"range": 10.0,
			"radius": 2.0,
			"length": 6.0,
			"width": 1.4,
			"angle_degrees": 64.0,
			"show_range_ring": true,
		})
		var preview: SpellTargetingPreview = TargetingPreview.new() as SpellTargetingPreview
		preview.name = shape.capitalize() + "Preview"
		add_child(preview)
		preview.configure(profile, source)
		preview.set_preview_state(
			Vector3(4.0, 0.05, -2.0),
			Vector3(1.0, 0.0, -0.5),
			true
		)
		await get_tree().process_frame
		var debug: Dictionary = preview.get_debug_data()
		_expect(str(debug.get("shape", "")) == shape, "Renderer reports " + shape + " shape")
		_expect(bool(debug.get("has_outline", false)), shape + " preview builds an outline")
		_expect(bool(debug.get("has_range_ring", false)), shape + " preview builds a range ring")
		preview.set_preview_state(
			Vector3(4.0, 0.05, -2.0),
			Vector3(1.0, 0.0, -0.5),
			false,
			"invalid test"
		)
		debug = preview.get_debug_data()
		_expect(not bool(debug.get("valid", true)), shape + " preview accepts invalid state")
		preview.queue_free()
		await get_tree().process_frame


func _test_ground_targeting(source: Node3D) -> void:
	var ability := AbilityDefinition.new()
	ability.spell_id = "earth_spike"
	ability.display_name = "Earth Spike"
	ability.element = "earth"
	ability.targeting_style = "ground_aoe"
	ability.delivery_type = "instant"
	var controller: GroundTargetingController = GroundTargeting.new()
	var started: bool = controller.start(
		self,
		source,
		ability,
		{
			"spell_key": "earth_spike",
			"shape": "circle",
			"placement": "free_ground",
			"radius": 2.15,
			"range": 12.0,
			"initial_distance": 4.0,
			"require_ground": true,
			"show_range_ring": true,
		}
	)
	_expect(started, "Ground targeting starts from a shared profile")
	if not started:
		return
	await get_tree().process_frame
	var debug: Dictionary = controller.get_debug_data()
	_expect(str(debug.get("shape", "")) == "circle", "Ground spell migrates to circle preview")
	_expect(bool(debug.get("valid", false)), "Ground spell begins on valid terrain")
	var profile: SpellTargetingProfile = controller.get_targeting_profile()
	_expect(profile != null and is_equal_approx(profile.radius, 2.15), "Ground profile preserves authored radius")

	controller.set("target_position", controller.resolve_ground(Vector3(40.0, 0.0, 40.0)))
	controller.call("_evaluate_target_validity")
	controller.update_marker()
	debug = controller.get_debug_data()
	_expect(not bool(debug.get("valid", true)), "Ground targeting rejects missing terrain")
	_expect(str(debug.get("invalid_reason", "")) != "", "Invalid placement exposes a player-facing reason")
	var preview_debug: Dictionary = debug.get("preview", {}) as Dictionary
	_expect(not bool(preview_debug.get("valid", true)), "Preview renderer receives invalid placement state")
	controller.cancel()


func _make_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.name = "TargetingPreviewFloor"
	floor.position = Vector3(0.0, -0.1, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(24.0, 0.2, 24.0)
	collision.shape = shape
	floor.add_child(collision)
	return floor


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
