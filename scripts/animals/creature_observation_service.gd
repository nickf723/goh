extends Node

signal observation_reported(species_id: String, event_type: String, context: Dictionary)
signal discovery_awarded(species_id: String, discovery_id: String, result: Dictionary)

const MAX_HISTORY: int = 48

const DISCOVERY_RULES: Dictionary = {
	"gremlin": [
		{
			"event_type": "species_sighted",
			"discovery_id": "first_encounter",
			"label": "First encounter",
			"points": 1,
			"requires_witness": true,
		},
		{
			"event_type": "action_active",
			"action_id": "gremlin_backstep",
			"discovery_id": "witnessed_backstep",
			"label": "Witnessed Backstep",
			"points": 1,
			"requires_witness": true,
		},
		{
			"event_type": "action_survived",
			"action_id": "gremlin_pounce",
			"discovery_id": "survived_pounce",
			"label": "Survived Pounce",
			"points": 1,
			"requires_player_target": true,
			"requires_target_survived": true,
		},
		{
			"event_type": "squad_coordination",
			"discovery_id": "pack_coordination",
			"label": "Observed pack coordination",
			"points": 2,
			"minimum_pack_members": 2,
			"minimum_result_count": 1,
			"requires_witness": true,
		},
		{
			"event_type": "reaction_triggered",
			"reaction_id": "wet_conduction",
			"discovery_id": "conduct_susceptibility",
			"label": "Discovered Conduct susceptibility",
			"points": 4,
			"requires_witness": true,
		},
		{
			"event_type": "pack_defeated",
			"discovery_id": "defeated_wild_pack",
			"label": "Defeated a wild Gremlin pack",
			"points": 1,
			"minimum_pack_members": 2,
		},
	],
}

@export_group("Field Observation")
@export_range(0.1, 2.0, 0.05) var sight_scan_interval: float = 0.35
@export_range(4.0, 50.0, 0.5) var sight_range: float = 20.0
@export_range(-1.0, 1.0, 0.05) var minimum_camera_dot: float = -0.1

var sight_scan_remaining: float = 0.0
var pack_member_ids: Dictionary = {}
var pack_max_members: Dictionary = {}
var observation_history: Array[Dictionary] = []
var total_events_reported: int = 0
var total_discoveries_awarded: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("debuggable")


func _process(delta: float) -> void:
	sight_scan_remaining = maxf(sight_scan_remaining - maxf(delta, 0.0), 0.0)
	if sight_scan_remaining > 0.0:
		return
	sight_scan_remaining = maxf(sight_scan_interval, 0.1)
	_scan_for_first_sightings()


func register_creature(creature: Node) -> Dictionary:
	var species_id: String = get_species_id(creature)
	if species_id == "" or not is_instance_valid(creature):
		return {}
	var pack_key: String = get_pack_key(creature)
	var members: Dictionary = _dictionary(pack_member_ids.get(pack_key, {}))
	members[creature.get_instance_id()] = true
	pack_member_ids[pack_key] = members
	pack_max_members[pack_key] = maxi(
		int(pack_max_members.get(pack_key, 0)),
		members.size()
	)
	return {
		"species_id": species_id,
		"pack_key": pack_key,
		"pack_members_seen": int(pack_max_members.get(pack_key, 1)),
	}


func report_event(
	species_id: String,
	event_type: String,
	context: Dictionary = {}
) -> Dictionary:
	var normalized_species: String = species_id.strip_edges().to_lower()
	var normalized_event: String = event_type.strip_edges().to_lower()
	if normalized_species == "" or normalized_event == "":
		return {"ok": false, "error": "Observation requires species and event ids"}

	var clean_context: Dictionary = context.duplicate(false)
	clean_context["species_id"] = normalized_species
	clean_context["event_type"] = normalized_event
	clean_context["reported_at"] = _now_seconds()
	total_events_reported += 1
	observation_reported.emit(
		normalized_species,
		normalized_event,
		_sanitize_context(clean_context)
	)

	var awarded: Array[Dictionary] = []
	var rules_value: Variant = DISCOVERY_RULES.get(normalized_species, [])
	if rules_value is Array:
		for rule_value: Variant in rules_value as Array:
			if not rule_value is Dictionary:
				continue
			var rule: Dictionary = rule_value as Dictionary
			if not _rule_matches(rule, normalized_event, clean_context):
				continue
			var result: Dictionary = _award_discovery(normalized_species, rule)
			if not result.is_empty():
				awarded.append(result)

	var history_row: Dictionary = {
		"species_id": normalized_species,
		"event_type": normalized_event,
		"context": _sanitize_context(clean_context),
		"awarded": awarded.duplicate(true),
	}
	observation_history.append(history_row)
	while observation_history.size() > MAX_HISTORY:
		observation_history.pop_front()
	return {
		"ok": true,
		"species_id": normalized_species,
		"event_type": normalized_event,
		"awarded": awarded,
	}


func report_action_event(
	creature: Node,
	event_type: String,
	action: Resource,
	context: Dictionary = {}
) -> Dictionary:
	var species_id: String = get_species_id(creature)
	if species_id == "" or action == null:
		return {}
	var enriched: Dictionary = context.duplicate(false)
	enriched["actor_ref"] = creature
	enriched["actor_id"] = creature.get_instance_id() if is_instance_valid(creature) else 0
	if action.has_method("get_action_id"):
		enriched["action_id"] = str(action.call("get_action_id")).strip_edges().to_lower()
	if action.has_method("get_display_name"):
		enriched["action_name"] = str(action.call("get_display_name"))
	enriched["pack_key"] = get_pack_key(creature)
	enriched["pack_member_count"] = get_pack_member_count(creature)
	return report_event(species_id, event_type, enriched)


func report_squad_coordination(
	creature: Node,
	results: Array,
	context: Dictionary = {}
) -> Dictionary:
	var species_id: String = get_species_id(creature)
	if species_id == "":
		return {}
	var enriched: Dictionary = context.duplicate(false)
	enriched["actor_ref"] = creature
	enriched["pack_key"] = get_pack_key(creature)
	enriched["pack_member_count"] = get_pack_member_count(creature)
	enriched["result_count"] = results.size()
	return report_event(species_id, "squad_coordination", enriched)


func report_reaction(
	target: Node,
	reaction: Dictionary,
	payload: Resource = null
) -> Dictionary:
	var species_id: String = get_species_id(target)
	if species_id == "":
		return {}
	var context: Dictionary = {
		"actor_ref": target,
		"target_id": target.get_instance_id() if is_instance_valid(target) else 0,
		"reaction_id": str(reaction.get("reaction_id", "")).strip_edges().to_lower(),
		"reaction_name": str(reaction.get("reaction", "")),
		"pack_key": get_pack_key(target),
		"pack_member_count": get_pack_member_count(target),
	}
	if payload != null:
		if "element" in payload:
			context["incoming_element"] = str(payload.get("element")).to_lower()
		if "source_name" in payload:
			context["source_name"] = str(payload.get("source_name"))
	return report_event(species_id, "reaction_triggered", context)


func report_creature_defeated(creature: Node) -> Dictionary:
	var species_id: String = get_species_id(creature)
	if species_id == "":
		return {}
	var pack_key: String = get_pack_key(creature)
	var context: Dictionary = {
		"actor_ref": creature,
		"actor_id": creature.get_instance_id() if is_instance_valid(creature) else 0,
		"pack_key": pack_key,
		"pack_member_count": int(pack_max_members.get(pack_key, 1)),
	}
	var result: Dictionary = report_event(species_id, "creature_defeated", context)
	call_deferred("_evaluate_pack_defeat", species_id, pack_key)
	return result


func get_species_id(creature: Node) -> String:
	if not is_instance_valid(creature):
		return ""
	if creature.has_meta("creature_species_id"):
		return str(creature.get_meta("creature_species_id")).strip_edges().to_lower()
	return ""


func get_pack_key(creature: Node) -> String:
	if not is_instance_valid(creature):
		return "unknown_pack"
	var species_id: String = get_species_id(creature)
	var squad_id: String = ""
	if creature.has_meta("tactical_squad_id"):
		squad_id = str(creature.get_meta("tactical_squad_id")).strip_edges().to_lower()
	if squad_id == "":
		var brain: Node = creature.get_node_or_null("EnemyBrain")
		if brain != null and brain.has_method("get_tactical_squad_id"):
			squad_id = str(brain.call("get_tactical_squad_id")).strip_edges().to_lower()
	if squad_id == "":
		var parent: Node = creature.get_parent()
		squad_id = "group_" + str(parent.get_instance_id() if parent != null else 0)
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	var scene_id: int = scene.get_instance_id() if scene != null else 0
	return species_id + "::" + squad_id + "::" + str(scene_id)


func get_pack_member_count(creature: Node) -> int:
	var pack_key: String = get_pack_key(creature)
	var live_count: int = 0
	for value: Variant in get_tree().get_nodes_in_group("creature_observable"):
		if not value is Node:
			continue
		var member: Node = value as Node
		if not is_instance_valid(member) or member.is_queued_for_deletion():
			continue
		if get_pack_key(member) == pack_key and member.is_in_group("enemy"):
			live_count += 1
	return maxi(live_count, int(pack_max_members.get(pack_key, 0)))


func can_player_witness(creature: Node) -> bool:
	if not creature is Node3D or not is_instance_valid(creature):
		return false
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return true
	var actor: Node3D = creature as Node3D
	var aim_point: Vector3 = _get_aim_point(actor)
	if player.global_position.distance_to(aim_point) > sight_range:
		return false
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return true
	if camera.is_position_behind(aim_point):
		return false
	var to_actor: Vector3 = aim_point - camera.global_position
	if to_actor.length_squared() <= 0.0001:
		return true
	var forward_dot: float = (-camera.global_basis.z).normalized().dot(to_actor.normalized())
	if forward_dot < minimum_camera_dot:
		return false
	return _has_line_of_sight(player, actor, aim_point, camera.global_position)


func clear_runtime_state() -> void:
	pack_member_ids.clear()
	pack_max_members.clear()
	observation_history.clear()
	total_events_reported = 0
	total_discoveries_awarded = 0
	sight_scan_remaining = 0.0


func get_debug_data() -> Dictionary:
	return {
		"events_reported": total_events_reported,
		"discoveries_awarded": total_discoveries_awarded,
		"tracked_packs": pack_max_members.size(),
		"history": observation_history.duplicate(true),
	}


func _scan_for_first_sightings() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	for value: Variant in get_tree().get_nodes_in_group("creature_observable"):
		if not value is Node3D:
			continue
		var creature: Node3D = value as Node3D
		var species_id: String = get_species_id(creature)
		if species_id == "" or _has_discovery(species_id, "first_encounter"):
			continue
		if can_player_witness(creature):
			report_event(
				species_id,
				"species_sighted",
				{
					"actor_ref": creature,
					"actor_id": creature.get_instance_id(),
					"pack_key": get_pack_key(creature),
					"pack_member_count": get_pack_member_count(creature),
				}
			)


func _evaluate_pack_defeat(species_id: String, pack_key: String) -> void:
	var maximum_members: int = int(pack_max_members.get(pack_key, 0))
	if maximum_members < 2:
		return
	for value: Variant in get_tree().get_nodes_in_group("creature_observable"):
		if not value is Node:
			continue
		var member: Node = value as Node
		if not is_instance_valid(member) or member.is_queued_for_deletion():
			continue
		if get_species_id(member) != species_id or get_pack_key(member) != pack_key:
			continue
		if member.is_in_group("enemy"):
			return
	report_event(
		species_id,
		"pack_defeated",
		{
			"pack_key": pack_key,
			"pack_member_count": maximum_members,
		}
	)


func _rule_matches(
	rule: Dictionary,
	event_type: String,
	context: Dictionary
) -> bool:
	if str(rule.get("event_type", "")).to_lower() != event_type:
		return false
	if rule.has("action_id"):
		if str(context.get("action_id", "")).to_lower() != str(rule.get("action_id", "")).to_lower():
			return false
	if rule.has("reaction_id"):
		if str(context.get("reaction_id", "")).to_lower() != str(rule.get("reaction_id", "")).to_lower():
			return false
	if bool(rule.get("requires_player_target", false)) and not bool(context.get("target_is_player", false)):
		return false
	if bool(rule.get("requires_target_survived", false)) and not bool(context.get("target_survived", false)):
		return false
	if int(context.get("pack_member_count", 0)) < int(rule.get("minimum_pack_members", 0)):
		return false
	if int(context.get("result_count", 0)) < int(rule.get("minimum_result_count", 0)):
		return false
	if bool(rule.get("requires_witness", false)):
		var actor_value: Variant = context.get("actor_ref")
		if not actor_value is Node or not can_player_witness(actor_value as Node):
			return false
	return true


func _award_discovery(species_id: String, rule: Dictionary) -> Dictionary:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null or not service.has_method("add_discovery"):
		return {}
	var discovery_id: String = str(rule.get("discovery_id", "")).strip_edges()
	if discovery_id == "":
		return {}
	var result_value: Variant = service.call(
		"add_discovery",
		species_id,
		discovery_id,
		str(rule.get("label", discovery_id.replace("_", " ").capitalize())),
		int(rule.get("points", 1))
	)
	if not result_value is Dictionary:
		return {}
	var result: Dictionary = result_value as Dictionary
	if not bool(result.get("new_discovery", false)):
		return {}
	total_discoveries_awarded += 1
	var row: Dictionary = {
		"species_id": species_id,
		"discovery_id": discovery_id,
		"label": str(result.get("discovery_label", rule.get("label", discovery_id))),
		"points": int(rule.get("points", 1)),
		"rank": int(result.get("rank", 0)),
	}
	discovery_awarded.emit(species_id, discovery_id, row.duplicate(true))
	_show_discovery_feedback(row)
	return row


func _has_discovery(species_id: String, discovery_id: String) -> bool:
	var service: Node = get_node_or_null("/root/SpeciesKnowledge")
	if service == null or not service.has_method("get_species_data"):
		return false
	var value: Variant = service.call("get_species_data", species_id)
	if not value is Dictionary:
		return false
	var data: Dictionary = value as Dictionary
	return _dictionary(data.get("discoveries", {})).has(discovery_id)


func _show_discovery_feedback(row: Dictionary) -> void:
	var text: String = (
		"Field insight: " + str(row.get("label", "Discovery"))
		+ "  •  +" + str(row.get("points", 0)) + " knowledge"
	)
	if GameState.has_method("show_system_message"):
		GameState.call("show_system_message", text)
		return
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func _has_line_of_sight(
	player: Node3D,
	creature: Node3D,
	aim_point: Vector3,
	origin: Vector3
) -> bool:
	var world: World3D = player.get_world_3d()
	if world == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(origin, aim_point)
	var exclusions: Array[RID] = []
	if player is CollisionObject3D:
		exclusions.append((player as CollisionObject3D).get_rid())
	query.exclude = exclusions
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Node = hit.get("collider") as Node
	if collider == null:
		return false
	return (
		collider == creature
		or creature.is_ancestor_of(collider)
		or collider.is_ancestor_of(creature)
	)


func _get_aim_point(creature: Node3D) -> Vector3:
	if creature.has_method("get_targeting_aim_point"):
		var value: Variant = creature.call("get_targeting_aim_point")
		if value is Vector3:
			return value as Vector3
	return creature.global_position + Vector3.UP * 0.7


func _sanitize_context(context: Dictionary) -> Dictionary:
	var clean: Dictionary = context.duplicate(false)
	clean.erase("actor_ref")
	return clean


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
