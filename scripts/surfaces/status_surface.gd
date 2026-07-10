extends Area3D

@export var surface_name: String = "Status Surface"

@export var status_effect: String = "wet"
@export var status_duration: float = 8.0
@export var status_strength: float = 1.0
@export var status_source: String = "surface"

@export var removes_statuses: Array[String] = []
@export var removes_statuses_while_inside: bool = true

@export var applies_to_bodies: bool = true
@export var applies_to_areas: bool = true
@export var scan_existing_overlaps_on_start: bool = true
@export var show_feedback: bool = true

@export var refresh_interval: float = 0.1

var active_targets: Dictionary = {}
var refresh_timer: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = true

	if applies_to_bodies:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	if applies_to_areas:
		area_entered.connect(_on_area_entered)
		area_exited.connect(_on_area_exited)

	if scan_existing_overlaps_on_start:
		call_deferred("register_current_overlaps")

func _process(delta: float) -> void:
	if active_targets.is_empty():
		return

	if refresh_interval <= 0.0:
		refresh_active_targets()
		return

	refresh_timer -= delta

	if refresh_timer > 0.0:
		return

	refresh_timer = refresh_interval
	refresh_active_targets()

func register_current_overlaps() -> void:
	for body: Node3D in get_overlapping_bodies():
		register_surface_target(body)

	for area: Area3D in get_overlapping_areas():
		register_surface_target(area)

func _on_body_entered(body: Node3D) -> void:
	register_surface_target(body)

func _on_body_exited(body: Node3D) -> void:
	unregister_surface_target(body)

func _on_area_entered(area: Area3D) -> void:
	register_surface_target(area)

func _on_area_exited(area: Area3D) -> void:
	unregister_surface_target(area)

func register_surface_target(raw_target: Node) -> void:
	var target: Node = find_status_target(raw_target)

	if target == null:
		return

	if target == self:
		return

	var target_id: int = target.get_instance_id()

	if active_targets.has(target_id):
		active_targets[target_id]["count"] += 1
		sustain_surface_status(target)
		return

	active_targets[target_id] = {
		"target": target,
		"count": 1,
	}

	apply_surface_status_to_target(target, show_feedback)

func unregister_surface_target(raw_target: Node) -> void:
	var target: Node = find_status_target(raw_target)

	if target == null:
		return

	var target_id: int = target.get_instance_id()

	if not active_targets.has(target_id):
		return

	active_targets[target_id]["count"] -= 1

	if active_targets[target_id]["count"] <= 0:
		active_targets.erase(target_id)

func refresh_active_targets() -> void:
	var stale_ids: Array[int] = []

	for target_id in active_targets.keys():
		var target: Node = active_targets[target_id]["target"]

		if target == null or not is_instance_valid(target):
			stale_ids.append(target_id)
			continue

		sustain_surface_status(target)

	for target_id: int in stale_ids:
		active_targets.erase(target_id)

func apply_surface_status_to_target(target: Node, should_show_feedback: bool) -> void:
	remove_statuses_from_target(target)
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver != null and status_receiver.has_method("apply_status"):
		status_receiver.apply_status(
			status_effect,
			status_duration,
			status_strength,
			status_source
		)

		if should_show_feedback:
			show_message(target.name + " is affected by " + surface_name + ".")

		return

	var tag_component: Node = target.get_node_or_null("TagComponent")

	if tag_component != null and tag_component.has_method("add_tag"):
		tag_component.add_tag(status_effect)

		if should_show_feedback:
			show_message(target.name + " gains tag: " + status_effect + ".")

func sustain_surface_status(target: Node) -> void:
	if removes_statuses_while_inside:
		remove_statuses_from_target(target)
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver != null:
		if status_receiver.has_method("sustain_status"):
			status_receiver.sustain_status(
				status_effect,
				status_duration,
				status_strength,
				status_source
			)
			return

		if status_receiver.has_method("apply_status"):
			status_receiver.apply_status(
				status_effect,
				status_duration,
				status_strength,
				status_source
			)
			return

	var tag_component: Node = target.get_node_or_null("TagComponent")

	if tag_component != null and tag_component.has_method("add_tag"):
		tag_component.add_tag(status_effect)

func find_status_target(start_node: Node) -> Node:
	var current: Node = start_node

	while current != null:
		if is_surface_target(current):
			return current

		current = current.get_parent()

	return null

func is_surface_target(node: Node) -> bool:
	if node.get_node_or_null("StatusReceiver") != null:
		return true

	if node.get_node_or_null("TagComponent") != null:
		return true

	if node.get_node_or_null("PayloadReceiver") != null:
		return true

	if node.get_node_or_null("HitReceiver") != null:
		return true

	return false

func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)

func get_debug_data() -> Dictionary:
	return {
		"surface": surface_name,
		"status": status_effect,
		"duration": status_duration,
		"strength": status_strength,
		"source": status_source,
		"active": active_targets.size(),
	}

func remove_statuses_from_target(target: Node) -> void:
	if removes_statuses.size() == 0:
		return

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver == null:
		return

	if not status_receiver.has_method("remove_status"):
		return

	for status_name: String in removes_statuses:
		status_receiver.remove_status(status_name)
