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

	var player: CharacterBody3D = target.get_node_or_null("Player") as CharacterBody3D
	var fauna_root: Node = target.get_node_or_null("GreenGrottoArt/Fauna")
	_expect(player != null, "fauna behavior test resolves Grace")
	_expect(fauna_root != null, "fauna behavior test resolves Green fauna root")
	if player != null and fauna_root != null:
		_validate_behavior_installation(target, fauna_root)
		_validate_raptor_reactivity(fauna_root, player)
		_validate_sauropod_behavior(fauna_root, player)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_behavior_installation(target: Node, fauna_root: Node) -> void:
	var fauna_count: int = 0
	var behavior_count: int = 0
	for child: Node in fauna_root.get_children():
		if not child is GreenGrottoFaunaVisual:
			continue
		fauna_count += 1
		var creature: GreenGrottoFaunaVisual = child as GreenGrottoFaunaVisual
		var behavior: GreenGrottoFaunaAmbientBehavior = creature.get_node_or_null(
			"AmbientBehavior"
		) as GreenGrottoFaunaAmbientBehavior
		_expect(behavior != null, creature.name + " receives AmbientBehavior")
		if behavior != null:
			behavior_count += 1
			var data: Dictionary = behavior.get_debug_data()
			_expect(bool(data.get("presentation_only", false)), creature.name + " behavior is presentation-only")
			_expect(not bool(data.get("uses_navigation", true)), creature.name + " behavior uses no navigation")
			_expect(not bool(data.get("combat_authority", true)), creature.name + " behavior owns no combat state")
		_expect(not creature.animate_creature, creature.name + " retires the old perpetual patrol animator")
	_expect(fauna_count == 4, "Green still contains exactly four authored fauna actors")
	_expect(behavior_count == 4, "all four fauna actors receive ambient behavior")
	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(int(pass_data.get("fauna_ambient_behavior_count", 0)) == 4, "Green pass reports four ambient fauna behaviors")


func _validate_raptor_reactivity(
	fauna_root: Node,
	player: CharacterBody3D
) -> void:
	var raptor: GreenGrottoFaunaVisual = fauna_root.get_node_or_null(
		"RaptorArrival"
	) as GreenGrottoFaunaVisual
	_expect(raptor != null, "reactivity test resolves arrival raptor")
	if raptor == null:
		return
	var behavior: GreenGrottoFaunaAmbientBehavior = raptor.get_node_or_null(
		"AmbientBehavior"
	) as GreenGrottoFaunaAmbientBehavior
	_expect(behavior != null, "arrival raptor has ambient behavior")
	if behavior == null:
		return

	player.global_position = raptor.global_position + Vector3(5.0, 0.0, 0.0)
	behavior.call("_process", 0.08)
	_expect(behavior.behavior_state == "curious", "raptor becomes curious at medium Grace distance")
	var curious_yaw: float = raptor.rotation.y
	for _index: int in range(6):
		behavior.call("_process", 0.12)
	_expect(absf(wrapf(raptor.rotation.y - curious_yaw, -PI, PI)) > 0.005, "curious raptor visibly turns toward Grace")

	var before_startle: Vector3 = raptor.position
	player.global_position = raptor.global_position + Vector3(0.7, 0.0, 0.0)
	for _index: int in range(8):
		behavior.call("_process", 0.12)
	_expect(behavior.behavior_state == "startled", "raptor enters startled state when Grace crowds it")
	_expect(raptor.position.distance_to(before_startle) > 0.05, "startled raptor takes a short presentation retreat")

	player.global_position = Vector3(100.0, 100.0, 100.0)
	behavior.elapsed = 6.2 - raptor.idle_phase * 2.7
	behavior.call("_process", 0.01)
	_expect(behavior.behavior_state == "pause", "far raptor returns to deterministic pause beat")
	behavior.elapsed = 8.1 - raptor.idle_phase * 2.7
	behavior.call("_process", 0.01)
	_expect(behavior.behavior_state == "forage", "far raptor enters deterministic forage beat")


func _validate_sauropod_behavior(
	fauna_root: Node,
	player: CharacterBody3D
) -> void:
	var sauropod: GreenGrottoFaunaVisual = fauna_root.get_node_or_null(
		"DistantSauropod"
	) as GreenGrottoFaunaVisual
	_expect(sauropod != null, "test resolves distant sauropod")
	if sauropod == null:
		return
	var behavior: GreenGrottoFaunaAmbientBehavior = sauropod.get_node_or_null(
		"AmbientBehavior"
	) as GreenGrottoFaunaAmbientBehavior
	_expect(behavior != null, "sauropod has ambient behavior")
	if behavior == null:
		return
	player.global_position = sauropod.global_position + Vector3(0.5, 0.0, 0.0)
	behavior.call("_process", 0.1)
	_expect(behavior.behavior_state not in ["curious", "startled"], "sauropod does not inherit raptor proximity behavior")
	behavior.target_actor = null
	behavior.elapsed = 10.0
	var state_value: String = str(behavior.call("_resolve_behavior_state"))
	_expect(state_value in ["roam", "forage", "pause"], "sauropod stays on slow ambient behavior clock")


func _dictionary_value(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GREEN_GROTTO_FAUNA_AMBIENT_BEHAVIOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GREEN_GROTTO_FAUNA_AMBIENT_BEHAVIOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
