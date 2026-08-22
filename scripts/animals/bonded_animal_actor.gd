extends GenericAnimalActor
class_name BondedAnimalActor

signal bond_changed(bonded: bool, follow_enabled: bool)

@export var persistent_animal_id: String = ""
@export var treat_item_id: String = "field_treat"

var bond_store: AnimalBondStore
var bonded: bool = false
var follow_enabled: bool = false
var help_events: int = 0
var harm_events: int = 0
var persistence_time_remaining: float = 1.0
var disk_flush_time_remaining: float = 5.0


func _ready() -> void:
	super._ready()
	if persistent_animal_id.strip_edges() == "":
		persistent_animal_id = _derive_persistent_id()
	bond_store = AnimalBondStore.get_or_create(get_tree())
	reload_persistent_state()


func _exit_tree() -> void:
	persist_named_state(true)


func get_mob_decision_context() -> Dictionary:
	var context: Dictionary = super.get_mob_decision_context()
	if relationship == null or perception == null:
		return context
	var grace: Node3D = _get_grace_target()
	if grace == null:
		return context
	var grace_distance: float = global_position.distance_to(grace.global_position)
	if _grace_is_current_threat(grace_distance):
		return context
	var score_modifiers: Dictionary = context.get("move_score_modifiers", {}).duplicate(true)
	var tags: Array = context.get("context_tags", [])
	if bonded:
		tags.append("bonded_to_grace")
		if follow_enabled and perception.remembers_target:
			score_modifiers["idle"] = float(score_modifiers.get("idle", 0.0)) + 5.0
			tags.append("following_grace")
	elif relationship_label == "curious" and perception.can_see_target:
		score_modifiers["idle"] = float(score_modifiers.get("idle", 0.0)) + 3.0
		tags.append("approaching_grace")
	elif relationship_label == "wary" and perception.can_see_target:
		score_modifiers["idle"] = float(score_modifiers.get("idle", 0.0)) + 2.0
		tags.append("watching_grace")
	context["move_score_modifiers"] = score_modifiers
	context["context_tags"] = tags
	return context


func interact_with_grace(interaction_id: String) -> Dictionary:
	var normalized_id: String = interaction_id.to_lower().strip_edges()
	var consumed_treat: bool = false
	if normalized_id == "feed":
		var grace: Node3D = _get_grace_target()
		if grace == null:
			return {"ok": false, "error": "Grace unavailable"}
		var distance: float = global_position.distance_to(grace.global_position)
		if distance > 4.4:
			return {
				"ok": false,
				"error": "too far",
				"distance": distance,
				"maximum_distance": 4.4,
			}
		if GameState.get_inventory_count(treat_item_id) <= 0:
			return {
				"ok": false,
				"error": "no treats",
				"item_id": treat_item_id,
			}
		consumed_treat = GameState.consume_inventory_item(treat_item_id, 1)
		if not consumed_treat:
			return {"ok": false, "error": "treat could not be consumed"}
	var result: Dictionary = super.interact_with_grace(normalized_id)
	if not bool(result.get("ok", false)) and consumed_treat:
		GameState.add_inventory_item(treat_item_id, 1)
	if bool(result.get("ok", false)):
		result["item_id"] = treat_item_id if normalized_id == "feed" else ""
		result["item_count"] = GameState.get_inventory_count(treat_item_id)
		persist_named_state(true)
	return result


func report_grace_event(event_id: String, intensity: float = 1.0) -> Dictionary:
	if relationship == null:
		return {"ok": false, "error": "relationship unavailable"}
	var normalized_id: String = event_id.to_lower().strip_edges()
	var interaction_id: String = ""
	match normalized_id:
		"help", "heal", "rescue":
			interaction_id = "help"
			help_events += 1
			add_drive("fear", -0.42 * clampf(intensity, 0.1, 2.0))
			add_drive("social_need", -0.2)
		"attack", "damage":
			interaction_id = "attack"
			harm_events += 1
			_interrupt_current_action("grace_attack", true)
			set_drive("fear", 1.0)
			set_drive("territorial_pressure", 1.0)
			var grace: Node3D = _get_grace_target()
			if grace != null:
				_broadcast_alert(grace.global_position, 1.0)
		"chase", "threaten":
			interaction_id = "startle"
			harm_events += 1
			_interrupt_current_action("grace_threat", true)
			set_drive("fear", maxf(get_drive("fear"), 0.82))
		_:
			return {"ok": false, "error": "unknown event"}
	var result: Dictionary = relationship.apply_interaction(interaction_id)
	if not bool(result.get("ok", false)):
		return result
	relationship.last_interaction = normalized_id
	relationship_label = relationship.get_relationship_label(get_drive("fear"))
	brain.clear_memory()
	force_decision(true)
	persist_named_state(true)
	result["event"] = normalized_id
	result["relationship_label"] = relationship_label
	return result


func attempt_bond() -> Dictionary:
	if relationship == null:
		return {"ok": false, "error": "relationship unavailable"}
	if bonded:
		return {
			"ok": true,
			"already_bonded": true,
			"bonded": bonded,
			"follow_enabled": follow_enabled,
		}
	var grace: Node3D = _get_grace_target()
	if grace == null or global_position.distance_to(grace.global_position) > 4.4:
		return {"ok": false, "error": "too far"}
	if _is_grace_threatening():
		return {"ok": false, "error": "Grace is threatening"}
	var requirements: Dictionary = get_bond_requirements()
	if not bool(requirements.get("eligible", false)):
		return {
			"ok": false,
			"error": "relationship requirements not met",
			"requirements": requirements,
		}
	bonded = true
	follow_enabled = true
	_interrupt_current_action("bonded", true)
	relationship.trust = maxf(relationship.trust, 0.72)
	relationship.familiarity = maxf(relationship.familiarity, 0.65)
	relationship.fear_association = minf(relationship.fear_association, 0.12)
	relationship.last_interaction = "bond"
	relationship.interaction_count += 1
	relationship_label = relationship.get_relationship_label(get_drive("fear"))
	brain.clear_memory()
	force_decision(true)
	persist_named_state(true)
	bond_changed.emit(bonded, follow_enabled)
	return {
		"ok": true,
		"bonded": bonded,
		"follow_enabled": follow_enabled,
		"relationship_label": relationship_label,
	}


func toggle_follow() -> Dictionary:
	if not bonded:
		return {"ok": false, "error": "animal is not bonded"}
	follow_enabled = not follow_enabled
	_interrupt_current_action("follow_mode_changed", true)
	brain.clear_memory()
	force_decision(true)
	persist_named_state(true)
	bond_changed.emit(bonded, follow_enabled)
	return {
		"ok": true,
		"bonded": bonded,
		"follow_enabled": follow_enabled,
	}


func get_bond_requirements() -> Dictionary:
	var trust_value: float = relationship.trust if relationship != null else 0.0
	var familiarity_value: float = relationship.familiarity if relationship != null else 0.0
	var fear_value: float = relationship.fear_association if relationship != null else 1.0
	var current_fear: float = get_drive("fear")
	return {
		"eligible": (
			trust_value >= 0.58
			and familiarity_value >= 0.45
			and fear_value <= 0.3
			and current_fear <= 0.35
		),
		"trust": trust_value,
		"trust_required": 0.58,
		"familiarity": familiarity_value,
		"familiarity_required": 0.45,
		"fear_association": fear_value,
		"fear_association_maximum": 0.3,
		"current_fear": current_fear,
		"current_fear_maximum": 0.35,
	}


func get_bond_data() -> Dictionary:
	return {
		"persistent_animal_id": persistent_animal_id,
		"bonded": bonded,
		"follow_enabled": follow_enabled,
		"help_events": help_events,
		"harm_events": harm_events,
		"requirements": get_bond_requirements(),
	}


func persist_named_state(save_now: bool = false) -> Dictionary:
	if relationship == null or persistent_animal_id == "" or not is_inside_tree():
		return {}
	if bond_store == null:
		bond_store = AnimalBondStore.get_or_create(get_tree())
	if bond_store == null:
		return {}
	return bond_store.set_record(
		persistent_animal_id,
		{
			"animal_name": animal_name,
			"species_id": species_id,
			"personality_profile_id": personality_profile_id,
			"relationship": relationship.to_dictionary(),
			"bonded": bonded,
			"follow_enabled": follow_enabled,
			"help_events": help_events,
			"harm_events": harm_events,
		},
		save_now
	)


func reload_persistent_state() -> bool:
	if persistent_animal_id == "" or relationship == null:
		return false
	if bond_store == null:
		bond_store = AnimalBondStore.get_or_create(get_tree())
	if bond_store == null:
		return false
	var record: Dictionary = bond_store.get_record(persistent_animal_id)
	if record.is_empty():
		return false
	var saved_relationship: Dictionary = record.get("relationship", {}) as Dictionary
	relationship.trust = clampf(float(saved_relationship.get("trust", relationship.trust)), -1.0, 1.0)
	relationship.familiarity = clampf(float(saved_relationship.get("familiarity", relationship.familiarity)), 0.0, 1.0)
	relationship.fear_association = clampf(float(saved_relationship.get("fear_association", relationship.fear_association)), 0.0, 1.0)
	relationship.peaceful_exposure = maxf(float(saved_relationship.get("peaceful_exposure", relationship.peaceful_exposure)), 0.0)
	relationship.last_interaction = str(saved_relationship.get("last_interaction", relationship.last_interaction))
	relationship.interaction_count = maxi(int(saved_relationship.get("interaction_count", relationship.interaction_count)), 0)
	bonded = bool(record.get("bonded", false))
	follow_enabled = bool(record.get("follow_enabled", bonded)) and bonded
	help_events = maxi(int(record.get("help_events", 0)), 0)
	harm_events = maxi(int(record.get("harm_events", 0)), 0)
	relationship_label = relationship.get_relationship_label(get_drive("fear"))
	previous_relationship_label = relationship_label
	if brain != null:
		brain.clear_memory()
		force_decision(true)
	bond_changed.emit(bonded, follow_enabled)
	return true


func clear_persistent_bond() -> bool:
	if bond_store == null:
		bond_store = AnimalBondStore.get_or_create(get_tree())
	var removed: bool = bond_store != null and bond_store.remove_record(persistent_animal_id, true)
	super.reset_actor()
	bonded = false
	follow_enabled = false
	help_events = 0
	harm_events = 0
	bond_changed.emit(false, false)
	return removed


func reset_actor() -> void:
	super.reset_actor()
	bonded = false
	follow_enabled = false
	help_events = 0
	harm_events = 0
	reload_persistent_state()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["bond"] = get_bond_data()
	return data


func _update_perception_and_relationship(delta: float) -> void:
	super._update_perception_and_relationship(delta)
	if delta <= 0.0 or relationship == null:
		return
	persistence_time_remaining -= delta
	disk_flush_time_remaining -= delta
	if persistence_time_remaining <= 0.0:
		persistence_time_remaining = 1.0
		persist_named_state(false)
	if disk_flush_time_remaining <= 0.0:
		disk_flush_time_remaining = 5.0
		if bond_store != null:
			bond_store.flush_if_dirty()


func _resolve_execution_action(move_id: String) -> String:
	if move_id == "idle" and perception != null and relationship != null:
		var grace: Node3D = _get_grace_target()
		var grace_distance: float = global_position.distance_to(grace.global_position) if grace != null else 999.0
		if grace != null and not _grace_is_current_threat(grace_distance):
			if bonded and follow_enabled and perception.remembers_target:
				return "follow_grace"
			if relationship_label == "curious" and perception.can_see_target:
				return "approach_grace"
			if relationship_label == "wary" and perception.can_see_target:
				return "watch_grace"
	return super._resolve_execution_action(move_id)


func _execute_current_action(delta: float) -> void:
	if not ["follow_grace", "approach_grace", "watch_grace"].has(current_action_id):
		super._execute_current_action(delta)
		return
	var grace: Node3D = _get_grace_target()
	if grace == null:
		current_action_id = "idle"
		current_move_id = "idle"
		return
	var distance: float = global_position.distance_to(grace.global_position)
	var direction: Vector3 = Vector3.ZERO
	var speed_multiplier: float = 0.75
	match current_action_id:
		"follow_grace":
			speed_multiplier = 1.0
			if distance > 3.1:
				direction = _direction_to(grace.global_position)
			elif distance < 1.55:
				direction = _flat_direction(global_position - grace.global_position)
		"approach_grace":
			var preferred: float = maxf(relationship.get_personal_space() + 0.55, 2.1)
			if distance > preferred:
				direction = _direction_to(grace.global_position)
			elif distance < relationship.get_personal_space():
				direction = _flat_direction(global_position - grace.global_position)
		"watch_grace":
			var comfort: float = relationship.get_comfort_distance()
			if distance < comfort:
				direction = _flat_direction(global_position - grace.global_position)
	var target_velocity: Vector3 = direction * move_speed * speed_multiplier
	velocity.x = move_toward(velocity.x, target_velocity.x, move_speed * 4.0 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, move_speed * 4.0 * delta)
	var facing: Vector3 = _flat_direction(grace.global_position - global_position)
	if facing.length_squared() > 0.001:
		var target_yaw: float = atan2(-facing.x, -facing.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * turn_speed, 0.0, 1.0))
	if action_time_remaining <= 0.0:
		current_action_id = "idle"
		current_move_id = "idle"


func _action_duration(move_id: String, effect: Dictionary) -> float:
	match move_id:
		"follow_grace": return 1.8
		"approach_grace": return 1.4
		"watch_grace": return 1.5
		_: return super._action_duration(move_id, effect)


func _grace_is_current_threat(grace_distance: float) -> bool:
	if bonded and not _is_grace_threatening():
		return false
	return super._grace_is_current_threat(grace_distance)


func _derive_persistent_id() -> String:
	var slug: String = animal_name.to_lower().strip_edges().replace(" ", "_")
	return "named_animal:" + species_id.to_lower().strip_edges() + ":" + slug
