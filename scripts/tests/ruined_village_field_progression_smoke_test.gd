extends Node

const FieldScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_ruined_village_field_progression_v1.tscn"
)
const FinalEncounter: EncounterDefinition = preload(
	"res://data/encounters/village_church_steps_showcase.tres"
)

var failures: Array[String] = []
var field_level: Node


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	GameState.reset_run()
	field_level = FieldScene.instantiate()
	add_child(field_level)

	for _index: int in range(20):
		await get_tree().process_frame
	await get_tree().physics_frame

	_validate_structure()
	_validate_quest_bootstrap()
	_validate_garden_discovery()
	_validate_square_and_routes()
	_validate_satchel_side_quest()
	_validate_travel_alchemy()
	_validate_final_showcase()

	if field_level != null and is_instance_valid(field_level):
		field_level.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_structure() -> void:
	assert_true(field_level != null, "field scene instantiates")
	if field_level == null:
		return
	assert_true(
		field_level.is_in_group("ruined_village_field_progression"),
		"field route advertises its progression group"
	)
	assert_true(
		field_level.get_node_or_null("FieldProgression/Interactions/HerbalistLedger") != null,
		"herbalist ledger exists"
	)
	assert_true(
		field_level.get_node_or_null("FieldProgression/Interactions/MoonveilFern") != null,
		"Moonveil Fern discovery exists"
	)
	assert_true(
		field_level.get_node_or_null("FieldProgression/Interactions/HerbalistSatchel") != null,
		"satchel reward exists"
	)
	assert_true(
		field_level.get_node_or_null("FieldProgression/TravelAlchemy/TravelCauldron") != null,
		"travel cauldron exists"
	)
	assert_true(
		field_level.get_node_or_null("FieldProgression/Encounters/ChurchStepsShowcaseEncounter") != null,
		"final showcase encounter exists"
	)
	assert_true(
		get_tree().get_nodes_in_group("encounter_controller").size() >= 2,
		"base square and final showcase encounters coexist"
	)
	assert_equal(FinalEncounter.enemy_scenes.size(), 4, "final showcase uses a four-enemy cluster")
	var debug: Dictionary = field_level.call("get_field_progression_debug_data") as Dictionary
	assert_true(bool(debug.get("initialized", false)), "field slice reports initialized")
	assert_true(int(debug.get("water_opportunities", 0)) >= 3, "square exposes three Water opportunities")
	assert_true(bool(debug.get("has_travel_cauldron", false)), "debug contract sees travel alchemy")
	assert_true(bool(debug.get("has_final_encounter", false)), "debug contract sees final encounter")


func _validate_quest_bootstrap() -> void:
	var story: Dictionary = GameState.get_quest("through_the_vanished_village")
	assert_equal(story.get("state"), "active", "story route begins active")
	assert_equal(story.get("quest_type"), "story", "route is classified as a story quest")
	assert_equal((story.get("stages", []) as Array).size(), 5, "story route has five readable stages")
	var tracker: Node = get_node_or_null("/root/FullMenuDirector/ProgressionTracker")
	assert_true(tracker != null, "progression tracker is available")
	if tracker != null and tracker.has_method("get_tracked_progress_row"):
		var tracked: Dictionary = tracker.call("get_tracked_progress_row") as Dictionary
		assert_equal(tracked.get("id"), "through_the_vanished_village", "story route is initially pinned")


func _validate_garden_discovery() -> void:
	var ledger: Node = field_level.get_node_or_null(
		"FieldProgression/Interactions/HerbalistLedger"
	)
	assert_true(ledger != null, "ledger remains available for interaction")
	if ledger != null:
		var result: Dictionary = ledger.call("interact") as Dictionary
		assert_true(str(result.get("message", "")).contains("Side quest started"), "ledger explains the side quest")
	var side: Dictionary = GameState.get_quest("herbalists_satchel")
	assert_equal(side.get("state"), "active", "ledger starts herbalist side quest")
	assert_equal(
		GameState.get_quest("through_the_vanished_village").get("stage"),
		1,
		"ledger advances the story route to the square"
	)

	var fern: Node = field_level.get_node_or_null(
		"FieldProgression/Interactions/MoonveilFern"
	)
	assert_true(fern != null, "Moonveil Fern remains available")
	if fern != null:
		fern.call("interact")
	var tracker: Node = get_node_or_null("/root/FullMenuDirector/ProgressionTracker")
	if tracker != null and tracker.has_method("has_discovery"):
		assert_true(
			bool(tracker.call("has_discovery", "flora", "moonveil_fern")),
			"fern enters the Journal discovery ledger"
		)
	assert_true(GameState.get_inventory_count("life_bloom") >= 1, "fern yields a usable alchemy ingredient")


func _validate_square_and_routes() -> void:
	field_level.call("_on_square_encounter_completed", "village_square_ambush")
	assert_equal(
		GameState.get_quest("through_the_vanished_village").get("stage"),
		2,
		"square completion advances the story to the ravine"
	)
	var debris: Node = field_level.get_node_or_null("VillagePuzzles/RavineDebrisGate")
	assert_true(debris != null, "existing multi-solution debris route is preserved")
	if debris != null:
		assert_true(bool(debris.get("accepts_fire")), "debris route still accepts Fire")
		assert_true(bool(debris.get("accepts_ice_force_combo")), "debris route still accepts Ice plus Force")
	assert_true(
		get_tree().get_nodes_in_group("village_ice_bridge").size() == 1,
		"frozen bridge remains the alternate ravine route"
	)


func _validate_satchel_side_quest() -> void:
	var before_life: int = GameState.get_inventory_count("life_bloom")
	var before_echo: int = GameState.get_inventory_count("echo_reed")
	var satchel: Node = field_level.get_node_or_null(
		"FieldProgression/Interactions/HerbalistSatchel"
	)
	assert_true(satchel != null, "satchel can be recovered")
	if satchel != null:
		satchel.call("interact")
	var side: Dictionary = GameState.get_quest("herbalists_satchel")
	assert_equal(side.get("state"), "completed", "satchel completes the side quest")
	assert_true(GameState.get_flag("field_progression_v1_satchel_recovered"), "satchel completion persists")
	assert_true(GameState.get_inventory_count("life_bloom") >= before_life + 2, "satchel grants Life Bloom")
	assert_true(GameState.get_inventory_count("echo_reed") >= before_echo + 2, "satchel grants Echo Reed")


func _validate_travel_alchemy() -> void:
	var cauldron: Node = field_level.get_node_or_null(
		"FieldProgression/TravelAlchemy/TravelCauldron"
	)
	assert_true(cauldron != null, "travel cauldron remains available")
	if cauldron == null:
		return
	GameState.set_inventory_count("life_bloom", maxi(GameState.get_inventory_count("life_bloom"), 4))
	GameState.set_inventory_count("springwater", maxi(GameState.get_inventory_count("springwater"), 4))
	var ingredients: Array[String] = ["life_bloom", "springwater"]
	cauldron.set("selected_ingredients", ingredients)
	cauldron.call("apply_element", "fire")
	cauldron.call("brew")
	assert_true(GameState.get_flag("field_progression_v1_travel_brew_completed"), "field brew marks the route")
	assert_true(GameState.get_flag("recipe_discovered_healing_potion"), "field brew discovers a real recipe")
	var side: Dictionary = GameState.get_quest("herbalists_satchel")
	var optional: Dictionary = side.get("optional_completed", {}) as Dictionary
	assert_true(bool(optional.get("brew_in_field", false)), "field brew completes the side objective")


func _validate_final_showcase() -> void:
	field_level.call("_on_final_encounter_completed", "village_church_steps_showcase")
	var story: Dictionary = GameState.get_quest("through_the_vanished_village")
	assert_equal(story.get("state"), "completed", "final showcase completes the story route")
	assert_equal(GameState.current_objective, "Enter the Church of Angels.", "route leaves a clear next objective")
	var debug: Dictionary = field_level.call("get_field_progression_debug_data") as Dictionary
	var summary: Dictionary = debug.get("route_summary", {}) as Dictionary
	assert_true(not summary.is_empty(), "route completion builds a progression summary")
	assert_true(bool(summary.get("satchel_recovered", false)), "summary remembers the side quest")
	assert_true(bool(summary.get("field_brewed", false)), "summary remembers field alchemy")
	var tracker: Node = get_node_or_null("/root/FullMenuDirector/ProgressionTracker")
	if tracker != null and tracker.has_method("has_discovery"):
		assert_true(
			bool(tracker.call("has_discovery", "field_note", "vanished_village_progression_route")),
			"completed route enters the Journal field notes"
		)


func _finish() -> void:
	if failures.is_empty():
		print("RUINED_VILLAGE_FIELD_PROGRESSION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RUINED_VILLAGE_FIELD_PROGRESSION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
