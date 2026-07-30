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
const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	_prepare_stats()
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
	await _test_invalid_confirmation_preserves_resources()

	_restore_stats()
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
		var profile: SpellTargetingProfile = TargetingCatalog.build_profile(
			ability
		)
		_expect(
			profile.get_shape_name() == str(case.get("shape", "")),
			"Catalog infers " + str(case.get("shape", "")) + " previews"
		)
		_expect(
			profile.validate_profile().is_empty(),
			"Inferred " + str(case.get("shape", "")) + " profile validates"
		)

	var explicit: SpellTargetingProfile = (
		TargetingCatalog.build_profile_from_config({
			"profile_id": "explicit_cone",
			"shape": "cone",
			"placement": "forward",
			"range": 9.0,
			"length": 7.5,
			"angle_degrees": 72.0,
		})
	)
	_expect(
		explicit.get_shape_name() == "cone",
		"Explicit preview shape overrides inference"
	)
	_expect(
		is_equal_approx(explicit.length, 7.5),
		"Explicit preview dimensions survive normalization"
	)


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
		var profile: SpellTargetingProfile = (
			TargetingCatalog.build_profile_from_config({
				"profile_id": shape + "_preview_test",
				"shape": shape,
				"placement": (
					"free_ground" if shape == "circle" else "forward"
				),
				"range": 10.0,
				"radius": 2.0,
				"length": 6.0,
				"width": 1.4,
				"angle_degrees": 64.0,
				"show_range_ring": true,
			})
		)
		var preview: SpellTargetingPreview = (
			TargetingPreview.new() as SpellTargetingPreview
		)
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
		_expect(
			str(debug.get("shape", "")) == shape,
			"Renderer reports " + shape + " shape"
		)
		_expect(
			bool(debug.get("has_outline", false)),
			shape + " preview builds an outline"
		)
		_expect(
			bool(debug.get("has_range_ring", false)),
			shape + " preview builds a range ring"
		)
		preview.set_preview_state(
			Vector3(4.0, 0.05, -2.0),
			Vector3(1.0, 0.0, -0.5),
			false,
			"invalid test"
		)
		debug = preview.get_debug_data()
		_expect(
			not bool(debug.get("valid", true)),
			shape + " preview accepts invalid state"
		)
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
	_expect(
		started,
		"Ground targeting starts from a shared profile"
	)
	if not started:
		return
	await get_tree().process_frame
	var debug: Dictionary = controller.get_debug_data()
	_expect(
		str(debug.get("shape", "")) == "circle",
		"Ground spell migrates to circle preview"
	)
	_expect(
		bool(debug.get("valid", false)),
		"Ground spell begins on valid terrain"
	)
	var profile: SpellTargetingProfile = (
		controller.get_targeting_profile()
	)
	_expect(
		profile != null and is_equal_approx(profile.radius, 2.15),
		"Ground profile preserves authored radius"
	)

	controller.set(
		"target_position",
		controller.resolve_ground(Vector3(40.0, 0.0, 40.0))
	)
	controller.call("_evaluate_target_validity")
	controller.update_marker()
	debug = controller.get_debug_data()
	_expect(
		not bool(debug.get("valid", true)),
		"Ground targeting rejects missing terrain"
	)
	_expect(
		str(debug.get("invalid_reason", "")) != "",
		"Invalid placement exposes a player-facing reason"
	)
	var preview_debug: Dictionary = (
		debug.get("preview", {}) as Dictionary
	)
	_expect(
		not bool(preview_debug.get("valid", true)),
		"Preview renderer receives invalid placement state"
	)
	controller.cancel()


func _test_invalid_confirmation_preserves_resources() -> void:
	var player: CharacterBody3D = (
		PlayerScene.instantiate() as CharacterBody3D
	)
	player.name = "TargetingCostTestPlayer"
	player.position = Vector3(0.0, 0.96, 4.0)
	add_child(player)
	for _frame: int in range(10):
		await get_tree().process_frame
	await get_tree().physics_frame
	var caster: Node = player.get_node_or_null("AbilityCaster")
	_expect(caster != null, "Player caster is available for cost validation")
	if caster == null:
		player.queue_free()
		return
	var loadout_value: Variant = caster.get("loadout")
	var loadout: AbilityLoadout = (
		loadout_value as AbilityLoadout
		if loadout_value is AbilityLoadout
		else null
	)
	var earth_spike_index: int = _find_spell_index(
		loadout,
		"earth_spike"
	)
	_expect(
		earth_spike_index >= 0,
		"Player loadout exposes Earth Spike for integration validation"
	)
	if earth_spike_index < 0:
		player.queue_free()
		return
	caster.call("select_ability", earth_spike_index, false)
	var started: bool = bool(
		caster.call("cast_from_player", player, 0.18, false)
	)
	_expect(started, "Player enters shared Earth Spike targeting")
	if not started:
		player.queue_free()
		return
	var controller: RefCounted = caster.call(
		"get_ground_targeting_controller"
	) as RefCounted
	controller.set(
		"target_position",
		controller.call(
			"resolve_ground",
			Vector3(40.0, 0.0, 40.0)
		)
	)
	controller.call("_evaluate_target_validity")
	controller.call("update_marker")
	var mana_before: int = GameState.get_stat("mana")
	var confirmation_handled: bool = bool(
		caster.call("confirm_ground_targeting")
	)
	_expect(
		confirmation_handled,
		"Invalid confirmation is consumed without leaking input"
	)
	_expect(
		bool(caster.call("is_ground_targeting")),
		"Invalid confirmation keeps targeting active for correction"
	)
	_expect(
		GameState.get_stat("mana") == mana_before,
		"Invalid confirmation spends no Mana"
	)
	caster.call("cancel_ground_targeting", false)
	player.queue_free()
	await get_tree().process_frame


func _find_spell_index(
	loadout: AbilityLoadout,
	spell_id: String
) -> int:
	if loadout == null:
		return -1
	for index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(index)
		if ability != null and ability.get_spell_id() == spell_id:
			return index
	return -1


func _prepare_stats() -> void:
	GameState.set_stat("max_health", 100)
	GameState.set_stat("health", 100)
	GameState.set_stat("max_mana", 100)
	GameState.set_stat("mana", 100)
	GameState.set_stat("max_stamina", 60)
	GameState.set_stat("stamina", 60)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)
	GameState.set_stat("max_focus", 40)
	GameState.set_stat("focus", 40)


func _restore_stats() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(
			stat_id,
			int(GameState.stats[stat_value])
		)


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
