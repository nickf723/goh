extends "res://scripts/expedition/expedition_route_generator.gd"

const RegionalStoreScript = preload("res://scripts/expedition/regional_expedition_store.gd")
const PlannerScript = preload("res://scripts/expedition/route_familiarity_planner.gd")
const FamiliaritySegmentScript = preload("res://scripts/expedition/familiarity_expedition_segment_3d.gd")
const WildsAnimalHabitatScript = preload(
	"res://scripts/expedition/wilds_animal_habitat_encounter.gd"
)

@export var regional_network_record_path: String = RegionalStoreScript.DEFAULT_RECORD_PATH
@export var regional_map_scene_path: String = "res://scenes/levels/prototypes/prototype_regional_expedition_map_v1.tscn"

var regional_launch_context: Dictionary = {}
var launched_from_regional_map: bool = false
var regional_arrival_pending: bool = false
var active_familiarity_plan: Dictionary = {}
var active_route_state: String = RegionalStoreScript.STATE_DISCOVERED
var active_route_seed: int = 18890417
var wildlife_habitats: Array[WildsAnimalHabitatEncounter] = []


func _ready() -> void:
	read_regional_launch_context()
	super._ready()
	if launched_from_regional_map:
		apply_regional_launch_origin()
		set_regional_route_objective()


func _unhandled_input(event: InputEvent) -> void:
	if not launched_from_regional_map:
		super._unhandled_input(event)
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_F8:
			apply_regional_launch_origin()
			get_viewport().set_input_as_handled()
		KEY_F9:
			assemble_full_expedition()
			apply_regional_launch_origin()
			show_message("The selected route was rebuilt from its saved regional seed.")
			get_viewport().set_input_as_handled()
		KEY_F10:
			show_message("Regional route seeds advance after a completed crossing.")
			get_viewport().set_input_as_handled()


func read_regional_launch_context() -> void:
	if not get_tree().root.has_meta("regional_expedition_launch"):
		return
	var context_value: Variant = get_tree().root.get_meta("regional_expedition_launch")
	if not context_value is Dictionary:
		return
	regional_launch_context = (context_value as Dictionary).duplicate(true)
	launched_from_regional_map = not regional_launch_context.is_empty()
	if not launched_from_regional_map:
		return
	record_path = str(regional_launch_context.get("expedition_record_path", record_path))
	regional_network_record_path = str(
		regional_launch_context.get("network_record_path", regional_network_record_path)
	)
	regional_map_scene_path = str(regional_launch_context.get("map_scene_path", regional_map_scene_path))
	active_route_state = str(
		regional_launch_context.get("route_state", RegionalStoreScript.STATE_DISCOVERED)
	)
	active_route_seed = int(regional_launch_context.get("route_seed", default_seed))


func assemble_full_expedition() -> void:
	if not launched_from_regional_map:
		super.assemble_full_expedition()
		_attach_wildlife_habitats()
		return
	assemble_regional_route_slice()


func assemble_regional_route_slice() -> void:
	assembly_count += 1
	clear_generated_route()
	prepare_active_familiarity_plan()

	generated_root = Node3D.new()
	generated_root.name = "GeneratedRegionalExpedition"
	add_child(generated_root)

	build_regional_west_endpoint()
	var next_socket_transform: Transform3D = Transform3D(Basis.IDENTITY, route_start_offset)
	for entry: Dictionary in route_plan:
		var source_index: int = int(entry.get("source_index", -1))
		if source_index < 0 or source_index >= main_segment_definitions.size():
			continue
		var definition: ExpeditionSegmentDefinition = main_segment_definitions[source_index]
		if definition == null:
			continue
		var segment_transform: Transform3D = next_socket_transform
		segment_transform.basis = segment_transform.basis.rotated(
			Vector3.UP,
			deg_to_rad(float(entry.get("turn_degrees", 0.0)))
		)
		var segment: FamiliarityExpeditionSegment3D = (
			FamiliaritySegmentScript.new() as FamiliarityExpeditionSegment3D
		)
		generated_root.add_child(segment)
		segment.global_transform = segment_transform
		var modifiers_value: Variant = entry.get("modifiers", {})
		var modifiers: Dictionary = (
			(modifiers_value as Dictionary).duplicate(true)
			if modifiers_value is Dictionary
			else {}
		)
		segment.configure_familiarity(
			definition,
			int(entry.get("seed", active_route_seed + source_index)),
			modifiers,
			false
		)
		main_segments.append(segment)
		next_socket_transform = segment.get_exit_global_transform()

		if should_build_main_cairn_branch(source_index):
			build_familiarity_optional_branch(segment, modifiers)

	build_regional_east_endpoint(next_socket_transform)
	_attach_wildlife_habitats()
	route_valid = validate_regional_route_chain()
	RecordStoreScript.save_record(route_record, record_path)
	refresh_status_hud()


func prepare_active_familiarity_plan() -> void:
	var plan_value: Variant = regional_launch_context.get("familiarity_plan", {})
	if plan_value is Dictionary and not (plan_value as Dictionary).is_empty():
		active_familiarity_plan = (plan_value as Dictionary).duplicate(true)
	else:
		var network_record: Dictionary = RegionalStoreScript.load_or_create(
			regional_network_record_path
		)
		var route_id_value: String = str(
			regional_launch_context.get("route_id", RegionalStoreScript.ROUTE_MAIN)
		)
		active_route_state = RegionalStoreScript.get_route_state(network_record, route_id_value)
		active_route_seed = RegionalStoreScript.get_route_seed(network_record, route_id_value)
		active_familiarity_plan = PlannerScript.build_plan(
			route_id_value,
			active_route_state,
			active_route_seed,
			str(regional_launch_context.get("origin_node_id", RegionalStoreScript.NODE_CYPRESS)),
			str(regional_launch_context.get("destination_node_id", RegionalStoreScript.NODE_BLUE_RIDGE))
		)

	active_route_state = str(
		active_familiarity_plan.get("state", RegionalStoreScript.STATE_DISCOVERED)
	)
	active_route_seed = int(active_familiarity_plan.get("seed", default_seed))
	route_plan.clear()
	var entries_value: Variant = active_familiarity_plan.get("entries", [])
	if entries_value is Array:
		for entry_value: Variant in entries_value as Array:
			if entry_value is Dictionary:
				route_plan.append((entry_value as Dictionary).duplicate(true))


func build_regional_west_endpoint() -> void:
	var route_id_value: String = get_selected_regional_route_id()
	if route_id_value == RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE:
		build_cairn_waystation(Transform3D.IDENTITY, true)
	else:
		build_start_camp()


func build_regional_east_endpoint(exit_transform: Transform3D) -> void:
	var route_id_value: String = get_selected_regional_route_id()
	if route_id_value == RegionalStoreScript.ROUTE_CYPRESS_CAIRN:
		build_cairn_waystation(exit_transform, false)
	else:
		build_destination_waystation(exit_transform)


func build_cairn_waystation(anchor_transform: Transform3D, is_west_endpoint: bool) -> void:
	var station_root: Node3D = Node3D.new()
	station_root.name = "OldSurveyCairnWaystation"
	generated_root.add_child(station_root)
	station_root.global_transform = anchor_transform
	var center: Vector3 = Vector3(0.0, 0.0, 2.0 if is_west_endpoint else 5.0)
	add_static_box(
		station_root,
		"CairnGround",
		Vector3(14.0, 0.55, 11.0),
		center + Vector3(0.0, -0.28, 0.0),
		Color(0.2, 0.25, 0.22, 1.0)
	)
	add_waystation_props(station_root, center, Color(0.48, 0.86, 1.0, 1.0))
	add_world_label(
		station_root,
		"OLD SURVEY CAIRN",
		center + Vector3(0.0, 3.3, 0.0),
		Color(0.58, 0.9, 1.0, 1.0)
	)
	landmark_marker = RouteMarkerScript.new() as ExpeditionRouteMarker
	landmark_marker.configure(
		"landmark",
		RegionalStoreScript.NODE_CAIRN,
		"Old Survey Cairn",
		Color(0.58, 0.9, 1.0, 1.0)
	)
	station_root.add_child(landmark_marker)
	landmark_marker.position = center + Vector3(-3.4 if is_west_endpoint else 0.0, 0.0, 0.0)


func should_build_main_cairn_branch(source_index: int) -> bool:
	return (
		get_selected_regional_route_id() == RegionalStoreScript.ROUTE_MAIN
		and source_index == branch_after_index
		and branch_segment_definition != null
	)


func build_familiarity_optional_branch(
	source_segment: ExpeditionSegment3D,
	modifiers: Dictionary
) -> void:
	if source_segment == null or branch_segment_definition == null:
		return
	var branch_transform: Transform3D = source_segment.get_branch_global_transform()
	if branch_transform == Transform3D.IDENTITY:
		return
	var branch: FamiliarityExpeditionSegment3D = (
		FamiliaritySegmentScript.new() as FamiliarityExpeditionSegment3D
	)
	branch_segment = branch
	generated_root.add_child(branch)
	branch.global_transform = branch_transform
	branch.configure_familiarity(
		branch_segment_definition,
		active_route_seed ^ 0x51A7,
		modifiers,
		true
	)
	var marker_transform: Transform3D = branch.get_exit_global_transform()
	landmark_marker = RouteMarkerScript.new() as ExpeditionRouteMarker
	landmark_marker.configure(
		"landmark",
		RegionalStoreScript.NODE_CAIRN,
		"Old Survey Cairn",
		Color(0.58, 0.9, 1.0, 1.0)
	)
	generated_root.add_child(landmark_marker)
	landmark_marker.global_transform = marker_transform.translated_local(Vector3(0.0, 0.0, -1.6))


func validate_regional_route_chain() -> bool:
	if main_segments.size() != route_plan.size() or main_segments.is_empty():
		return false
	for index: int in range(main_segments.size() - 1):
		var current_exit: Vector3 = main_segments[index].get_exit_global_transform().origin
		var next_entry: Vector3 = main_segments[index + 1].global_transform.origin
		if current_exit.distance_to(next_entry) > 0.05:
			return false
	match get_selected_regional_route_id():
		RegionalStoreScript.ROUTE_CYPRESS_CAIRN:
			return start_marker != null and landmark_marker != null
		RegionalStoreScript.ROUTE_CAIRN_BLUE_RIDGE:
			return landmark_marker != null and destination_marker != null
		_:
			return start_marker != null and destination_marker != null


func _attach_wildlife_habitats() -> void:
	wildlife_habitats.clear()
	for segment: ExpeditionSegment3D in main_segments:
		if (
			segment == null
			or not is_instance_valid(segment)
			or segment.definition == null
		):
			continue
		var habitat_id_value: String = segment.definition.segment_id
		if not (
			habitat_id_value in [
				"cypress_basin",
				"wet_woodland",
				"pine_ridge",
			]
		):
			continue
		var habitat := (
			WildsAnimalHabitatScript.new()
			as WildsAnimalHabitatEncounter
		)
		if (
			habitat_id_value == "wet_woodland"
			and (
				not segment.has_method("uses_authored_layout")
				or not bool(segment.call("uses_authored_layout"))
			)
		):
			habitat.position.y = segment.elevation_at(15.5)
		segment.add_child(habitat)
		habitat.configure(habitat_id_value)
		wildlife_habitats.append(habitat)


func get_wildlife_habitats() -> Array[WildsAnimalHabitatEncounter]:
	var result: Array[WildsAnimalHabitatEncounter] = []
	result.assign(wildlife_habitats)
	return result


func get_wildlife_animal_count() -> int:
	var result: int = 0
	for habitat: WildsAnimalHabitatEncounter in wildlife_habitats:
		if habitat != null and is_instance_valid(habitat):
			result += habitat.animals.size()
	return result


func clear_generated_route() -> void:
	wildlife_habitats.clear()
	clear_player_generated_references()
	super.clear_generated_route()


func clear_player_generated_references() -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")
	else:
		player.set("lock_on_target", null)

	player.set("current_interactable", null)

	var nearby_value: Variant = player.get("nearby_interactables")
	if nearby_value is Array:
		var nearby: Array = nearby_value as Array
		nearby.clear()
		player.set("nearby_interactables", nearby)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("hide_prompt"):
		ui.call("hide_prompt")


func apply_regional_launch_origin() -> void:
	if player == null or not is_instance_valid(player):
		return
	var origin_node_id: String = str(
		regional_launch_context.get("origin_node_id", RegionalStoreScript.NODE_CYPRESS)
	)
	match origin_node_id:
		RegionalStoreScript.NODE_BLUE_RIDGE:
			place_player_near_marker(destination_marker, Vector3(0.0, 1.0, 3.1))
		RegionalStoreScript.NODE_CAIRN:
			place_player_near_marker(landmark_marker, Vector3(2.6, 1.0, 0.0))
		_:
			reset_player_to_route_start()


func place_player_near_marker(marker: Node3D, local_offset: Vector3) -> void:
	if marker == null or not is_instance_valid(marker) or player == null:
		return
	player.global_transform = marker.global_transform.translated_local(local_offset)
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")
	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")


func set_regional_route_objective() -> void:
	var destination_node_id: String = str(regional_launch_context.get("destination_node_id", ""))
	var objective: String = "Reach " + get_regional_node_display_name(destination_node_id) + "."
	GameState.set_objective(objective)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", objective)
	show_message(
		"Regional route assembled: "
		+ get_regional_node_display_name(str(regional_launch_context.get("origin_node_id", "")))
		+ " → "
		+ get_regional_node_display_name(destination_node_id)
		+ "  •  "
		+ active_route_state.capitalize()
		+ "  •  "
		+ str(main_segments.size())
		+ " segments"
	)


func refresh_status_hud() -> void:
	if not launched_from_regional_map:
		super.refresh_status_hud()
		return
	if status_label == null:
		return
	status_label.text = (
		"WILDS  •  "
		+ get_selected_regional_route_id().replace("_", " ").to_upper()
		+ "  •  "
		+ active_route_state.to_upper()
		+ "  •  SEED "
		+ str(active_route_seed)
		+ "  •  "
		+ str(main_segments.size())
		+ " SEGMENTS"
		+ "\nF8 Return to origin  •  F9 Rebuild route  •  Route seed advances on arrival"
	)


func activate_route_marker(marker_type: String, marker_id: String) -> Dictionary:
	if not launched_from_regional_map:
		return super.activate_route_marker(marker_type, marker_id)

	var marker_node_id: String = get_regional_node_for_marker(marker_type, marker_id)
	var destination_node_id: String = str(regional_launch_context.get("destination_node_id", ""))
	var selected_route_id: String = get_selected_regional_route_id()

	if marker_type == "landmark":
		var landmark_result: Dictionary = super.activate_route_marker(marker_type, marker_id)
		sync_regional_network_from_expedition()
		if marker_node_id == destination_node_id:
			return complete_regional_arrival(selected_route_id, destination_node_id, landmark_result)
		return landmark_result

	if marker_node_id != destination_node_id:
		return {
			"message": get_regional_node_display_name(marker_node_id) + " is not the selected destination.",
			"objective": "Reach " + get_regional_node_display_name(destination_node_id) + ".",
		}

	var base_result: Dictionary = {}
	if selected_route_id == RegionalStoreScript.ROUTE_MAIN:
		base_result = super.activate_route_marker(marker_type, marker_id)
	return complete_regional_arrival(selected_route_id, destination_node_id, base_result)


func complete_regional_arrival(
	selected_route_id: String,
	destination_node_id: String,
	base_result: Dictionary = {}
) -> Dictionary:
	if regional_arrival_pending:
		return base_result
	regional_arrival_pending = true

	var network_record: Dictionary = RegionalStoreScript.load_or_create(regional_network_record_path)
	network_record = RegionalStoreScript.sync_from_expedition_record(network_record, route_record)
	network_record = RegionalStoreScript.complete_route(
		network_record,
		selected_route_id,
		destination_node_id,
		str(active_familiarity_plan.get("signature", ""))
	)
	RegionalStoreScript.save_record(network_record, regional_network_record_path)

	var result: Dictionary = base_result.duplicate(true)
	result["message"] = (
		"Arrived at "
		+ get_regional_node_display_name(destination_node_id)
		+ ". Route familiarity and the next expedition seed have been updated."
	)
	result["objective"] = "Choose the next expedition route."

	if not bool(regional_launch_context.get("suppress_scene_transition", false)):
		get_tree().root.remove_meta("regional_expedition_launch")
		call_deferred("return_to_regional_map")
	return result


func sync_regional_network_from_expedition() -> void:
	var network_record: Dictionary = RegionalStoreScript.load_or_create(regional_network_record_path)
	network_record = RegionalStoreScript.sync_from_expedition_record(network_record, route_record)
	RegionalStoreScript.save_record(network_record, regional_network_record_path)


func return_to_regional_map() -> void:
	get_tree().change_scene_to_file(regional_map_scene_path)


func get_selected_regional_route_id() -> String:
	return str(regional_launch_context.get("route_id", RegionalStoreScript.ROUTE_MAIN))


func get_regional_node_for_marker(marker_type: String, marker_id: String) -> String:
	match marker_type:
		"start":
			return RegionalStoreScript.NODE_CYPRESS
		"destination":
			return RegionalStoreScript.NODE_BLUE_RIDGE
		"landmark":
			if marker_id == RegionalStoreScript.NODE_CAIRN:
				return RegionalStoreScript.NODE_CAIRN
	return ""


func get_regional_node_display_name(node_id: String) -> String:
	match node_id:
		RegionalStoreScript.NODE_CYPRESS:
			return "Cypress Field Camp"
		RegionalStoreScript.NODE_BLUE_RIDGE:
			return "Blue Ridge Waystation"
		RegionalStoreScript.NODE_CAIRN:
			return "Old Survey Cairn"
	return "Unknown Location"


func get_debug_data() -> Dictionary:
	if not launched_from_regional_map:
		var base_data: Dictionary = super.get_debug_data()
		base_data["wildlife_habitats"] = wildlife_habitats.size()
		base_data["wildlife_animals"] = get_wildlife_animal_count()
		return base_data
	return {
		"route": get_selected_regional_route_id(),
		"state": active_route_state,
		"seed": active_route_seed,
		"segments": main_segments.size(),
		"valid": route_valid,
		"signature": str(active_familiarity_plan.get("signature", "")),
		"origin": str(regional_launch_context.get("origin_node_id", "")),
		"destination": str(regional_launch_context.get("destination_node_id", "")),
		"wildlife_habitats": wildlife_habitats.size(),
		"wildlife_animals": get_wildlife_animal_count(),
	}
