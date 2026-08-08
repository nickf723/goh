extends Node

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)

var failures: Array[String] = []
var original_stats: Dictionary = {}
var original_quick_spell_loadouts: Dictionary = {}
var original_quick_spell_selected_slots: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	original_stats = GameState.get_stat_snapshot()
	original_quick_spell_loadouts = GameState.quick_spell_loadouts.duplicate(true)
	original_quick_spell_selected_slots = GameState.quick_spell_selected_slots.duplicate(true)
	_prepare_stats()

	var floor := StaticBody3D.new()
	floor.name = "RepeatTestFloor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	floor.collision_layer = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40.0, 1.0, 40.0)
	floor_collision.shape = floor_shape
	floor.add_child(floor_collision)
	add_child(floor)

	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "RepeatTestPlayer"
	player.position = Vector3(0.0, 0.96, 0.0)
	player.add_to_group("player")
	add_child(player)
	await _wait_frames(20)
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	var grow_index: int = _find_ability_index(caster, "grow")
	var repeat_index: int = _find_ability_index(caster, "repeat")
	_expect(grow_index >= 0, "Grow remains in Grace's Focus library")
	_expect(repeat_index >= 0, "Repeat appears in Grace's Focus library")
	if caster == null or grow_index < 0 or repeat_index < 0:
		_finish([player, floor])
		return

	caster.call("select_ability", grow_index, false)
	_expect(
		bool(caster.call("cast_from_player", player, 0.0, false)),
		"Grow casts before the visual persistence check"
	)
	await _wait_frames(45)
	var body_controller: Node = player.get_node_or_null("BodyFormController")
	var grace_visual: Node3D = player.get_node_or_null("GraceVisualV1") as Node3D
	_expect(
		body_controller is PlayerBodyFormControllerVisualAuthority,
		"runtime Grow installs the late visual-authority controller"
	)
	_expect(
		grace_visual != null and grace_visual.scale.x > 1.5,
		"Grow remains visibly enlarged after many animation frames"
	)
	if body_controller != null and body_controller.has_method("reset_target"):
		body_controller.call("reset_target")
	await _wait_frames(4)
	_expect(
		grace_visual != null and is_equal_approx(grace_visual.scale.x, 1.0),
		"returning to normal restores the authored visual scale"
	)

	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	caster.call("select_ability", repeat_index, false)
	_expect(
		bool(caster.call("cast_from_player", player, 0.0, false)),
		"Repeat casts through the ordinary AbilityCaster path"
	)
	await _wait_frames(8)
	var manager: Node = get_tree().get_first_node_in_group("concentration_manager")
	var repeat_controller: RepeatEchoController = get_tree().get_first_node_in_group(
		"repeat_echo_controller"
	) as RepeatEchoController
	_expect(manager != null, "Repeat resolves the shared concentration manager")
	_expect(repeat_controller != null, "Repeat creates one timeline controller")
	if manager != null:
		var active_value: Variant = manager.get("active_effect")
		_expect(
			active_value is Resource
			and str((active_value as Resource).get("effect_id")) == "repeat_concentration",
			"Repeat owns the active concentration slot"
		)
		_expect(
			int(manager.call("get_reservation_percent")) == 30,
			"Repeat reserves 30 percent of maximum Mana"
		)
	_expect(
		get_tree().get_node_count_in_group("repeat_echoes") == 1,
		"Repeat v1 sustains exactly one delayed echo"
	)

	if repeat_controller != null:
		for step: int in range(85):
			player.global_position.x = float(step) * 0.045
			await get_tree().physics_frame
		var echo: RepeatEchoActor = get_tree().get_first_node_in_group(
			"repeat_echoes"
		) as RepeatEchoActor
		_expect(echo != null, "the delayed echo remains alive after one second")
		if echo != null:
			_expect(
				echo.global_position.x < player.global_position.x - 0.5,
				"the echo occupies an older point on Grace's timeline"
			)
		var debug: Dictionary = repeat_controller.get_debug_data()
		_expect(
			int(debug.get("recorded_snapshots", 0)) >= 60,
			"Repeat records a dense movement history"
		)
		_expect(
			bool(debug.get("future_multi_source_hook", false)),
			"Repeat exposes the future Soul-double source hook"
		)

	caster.call("select_ability", repeat_index, false)
	await _wait_frames(8)
	caster.call("cast_from_player", player, 0.0, false)
	await _wait_frames(8)
	_expect(
		manager != null and manager.get("active_effect") == null,
		"casting Repeat again releases concentration"
	)
	_expect(
		get_tree().get_node_count_in_group("repeat_echoes") == 0,
		"releasing Repeat removes its delayed echo"
	)

	_finish([player, floor])


func _find_ability_index(caster: Node, spell_id: String) -> int:
	if caster == null:
		return -1
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return -1
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
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
	GameState.set_stat("max_stamina", 40)
	GameState.set_stat("stamina", 40)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)


func _wait_frames(frame_count: int) -> void:
	for _frame: int in range(maxi(frame_count, 0)):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("REPEAT_AND_BODY_VISUAL_SMOKE_TEST: " + label)


func _restore_state() -> void:
	GameState.stats = original_stats.duplicate(true)
	for stat_value: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_value)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_value]))
	GameState.quick_spell_loadouts = original_quick_spell_loadouts.duplicate(true)
	GameState.quick_spell_selected_slots = original_quick_spell_selected_slots.duplicate(true)


func _finish(nodes: Array) -> void:
	Engine.time_scale = 1.0
	var manager: Node = get_tree().get_first_node_in_group("concentration_manager")
	if manager != null and is_instance_valid(manager) and manager.has_method("deactivate_effect"):
		manager.call("deactivate_effect", false)
	_restore_state()
	for node_value: Variant in nodes:
		if node_value is Node and is_instance_valid(node_value as Node):
			(node_value as Node).queue_free()
	if failures.is_empty():
		print("REPEAT_AND_BODY_VISUAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("REPEAT_AND_BODY_VISUAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
