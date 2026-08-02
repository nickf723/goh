extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_recorded_object_lab_v1.tscn"
)
const ReproduceAbility: AbilityDefinition = preload(
	"res://data/abilities/recorded_object_summon_ability.tres"
)
const Catalog = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)

var failures: Array[String] = []
var old_inventory: Dictionary = {}
var old_story_flags: Dictionary = {}
var old_stats: Dictionary = {}
var lab: Node3D
var manager: RecordedObjectManagerSpell


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_state()
	_clear_blueprints()
	Engine.time_scale = 1.0
	lab = LabScene.instantiate() as Node3D
	add_child(lab)
	for _index: int in range(24):
		await get_tree().process_frame
	await get_tree().physics_frame

	manager = get_tree().get_first_node_in_group(
		"recorded_object_manager"
	) as RecordedObjectManagerSpell
	var player: Node3D = lab.get_node_or_null("Player") as Node3D
	var spell_controller: PlayerRecordedObjectSpellController = (
		get_tree().get_first_node_in_group(
			"recorded_object_spell_controllers"
		) as PlayerRecordedObjectSpellController
	)
	var context_hud: GameplayContextHUD = get_tree().get_first_node_in_group(
		"gameplay_context_hud"
	) as GameplayContextHUD

	assert_true(manager != null, "spell-aware recorded object manager exists")
	assert_true(player != null, "player exists")
	assert_true(
		spell_controller != null,
		"recorded object spell controller exists"
	)
	assert_true(context_hud != null, "global gameplay context HUD exists")
	if manager == null or player == null or spell_controller == null:
		_restore_state()
		_finish()
		return

	lab.call("record_all_for_debug")
	await get_tree().process_frame
	assert_equal(
		Catalog.get_recorded_blueprint_ids().size(),
		4,
		"all object blueprints are available"
	)
	Catalog.select_blueprint("crate")
	var cast_started: bool = spell_controller.begin_ability_channel(
		player,
		ReproduceAbility
	)
	assert_true(cast_started, "Reproduce Object begins placement")
	assert_true(manager.placement_active, "spell owns active placement")
	var before_depth: float = manager.placement_depth_offset
	manager.adjust_depth(1)
	manager.rotate_preview(1)
	assert_true(
		manager.placement_depth_offset > before_depth,
		"depth control moves the preview farther"
	)
	assert_true(
		is_equal_approx(manager.placement_yaw_degrees, 90.0),
		"shoulder rotation advances the preview by 90 degrees"
	)
	await get_tree().process_frame
	if context_hud != null:
		context_hud.call("_refresh")
		var hud_debug: Dictionary = context_hud.get_debug_data()
		assert_true(
			bool(hud_debug.get("object_context", false)),
			"global HUD reports object placement context"
		)
	manager.cancel_placement()

	var soul_controller: SoulGripSpellController = get_tree().get_first_node_in_group(
		"soul_grip_controllers"
	) as SoulGripSpellController
	assert_true(soul_controller != null, "Soul Grasp controller exists")
	if soul_controller != null and context_hud != null:
		soul_controller.channel_requested = true
		context_hud.call("_refresh")
		assert_true(
			bool(context_hud.get_debug_data().get("soul_context", false)),
			"global HUD reports Soul Grasp context"
		)
		soul_controller.channel_requested = false
		context_hud.call("_refresh")

	manager.clear_spawned_objects()
	Catalog.select_blueprint("blast_barrel")
	var first: RecordedObjectInstance = manager.place_selected_at(
		Vector3(-1.0, 0.0, 9.0),
		0.0,
		true,
		true
	)
	var second: RecordedObjectInstance = manager.place_selected_at(
		Vector3(1.0, 0.0, 9.0),
		0.0,
		true,
		true
	)
	assert_true(first is RecordedObjectInstanceSafe, "barrels use safe actor")
	assert_true(second is RecordedObjectInstanceSafe, "chain barrel uses safe actor")
	if first != null:
		var fire := DamagePayload.new()
		fire.element = "fire"
		fire.amount = 3
		fire.status_strength = 1.0
		fire.source_name = "Smoke Firebolt"
		fire.tags = ["fire", "ignite", "projectile"]
		first.receive_damage_payload(fire)

	var frame_counter: int = 0
	for _index: int in range(8):
		await get_tree().process_frame
		frame_counter += 1
		await get_tree().physics_frame
	assert_equal(frame_counter, 8, "frames continue after barrel impact")
	assert_true(
		is_equal_approx(Engine.time_scale, 1.0),
		"barrel chain does not freeze global time"
	)
	assert_true(
		first == null or not is_instance_valid(first) or first.is_queued_for_deletion(),
		"first barrel resolves and exits"
	)
	assert_true(
		second == null or not is_instance_valid(second) or second.is_queued_for_deletion(),
		"nearby barrel chain resolves without recursion"
	)

	_restore_state()
	_finish()


func _capture_state() -> void:
	old_inventory = GameState.inventory.duplicate(true)
	old_story_flags = GameState.story_flags.duplicate(true)
	old_stats = GameState.stats.duplicate(true)


func _clear_blueprints() -> void:
	for blueprint_id: String in Catalog.BLUEPRINT_ORDER:
		GameState.inventory.erase(Catalog.get_item_id(blueprint_id))
	GameState.story_flags.erase(Catalog.SELECTED_BLUEPRINT_FLAG)


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
		print("RECORDED_OBJECT_SPELL_CONTEXT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RECORDED_OBJECT_SPELL_CONTEXT_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label
			+ " (expected "
			+ str(expected)
			+ ", got "
			+ str(actual)
			+ ")"
		)
