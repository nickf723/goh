extends Area3D
class_name StatusSurface

const ReactionResolverScript = preload("res://scripts/systems/reaction_resolver.gd")
const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")
const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

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

@export_group("Reaction Surface")
@export var reactive_enabled: bool = false
@export_enum("none", "water", "oil") var visual_profile: String = "none"
@export var hazard_tags: Array[String] = []
@export var burning_state_duration: float = 6.0
@export var electrified_state_duration: float = 3.2
@export var frozen_state_duration: float = 10.0
@export var steam_state_duration: float = 3.0

var active_targets: Dictionary = {}
var refresh_timer: float = 0.0
var reaction_state: String = "normal"
var reaction_timer: float = 0.0
var reaction_tick_timer: float = 0.0
var visual_elapsed: float = 0.0
var last_reaction_summary: String = "none"


func _ready() -> void:
	monitoring = true
	monitorable = true
	add_to_group("debuggable")
	add_to_group("lab_resettable")

	if applies_to_bodies:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

	if applies_to_areas:
		area_entered.connect(_on_area_entered)
		area_exited.connect(_on_area_exited)

	if reactive_enabled:
		ElementVisuals.configure_surface_visual(self, visual_profile, reaction_state)

	if scan_existing_overlaps_on_start:
		call_deferred("register_current_overlaps")


func _process(delta: float) -> void:
	visual_elapsed += delta

	if reactive_enabled:
		ElementVisuals.animate_surface_visual(self, visual_profile, reaction_state, visual_elapsed)
		update_reaction_state(delta)

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


func update_reaction_state(delta: float) -> void:
	if reaction_state == "normal" or reaction_state == "shattered":
		return

	if reaction_timer > 0.0:
		reaction_timer -= delta

	reaction_tick_timer -= delta

	if reaction_tick_timer <= 0.0:
		reaction_tick_timer = 0.35
		apply_reaction_state_to_active_targets()

	if reaction_timer <= 0.0:
		set_reaction_state("normal", 0.0)


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

	if target == null or target == self:
		return

	var target_id: int = target.get_instance_id()

	if active_targets.has(target_id):
		active_targets[target_id]["count"] += 1
		sustain_surface_status(target)
		apply_reaction_state_to_target(target)
		return

	active_targets[target_id] = {
		"target": target,
		"count": 1,
	}

	apply_surface_status_to_target(target, show_feedback)
	apply_reaction_state_to_target(target)


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

	for target_id: Variant in active_targets.keys():
		var target: Node = active_targets[target_id]["target"]

		if target == null or not is_instance_valid(target):
			stale_ids.append(int(target_id))
			continue

		sustain_surface_status(target)
		apply_reaction_state_to_target(target)

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


func apply_reaction_state_to_active_targets() -> void:
	for entry_value: Variant in active_targets.values():
		if not (entry_value is Dictionary):
			continue

		var entry: Dictionary = entry_value as Dictionary
		var target: Node = entry.get("target") as Node

		if target != null and is_instance_valid(target):
			apply_reaction_state_to_target(target)


func apply_reaction_state_to_target(target: Node) -> void:
	if target == null:
		return

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver == null or not status_receiver.has_method("sustain_status"):
		return

	match reaction_state:
		"burning":
			status_receiver.sustain_status("burning", 1.1, 1.0, surface_name + " ignition")
		"electrified":
			status_receiver.sustain_status("stunned", 0.45, 1.0, surface_name + " conduction")
		"frozen":
			status_receiver.sustain_status("frozen", 0.65, 1.0, surface_name + " freeze")
		"steaming":
			status_receiver.sustain_status("steamed", 0.6, 1.0, surface_name + " steam")
		_:
			pass


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if not reactive_enabled or payload == null:
		return {
			"message": payload.source_name + " splashes across " + surface_name + "." if payload != null else surface_name + " receives an empty payload.",
			"objective": "",
		}

	var reactions: Array[Dictionary] = ReactionResolverScript.resolve_hazard_reactions(
		self,
		payload,
		get_payload_source_position()
	)
	var messages: Array[String] = []

	for reaction: Dictionary in reactions:
		var reaction_id: String = str(reaction.get("reaction", "reaction"))
		last_reaction_summary = reaction_id
		CombatFeedback.show_reaction_feedback(self, reaction_id, reaction)

		if reaction.has("message"):
			messages.append(str(reaction["message"]))

	if messages.is_empty():
		return {
			"message": payload.source_name + " touches " + surface_name + ", but no reaction recipe matches.",
			"objective": "",
		}

	return {
		"message": "\n".join(messages),
		"objective": "Combine elements to change the laboratory surfaces.",
	}


func get_payload_source_position() -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player")

	if player != null:
		return player.global_position

	return global_position


func get_hazard_tags() -> Array[String]:
	var tags: Array[String] = hazard_tags.duplicate()

	if status_effect != "" and not tags.has(status_effect):
		tags.append(status_effect)

	if visual_profile != "none" and not tags.has(visual_profile):
		tags.append(visual_profile)

	match reaction_state:
		"burning":
			tags.append("burning")
			tags.append("fire")
		"electrified":
			tags.append("electrified")
			tags.append("lightning")
		"frozen":
			tags.append("frozen")
			tags.append("ice")
		"steaming":
			tags.append("steamed")
			tags.append("steam")
		"shattered":
			tags.append("shattered")

	return tags


func trigger_ignite(_source_position: Vector3 = Vector3.ZERO) -> void:
	set_reaction_state("burning", burning_state_duration)


func trigger_electrify(_source_position: Vector3 = Vector3.ZERO) -> void:
	set_reaction_state("electrified", electrified_state_duration)


func trigger_freeze(_source_position: Vector3 = Vector3.ZERO) -> void:
	set_reaction_state("frozen", frozen_state_duration)


func trigger_shatter(_source_position: Vector3 = Vector3.ZERO) -> void:
	set_reaction_state("shattered", 0.0)
	var return_tween: Tween = create_tween()
	return_tween.tween_interval(0.55)
	return_tween.tween_callback(Callable(self, "return_from_shatter"))


func return_from_shatter() -> void:
	if reaction_state == "shattered":
		set_reaction_state("normal", 0.0)


func trigger_steam(_source_position: Vector3 = Vector3.ZERO) -> void:
	set_reaction_state("steaming", steam_state_duration)


func set_reaction_state(next_state: String, duration: float) -> void:
	reaction_state = next_state
	reaction_timer = max(duration, 0.0)
	reaction_tick_timer = 0.0
	ElementVisuals.configure_surface_visual(self, visual_profile, reaction_state)
	apply_reaction_state_to_active_targets()


func reset_surface() -> void:
	reaction_state = "normal"
	reaction_timer = 0.0
	reaction_tick_timer = 0.0
	last_reaction_summary = "none"
	ElementVisuals.configure_surface_visual(self, visual_profile, reaction_state)
	refresh_active_targets()


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
		"reaction_state": reaction_state,
		"reaction_time": snapped(reaction_timer, 0.1),
		"last_reaction": last_reaction_summary,
		"hazard_tags": get_hazard_tags(),
	}


func remove_statuses_from_target(target: Node) -> void:
	if removes_statuses.size() == 0:
		return

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver == null or not status_receiver.has_method("remove_status"):
		return

	for status_name: String in removes_statuses:
		status_receiver.remove_status(status_name)
