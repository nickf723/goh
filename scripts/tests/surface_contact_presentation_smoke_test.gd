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
	for _index: int in range(5):
		await get_tree().process_frame

	var director: SurfaceContactPresentationDirector3D = target.get_node_or_null(
		"SurfaceContactPresentationDirector"
	) as SurfaceContactPresentationDirector3D
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	var motion_feedback: PlayerMotionFeedback = target.get_node_or_null(
		"Player/PlayerMotionFeedback"
	) as PlayerMotionFeedback
	_expect(director != null, "Green installs SurfaceContactPresentationDirector")
	_expect(lighting != null, "contact test resolves LightingDirector")
	_expect(motion_feedback != null, "contact test resolves existing PlayerMotionFeedback")
	if director != null and lighting != null:
		_validate_contract(target, director, motion_feedback)
		await _validate_quality_ladder(director, lighting)
		_validate_regional_styles(director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(
	target: Node,
	director: SurfaceContactPresentationDirector3D,
	motion_feedback: PlayerMotionFeedback
) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("surface_contact_presentation_director", false)), "contact director publishes debug contract")
	_expect(bool(data.get("initialized", false)), "contact director connects to existing presentation service")
	_expect(str(data.get("profile_id", "")) == "green_grotto_surface_contact", "Green uses dedicated contact profile")
	_expect(int(data.get("region_count", 0)) == 3, "Green authors exactly three contact-style override regions")
	_expect(bool(data.get("uses_existing_presentation_events", false)), "contact director consumes existing semantic movement events")
	_expect(not bool(data.get("per_contact_raycast", true)), "contact director performs no second floor raycast")
	_expect(not bool(data.get("audio_authority", true)), "contact director owns no audio")
	_expect(not bool(data.get("gameplay_authority", true)), "contact director owns no gameplay state")
	if motion_feedback != null:
		_expect(motion_feedback.visual_effect_scale <= 0.141, "Green benchmark subdues legacy generic blue motion rings")
	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(bool(pass_data.get("surface_contact_presentation", false)), "Green pass reports surface contact presentation")


func _validate_quality_ladder(
	director: SurfaceContactPresentationDirector3D,
	lighting: LightingDirector3D
) -> void:
	director.call("_clear_live_pieces")
	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	await get_tree().process_frame
	await get_tree().process_frame
	var performance_count: int = director.present_contact_for_test(
		"footstep",
		Vector3(0.0, 0.0, 13.0),
		"stone",
		0.4
	)
	_expect(performance_count == 0, "Performance adds no micro contact pieces")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	await get_tree().process_frame
	await get_tree().process_frame
	director.call("_clear_live_pieces")
	var balanced_step: int = director.present_contact_for_test(
		"footstep",
		Vector3(0.0, 0.0, 13.0),
		"stone",
		0.4
	)
	var balanced_landing: int = director.present_contact_for_test(
		"landing",
		Vector3(5.8, -1.0, -9.2),
		"stone",
		0.8
	)
	_expect(balanced_step == 3, "Balanced footstep spawns exactly three restrained pieces")
	_expect(balanced_landing == 7, "Balanced landing spawns exactly seven restrained pieces")

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	await get_tree().process_frame
	await get_tree().process_frame
	director.call("_clear_live_pieces")
	var cinematic_step: int = director.present_contact_for_test(
		"footstep",
		Vector3(0.0, 0.0, 0.0),
		"stone",
		0.5
	)
	var cinematic_landing: int = director.present_contact_for_test(
		"landing",
		Vector3(0.0, 3.0, -15.0),
		"stone",
		1.0
	)
	_expect(cinematic_step == 5, "Cinematic footstep spawns exactly five pieces")
	_expect(cinematic_landing == 11, "Cinematic landing spawns exactly eleven pieces")
	_expect(director.live_pieces.size() <= director.profile.maximum_live_pieces, "contact pieces remain inside live-piece budget")


func _validate_regional_styles(
	director: SurfaceContactPresentationDirector3D
) -> void:
	_expect(str(director.call("_resolve_style", Vector3(0.0, 0.0, 13.0), "stone")) == "dust", "arrival shelf resolves warm dust style")
	_expect(str(director.call("_resolve_style", Vector3(5.8, -1.0, -9.2), "stone")) == "damp", "waterfall bowl resolves damp contact style")
	_expect(str(director.call("_resolve_style", Vector3(0.0, 3.0, -15.0), "stone")) == "leaf_litter", "shrine court resolves leaf-litter contact style")
	_expect(str(director.call("_resolve_style", Vector3(0.0, 1.0, -4.0), "stone")) == "stone", "unmarked causeway falls back to stone contact")
	var data: Dictionary = director.get_debug_data()
	_expect(int(data.get("event_counter", 0)) >= 4, "contact director records synthetic and semantic contact work")


func _dictionary_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("SURFACE_CONTACT_PRESENTATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SURFACE_CONTACT_PRESENTATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
