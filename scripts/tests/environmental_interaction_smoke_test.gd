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

	var director: EnvironmentalMotionDirector3D = target.get_node_or_null(
		"EnvironmentalMotionDirector"
	) as EnvironmentalMotionDirector3D
	var player: CharacterBody3D = target.get_node_or_null("Player") as CharacterBody3D
	var influencer: EnvironmentalMotionInfluencer3D = target.get_node_or_null(
		"Player/EnvironmentalMotionInfluencer"
	) as EnvironmentalMotionInfluencer3D

	_expect(director != null, "Green resolves EnvironmentalMotionDirector")
	_expect(player != null, "Green resolves Grace player actor")
	_expect(influencer != null, "Green installs Grace environmental motion influencer")
	if director != null and player != null and influencer != null:
		director.call("_refresh_influencers")
		_validate_contract(target, director, influencer)
		_validate_velocity_response(director, player, influencer)
		_validate_transform_response(director, player, influencer)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(
	target: Node,
	director: EnvironmentalMotionDirector3D,
	influencer: EnvironmentalMotionInfluencer3D
) -> void:
	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(
		bool(pass_data.get("grace_environment_interaction", false)),
		"Green pass reports Grace/environment interaction"
	)
	var director_data: Dictionary = director.get_debug_data()
	_expect(
		bool(director_data.get("local_interaction_aware", false)),
		"Motion Director enables local interaction"
	)
	_expect(
		int(director_data.get("influencer_count", 0)) == 1,
		"Green exposes exactly one Grace interaction influencer"
	)
	_expect(
		not bool(director_data.get("interaction_moves_colliders", true)),
		"interaction never moves collision geometry"
	)
	var influencer_data: Dictionary = influencer.get_debug_data()
	_expect(
		bool(influencer_data.get("presentation_only", false)),
		"Grace influence is presentation-only"
	)
	_expect(
		not bool(influencer_data.get("applies_gameplay_force", true)),
		"Grace influence applies no gameplay force"
	)
	_expect(
		influencer.channel == "green_grotto_motion",
		"Grace influence shares the Green motion channel"
	)


func _validate_velocity_response(
	director: EnvironmentalMotionDirector3D,
	player: CharacterBody3D,
	influencer: EnvironmentalMotionInfluencer3D
) -> void:
	var target_info: Dictionary = _first_target_of_kind(director, "foliage")
	_expect(not target_info.is_empty(), "test resolves a foliage motion target")
	if target_info.is_empty():
		return
	var foliage: Node3D = target_info.get("target") as Node3D
	if foliage == null:
		return

	player.global_position = foliage.global_position + Vector3(0.62, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	var idle_sample: Dictionary = influencer.sample_influence(foliage.global_position)
	var idle_strength: float = float(idle_sample.get("strength", 0.0))
	_expect(idle_strength > 0.08, "standing inside foliage produces restrained contact influence")

	player.velocity = Vector3(8.0, 0.0, 0.0)
	var sprint_sample: Dictionary = influencer.sample_influence(foliage.global_position)
	var sprint_strength: float = float(sprint_sample.get("strength", 0.0))
	_expect(
		sprint_strength > idle_strength + 0.10,
		"sprinting produces a stronger vegetation wake than idle contact"
	)

	var director_sample: Dictionary = director.sample_local_interaction_for_test(
		foliage.global_position,
		"foliage"
	)
	_expect(
		float(director_sample.get("strength", 0.0)) > 0.08,
		"Motion Director receives Grace influence for foliage"
	)
	var canopy_sample: Dictionary = director.sample_local_interaction_for_test(
		foliage.global_position,
		"canopy"
	)
	_expect(
		float(canopy_sample.get("strength", 99.0)) == 0.0,
		"Grace contact does not bend canopy-scale targets"
	)


func _validate_transform_response(
	director: EnvironmentalMotionDirector3D,
	player: CharacterBody3D,
	influencer: EnvironmentalMotionInfluencer3D
) -> void:
	var target_info: Dictionary = _first_target_of_kind(director, "foliage")
	if target_info.is_empty():
		return
	var foliage: Node3D = target_info.get("target") as Node3D
	var source_record: Dictionary = target_info.get("record", {}) as Dictionary
	if foliage == null or source_record.is_empty():
		return
	var base_position: Vector3 = source_record.get("base_position", foliage.position)
	var base_rotation: Vector3 = source_record.get("base_rotation", foliage.rotation)
	var base_scale: Vector3 = source_record.get("base_scale", foliage.scale)

	player.global_position = foliage.global_position + Vector3(0.55, 1.0, 0.0)
	player.velocity = Vector3(7.5, 0.0, 0.0)
	director.elapsed = 1.7

	influencer.active = false
	foliage.position = base_position
	foliage.rotation = base_rotation
	foliage.scale = base_scale
	var ambient_record: Dictionary = source_record.duplicate(true)
	ambient_record["smoothed_interaction"] = Vector3.ZERO
	director.call("_apply_target_motion", foliage, ambient_record, 1.0, 0.24)
	var ambient_position: Vector3 = foliage.position
	var ambient_rotation: Vector3 = foliage.rotation

	influencer.active = true
	foliage.position = base_position
	foliage.rotation = base_rotation
	foliage.scale = base_scale
	var interaction_record: Dictionary = source_record.duplicate(true)
	interaction_record["smoothed_interaction"] = Vector3.ZERO
	director.call("_apply_target_motion", foliage, interaction_record, 1.0, 0.24)
	var interaction_delta: float = (
		foliage.position.distance_to(ambient_position)
		+ foliage.rotation.distance_to(ambient_rotation)
	)
	_expect(
		interaction_delta > 0.002,
		"Grace contact visibly changes the foliage pose beyond ambient wind"
	)

	director.targets[foliage.get_instance_id()] = interaction_record
	director.set_enabled(false)
	_expect(
		foliage.position.distance_to(base_position) < 0.000001,
		"F5/OFF restores exact authored foliage position after interaction"
	)
	_expect(
		foliage.rotation.distance_to(base_rotation) < 0.000001,
		"F5/OFF restores exact authored foliage rotation after interaction"
	)
	_expect(
		foliage.scale.distance_to(base_scale) < 0.000001,
		"F5/OFF restores exact authored foliage scale after interaction"
	)
	director.set_enabled(true)


func _first_target_of_kind(
	director: EnvironmentalMotionDirector3D,
	kind: String
) -> Dictionary:
	for raw_id: Variant in director.targets.keys():
		var record: Dictionary = director.targets[int(raw_id)] as Dictionary
		if str(record.get("kind", "")) != kind:
			continue
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if target_value is Node3D:
			return {
				"target": target_value as Node3D,
				"record": record,
			}
	return {}


func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("ENVIRONMENTAL_INTERACTION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ENVIRONMENTAL_INTERACTION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
