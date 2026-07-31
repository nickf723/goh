extends Node

const TrainingYardScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_familiar_training_yard_v1.tscn"
)
const FamiliarAbility: AbilityDefinition = preload(
	"res://data/abilities/spectral_familiar_ability.tres"
)

var failures: Array[String] = []
var species_knowledge: Node = null
var original_snapshot: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	species_knowledge = get_node_or_null("/root/SpeciesKnowledge")
	_expect(species_knowledge != null, "SpeciesKnowledge autoload resolves")
	if species_knowledge == null:
		_finish()
		return
	original_snapshot = species_knowledge.call("get_snapshot") as Dictionary
	await _test_familiar_swap_and_grounding()
	_restore_snapshot()
	_finish()


func _test_familiar_swap_and_grounding() -> void:
	species_knowledge.call("reset_species", "gremlin")
	species_knowledge.call("set_equipped_familiar_species", "")

	var yard_value: Variant = TrainingYardScene.instantiate()
	_expect(yard_value is Node3D, "Familiar Training Yard instantiates")
	if not yard_value is Node3D:
		return
	var yard: Node3D = yard_value as Node3D
	yard.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(yard)
	await get_tree().process_frame
	await get_tree().process_frame

	var player: Node3D = yard.get_node_or_null("Player") as Node3D
	var manager: Node = player.get_node_or_null("SummonManager") if player != null else null
	_expect(player != null and manager != null, "Player and summon manager resolve")
	if player == null or manager == null:
		yard.queue_free()
		return

	_expect(bool(manager.call("summon_familiar")), "Default familiar summons first")
	var default_familiar: Variant = manager.call("get_active_summon")
	_expect(default_familiar is Node, "Default familiar is active")
	var default_debug: Dictionary = _debug_data(default_familiar)
	_expect(
		str(default_debug.get("name", "")).contains("Lumen"),
		"Initial summon is the fallback familiar"
	)

	species_knowledge.call(
		"add_discovery",
		"gremlin",
		"first_encounter",
		"First encounter",
		1
	)
	species_knowledge.call(
		"add_discovery",
		"gremlin",
		"survived_pounce",
		"Survived Pounce",
		1
	)
	var equip_result: Dictionary = (
		species_knowledge.call("set_equipped_familiar_species", "gremlin")
		as Dictionary
	)
	_expect(bool(equip_result.get("ok", false)), "Gremlin equips while Lumen is active")

	_expect(
		bool(manager.call("begin_ability_channel", player, FamiliarAbility)),
		"Recasting the summon spell dismisses the active familiar"
	)
	_expect(manager.call("get_active_summon") == null, "Dismissal clears the active slot immediately")
	await get_tree().process_frame

	_expect(bool(manager.call("summon_familiar")), "Next summon resolves the newly equipped blueprint")
	var gremlin_value: Variant = manager.call("get_active_summon")
	_expect(gremlin_value is Node3D, "Gremlin familiar becomes active")
	if not gremlin_value is Node3D:
		yard.queue_free()
		return
	var gremlin: Node3D = gremlin_value as Node3D
	var gremlin_script: Script = gremlin.get_script() as Script
	_expect(
		gremlin_script != null
		and gremlin_script.resource_path == "res://scripts/summons/gremlin_familiar.gd",
		"Resummon uses the Gremlin familiar driver"
	)
	var visual: Node3D = gremlin.get_node_or_null("GremlinVisual") as Node3D
	_expect(visual != null, "Gremlin familiar visual resolves")
	if visual != null:
		_expect(visual.position.y >= 0.45, "Gremlin feet receive a grounded body offset")
		gremlin.call("_update_visual")
		_expect(visual.position.y >= 0.45, "Visual updates preserve the grounded offset")
	_expect(float(gremlin.get("floor_snap_length")) >= 0.3, "Gremlin familiar uses floor snapping")

	var dummy: Node3D = yard.get_node_or_null("DummyLeft") as Node3D
	_expect(dummy != null and dummy.has_method("get_targeting_aim_point"), "Training dummy exposes an authored aim point")
	if dummy != null and dummy.has_method("get_targeting_aim_point"):
		var aim_value: Variant = dummy.call("get_targeting_aim_point")
		var collision: CollisionShape3D = dummy.get_node_or_null("CollisionShape3D") as CollisionShape3D
		_expect(aim_value is Vector3 and collision != null, "Dummy aim point and collision resolve")
		if aim_value is Vector3 and collision != null:
			var aim_point: Vector3 = aim_value as Vector3
			_expect(aim_point.is_equal_approx(collision.global_position), "Dummy aims at its collision center")
			var camera: Camera3D = player.get_viewport().get_camera_3d()
			var caster: Node = player.get_node_or_null("AbilityCaster")
			_expect(camera != null and caster != null, "Camera and ability caster resolve")
			if camera != null and caster != null:
				camera.global_position = aim_point + Vector3(0.0, 1.5, 4.0)
				camera.look_at(aim_point, Vector3.UP)
				var cast_origin: Vector3 = player.global_position + Vector3.UP * 0.3
				var direction_value: Variant = caster.call(
					"_get_camera_converged_cast_direction",
					player,
					cast_origin
				)
				_expect(direction_value is Vector3, "Free-fire convergence returns a direction")
				if direction_value is Vector3:
					var direction: Vector3 = direction_value as Vector3
					var expected: Vector3 = (aim_point - cast_origin).normalized()
					_expect(
						direction.dot(expected) >= 0.98,
						"Free-fire projectile converges on the dummy instead of the floor"
					)

	manager.call("dismiss_summon", false)
	yard.queue_free()
	await get_tree().process_frame


func _debug_data(value: Variant) -> Dictionary:
	if value is Node and (value as Node).has_method("get_debug_data"):
		var debug_value: Variant = (value as Node).call("get_debug_data")
		if debug_value is Dictionary:
			return debug_value as Dictionary
	return {}


func _restore_snapshot() -> void:
	if species_knowledge != null and not original_snapshot.is_empty():
		species_knowledge.call("apply_snapshot", original_snapshot)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("FAMILIAR_POLISH_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("FAMILIAR_POLISH_SMOKE_TEST: " + failure)
	get_tree().quit(1)
