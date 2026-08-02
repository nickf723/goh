extends "res://scripts/levels/prototype_ruined_village_approach.gd"
class_name PrototypeRuinedVillageFieldProgression

const FieldInteractableScript = preload(
	"res://scripts/interaction/field_progression_interactable.gd"
)
const AlchemyCauldronScript = preload(
	"res://scripts/alchemy/alchemy_cauldron.gd"
)
const IngredientPickupScript = preload(
	"res://scripts/alchemy/alchemy_ingredient_pickup.gd"
)
const CatalystStationScript = preload(
	"res://scripts/alchemy/alchemy_catalyst_station.gd"
)
const EncounterControllerFieldScript = preload(
	"res://scripts/encounters/encounter_controller.gd"
)
const CreatureStudyTerminalScene: PackedScene = preload(
	"res://scenes/actors/interactables/creature_study_terminal.tscn"
)
const OilPatchScene: PackedScene = preload(
	"res://scenes/surfaces/oil_patch.tscn"
)
const WaterPatchScene: PackedScene = preload(
	"res://scenes/surfaces/water_patch.tscn"
)
const FinalEncounter: EncounterDefinition = preload(
	"res://data/encounters/village_church_steps_showcase.tres"
)

const STORY_QUEST_ID: String = "through_the_vanished_village"
const SIDE_QUEST_ID: String = "herbalists_satchel"
const FIELD_FLAG_PREFIX: String = "field_progression_v1_"
const FIELD_FLAGS: Array[String] = [
	FIELD_FLAG_PREFIX + "ledger_read",
	FIELD_FLAG_PREFIX + "moonveil_recorded",
	FIELD_FLAG_PREFIX + "satchel_recovered",
	FIELD_FLAG_PREFIX + "travel_brew_completed",
	"cleared_village_church_steps_showcase",
]

var field_root: Node3D
var field_interactions: Node3D
var field_alchemy: Node3D
var field_encounters: Node3D
var final_encounter_controller: Node3D
var route_baseline: Dictionary = {}
var route_summary: Dictionary = {}
var initialized_field_slice: bool = false


func _ready() -> void:
	await super._ready()
	add_to_group("ruined_village_field_progression")
	_build_field_roots()
	_build_ruined_garden()
	_build_square_progression_opportunities()
	_build_travel_cauldron()
	_build_satchel_reward()
	_build_final_showcase_encounter()
	_connect_existing_village_flow()
	_start_field_quests()
	_sync_field_progression_from_state()
	route_baseline = _capture_progress_snapshot()
	initialized_field_slice = true
	GameState.set_objective(_get_active_field_objective())
	_show_field_message(
		"Field progression route active. Explore the herbalist garden, use the square's elemental opportunities, cross the ravine, and test what Grace learns on the church road."
	)


func _build_field_roots() -> void:
	field_root = Node3D.new()
	field_root.name = "FieldProgression"
	add_child(field_root)

	field_interactions = Node3D.new()
	field_interactions.name = "Interactions"
	field_root.add_child(field_interactions)

	field_alchemy = Node3D.new()
	field_alchemy.name = "TravelAlchemy"
	field_root.add_child(field_alchemy)

	field_encounters = Node3D.new()
	field_encounters.name = "Encounters"
	field_root.add_child(field_encounters)


func _build_ruined_garden() -> void:
	create_static_box(
		"FieldGardenTerrace",
		Vector3(-13.0, 3.05, 20.0),
		Vector3(10.0, 0.28, 11.0),
		palette["moss"]
	)
	create_region_label(
		"HERBALIST'S GARDEN",
		Vector3(-13.0, 6.1, 20.0),
		34,
		Color(0.54, 1.0, 0.58, 1.0)
	)

	_create_field_interactable(
		"HerbalistLedger",
		Vector3(-10.4, 3.25, 23.0),
		"herbalist_ledger",
		"Weathered Herbalist Ledger",
		"Read the ledger",
		"The final page lists a satchel carried toward the ravine during the village's disappearance.",
		FIELD_FLAG_PREFIX + "ledger_read",
		"▤",
		Color(0.94, 0.76, 0.34, 1.0),
		false
	)
	_create_field_interactable(
		"MoonveilFern",
		Vector3(-15.2, 3.22, 18.5),
		"moonveil_fern",
		"Moonveil Fern",
		"Study the unfamiliar fern",
		"A silver-veined fern closes when magic is nearby and opens again after the spell has passed.",
		FIELD_FLAG_PREFIX + "moonveil_recorded",
		"✧",
		Color(0.52, 0.96, 0.78, 1.0),
		false
	)

	_create_ingredient_pickup(
		"GardenLifeBloom",
		Vector3(-16.4, 3.12, 22.0),
		"life_bloom",
		"Life Bloom",
		"life / body",
		Color(0.35, 0.95, 0.45),
		3
	)
	_create_ingredient_pickup(
		"GardenEchoReed",
		Vector3(-12.8, 3.12, 16.8),
		"echo_reed",
		"Echo Reed",
		"sound / air",
		Color(0.82, 0.42, 1.0),
		3
	)
	_create_ingredient_pickup(
		"GardenSpringwater",
		Vector3(-9.8, 3.12, 18.2),
		"springwater",
		"Springwater",
		"water / cleanse",
		Color(0.25, 0.72, 1.0),
		5
	)


func _build_square_progression_opportunities() -> void:
	create_region_label(
		"FLOODED COURTYARD",
		Vector3(0.0, 7.2, -1.0),
		32,
		Color(0.46, 0.76, 1.0, 1.0)
	)
	var wet_positions: Array[Vector3] = [
		Vector3(-5.5, 3.12, -2.5),
		Vector3(5.5, 3.12, 0.5),
		Vector3(0.0, 3.12, -7.0),
	]
	for index: int in range(wet_positions.size()):
		var patch: Node3D = WaterPatchScene.instantiate() as Node3D
		patch.name = "FieldWaterPatch" + str(index + 1)
		patch.position = wet_positions[index]
		field_root.add_child(patch)

	var oil: Node3D = OilPatchScene.instantiate() as Node3D
	oil.name = "FieldOilPatch"
	oil.position = Vector3(7.4, 3.12, -3.8)
	field_root.add_child(oil)

	var study: Node3D = CreatureStudyTerminalScene.instantiate() as Node3D
	study.name = "CourtyardGremlinStudy"
	study.position = Vector3(-9.2, 3.12, -6.5)
	study.set("species_id", "gremlin")
	study.set("discovery_id", "flooded_courtyard_pack_spacing")
	study.set("discovery_label", "Observed flooded-courtyard pack spacing")
	study.set("knowledge_points", 2)
	study.set("prompt_text", "Study Gremlin tracks")
	study.set("objective_after", "Use the flooded square to test elemental combinations.")
	field_root.add_child(study)


func _build_travel_cauldron() -> void:
	create_static_box(
		"FieldTravelAlchemyPlatform",
		Vector3(-12.0, 5.98, -44.0),
		Vector3(10.0, 0.34, 10.0),
		palette["stone_warm"]
	)
	create_region_label(
		"TRAVEL ALCHEMY",
		Vector3(-12.0, 9.15, -44.0),
		32,
		Color(0.88, 0.6, 1.0, 1.0)
	)

	var cauldron := Area3D.new()
	cauldron.name = "TravelCauldron"
	cauldron.set_script(AlchemyCauldronScript)
	cauldron.position = Vector3(-12.0, 6.18, -44.0)
	field_alchemy.add_child(cauldron)
	if cauldron.has_signal("brew_completed"):
		cauldron.connect("brew_completed", _on_field_brew_completed)

	_create_catalyst_station(
		"FieldFireTreatment",
		Vector3(-14.3, 6.05, -45.8),
		"fire",
		"Fire Treatment",
		Color(1.0, 0.28, 0.08)
	)
	_create_catalyst_station(
		"FieldWaterTreatment",
		Vector3(-12.0, 6.05, -47.0),
		"water",
		"Water Treatment",
		Color(0.18, 0.62, 1.0)
	)
	_create_catalyst_station(
		"FieldLightningTreatment",
		Vector3(-9.7, 6.05, -45.8),
		"lightning",
		"Lightning Treatment",
		Color(1.0, 0.82, 0.18)
	)

	_create_ingredient_pickup(
		"FieldFrostSalt",
		Vector3(-15.0, 6.05, -41.8),
		"frost_salt",
		"Frost Salt",
		"ice / poison",
		Color(0.55, 0.93, 1.0),
		3,
		field_alchemy
	)
	_create_ingredient_pickup(
		"FieldSparkOre",
		Vector3(-9.0, 6.05, -41.8),
		"spark_ore",
		"Spark Ore",
		"metal / lightning",
		Color(1.0, 0.78, 0.18),
		3,
		field_alchemy
	)

	var guide := Label3D.new()
	guide.name = "TravelRecipeGuide"
	guide.position = Vector3(-12.0, 8.15, -40.7)
	guide.text = (
		"FIELD FORMULAS\n"
		+ "Life Bloom + Springwater  •  FIRE\n"
		+ "Frost Salt + Springwater  •  WATER\n"
		+ "Spark Ore + Springwater  •  LIGHTNING"
	)
	guide.font_size = 25
	guide.pixel_size = 0.0065
	guide.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guide.outline_size = 7
	guide.modulate = Color(0.92, 0.84, 1.0)
	field_alchemy.add_child(guide)


func _build_satchel_reward() -> void:
	_create_field_interactable(
		"HerbalistSatchel",
		Vector3(12.0, 6.18, -45.0),
		"herbalist_satchel",
		"Herbalist's Satchel",
		"Recover the satchel",
		"The leather is weathered, but the dried plants and field notes survived the village's disappearance.",
		FIELD_FLAG_PREFIX + "satchel_recovered",
		"▣",
		Color(1.0, 0.68, 0.26, 1.0),
		true
	)
	var route_hint := Label3D.new()
	route_hint.name = "SatchelRouteHint"
	route_hint.position = Vector3(12.0, 8.25, -40.5)
	route_hint.text = "SATCHEL ROUTE\nFire clears roots  •  Ice + Force shatters them\nThe frozen bridge reaches the same landing"
	route_hint.font_size = 24
	route_hint.pixel_size = 0.0065
	route_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	route_hint.outline_size = 7
	route_hint.modulate = Color(1.0, 0.78, 0.42)
	field_interactions.add_child(route_hint)


func _build_final_showcase_encounter() -> void:
	create_region_label(
		"CHURCH ROAD SHOWCASE",
		Vector3(0.0, 12.2, -62.0),
		34,
		Color(1.0, 0.7, 0.28, 1.0)
	)

	for index: int in range(3):
		var patch: Node3D = WaterPatchScene.instantiate() as Node3D
		patch.name = "ShowcaseWaterPatch" + str(index + 1)
		patch.position = Vector3(float(index - 1) * 2.2, 8.08, -62.0 + float(index % 2) * 1.6)
		field_root.add_child(patch)

	final_encounter_controller = Node3D.new()
	final_encounter_controller.name = "ChurchStepsShowcaseEncounter"
	final_encounter_controller.set_script(EncounterControllerFieldScript)
	final_encounter_controller.set("definition", FinalEncounter)
	final_encounter_controller.set("activate_on_ready", false)
	final_encounter_controller.set("reward_group_name", "field_route_reward")
	final_encounter_controller.position = Vector3(0.0, 8.08, -62.0)
	field_encounters.add_child(final_encounter_controller)
	if final_encounter_controller.has_signal("encounter_completed"):
		final_encounter_controller.connect("encounter_completed", _on_final_encounter_completed)

	var hint := Label3D.new()
	hint.name = "RewardShowcaseHint"
	hint.position = Vector3(0.0, 10.0, -57.0)
	hint.text = "CLUSTERED FORMATION\nNew multi-target techniques belong here"
	hint.font_size = 27
	hint.pixel_size = 0.0065
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.outline_size = 7
	hint.modulate = Color(0.66, 0.86, 1.0)
	field_encounters.add_child(hint)


func _connect_existing_village_flow() -> void:
	var square_encounter: Node = get_node_or_null(
		"VillageEncounters/VillageSquareEncounter"
	)
	if (
		square_encounter != null
		and square_encounter.has_signal("encounter_completed")
		and not square_encounter.is_connected(
			"encounter_completed",
			_on_square_encounter_completed
		)
	):
		square_encounter.connect(
			"encounter_completed",
			_on_square_encounter_completed
		)


func _start_field_quests() -> void:
	if GameState.get_quest(STORY_QUEST_ID).is_empty():
		GameState.start_quest(
			STORY_QUEST_ID,
			{
				"title": "Through the Vanished Village",
				"quest_type": "story",
				"summary": "Follow the damaged village road to the Church of Angels while learning from what remains.",
				"objective": "Inspect the herbalist's garden and follow the road toward the flooded square.",
				"stage": 0,
				"stages": [
					"Read the village's surviving traces",
					"Clear the flooded village square",
					"Cross the collapsed ravine",
					"Break the church-road formation",
					"Enter the Church of Angels",
				],
				"rewards": ["Village field record", "Progression route completion"],
			}
		)
	var tracker: Node = _get_progression_tracker()
	if (
		tracker != null
		and tracker.has_method("get_tracked_progress_kind")
		and str(tracker.call("get_tracked_progress_kind")) == ""
		and tracker.has_method("track_quest")
	):
		tracker.call("track_quest", STORY_QUEST_ID)


func _sync_field_progression_from_state() -> void:
	if GameState.get_flag("cleared_village_church_steps_showcase"):
		_complete_story_route(false)
	elif GameState.get_flag("cleared_village_square_ambush"):
		_set_story_stage(
			2,
			"Cross the collapsed ravine. The herbalist's satchel may still be on the far landing."
		)
	elif GameState.get_flag(FIELD_FLAG_PREFIX + "ledger_read"):
		_set_story_stage(
			1,
			"Clear the scavengers occupying the flooded village square."
		)

	if GameState.get_flag(FIELD_FLAG_PREFIX + "satchel_recovered"):
		_ensure_side_quest_started()
		if str(GameState.get_quest(SIDE_QUEST_ID).get("state", "")) == "active":
			GameState.complete_quest(
				SIDE_QUEST_ID,
				"Return to the church road with the recovered satchel."
			)


func handle_field_progression_action(
	action_id: String,
	_source: Node = null
) -> Dictionary:
	match action_id:
		"herbalist_ledger":
			_ensure_side_quest_started()
			_set_story_stage(
				1,
				"Clear the scavengers occupying the flooded village square."
			)
			return {
				"message": "The ledger names a missing satchel and sketches three routes toward the ravine. Side quest started: The Herbalist's Satchel.",
				"objective": "Clear the flooded square, then search the far ravine landing.",
				"completed": true,
			}
		"moonveil_fern":
			var tracker: Node = _get_progression_tracker()
			if tracker != null and tracker.has_method("record_discovery"):
				tracker.call(
					"record_discovery",
					"flora",
					"moonveil_fern",
					{
						"source": "ruined_village_field_route",
						"habitat": "abandoned herbalist garden",
					}
				)
			GameState.add_inventory_item("life_bloom", 1)
			if not GameState.get_quest(SIDE_QUEST_ID).is_empty():
				GameState.complete_quest_optional(SIDE_QUEST_ID, "record_moonveil_fern")
			return {
				"message": "Journal discovery: Moonveil Fern. One usable Life Bloom was gathered from beneath it.",
				"objective": _get_active_field_objective(),
				"completed": true,
			}
		"herbalist_satchel":
			_ensure_side_quest_started()
			GameState.add_inventory_item("life_bloom", 2)
			GameState.add_inventory_item("echo_reed", 2)
			GameState.set_flag(FIELD_FLAG_PREFIX + "satchel_recovered", true)
			GameState.complete_quest(
				SIDE_QUEST_ID,
				"The satchel is safe. Continue toward the church."
			)
			var tracker: Node = _get_progression_tracker()
			if tracker != null and tracker.has_method("record_discovery"):
				tracker.call(
					"record_discovery",
					"field_note",
					"herbalists_satchel",
					{"source": "ruined_village_field_route"}
				)
			return {
				"message": "The Herbalist's Satchel was recovered. Life Bloom ×2 and Echo Reed ×2 were added to the field inventory.",
				"objective": "Use the travel cauldron or continue up the church road.",
				"completed": true,
			}
		"route_summary":
			return {
				"message": _format_route_summary(),
				"objective": "Enter the Church of Angels.",
				"completed": false,
			}
	return {
		"message": "The field progression action is not registered: " + action_id,
		"objective": "",
		"completed": false,
	}


func _ensure_side_quest_started() -> void:
	if not GameState.get_quest(SIDE_QUEST_ID).is_empty():
		return
	GameState.start_quest(
		SIDE_QUEST_ID,
		{
			"title": "The Herbalist's Satchel",
			"quest_type": "side",
			"summary": "Recover the satchel carried toward the ravine and preserve whatever knowledge survived inside it.",
			"objective": "Search the far ravine landing for the herbalist's satchel.",
			"stage": 0,
			"stages": ["Find the satchel", "Preserve its contents"],
			"optional_objectives": ["record_moonveil_fern", "brew_in_field"],
			"rewards": ["Life Bloom ×2", "Echo Reed ×2", "Herbalist field note"],
		}
	)


func _on_square_encounter_completed(_encounter_id: String) -> void:
	_set_story_stage(
		2,
		"Cross the collapsed ravine. Fire, Ice plus Force, or a frozen bridge can open the way."
	)
	var tracker: Node = _get_progression_tracker()
	if tracker != null and tracker.has_method("record_discovery"):
		tracker.call(
			"record_discovery",
			"field_note",
			"flooded_village_square",
			{"source": "village_square_encounter"}
		)


func _on_field_brew_completed(recipe_id: String, output_item_id: String) -> void:
	GameState.set_flag(FIELD_FLAG_PREFIX + "travel_brew_completed", true)
	if not GameState.get_quest(SIDE_QUEST_ID).is_empty():
		GameState.complete_quest_optional(SIDE_QUEST_ID, "brew_in_field")
	var hud: Node = _get_feedback_hud()
	if hud != null and hud.has_method("push_feedback"):
		hud.call(
			"push_feedback",
			"discovery",
			"Field Brew Complete",
			output_item_id.replace("_", " ").capitalize() + " prepared on the road.",
			"field_brew:" + recipe_id,
			-1,
			-1,
			false
		)


func _on_final_encounter_completed(_encounter_id: String) -> void:
	_complete_story_route(true)


func _complete_story_route(show_feedback: bool) -> void:
	var quest: Dictionary = GameState.get_quest(STORY_QUEST_ID)
	if not quest.is_empty() and str(quest.get("state", "")) == "active":
		GameState.set_quest_stage(
			STORY_QUEST_ID,
			4,
			"Enter the Church of Angels."
		)
		GameState.complete_quest(
			STORY_QUEST_ID,
			"Enter the Church of Angels."
		)
	var tracker: Node = _get_progression_tracker()
	if tracker != null and tracker.has_method("record_discovery"):
		tracker.call(
			"record_discovery",
			"field_note",
			"vanished_village_progression_route",
			{"source": "ruined_village_field_route"}
		)
	route_summary = _build_route_summary()
	if show_feedback:
		var hud: Node = _get_feedback_hud()
		if hud != null and hud.has_method("push_feedback"):
			hud.call(
				"push_feedback",
				"quest",
				"Field Route Complete",
				_format_route_summary(),
				"field_route:vanished_village",
				-1,
				-1,
				true
			)
		_show_field_message(_format_route_summary())


func _set_story_stage(stage: int, objective: String) -> void:
	var quest: Dictionary = GameState.get_quest(STORY_QUEST_ID)
	if quest.is_empty() or str(quest.get("state", "")) != "active":
		return
	if int(quest.get("stage", 0)) > stage:
		return
	GameState.set_quest_stage(STORY_QUEST_ID, stage, objective)


func _get_active_field_objective() -> String:
	var story: Dictionary = GameState.get_quest(STORY_QUEST_ID)
	if not story.is_empty() and str(story.get("state", "")) == "active":
		return str(story.get("objective", ARRIVAL_OBJECTIVE))
	return "Enter the Church of Angels."


func _capture_progress_snapshot() -> Dictionary:
	var tracker: Node = _get_progression_tracker()
	var challenges: Dictionary = {}
	if tracker != null and tracker.has_method("get_challenge_rows"):
		var rows_value: Variant = tracker.call("get_challenge_rows")
		if rows_value is Array:
			for raw_row: Variant in rows_value as Array:
				if raw_row is Dictionary:
					var row: Dictionary = raw_row as Dictionary
					challenges[str(row.get("challenge_id", ""))] = int(
						row.get("progress_current", 0)
					)
	var mastery_total: int = 0
	for raw_points: Variant in GameState.get_weapon_mastery_snapshot().values():
		mastery_total += int(raw_points)
	var gremlin_rank: int = 0
	if SpeciesKnowledge.has_method("get_species_data"):
		gremlin_rank = int(
			(SpeciesKnowledge.get_species_data("gremlin") as Dictionary).get("rank", 0)
		)
	return {
		"experience": GameState.get_experience(),
		"weapon_mastery": mastery_total,
		"gremlin_rank": gremlin_rank,
		"challenges": challenges,
		"reaction_discoveries": (
			int(tracker.call("get_discovery_count", "reaction"))
			if tracker != null and tracker.has_method("get_discovery_count")
			else 0
		),
		"recipe_discoveries": (
			int(tracker.call("get_discovery_count", "recipe"))
			if tracker != null and tracker.has_method("get_discovery_count")
			else 0
		),
	}


func _build_route_summary() -> Dictionary:
	var current: Dictionary = _capture_progress_snapshot()
	var challenge_advances: int = 0
	var before_challenges: Dictionary = route_baseline.get("challenges", {}) as Dictionary
	var after_challenges: Dictionary = current.get("challenges", {}) as Dictionary
	for raw_id: Variant in after_challenges.keys():
		var challenge_id: String = str(raw_id)
		if int(after_challenges.get(challenge_id, 0)) > int(before_challenges.get(challenge_id, 0)):
			challenge_advances += 1
	return {
		"challenge_tracks": challenge_advances,
		"reaction_discoveries": maxi(
			int(current.get("reaction_discoveries", 0)) - int(route_baseline.get("reaction_discoveries", 0)),
			0
		),
		"recipe_discoveries": maxi(
			int(current.get("recipe_discoveries", 0)) - int(route_baseline.get("recipe_discoveries", 0)),
			0
		),
		"weapon_mastery": maxi(
			int(current.get("weapon_mastery", 0)) - int(route_baseline.get("weapon_mastery", 0)),
			0
		),
		"gremlin_ranks": maxi(
			int(current.get("gremlin_rank", 0)) - int(route_baseline.get("gremlin_rank", 0)),
			0
		),
		"experience": maxi(
			int(current.get("experience", 0)) - int(route_baseline.get("experience", 0)),
			0
		),
		"satchel_recovered": GameState.get_flag(FIELD_FLAG_PREFIX + "satchel_recovered"),
		"field_brewed": GameState.get_flag(FIELD_FLAG_PREFIX + "travel_brew_completed"),
	}


func _format_route_summary() -> String:
	if route_summary.is_empty():
		route_summary = _build_route_summary()
	var highlights: Array[String] = []
	var challenge_tracks: int = int(route_summary.get("challenge_tracks", 0))
	if challenge_tracks > 0:
		highlights.append(str(challenge_tracks) + " challenge track" + ("s" if challenge_tracks != 1 else ""))
	var discoveries: int = int(route_summary.get("reaction_discoveries", 0)) + int(route_summary.get("recipe_discoveries", 0))
	if discoveries > 0:
		highlights.append(str(discoveries) + " systemic discovery" + ("ies" if discoveries != 1 else ""))
	if int(route_summary.get("weapon_mastery", 0)) > 0:
		highlights.append("weapon mastery +" + str(route_summary.get("weapon_mastery", 0)))
	if int(route_summary.get("gremlin_ranks", 0)) > 0:
		highlights.append("Gremlin knowledge rank +" + str(route_summary.get("gremlin_ranks", 0)))
	if bool(route_summary.get("satchel_recovered", false)):
		highlights.append("satchel recovered")
	if bool(route_summary.get("field_brewed", false)):
		highlights.append("field potion brewed")
	if highlights.is_empty():
		highlights.append("the church road opened")
	return "Field route complete: " + ", ".join(highlights) + "."


func _create_field_interactable(
	node_name: String,
	position_value: Vector3,
	action_id: String,
	display_name: String,
	prompt: String,
	description: String,
	story_flag: String,
	icon: String,
	color: Color,
	hide_when_complete: bool
) -> Area3D:
	var node := Area3D.new()
	node.name = node_name
	node.set_script(FieldInteractableScript)
	node.set("action_id", action_id)
	node.set("display_name", display_name)
	node.set("prompt_text", prompt)
	node.set("description", description)
	node.set("story_flag", story_flag)
	node.set("visual_icon", icon)
	node.set("visual_color", color)
	node.set("hide_when_complete", hide_when_complete)
	node.position = position_value
	field_interactions.add_child(node)
	return node


func _create_ingredient_pickup(
	node_name: String,
	position_value: Vector3,
	ingredient_id: String,
	display_name: String,
	element: String,
	color: Color,
	amount: int,
	parent: Node = null
) -> Area3D:
	var pickup := Area3D.new()
	pickup.name = node_name
	pickup.set_script(IngredientPickupScript)
	pickup.set("ingredient_id", ingredient_id)
	pickup.set("display_name", display_name)
	pickup.set("element", element)
	pickup.set("ingredient_color", color)
	pickup.set("amount", amount)
	pickup.set("prompt_text", "Gather " + display_name)
	pickup.set("respawns_in_lab", false)
	pickup.position = position_value
	(parent if parent != null else field_interactions).add_child(pickup)
	if pickup.has_signal("ingredient_collected"):
		pickup.connect("ingredient_collected", _on_field_ingredient_collected)
	return pickup


func _create_catalyst_station(
	node_name: String,
	position_value: Vector3,
	element: String,
	display_name: String,
	color: Color
) -> Area3D:
	var station := Area3D.new()
	station.name = node_name
	station.set_script(CatalystStationScript)
	station.set("element", element)
	station.set("display_name", display_name)
	station.set("station_color", color)
	station.set("prompt_text", "Apply " + display_name)
	station.position = position_value
	field_alchemy.add_child(station)
	return station


func _on_field_ingredient_collected(ingredient_id: String, _amount: int) -> void:
	var tracker: Node = _get_progression_tracker()
	if tracker == null or not tracker.has_method("record_discovery"):
		return
	var category: String = "flora" if ingredient_id in ["life_bloom", "echo_reed"] else "ingredient"
	tracker.call(
		"record_discovery",
		category,
		ingredient_id,
		{"source": "ruined_village_field_route"}
	)


func _get_progression_tracker() -> Node:
	return get_node_or_null("/root/FullMenuDirector/ProgressionTracker")


func _get_feedback_hud() -> Node:
	return get_node_or_null("/root/FullMenuDirector/ProgressionFeedbackHUD")


func _show_field_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func reset_field_progression_for_test() -> void:
	for flag: String in FIELD_FLAGS:
		GameState.set_flag(flag, false)
	GameState.reset_quest(STORY_QUEST_ID)
	GameState.reset_quest(SIDE_QUEST_ID)
	for node: Node in get_tree().get_nodes_in_group("field_progression_interactable"):
		if node != null and node.has_method("reset_target"):
			node.call("reset_target")
	if final_encounter_controller != null and final_encounter_controller.has_method("reset_encounter"):
		final_encounter_controller.call("reset_encounter")
	_start_field_quests()
	route_baseline = _capture_progress_snapshot()
	route_summary.clear()


func get_field_progression_debug_data() -> Dictionary:
	return {
		"initialized": initialized_field_slice,
		"story_quest": GameState.get_quest(STORY_QUEST_ID),
		"side_quest": GameState.get_quest(SIDE_QUEST_ID),
		"field_interactables": get_tree().get_nodes_in_group("field_progression_interactable").size(),
		"water_opportunities": field_root.find_children("FieldWaterPatch*", "Node3D", true, false).size() if field_root != null else 0,
		"has_travel_cauldron": get_node_or_null("FieldProgression/TravelAlchemy/TravelCauldron") != null,
		"has_final_encounter": final_encounter_controller != null,
		"route_summary": route_summary.duplicate(true),
	}
