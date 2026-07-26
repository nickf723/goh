extends Node3D
class_name ExpeditionRouteGenerator

const SegmentScript = preload("res://scripts/expedition/expedition_segment_3d.gd")
const RecordStoreScript = preload("res://scripts/expedition/expedition_record_store.gd")
const RouteMarkerScript = preload("res://scripts/expedition/expedition_route_marker.gd")

@export var route_id: String = "cypress_blue_ridge"
@export var route_display_name: String = "Cypress Field Camp → Blue Ridge Waystation"
@export var default_seed: int = 18890417
@export var record_path: String = "user://expedition_cypress_blue_ridge.json"
@export var main_segment_definitions: Array[ExpeditionSegmentDefinition] = []
@export var branch_segment_definition: ExpeditionSegmentDefinition
@export_range(0, 12, 1) var branch_after_index: int = 1
@export var route_start_offset: Vector3 = Vector3(0.0, 0.0, 8.0)
@export var turn_choices_degrees: Array[float] = [-12.0, -6.0, 0.0, 6.0, 12.0]

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D

var route_record: Dictionary = {}
var route_plan: Array[Dictionary] = []
var generated_root: Node3D
var main_segments: Array[ExpeditionSegment3D] = []
var branch_segment: ExpeditionSegment3D
var start_marker: ExpeditionRouteMarker
var destination_marker: ExpeditionRouteMarker
var landmark_marker: ExpeditionRouteMarker
var status_label: Label
var return_mode: bool = false
var route_valid: bool = false
var assembly_count: int = 0
var initial_player_transform: Transform3D


func _ready() -> void:
	add_to_group("expedition_route_director")
	add_to_group("debuggable")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player != null:
		initial_player_transform = player.global_transform
	build_status_hud()
	load_route_record()
	assemble_full_expedition()
	set_route_objective()
	show_message(
		"Expedition assembled before entry. Follow the biome gradient from Cypress Field Camp to Blue Ridge Waystation."
	)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_F8:
			reset_player_to_route_start()
			get_viewport().set_input_as_handled()
		KEY_F9:
			assemble_full_expedition()
			reset_player_to_route_start()
			show_message("Saved expedition rebuilt from seed " + str(route_record.get("seed", default_seed)) + ".")
			get_viewport().set_input_as_handled()
		KEY_F10:
			generate_new_route_seed()
			assemble_full_expedition()
			reset_player_to_route_start()
			show_message("A new wilderness layout has been assembled. Persistent discoveries remain recorded.")
			get_viewport().set_input_as_handled()


func load_route_record() -> void:
	route_record = RecordStoreScript.load_or_create(route_id, default_seed, record_path)
	return_mode = bool(route_record.get("completed_forward", false)) and not bool(route_record.get("completed_round_trip", false))


func assemble_full_expedition() -> void:
	assembly_count += 1
	clear_generated_route()
	resolve_route_plan()

	generated_root = Node3D.new()
	generated_root.name = "GeneratedExpedition"
	add_child(generated_root)

	build_start_camp()
	var next_socket_transform: Transform3D = Transform3D(Basis.IDENTITY, route_start_offset)
	for index: int in range(main_segment_definitions.size()):
		var definition: ExpeditionSegmentDefinition = main_segment_definitions[index]
		if definition == null:
			continue
		var plan_entry: Dictionary = route_plan[index] if index < route_plan.size() else {}
		var segment_transform: Transform3D = next_socket_transform
		var turn_degrees: float = float(plan_entry.get("turn_degrees", 0.0))
		segment_transform.basis = segment_transform.basis.rotated(Vector3.UP, deg_to_rad(turn_degrees))

		var segment: ExpeditionSegment3D = SegmentScript.new() as ExpeditionSegment3D
		generated_root.add_child(segment)
		segment.global_transform = segment_transform
		segment.configure(definition, int(plan_entry.get("seed", default_seed + index)), false)
		main_segments.append(segment)
		next_socket_transform = segment.get_exit_global_transform()

		if index == branch_after_index:
			build_optional_branch(segment)

	build_destination_waystation(next_socket_transform)
	route_valid = validate_route_chain()
	RecordStoreScript.save_record(route_record, record_path)
	refresh_status_hud()
	if player != null and assembly_count == 1:
		reset_player_to_route_start()


func resolve_route_plan() -> void:
	var stored_plan_value: Variant = route_record.get("segment_plan", [])
	if stored_plan_value is Array:
		var stored_plan: Array = stored_plan_value as Array
		if is_plan_compatible(stored_plan):
			route_plan.clear()
			for entry_value: Variant in stored_plan:
				if entry_value is Dictionary:
					route_plan.append((entry_value as Dictionary).duplicate(true))
			return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(route_record.get("seed", default_seed))
	route_plan.clear()
	for index: int in range(main_segment_definitions.size()):
		var definition: ExpeditionSegmentDefinition = main_segment_definitions[index]
		var turn_degrees: float = 0.0
		if index > 0 and index < main_segment_definitions.size() - 1 and not turn_choices_degrees.is_empty():
			turn_degrees = turn_choices_degrees[rng.randi_range(0, turn_choices_degrees.size() - 1)]
		route_plan.append({
			"segment_id": definition.segment_id if definition != null else "missing",
			"seed": int(rng.randi()),
			"turn_degrees": turn_degrees,
		})
	route_record["segment_plan"] = route_plan.duplicate(true)
	RecordStoreScript.save_record(route_record, record_path)


func is_plan_compatible(stored_plan: Array) -> bool:
	if stored_plan.size() != main_segment_definitions.size():
		return false
	for index: int in range(main_segment_definitions.size()):
		if not stored_plan[index] is Dictionary:
			return false
		var definition: ExpeditionSegmentDefinition = main_segment_definitions[index]
		if definition == null:
			return false
		if str((stored_plan[index] as Dictionary).get("segment_id", "")) != definition.segment_id:
			return false
	return true


func build_optional_branch(source_segment: ExpeditionSegment3D) -> void:
	if source_segment == null or branch_segment_definition == null:
		return
	var branch_transform: Transform3D = source_segment.get_branch_global_transform()
	if branch_transform == Transform3D.IDENTITY:
		return
	branch_segment = SegmentScript.new() as ExpeditionSegment3D
	generated_root.add_child(branch_segment)
	branch_segment.global_transform = branch_transform
	var branch_seed: int = int(route_record.get("seed", default_seed)) ^ 0x51A7
	branch_segment.configure(branch_segment_definition, branch_seed, true)

	var marker_transform: Transform3D = branch_segment.get_exit_global_transform()
	landmark_marker = RouteMarkerScript.new() as ExpeditionRouteMarker
	landmark_marker.configure(
		"landmark",
		branch_segment_definition.landmark_id,
		"Old Survey Cairn",
		Color(0.58, 0.9, 1.0, 1.0)
	)
	generated_root.add_child(landmark_marker)
	landmark_marker.global_transform = marker_transform.translated_local(Vector3(0.0, 0.0, -1.6))


func build_start_camp() -> void:
	var camp_root: Node3D = Node3D.new()
	camp_root.name = "CypressFieldCamp"
	generated_root.add_child(camp_root)
	add_static_box(
		camp_root,
		"CampGround",
		Vector3(15.0, 0.55, 12.0),
		Vector3(0.0, -0.28, 2.0),
		Color(0.19, 0.25, 0.16, 1.0)
	)
	add_waystation_props(camp_root, Vector3(0.0, 0.0, 1.5), Color(0.45, 0.78, 0.46, 1.0))
	add_world_label(camp_root, "CYPRESS FIELD CAMP", Vector3(0.0, 3.2, 1.0), Color(0.65, 1.0, 0.68, 1.0))

	start_marker = RouteMarkerScript.new() as ExpeditionRouteMarker
	start_marker.configure("start", "cypress_field_camp", "Cypress Field Camp", Color(0.65, 1.0, 0.68, 1.0))
	camp_root.add_child(start_marker)
	start_marker.position = Vector3(-3.6, 0.0, 2.0)


func build_destination_waystation(exit_transform: Transform3D) -> void:
	var station_root: Node3D = Node3D.new()
	station_root.name = "BlueRidgeWaystation"
	generated_root.add_child(station_root)
	station_root.global_transform = exit_transform

	add_static_box(
		station_root,
		"WaystationGround",
		Vector3(16.0, 0.6, 13.0),
		Vector3(0.0, -0.3, 5.2),
		Color(0.23, 0.24, 0.2, 1.0)
	)
	add_waystation_props(station_root, Vector3(0.0, 0.0, 4.8), Color(0.52, 0.72, 1.0, 1.0))
	add_world_label(station_root, "BLUE RIDGE WAYSTATION", Vector3(0.0, 3.3, 5.1), Color(0.64, 0.82, 1.0, 1.0))

	destination_marker = RouteMarkerScript.new() as ExpeditionRouteMarker
	destination_marker.configure("destination", "blue_ridge_waystation", "Blue Ridge Waystation", Color(0.64, 0.82, 1.0, 1.0))
	station_root.add_child(destination_marker)
	destination_marker.position = Vector3(0.0, 0.0, 5.0)


func add_waystation_props(parent: Node3D, center: Vector3, accent: Color) -> void:
	add_visual_box(parent, "ShelterRoof", Vector3(5.2, 0.22, 3.2), center + Vector3(0.0, 2.25, 0.0), Vector3(0.0, 0.0, -0.14), Color(0.28, 0.17, 0.09, 1.0))
	for side_sign: float in [-1.0, 1.0]:
		add_static_box(parent, "ShelterPost", Vector3(0.3, 2.4, 0.3), center + Vector3(side_sign * 2.1, 1.2, 1.15), Color(0.31, 0.2, 0.11, 1.0))
	add_visual_sphere(parent, center + Vector3(0.0, 0.48, -0.6), 0.42, Color(1.0, 0.34, 0.08, 1.0), true)
	add_visual_sphere(parent, center + Vector3(0.0, 2.75, 0.0), 0.22, accent, true)


func activate_route_marker(marker_type: String, marker_id: String) -> Dictionary:
	match marker_type:
		"landmark":
			var discoveries: Dictionary = route_record.get("discoveries", {}) as Dictionary
			discoveries[marker_id] = true
			route_record["discoveries"] = discoveries
			route_record["shortcut_unlocked"] = true
			RecordStoreScript.save_record(route_record, record_path)
			refresh_status_hud()
			return {
				"message": "Grace records the Old Survey Cairn. Future crossings remember this branch and its stabilized shortcut.",
				"objective": "Reach Blue Ridge Waystation.",
			}
		"destination":
			route_record["completed_forward"] = true
			return_mode = true
			RecordStoreScript.save_record(route_record, record_path)
			refresh_status_hud()
			return {
				"message": "Blue Ridge Waystation reached. The assembled wilds remain in place for the return crossing.",
				"objective": "Return to Cypress Field Camp.",
			}
		"start":
			if return_mode:
				route_record["completed_round_trip"] = true
				return_mode = false
				RecordStoreScript.save_record(route_record, record_path)
				refresh_status_hud()
				return {
					"message": "Round trip complete. The route seed and recorded discoveries persist for later expeditions.",
					"objective": "Expedition prototype complete. Rebuild with F9 or generate a new route with F10.",
				}
			return {
				"message": "Cypress Field Camp is ready. The entire wilderness has already been assembled.",
				"objective": "Travel through the wilds to Blue Ridge Waystation.",
			}
	return {}


func is_marker_recorded(marker_type: String, marker_id: String) -> bool:
	match marker_type:
		"landmark":
			var discoveries_value: Variant = route_record.get("discoveries", {})
			if discoveries_value is Dictionary:
				return bool((discoveries_value as Dictionary).get(marker_id, false))
		"destination":
			return bool(route_record.get("completed_forward", false))
		"start":
			return bool(route_record.get("completed_round_trip", false))
	return false


func validate_route_chain() -> bool:
	if main_segments.size() != main_segment_definitions.size():
		return false
	for index: int in range(main_segments.size() - 1):
		var current_exit: Vector3 = main_segments[index].get_exit_global_transform().origin
		var next_entry: Vector3 = main_segments[index + 1].global_transform.origin
		if current_exit.distance_to(next_entry) > 0.05:
			return false
	if branch_segment_definition != null and branch_segment == null:
		return false
	return true


func generate_new_route_seed() -> void:
	var current_seed: int = int(route_record.get("seed", default_seed))
	route_record["seed"] = current_seed + 7919
	route_record["segment_plan"] = []
	route_record["completed_forward"] = false
	route_record["completed_round_trip"] = false
	return_mode = false
	RecordStoreScript.save_record(route_record, record_path)


func clear_generated_route() -> void:
	main_segments.clear()
	branch_segment = null
	start_marker = null
	destination_marker = null
	landmark_marker = null
	if generated_root != null and is_instance_valid(generated_root):
		remove_child(generated_root)
		generated_root.free()
	generated_root = null


func reset_player_to_route_start() -> void:
	if player == null:
		return
	player.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0))
	player.velocity = Vector3.ZERO
	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")
	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")


func set_route_objective() -> void:
	var objective: String = "Return to Cypress Field Camp." if return_mode else "Travel through the wilds to Blue Ridge Waystation."
	GameState.set_objective(objective)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", objective)


func build_status_hud() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "ExpeditionHUD"
	canvas.layer = 18
	add_child(canvas)
	var panel: PanelContainer = PanelContainer.new()
	panel.offset_left = 24.0
	panel.offset_top = 24.0
	panel.offset_right = 580.0
	panel.offset_bottom = 112.0
	canvas.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1.0, 1.0))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(status_label)


func refresh_status_hud() -> void:
	if status_label == null:
		return
	var discovery_mark: String = "✓" if is_marker_recorded("landmark", branch_segment_definition.landmark_id if branch_segment_definition != null else "") else "□"
	var direction: String = "RETURN" if return_mode else "OUTBOUND"
	status_label.text = (
		"WILDS  •  "
		+ direction
		+ "  •  SEED "
		+ str(route_record.get("seed", default_seed))
		+ "  •  "
		+ str(main_segments.size())
		+ "+1 SEGMENTS  •  CAIRN "
		+ discovery_mark
		+ "\nF8 Reset  •  F9 Rebuild saved route  •  F10 New seeded layout"
	)


func add_static_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, color: Color) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = local_position
	parent.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = create_material(color)
	body.add_child(mesh_instance)
	return body


func add_visual_box(parent: Node3D, node_name: String, size: Vector3, local_position: Vector3, local_rotation: Vector3, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = local_position
	instance.rotation = local_rotation
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = create_material(color)
	parent.add_child(instance)
	return instance


func add_visual_sphere(parent: Node3D, local_position: Vector3, radius: float, color: Color, emissive: bool = false) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.position = local_position
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	instance.mesh = mesh
	instance.material_override = create_material(color, emissive)
	parent.add_child(instance)
	return instance


func add_world_label(parent: Node3D, text: String, local_position: Vector3, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.position = local_position
	label.text = text
	label.font_size = 44
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 7
	parent.add_child(label)


func create_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 1.2
	return material


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_route_signature() -> String:
	var parts: Array[String] = []
	for index: int in range(route_plan.size()):
		var entry: Dictionary = route_plan[index]
		parts.append(
			str(entry.get("segment_id", "missing"))
			+ ":"
			+ str(entry.get("seed", 0))
			+ ":"
			+ str(entry.get("turn_degrees", 0.0))
		)
	return "|".join(parts)


func get_debug_data() -> Dictionary:
	return {
		"route": route_display_name,
		"seed": int(route_record.get("seed", default_seed)),
		"segments": main_segments.size(),
		"branch": branch_segment != null,
		"valid": route_valid,
		"return_mode": return_mode,
		"signature": get_route_signature(),
		"record_path": record_path,
	}
