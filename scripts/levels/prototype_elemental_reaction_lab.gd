extends Node3D
class_name PrototypeElementalReactionLab

const ComboRuleRegistryScript = preload("res://scripts/systems/combo_rule_registry.gd")
const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const LabLoadout: Resource = preload("res://data/loadouts/grace_reaction_lab_loadout.tres")
const GoblinReactionTargetScene: PackedScene = preload("res://scenes/actors/testing/goblin_reaction_target.tscn")
const GremlinReactionTargetScene: PackedScene = preload("res://scenes/actors/testing/gremlin_reaction_target.tscn")

@export var opening_objective: String = "At the STEAM BURST station: cast Water, then Ice, then Fire. Watch the burst catch nearby targets."
@export var opening_message: String = "Elemental Reaction Laboratory online. The Steam arena now reports surface state, reaction history, and radial targets."
@export var refill_resources_on_ready: bool = true
@export var enable_editor_f8_reset: bool = true
@export var readout_refresh_interval: float = 0.12

var reset_count: int = 0
var station_readouts: Array[Dictionary] = []
var readout_refresh_timer: float = 0.0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("debuggable")
	configure_surface_catalysts()
	configure_lab_loadout()
	configure_steam_arena()
	configure_station_readouts()

	if refill_resources_on_ready:
		refill_player_resources()

	set_objective(opening_objective)
	show_message(get_opening_message())


func _process(delta: float) -> void:
	readout_refresh_timer -= delta
	if readout_refresh_timer > 0.0:
		return

	readout_refresh_timer = max(readout_refresh_interval, 0.05)
	update_station_readouts()


func configure_surface_catalysts() -> void:
	var catalysts: Array[Node] = find_children("ProjectileReceiver", "Area3D", true, false)

	for catalyst_node: Node in catalysts:
		if not (catalyst_node is Area3D):
			continue

		var catalyst := catalyst_node as Area3D
		catalyst.position = Vector3(1.55, 0.74, 0.75)

		var collision: CollisionShape3D = catalyst.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null and collision.shape is BoxShape3D:
			var box: BoxShape3D = collision.shape.duplicate() as BoxShape3D
			box.size = Vector3(0.72, 1.5, 0.72)
			collision.shape = box

		if catalyst.get_node_or_null("CatalystVisual") != null:
			continue

		var visual_root := Node3D.new()
		visual_root.name = "CatalystVisual"
		catalyst.add_child(visual_root)

		var surface: Node = catalyst.get_parent()
		var profile: String = "neutral"
		if surface != null:
			profile = str(surface.get("visual_profile"))
			if profile == "none":
				profile = str(surface.get("status_effect"))

		var color: Color = ElementVisuals.get_element_color(profile)
		ElementVisuals.add_box(
			visual_root,
			"CatalystPillar",
			Vector3(0.34, 1.18, 0.34),
			color,
			Vector3.ZERO,
			Vector3(0.0, 45.0, 0.0),
			1.4,
			0.82
		)
		ElementVisuals.add_torus(
			visual_root,
			"CatalystRing",
			0.22,
			0.29,
			color.lightened(0.18),
			Vector3(0.0, 0.18, 0.0),
			Vector3.ZERO,
			2.0,
			0.78
		)

		var label := Label3D.new()
		label.name = "CatalystLabel"
		label.position = Vector3(0.0, 0.94, 0.0)
		label.text = "SURFACE"
		label.font_size = 28
		label.pixel_size = 0.007
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = color.lightened(0.25)
		label.outline_size = 5
		visual_root.add_child(label)


func configure_steam_arena() -> void:
	var station: Node3D = get_node_or_null("SteamStation") as Node3D
	if station == null:
		return

	var primary_target: Node3D = station.get_node_or_null("GoblinTarget") as Node3D
	if primary_target != null:
		primary_target.position = Vector3(-1.55, 0.58, 0.35)
		primary_target.name = "SteamGoblinLeft"

	if station.get_node_or_null("SteamGremlinRight") == null:
		var gremlin: Node3D = GremlinReactionTargetScene.instantiate() as Node3D
		gremlin.name = "SteamGremlinRight"
		gremlin.position = Vector3(1.55, 0.5, 0.35)
		station.add_child(gremlin)

	if station.get_node_or_null("SteamGoblinRear") == null:
		var goblin: Node3D = GoblinReactionTargetScene.instantiate() as Node3D
		goblin.name = "SteamGoblinRear"
		goblin.position = Vector3(0.0, 0.58, 2.25)
		station.add_child(goblin)

	if station.get_node_or_null("BurstRadiusGuide") == null:
		var guide := Node3D.new()
		guide.name = "BurstRadiusGuide"
		station.add_child(guide)
		ElementVisuals.add_torus(
			guide,
			"SteamBurstRadius",
			2.58,
			2.66,
			ElementVisuals.get_element_color("steam"),
			Vector3(0.0, 0.16, 0.0),
			Vector3.ZERO,
			1.2,
			0.34
		)

		var radius_label := Label3D.new()
		radius_label.name = "RadiusLabel"
		radius_label.position = Vector3(0.0, 0.42, 2.72)
		radius_label.text = "STEAM BURST • 2.65m"
		radius_label.font_size = 26
		radius_label.pixel_size = 0.007
		radius_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		radius_label.modulate = ElementVisuals.get_element_color("steam")
		radius_label.outline_size = 5
		guide.add_child(radius_label)


func configure_station_readouts() -> void:
	station_readouts.clear()

	for station_name: String in [
		"IgniteStation",
		"ConductStation",
		"FreezeStation",
		"ShatterStation",
		"SteamStation",
	]:
		var station: Node3D = get_node_or_null(station_name) as Node3D
		if station == null:
			continue

		var surface: Node = find_reactive_surface(station)
		if surface == null:
			continue

		var label: Label3D = station.get_node_or_null("StateReadout") as Label3D
		if label == null:
			label = Label3D.new()
			label.name = "StateReadout"
			label.position = Vector3(0.0, 1.12, 2.05)
			label.font_size = 27 if station_name != "SteamStation" else 32
			label.pixel_size = 0.007
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.outline_size = 5
			station.add_child(label)

		station_readouts.append({
			"station": station_name,
			"surface": surface,
			"label": label,
		})

	update_station_readouts()


func find_reactive_surface(root: Node) -> Node:
	if root == null:
		return null

	if root.has_method("get_hazard_tags") and root.has_method("reset_surface"):
		return root

	for child: Node in root.get_children():
		var found: Node = find_reactive_surface(child)
		if found != null:
			return found

	return null


func update_station_readouts() -> void:
	for entry: Dictionary in station_readouts:
		var surface: Node = entry.get("surface") as Node
		var label: Label3D = entry.get("label") as Label3D
		if surface == null or label == null or not is_instance_valid(surface):
			continue
		if not surface.has_method("get_debug_data"):
			continue

		var data: Dictionary = surface.get_debug_data()
		var state: String = str(data.get("reaction_state", "normal"))
		var last_reaction: String = str(data.get("last_reaction", "none"))
		var area_count: int = int(data.get("area_target_count", 0))
		var target_names: Array[String] = []
		var raw_area_targets: Variant = data.get("area_targets", [])
		if raw_area_targets is Array:
			for raw_target: Variant in raw_area_targets as Array:
				var target_name: String = str(raw_target)
				if target_name != "":
					target_names.append(target_name)

		var target_text: String = "none" if target_names.is_empty() else ", ".join(target_names)
		label.text = (
			"STATE: "
			+ state.to_upper()
			+ "\nLAST: "
			+ last_reaction.to_upper()
			+ "\nBURST: "
			+ str(area_count)
			+ " | "
			+ target_text
		)
		label.modulate = get_state_color(state)


func get_state_color(state: String) -> Color:
	match state:
		"burning":
			return ElementVisuals.get_element_color("fire")
		"electrified":
			return ElementVisuals.get_element_color("lightning")
		"frozen", "shattered":
			return ElementVisuals.get_element_color("ice")
		"steaming":
			return ElementVisuals.get_element_color("steam")
		_:
			return ElementVisuals.get_element_color("neutral")


func _unhandled_input(event: InputEvent) -> void:
	if not enable_editor_f8_reset or not OS.has_feature("editor"):
		return
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != KEY_F8:
		return

	get_viewport().set_input_as_handled()
	reset_lab()


func get_opening_message() -> String:
	if enable_editor_f8_reset and OS.has_feature("editor"):
		return opening_message + " Press F8 or use the violet console to reset every station."

	return opening_message


func configure_lab_loadout() -> void:
	var ability_caster: Node = get_node_or_null("Player/AbilityCaster")

	if ability_caster == null:
		return

	ability_caster.set("loadout", LabLoadout)
	ability_caster.set("current_ability_index", 0)

	if ability_caster.has_method("align_focus_menu_to_current_ability"):
		ability_caster.align_focus_menu_to_current_ability()

	if ability_caster.has_method("emit_current_ability"):
		ability_caster.emit_current_ability()


func refill_player_resources() -> void:
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("focus", GameState.get_stat("max_focus"))


func reset_lab() -> void:
	reset_count += 1

	for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if node == null or not is_instance_valid(node):
			continue

		if node.has_method("reset_target"):
			node.reset_target()
		elif node.has_method("reset_surface"):
			node.reset_surface()
		elif node.has_method("reset_reveal"):
			node.reset_reveal()

	for receiver: Node in get_tree().get_nodes_in_group("detectable"):
		if receiver != null and receiver.has_method("reset_reveal"):
			receiver.reset_reveal()

	var player: Node = get_node_or_null("Player")
	if player != null:
		var player_status_receiver: Node = player.get_node_or_null("StatusReceiver")
		if player_status_receiver != null and player_status_receiver.has_method("clear_all_statuses"):
			player_status_receiver.clear_all_statuses()

	refill_player_resources()
	configure_lab_loadout()
	update_station_readouts()
	set_objective(opening_objective)
	show_message("Laboratory reset #" + str(reset_count) + ". Every surface, target, and burst readout is back at baseline.")


func get_station_summary() -> Array[String]:
	var rows: Array[String] = []

	for node: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if node == null or not is_instance_valid(node):
			continue

		if node.has_method("get_debug_data"):
			var data: Dictionary = node.get_debug_data()
			if data.has("surface"):
				rows.append(
					str(data["surface"])
					+ ":"
					+ str(data.get("reaction_state", "normal"))
					+ " burst="
					+ str(data.get("area_target_count", 0))
				)
			elif data.has("lab_target"):
				rows.append(str(data["lab_target"]) + ":" + str(data.get("reaction", "none")))

	return rows


func get_debug_data() -> Dictionary:
	var matrix: Array[Dictionary] = ComboRuleRegistryScript.get_debug_matrix_rows()
	return {
		"lab": "elemental_reaction_v1",
		"rules": matrix.size(),
		"resets": reset_count,
		"stations": get_station_summary(),
	}


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func set_objective(text: String) -> void:
	GameState.set_objective(text)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("set_objective"):
		ui.set_objective(text)
