extends Node3D
class_name PrototypeProgressionChallengeLab

const ChallengeCatalogScript = preload(
	"res://scripts/progression/progression_challenge_catalog.gd"
)
const LabLoadout: Resource = preload(
	"res://data/loadouts/grace_reaction_lab_loadout.tres"
)
const AlchemyCauldronScript = preload(
	"res://scripts/alchemy/alchemy_cauldron.gd"
)
const IngredientScript = preload(
	"res://scripts/alchemy/alchemy_ingredient_pickup.gd"
)
const CatalystScript = preload(
	"res://scripts/alchemy/alchemy_catalyst_station.gd"
)
const ConsoleScript = preload(
	"res://scripts/interaction/progression_lab_console.gd"
)
const CreatureStudyTerminalScene: PackedScene = preload(
	"res://scenes/actors/interactables/creature_study_terminal.tscn"
)
const GremlinTargetScene: PackedScene = preload(
	"res://scenes/actors/testing/gremlin_reaction_target.tscn"
)

const CHALLENGE_ORDER: Array[String] = [
	"trial_by_flame",
	"live_wire",
	"shatterproof",
	"kitchen_chemistry",
	"pack_scholar",
]
const REWARD_IDS: Array[String] = [
	"charged_firebolt",
	"chain_lightning",
	"piercing_ice_lance",
	"alchemy_recipe_insight",
	"gremlin_pounce",
]
const RECIPE_IDS: Array[String] = [
	"healing_potion",
	"resonance_tonic",
	"frost_vigor_draught",
	"antidote",
	"conductive_elixir",
]
const INGREDIENT_IDS: Array[String] = [
	"life_bloom",
	"springwater",
	"echo_reed",
	"frost_salt",
	"spark_ore",
]
const TELEPORTS: Dictionary = {
	KEY_F1: Vector3(-8.4, 1.0, -6.2),
	KEY_F2: Vector3(0.0, 1.0, -6.2),
	KEY_F3: Vector3(-5.2, 1.0, 3.4),
	KEY_F4: Vector3(5.2, 1.0, 3.4),
	KEY_F5: Vector3(0.0, 1.0, 10.8),
}

var reaction_wing: Node3D
var player: CharacterBody3D
var dashboard_text: RichTextLabel
var challenge_status_labels: Dictionary = {}
var refresh_timer: float = 0.0
var reset_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reaction_wing = get_node_or_null("ReactionWing") as Node3D
	player = get_node_or_null("ReactionWing/Player") as CharacterBody3D
	_configure_reaction_wing()
	_build_kitchen_chemistry_station()
	_build_pack_scholar_station()
	_build_entry_consoles()
	_build_dashboard()
	_configure_existing_challenge_labels()
	refill_lab_supplies()
	GameState.set_objective(
		"Complete the five challenge stations. Open Codex → Challenges at any time to inspect progress."
	)
	_show_message(
		"Progression Challenge Laboratory online. F1-F5 jump between stations; the entry consoles refill, reset, or complete the suite."
	)
	call_deferred("_update_challenge_displays")


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = 0.12
	_update_challenge_displays()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("editor") or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if TELEPORTS.has(key_event.physical_keycode):
		_teleport_player(TELEPORTS[key_event.physical_keycode] as Vector3)
		get_viewport().set_input_as_handled()
		return
	match key_event.physical_keycode:
		KEY_F8:
			reset_lab()
			get_viewport().set_input_as_handled()
		KEY_F9:
			reset_challenge_progress()
			get_viewport().set_input_as_handled()
		KEY_F10:
			complete_all_challenges()
			get_viewport().set_input_as_handled()


func refill_lab_supplies() -> Dictionary:
	for ingredient_id: String in INGREDIENT_IDS:
		GameState.set_inventory_count(
			ingredient_id,
			maxi(GameState.get_inventory_count(ingredient_id), 8)
		)
	for resource_id: String in ["health", "mana", "stamina", "focus", "stance"]:
		var maximum: int = GameState.get_stat("max_" + resource_id)
		if maximum > 0:
			GameState.set_stat(resource_id, maximum)
	_configure_lab_loadout()
	return {
		"message": "Mana, stamina, focus, health, and alchemy ingredients refilled.",
		"objective": "Choose a challenge station or open Codex → Challenges.",
	}


func reset_lab() -> Dictionary:
	reset_count += 1
	if reaction_wing != null and reaction_wing.has_method("reset_lab"):
		reaction_wing.call("reset_lab")
	else:
		for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
			if node != null and is_instance_valid(node):
				if node.has_method("reset_target"):
					node.call("reset_target")
				elif node.has_method("reset_surface"):
					node.call("reset_surface")
	refill_lab_supplies()
	GameState.set_objective(
		"Stations reset. Continue any unfinished progression challenge."
	)
	_update_challenge_displays()
	return {
		"message": "All stations reset and supplies refilled. Challenge progress was preserved.",
		"objective": "Continue any unfinished progression challenge.",
	}


func reset_challenge_progress() -> Dictionary:
	for raw_key: Variant in GameState.story_flags.keys():
		var key: String = str(raw_key)
		if key.begins_with("__progression__::"):
			GameState.story_flags.erase(raw_key)
	for recipe_id: String in RECIPE_IDS:
		GameState.set_flag("recipe_discovered_" + recipe_id, false)
	for reward_id: String in REWARD_IDS:
		GameState.revoke_unlock(reward_id)
	SpeciesKnowledge.reset_species("gremlin")
	var tracker: Node = _get_tracker()
	if tracker != null and tracker.has_method("synchronize_runtime_rewards"):
		tracker.call("synchronize_runtime_rewards")
	reset_lab()
	GameState.set_objective(
		"Challenge progress cleared. Begin with Trial by Flame or choose any station."
	)
	_update_challenge_displays()
	return {
		"message": "All five starter challenges, rewards, recipes, and Gremlin study progress were cleared.",
		"objective": "Begin with Trial by Flame or choose any station.",
	}


func complete_all_challenges() -> Dictionary:
	var tracker: Node = _get_tracker()
	if tracker == null or not tracker.has_method("record_event"):
		return {
			"message": "The progression tracker is unavailable.",
			"objective": "",
		}
	tracker.call("record_event", "reaction_triggered", "ignite_oil", {"amount": 1, "source": "challenge_lab"})
	for _index: int in range(3):
		tracker.call("record_event", "reaction_triggered", "wet_conduction", {"amount": 1, "source": "challenge_lab"})
	for _index: int in range(5):
		tracker.call("record_event", "reaction_triggered", "shatter", {"amount": 1, "source": "challenge_lab"})
	for recipe_id: String in ["healing_potion", "antidote", "conductive_elixir"]:
		GameState.set_flag("recipe_discovered_" + recipe_id, true)
	SpeciesKnowledge.add_discovery("gremlin", "challenge_lab_sighting", "Observed pack spacing", 3)
	SpeciesKnowledge.add_discovery("gremlin", "challenge_lab_pounce", "Mapped the pounce wind-up", 3)
	SpeciesKnowledge.add_discovery("gremlin", "challenge_lab_recovery", "Recorded post-pounce recovery", 3)
	if tracker.has_method("synchronize_runtime_rewards"):
		tracker.call("synchronize_runtime_rewards")
	_update_challenge_displays()
	return {
		"message": "All starter challenges completed. Every reward is ready for immediate testing.",
		"objective": "Test Charged Firebolt, Chain Lightning, Piercing Ice Lance, Recipe Insight, and Gremlin Pounce.",
	}


func get_debug_data() -> Dictionary:
	var tracker: Node = _get_tracker()
	var rows: Array = []
	if tracker != null and tracker.has_method("get_challenge_rows"):
		rows = tracker.call("get_challenge_rows") as Array
	return {
		"lab": "progression_challenge_v1",
		"challenge_count": rows.size(),
		"challenge_stations": challenge_status_labels.size(),
		"console_count": get_tree().get_nodes_in_group("progression_lab_console").size(),
		"study_terminal_count": get_tree().get_nodes_in_group("progression_lab_study").size(),
		"has_cauldron": get_node_or_null("KitchenChemistryStation/ChallengeCauldron") != null,
		"reset_count": reset_count,
		"public_cauldron_class": AlchemyCauldronScript != null,
	}


func _configure_reaction_wing() -> void:
	if reaction_wing == null:
		return
	reaction_wing.set("enable_editor_f8_reset", false)
	var title: Label3D = reaction_wing.get_node_or_null("LabTitle") as Label3D
	if title != null:
		title.text = "PROGRESSION CHALLENGE LABORATORY"
	var subtitle: Label3D = reaction_wing.get_node_or_null("LabSubtitle") as Label3D
	if subtitle != null:
		subtitle.text = "REACTIONS • ALCHEMY • CREATURE STUDY • LIVE REWARDS"
	var instruction: Label3D = reaction_wing.get_node_or_null("EntryInstruction") as Label3D
	if instruction != null:
		instruction.text = "F1-F5 STATIONS • F8 RESET • F9 CLEAR PROGRESS • F10 COMPLETE ALL"
	var old_console: Node = reaction_wing.get_node_or_null("LabResetConsole")
	if old_console != null:
		old_console.visible = false
		old_console.process_mode = Node.PROCESS_MODE_DISABLED
	for old_station_name: String in ["SteamStation", "SoundStation"]:
		var old_station: Node = reaction_wing.get_node_or_null(old_station_name)
		if old_station != null:
			old_station.free()
	var freeze_label: Label3D = reaction_wing.get_node_or_null("FreezeStation/Label") as Label3D
	if freeze_label != null:
		freeze_label.text = "FREEZE PREP\nWater → Ice\nThen strike at Shatterproof"
	_configure_lab_loadout()


func _configure_lab_loadout() -> void:
	var ability_caster: Node = get_node_or_null("ReactionWing/Player/AbilityCaster")
	if ability_caster == null:
		return
	ability_caster.set("loadout", LabLoadout)
	ability_caster.set("current_ability_index", 0)
	if ability_caster.has_method("align_focus_menu_to_current_ability"):
		ability_caster.call("align_focus_menu_to_current_ability")
	if ability_caster.has_method("emit_current_ability"):
		ability_caster.call("emit_current_ability")


func _build_kitchen_chemistry_station() -> void:
	var station := Node3D.new()
	station.name = "KitchenChemistryStation"
	station.position = Vector3(5.2, 0.0, 6.5)
	add_child(station)
	_add_station_platform(station, Color(0.42, 0.2, 0.58), Color(0.88, 0.55, 1.0))
	_add_station_title(
		station,
		"KITCHEN CHEMISTRY\nDiscover 3 potion formulas",
		Color(0.9, 0.62, 1.0)
	)
	var guide := Label3D.new()
	guide.name = "RecipeGuide"
	guide.position = Vector3(0.0, 2.9, 2.35)
	guide.text = (
		"1  Life Bloom + Springwater  •  FIRE\n"
		+ "2  Frost Salt + Springwater  •  WATER\n"
		+ "3  Spark Ore + Springwater  •  LIGHTNING"
	)
	guide.font_size = 24
	guide.pixel_size = 0.0065
	guide.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	guide.outline_size = 6
	guide.modulate = Color(0.92, 0.84, 1.0)
	station.add_child(guide)

	var cauldron := Area3D.new()
	cauldron.name = "ChallengeCauldron"
	cauldron.set_script(AlchemyCauldronScript)
	cauldron.position = Vector3.ZERO
	station.add_child(cauldron)

	var ingredient_configs: Array[Dictionary] = [
		{"id": "life_bloom", "name": "Life Bloom", "element": "life / body", "color": Color(0.35, 0.95, 0.45), "position": Vector3(-2.05, 0.0, 1.35)},
		{"id": "springwater", "name": "Springwater", "element": "water", "color": Color(0.25, 0.72, 1.0), "position": Vector3(0.0, 0.0, 1.9)},
		{"id": "frost_salt", "name": "Frost Salt", "element": "ice / poison", "color": Color(0.55, 0.93, 1.0), "position": Vector3(2.05, 0.0, 1.35)},
		{"id": "spark_ore", "name": "Spark Ore", "element": "metal / lightning", "color": Color(1.0, 0.78, 0.18), "position": Vector3(2.25, 0.0, -0.35)},
	]
	for config: Dictionary in ingredient_configs:
		var pickup := Area3D.new()
		pickup.name = "Ingredient_" + str(config.get("id", "ingredient"))
		pickup.set_script(IngredientScript)
		pickup.set("ingredient_id", str(config.get("id", "")))
		pickup.set("display_name", str(config.get("name", "Ingredient")))
		pickup.set("element", str(config.get("element", "neutral")))
		pickup.set("ingredient_color", config.get("color", Color.WHITE))
		pickup.set("amount", 8)
		pickup.set("prompt_text", "Gather " + str(config.get("name", "ingredient")))
		pickup.position = config.get("position", Vector3.ZERO) as Vector3
		station.add_child(pickup)

	var catalyst_configs: Array[Dictionary] = [
		{"element": "fire", "name": "Fire Treatment", "color": Color(1.0, 0.28, 0.08), "position": Vector3(-2.15, 0.0, -1.35)},
		{"element": "water", "name": "Water Treatment", "color": Color(0.18, 0.62, 1.0), "position": Vector3(0.0, 0.0, -1.85)},
		{"element": "lightning", "name": "Lightning Treatment", "color": Color(1.0, 0.82, 0.18), "position": Vector3(2.15, 0.0, -1.35)},
	]
	for config: Dictionary in catalyst_configs:
		var catalyst := Area3D.new()
		catalyst.name = "Catalyst_" + str(config.get("element", "element"))
		catalyst.set_script(CatalystScript)
		catalyst.set("element", str(config.get("element", "fire")))
		catalyst.set("display_name", str(config.get("name", "Treatment")))
		catalyst.set("station_color", config.get("color", Color.WHITE))
		catalyst.set("prompt_text", "Apply " + str(config.get("name", "treatment")))
		catalyst.position = config.get("position", Vector3.ZERO) as Vector3
		station.add_child(catalyst)


func _build_pack_scholar_station() -> void:
	var station := Node3D.new()
	station.name = "PackScholarStation"
	station.position = Vector3(0.0, 0.0, 14.0)
	add_child(station)
	_add_station_platform(station, Color(0.16, 0.26, 0.32), Color(0.42, 0.9, 1.0), Vector3(9.0, 0.16, 5.2))
	_add_station_title(
		station,
		"PACK SCHOLAR\nRecord all 3 Gremlin studies",
		Color(0.52, 0.92, 1.0)
	)
	var study_configs: Array[Dictionary] = [
		{"id": "challenge_lab_sighting", "label": "Pack Spacing", "position": Vector3(-3.0, 0.0, 0.3)},
		{"id": "challenge_lab_pounce", "label": "Pounce Wind-up", "position": Vector3(0.0, 0.0, 0.3)},
		{"id": "challenge_lab_recovery", "label": "Recovery Window", "position": Vector3(3.0, 0.0, 0.3)},
	]
	for config: Dictionary in study_configs:
		var terminal: Area3D = CreatureStudyTerminalScene.instantiate() as Area3D
		terminal.name = "Study_" + str(config.get("id", "gremlin"))
		terminal.set("species_id", "gremlin")
		terminal.set("discovery_id", str(config.get("id", "study")))
		terminal.set("discovery_label", str(config.get("label", "Gremlin Study")))
		terminal.set("knowledge_points", 3)
		terminal.set("prompt_text", "Record " + str(config.get("label", "Gremlin Study")))
		terminal.set("objective_after", "Record all three studies, then inspect Pack Scholar in the Codex.")
		terminal.position = config.get("position", Vector3.ZERO) as Vector3
		station.add_child(terminal)
		terminal.add_to_group("interactable_target")
		terminal.add_to_group("progression_lab_study")
	var gremlin: Node3D = GremlinTargetScene.instantiate() as Node3D
	gremlin.name = "StudyGremlin"
	gremlin.position = Vector3(0.0, 0.5, 2.0)
	station.add_child(gremlin)


func _build_entry_consoles() -> void:
	var configs: Array[Dictionary] = [
		{"action": "refill_supplies", "name": "REFILL SUPPLIES", "color": Color(0.3, 0.82, 1.0), "position": Vector3(-5.7, 0.0, -10.8)},
		{"action": "reset_stations", "name": "RESET STATIONS", "color": Color(0.72, 0.42, 1.0), "position": Vector3(-1.9, 0.0, -10.8)},
		{"action": "reset_progress", "name": "CLEAR PROGRESS", "color": Color(1.0, 0.36, 0.26), "position": Vector3(1.9, 0.0, -10.8)},
		{"action": "complete_all", "name": "COMPLETE ALL", "color": Color(1.0, 0.82, 0.24), "position": Vector3(5.7, 0.0, -10.8)},
	]
	for config: Dictionary in configs:
		var console := Area3D.new()
		console.name = str(config.get("name", "Console")).replace(" ", "")
		console.set_script(ConsoleScript)
		console.set("action_id", str(config.get("action", "refill_supplies")))
		console.set("display_name", str(config.get("name", "CONSOLE")))
		console.set("console_color", config.get("color", Color.WHITE))
		console.set("prompt_text", "Use " + str(config.get("name", "console")).to_lower())
		console.position = config.get("position", Vector3.ZERO) as Vector3
		add_child(console)
		console.add_to_group("progression_lab_console")


func _build_dashboard() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ProgressionChallengeHUD"
	layer.layer = 38
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var panel := PanelContainer.new()
	panel.name = "ChallengeDashboard"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -520.0
	panel.offset_right = -18.0
	panel.offset_top = 18.0
	panel.offset_bottom = 322.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_to_group("menu_suppressed_hud")
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.026, 0.045, 0.94)
	style.border_color = Color(0.44, 0.7, 1.0, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	dashboard_text = RichTextLabel.new()
	dashboard_text.name = "ChallengeDashboardText"
	dashboard_text.bbcode_enabled = true
	dashboard_text.fit_content = true
	dashboard_text.scroll_active = false
	dashboard_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dashboard_text.add_theme_font_size_override("normal_font_size", 15)
	margin.add_child(dashboard_text)


func _configure_existing_challenge_labels() -> void:
	var nodes: Dictionary = {
		"trial_by_flame": get_node_or_null("ReactionWing/IgniteStation"),
		"live_wire": get_node_or_null("ReactionWing/ConductStation"),
		"shatterproof": get_node_or_null("ReactionWing/ShatterStation"),
		"kitchen_chemistry": get_node_or_null("KitchenChemistryStation"),
		"pack_scholar": get_node_or_null("PackScholarStation"),
	}
	for challenge_id: String in CHALLENGE_ORDER:
		var station: Node3D = nodes.get(challenge_id) as Node3D
		if station == null:
			continue
		var label := Label3D.new()
		label.name = "ChallengeProgress"
		label.position = Vector3(0.0, 3.55, -1.3)
		label.font_size = 28
		label.pixel_size = 0.0065
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 6
		station.add_child(label)
		challenge_status_labels[challenge_id] = label


func _update_challenge_displays() -> void:
	var tracker: Node = _get_tracker()
	if tracker == null or not tracker.has_method("get_challenge_rows"):
		return
	var raw_rows: Array = tracker.call("get_challenge_rows") as Array
	var rows: Dictionary = {}
	for raw: Variant in raw_rows:
		if raw is Dictionary:
			var row: Dictionary = raw as Dictionary
			rows[str(row.get("challenge_id", ""))] = row
	for challenge_id: String in CHALLENGE_ORDER:
		var row: Dictionary = rows.get(challenge_id, {}) as Dictionary
		var label: Label3D = challenge_status_labels.get(challenge_id) as Label3D
		if label == null or row.is_empty():
			continue
		var complete: bool = bool(row.get("complete", false))
		label.text = (
			str(row.get("progress_current", 0))
			+ "/"
			+ str(row.get("progress_target", 1))
			+ "  •  "
			+ str(row.get("reward_runtime_state", "LOCKED"))
		)
		label.modulate = (
			Color(0.42, 1.0, 0.62)
			if complete
			else Color(1.0, 0.82, 0.34)
		)
	if dashboard_text == null:
		return
	var text: String = "[font_size=22][color=#9fd8ff][b]PROGRESSION CHALLENGE LAB[/b][/color][/font_size]\n"
	text += "[color=#71859b]F1-F5 stations  •  F8 reset  •  F9 clear  •  F10 complete[/color]\n\n"
	for challenge_id: String in CHALLENGE_ORDER:
		var row: Dictionary = rows.get(challenge_id, {}) as Dictionary
		if row.is_empty():
			continue
		var complete: bool = bool(row.get("complete", false))
		var color: String = "#72f39a" if complete else "#f0c65a"
		text += (
			"[color=" + color + "][b]"
			+ str(row.get("name", challenge_id.capitalize()))
			+ "[/b][/color]  "
			+ str(row.get("progress_current", 0))
			+ "/"
			+ str(row.get("progress_target", 1))
			+ "\n"
		)
		text += (
			"[color=#91a6bb]Reward: "
			+ str(row.get("reward", ""))
			+ "  •  Runtime: "
			+ str(row.get("reward_runtime_state", "LOCKED"))
			+ "[/color]\n"
		)
	dashboard_text.text = text


func _get_tracker() -> Node:
	return get_node_or_null("/root/FullMenuDirector/ProgressionTracker")


func _teleport_player(destination: Vector3) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.global_position = destination
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")
	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")


func _add_station_platform(
	parent: Node3D,
	base_color: Color,
	ring_color: Color,
	size: Vector3 = Vector3(5.1, 0.16, 5.1)
) -> void:
	var platform := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	platform.mesh = mesh
	platform.position.y = 0.02
	platform.material_override = _make_material(base_color, 0.18)
	parent.add_child(platform)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = min(size.x, size.z) * 0.42
	ring_mesh.outer_radius = min(size.x, size.z) * 0.44
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	ring.mesh = ring_mesh
	ring.position.y = 0.12
	ring.material_override = _make_material(ring_color, 1.5)
	parent.add_child(ring)


func _add_station_title(parent: Node3D, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.name = "StationTitle"
	label.text = text
	label.position = Vector3(0.0, 2.05, -2.2)
	label.font_size = 36
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = color
	parent.add_child(label)


func _make_material(color: Color, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color.darkened(0.18)
		material.emission_energy_multiplier = emission_energy
	return material


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
