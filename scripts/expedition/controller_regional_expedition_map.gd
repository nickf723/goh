extends "res://scripts/expedition/regional_expedition_map.gd"

const PlannerScript = preload("res://scripts/expedition/route_familiarity_planner.gd")

var preview_label: Label


func _ready() -> void:
	super._ready()
	configure_familiarity_panel()
	refresh_interface()
	call_deferred("focus_launch_action")


func configure_familiarity_panel() -> void:
	if selection_body != null:
		selection_body.size = Vector2(280.0, 132.0)
	if route_state_label != null:
		route_state_label.position = Vector2(895.0, 430.0)
	if launch_button != null:
		launch_button.position = Vector2(895.0, 495.0)
	if hint_label != null:
		hint_label.position = Vector2(895.0, 557.0)

	preview_label = Label.new()
	preview_label.name = "RoutePreview"
	preview_label.position = Vector2(895.0, 323.0)
	preview_label.size = Vector2(280.0, 100.0)
	preview_label.add_theme_font_size_override("font_size", 13)
	preview_label.add_theme_color_override("font_color", Color(0.68, 0.86, 0.92, 1.0))
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(preview_label)


func select_node(node_id: String) -> void:
	super.select_node(node_id)
	call_deferred("focus_launch_action")


func refresh_interface() -> void:
	super.refresh_interface()
	refresh_route_preview()


func refresh_route_preview() -> void:
	if preview_label == null:
		return
	if selected_route_id == "":
		preview_label.text = "PREVIEW  •  No known route"
		return
	var state_name: String = RegionalStoreScript.get_route_state(network_record, selected_route_id)
	if state_name == RegionalStoreScript.STATE_UNKNOWN:
		preview_label.text = "PREVIEW  •  Route remains unknown"
		return
	preview_label.text = PlannerScript.build_preview_text(get_selected_plan())


func get_selected_plan() -> Dictionary:
	return build_plan_for_context(
		selected_route_id,
		str(network_record.get("current_node_id", RegionalStoreScript.NODE_CYPRESS)),
		selected_node_id
	)


func build_plan_for_context(
	route_id_value: String,
	origin_node_id: String,
	destination_node_id: String
) -> Dictionary:
	if route_id_value == "":
		return {}
	var state_name: String = RegionalStoreScript.get_route_state(network_record, route_id_value)
	var route_seed: int = RegionalStoreScript.get_route_seed(network_record, route_id_value)
	return PlannerScript.build_plan(
		route_id_value,
		state_name,
		route_seed,
		origin_node_id,
		destination_node_id
	)


func build_launch_context() -> Dictionary:
	var route_id_value: String = selected_route_id
	var origin_node_id: String = str(
		network_record.get("current_node_id", RegionalStoreScript.NODE_CYPRESS)
	)
	var destination_node_id: String = selected_node_id
	var plan: Dictionary = build_plan_for_context(
		route_id_value,
		origin_node_id,
		destination_node_id
	)
	return {
		"route_id": route_id_value,
		"origin_node_id": origin_node_id,
		"destination_node_id": destination_node_id,
		"network_record_path": network_record_path,
		"expedition_record_path": expedition_record_path,
		"map_scene_path": map_scene_path,
		"suppress_scene_transition": not allow_scene_launch,
		"route_state": str(plan.get("state", RegionalStoreScript.STATE_DISCOVERED)),
		"route_seed": int(plan.get("seed", 18890417)),
		"familiarity_plan": plan,
		"plan_signature": str(plan.get("signature", "")),
	}


func get_route_description(route_id: String, from_node: String, to_node: String) -> String:
	var direction_text: String = get_node_display_name(from_node) + " → " + get_node_display_name(to_node)
	var state_name: String = RegionalStoreScript.get_route_state(network_record, route_id)
	var seed_value: int = RegionalStoreScript.get_route_seed(network_record, route_id)
	var plan: Dictionary = PlannerScript.build_plan(
		route_id,
		state_name,
		seed_value,
		from_node,
		to_node
	)
	var effects: String = "Unsurveyed paths, full enemy presence, and uncertain obstacles."
	match state_name:
		RegionalStoreScript.STATE_CROSSED:
			effects = "A known shelter is guaranteed and enemy presence begins to thin."
		RegionalStoreScript.STATE_MAPPED:
			effects = "Segment roles are charted, obstacles are lighter, and resources are easier to locate."
		RegionalStoreScript.STATE_STABILIZED:
			effects = "A shortened connector bypasses cleared terrain and hostile camps are largely abandoned."
	return (
		direction_text
		+ "\n\n"
		+ effects
		+ "\n\nDanger: "
		+ str(plan.get("danger", "Unknown"))
		+ "  •  Length: "
		+ str(plan.get("length_label", "Unknown"))
	)


func focus_launch_action() -> void:
	if launch_button != null and is_instance_valid(launch_button) and not launch_button.disabled:
		launch_button.grab_focus()
