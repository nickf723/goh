extends CharacterBody3D
class_name GenericAnimalActor

const EffectExecutorScript = preload(
	"res://scripts/mobs/mob_move_effect_executor.gd"
)
const VitalsScript = preload(
	"res://scripts/mobs/mob_vitals_component.gd"
)
const ConditionScript = preload(
	"res://scripts/combat/status_receiver.gd"
)
const LocomotionExecutorScript = preload(
	"res://scripts/mobs/mob_locomotion_executor.gd"
)

signal action_changed(move_id: String, intention_id: String)
signal selected_changed(selected: bool)
signal relationship_changed(label: String, trust: float)
signal perception_changed(stimulus_kind: String, awareness: float)
signal action_effect_resolved(move_id: String, result: Dictionary)

@export var species_id: String = "sheep"
@export var animal_name: String = "Animal"
@export var personality_profile_id: String = "balanced"
@export var move_speed: float = 2.4
@export var turn_speed: float = 6.0
@export var wander_radius: float = 2.5
@export var gravity: float = 18.0
@export var decision_interval: float = 0.65
@export var initial_locomotion_mode: String = ""

var brain: MobBrainComponent
var effect_executor: MobMoveEffectExecutor
var vitals: MobVitalsComponent
var condition_state: Node
var locomotion: MobLocomotionExecutor
var perception: AnimalPerceptionMemory
var relationship: AnimalRelationshipState
var perception_snapshot: Dictionary = {}
var relationship_label: String = "neutral"
var home_position: Vector3
var current_action_id: String = "idle"
var current_move_id: String = "idle"
var current_intention_id: String = "observe"
var action_time_remaining: float = 0.0
var decision_time_remaining: float = 0.0
var wander_target: Vector3
var wander_time_remaining: float = 0.0
var elapsed: float = 0.0
var selected: bool = false
var initial_position: Vector3
var visual_root: Node3D
var head_root: Node3D
var state_label: Label3D
var selection_marker: MeshInstance3D
var body_material: StandardMaterial3D
var accent_material: StandardMaterial3D
var flash_time_remaining: float = 0.0
var alert_broadcast_cooldown: float = 0.0
var previous_relationship_label: String = ""
var previous_stimulus_kind: String = ""
var last_effect_result: Dictionary = {}
var last_locomotion_solution: Dictionary = {}


func _ready() -> void:
	initial_position = global_position
	home_position = global_position
	wander_target = home_position
	add_to_group("generic_animals")
	add_to_group("debuggable")
	_build_collision()
	_build_visual()
	_build_vitals()
	_build_conditions()
	_build_locomotion()
	_build_brain()
	_build_social_state()
	decision_time_remaining = randf_range(0.1, decision_interval)


func _physics_process(delta: float) -> void:
	elapsed += delta
	flash_time_remaining = maxf(flash_time_remaining - delta, 0.0)
	decision_time_remaining -= delta
	wander_time_remaining -= delta
	alert_broadcast_cooldown = maxf(alert_broadcast_cooldown - delta, 0.0)
	if vitals != null and vitals.incapacitated:
		_halt_for_inactive_state(delta)
		return
	if is_action_blocked_by_status():
		_interrupt_current_action("status_blocked", true)
		_halt_for_inactive_state(delta)
		return
	_update_perception_and_relationship(delta)
	if brain != null and brain.has_active_move():
		var execution: Dictionary = brain.advance_active_move(delta)
		action_time_remaining = float(execution.get("remaining", 0.0))
		if bool(execution.get("completed", false)):
			_finish_current_action()
	else:
		action_time_remaining = 0.0
	if decision_time_remaining <= 0.0 and (brain == null or not brain.has_active_move()):
		force_decision(false)
	_execute_current_action(delta)
	_apply_gravity(delta)
	move_and_slide()
	_keep_inside_lab()
	_update_visual(delta)


func _halt_for_inactive_state(delta: float) -> void:
	_resolve_locomotion_velocity(Vector3.ZERO, delta, 1.0)
	_apply_gravity(delta)
	move_and_slide()
	_keep_inside_lab()
	_update_visual(delta)


func is_action_blocked_by_status() -> bool:
	return (
		condition_state != null
		and condition_state.has_method("blocks_actions")
		and bool(condition_state.call("blocks_actions"))
	)


func get_status_movement_multiplier() -> float:
	if (
		condition_state == null
		or not condition_state.has_method("get_movement_multiplier")
	):
		return 1.0
	return clampf(
		float(condition_state.call("get_movement_multiplier")),
		0.0,
		1.0
	)


func force_decision(refresh_perception: bool = true) -> Dictionary:
	if brain == null:
		return {}
	if vitals != null and vitals.incapacitated:
		return {"blocked": true, "reason": "incapacitated"}
	if is_action_blocked_by_status():
		return {"blocked": true, "reason": "status"}
	if refresh_perception:
		_update_perception_and_relationship(0.0)
	decision_time_remaining = decision_interval
	return brain.request_decision(get_mob_decision_context())


func get_mob_decision_context() -> Dictionary:
	var grace: Node3D = _get_grace_target()
	var target_position: Vector3 = (
		perception.get_target_position(grace.global_position if grace != null else home_position)
		if perception != null
		else (grace.global_position if grace != null else home_position)
	)
	var target_distance: float = global_position.distance_to(target_position)
	var forage_position: Vector3 = _get_lab_position("get_animal_forage_position", home_position)
	var water_position: Vector3 = _get_lab_position("get_animal_water_position", home_position)
	var forage_distance: float = global_position.distance_to(forage_position)
	var water_distance: float = global_position.distance_to(water_position)
	var context_tags: Array[String] = []
	var enemy_count: int = 0
	var aware_of_grace: bool = perception != null and (
		perception.can_see_target
		or perception.can_hear_target
		or perception.remembers_target
	)
	var grace_threat: bool = _grace_is_current_threat(target_distance)

	if perception != null:
		if perception.can_see_target:
			context_tags.append("line_of_sight")
			context_tags.append("grace_visible")
		if perception.can_hear_target:
			context_tags.append("heard_disturbance")
		if perception.remembers_target and not perception.can_see_target:
			context_tags.append("remembers_grace")
		if perception.social_alert_remaining > 0.0:
			context_tags.append("social_alert")
		if perception.awareness >= 0.6:
			context_tags.append("alert")

	context_tags.append("relationship_" + relationship_label)
	if vitals != null:
		var health_ratio: float = vitals.get_health_ratio()
		if health_ratio <= 0.65:
			context_tags.append("injured")
		if health_ratio <= 0.3:
			context_tags.append("critical_health")
	if aware_of_grace and grace_threat:
		enemy_count = 1
		if target_distance <= 3.0:
			context_tags.append("target_close")
		if species_id == "wolf" or relationship_label == "hostile":
			context_tags.append("hostile")
			context_tags.append("hunting")
			if _same_species_ally_count() > 0:
				context_tags.append("protecting_pack")
		else:
			context_tags.append("threatened")
			context_tags.append("predator_near")
			if target_distance <= 1.7:
				context_tags.append("cornered")
	else:
		context_tags.append("safe")
		if aware_of_grace and ["curious", "trusting"].has(relationship_label):
			context_tags.append("curious_about_grace")
		if perception != null and perception.can_hear_target and not perception.can_see_target:
			context_tags.append("investigating_noise")

	if not grace_threat:
		if species_id == "sheep":
			target_distance = forage_distance
			if forage_distance <= 2.4:
				context_tags.append("lush_forage")
		elif species_id == "capybara":
			target_distance = minf(forage_distance, water_distance)
			context_tags.append("hot")
			if water_distance <= 12.0:
				context_tags.append("water_near")
			if forage_distance <= 2.4:
				context_tags.append("lush_forage")
		elif not aware_of_grace:
			target_distance = 0.0

	return {
		"target_distance": target_distance,
		"self_health_ratio": (
			vitals.get_health_ratio()
			if vitals != null
			else 1.0
		),
		"target_health_ratio": 1.0,
		"ally_count": _same_species_ally_count(),
		"enemy_count": enemy_count,
		"context_tags": context_tags,
		"self_tags": _get_mob_self_tags(),
		"scalar_values": {
			"forage_distance": forage_distance,
			"water_distance": water_distance,
			"grace_distance": global_position.distance_to(grace.global_position) if grace != null else 999.0,
			"awareness": perception.awareness if perception != null else 0.0,
			"trust": relationship.trust if relationship != null else 0.0,
			"familiarity": relationship.familiarity if relationship != null else 0.0,
		},
	}


func set_selected(value: bool) -> void:
	selected = value
	if selection_marker != null:
		selection_marker.visible = selected
	selected_changed.emit(selected)


func set_drive(drive_id: String, value: float) -> void:
	if brain != null:
		brain.set_drive(drive_id, value)
		brain.clear_memory()
		decision_time_remaining = 0.0


func add_drive(drive_id: String, delta: float) -> void:
	if brain != null:
		brain.add_drive(drive_id, delta)
		decision_time_remaining = 0.0


func get_drive(drive_id: String) -> float:
	return brain.get_drive(drive_id) if brain != null else 0.0


func get_relationship_label() -> String:
	return relationship_label


func get_relationship_data() -> Dictionary:
	var data: Dictionary = relationship.to_dictionary() if relationship != null else {}
	data["relationship_label"] = relationship_label
	return data


func get_perception_data() -> Dictionary:
	return perception_snapshot.duplicate(true)


func get_vitals_data() -> Dictionary:
	return vitals.to_dictionary() if vitals != null else {}


func receive_damage_payload(payload: Variant) -> Dictionary:
	if vitals == null:
		return {"ok": false, "error": "animal vitals unavailable"}
	var result: Dictionary = vitals.receive_damage_payload(payload)
	_apply_payload_condition(payload)
	if float(result.get("damage_dealt", 0.0)) > 0.0:
		_interrupt_current_action("damage_received", true)
		if species_id in ["wolf", "gorgon"]:
			set_drive("territorial_pressure", 1.0)
		else:
			set_drive("fear", 1.0)
		decision_time_remaining = 0.0
	return result


func _apply_payload_condition(payload: Variant) -> void:
	if condition_state == null:
		return
	var status_id: String = str(_payload_property(
		payload,
		"status_effect",
		""
	)).to_lower().strip_edges()
	var duration: float = maxf(float(_payload_property(
		payload,
		"status_duration",
		0.0
	)), 0.0)
	if status_id == "" or duration <= 0.0:
		return
	condition_state.call(
		"sustain_status",
		status_id,
		duration,
		maxf(float(_payload_property(payload, "status_strength", 1.0)), 0.0),
		str(_payload_property(payload, "source_name", "Mob Move"))
	)


func _payload_property(
	payload: Variant,
	property_name: String,
	fallback: Variant
) -> Variant:
	if payload is Dictionary:
		return (payload as Dictionary).get(property_name, fallback)
	if payload is Object:
		var raw_value: Variant = (payload as Object).get(property_name)
		return fallback if raw_value == null else raw_value
	return fallback


func _get_condition_ids() -> Array[String]:
	var ids: Array[String] = []
	if (
		condition_state == null
		or not condition_state.has_method("get_active_status_names")
	):
		return ids
	var raw_ids: Variant = condition_state.call("get_active_status_names")
	if raw_ids is Array:
		for raw_id: Variant in raw_ids as Array:
			var condition_id: String = str(raw_id).to_lower().strip_edges()
			if condition_id != "" and not ids.has(condition_id):
				ids.append(condition_id)
	ids.sort()
	return ids


func _get_condition_context_tags() -> Array[String]:
	if (
		condition_state != null
		and condition_state.has_method("get_context_tags")
	):
		var raw_tags: Variant = condition_state.call("get_context_tags")
		var tags: Array[String] = []
		if raw_tags is Array:
			for raw_tag: Variant in raw_tags as Array:
				tags.append(str(raw_tag))
		return tags
	var fallback: Array[String] = []
	for condition_id: String in _get_condition_ids():
		fallback.append(condition_id)
		fallback.append("status:" + condition_id)
	return fallback


func _get_mob_self_tags() -> Array[String]:
	var tags: Array[String] = _get_condition_context_tags()
	if locomotion != null:
		for locomotion_tag: String in locomotion.get_context_tags():
			if not tags.has(locomotion_tag):
				tags.append(locomotion_tag)
	return tags


func receive_mob_recovery(
	effect: Dictionary,
	request: Dictionary = {}
) -> Dictionary:
	if vitals == null:
		return {"ok": false, "error": "animal vitals unavailable"}
	return vitals.receive_mob_recovery(effect, request)


func interact_with_grace(interaction_id: String) -> Dictionary:
	if relationship == null:
		return {"ok": false, "error": "relationship unavailable"}
	var grace: Node3D = _get_grace_target()
	if grace == null:
		return {"ok": false, "error": "Grace unavailable"}
	var distance: float = global_position.distance_to(grace.global_position)
	var normalized_id: String = interaction_id.to_lower().strip_edges()
	var maximum_distance: float = 4.4
	if normalized_id == "startle":
		maximum_distance = 8.0
	if distance > maximum_distance:
		return {
			"ok": false,
			"error": "too far",
			"distance": distance,
			"maximum_distance": maximum_distance,
		}
	var result: Dictionary = relationship.apply_interaction(normalized_id)
	if not bool(result.get("ok", false)):
		return result
	if ["startle", "attack"].has(normalized_id):
		_interrupt_current_action("relationship_" + normalized_id, true)
	match normalized_id:
		"feed":
			set_drive("hunger", 0.0)
			add_drive("fear", -0.2)
		"soothe":
			add_drive("fear", -0.48)
			add_drive("social_need", -0.18)
		"startle":
			set_drive("fear", 1.0)
			if perception != null:
				perception.receive_social_alert(grace.global_position, 1.0, 4.5)
			_broadcast_alert(grace.global_position, 1.0)
		"attack":
			set_drive("fear", 1.0)
			set_drive("territorial_pressure", 1.0)
			_broadcast_alert(grace.global_position, 1.0)
	relationship_label = relationship.get_relationship_label(get_drive("fear"))
	brain.clear_memory()
	force_decision(true)
	result["relationship_label"] = relationship_label
	return result


func receive_social_alert(position: Vector3, severity: float = 0.65) -> void:
	if perception == null:
		return
	perception.receive_social_alert(position, severity, 3.5)
	if species_id == "wolf":
		add_drive("territorial_pressure", severity * 0.22)
	else:
		add_drive("fear", severity * 0.28)
	decision_time_remaining = 0.0


func reset_actor() -> void:
	_interrupt_current_action("reset", true)
	global_position = initial_position
	velocity = Vector3.ZERO
	home_position = initial_position
	wander_target = home_position
	current_action_id = "idle"
	current_move_id = "idle"
	current_intention_id = "observe"
	action_time_remaining = 0.0
	decision_time_remaining = 0.1
	flash_time_remaining = 0.0
	alert_broadcast_cooldown = 0.0
	if brain != null:
		brain.clear_cooldowns()
		brain.clear_memory()
		brain.reset_drives()
	if effect_executor != null:
		effect_executor.reset_executor()
	if vitals != null:
		vitals.reset_to_full()
	if condition_state != null:
		condition_state.call("clear_all_statuses")
	if locomotion != null:
		locomotion.reset_executor()
	last_effect_result.clear()
	last_locomotion_solution.clear()
	_build_social_state()


func get_debug_data() -> Dictionary:
	return {
		"species_id": species_id,
		"animal_name": animal_name,
		"action": current_action_id,
		"move": current_move_id,
		"intention": current_intention_id,
		"selected": selected,
		"position": global_position,
		"relationship_label": relationship_label,
		"relationship": get_relationship_data(),
		"perception": get_perception_data(),
		"brain": brain.get_debug_data() if brain != null else {},
		"vitals": get_vitals_data(),
		"conditions": (
			condition_state.call("get_debug_data")
			if (
				condition_state != null
				and condition_state.has_method("get_debug_data")
			)
			else {}
		),
		"effect_executor": (
			effect_executor.get_debug_data()
			if effect_executor != null
			else {}
		),
		"locomotion": (
			locomotion.get_debug_data()
			if locomotion != null
			else {}
		),
		"last_effect_result": last_effect_result.duplicate(true),
		"last_locomotion_solution": last_locomotion_solution.duplicate(true),
	}


func _build_locomotion() -> void:
	locomotion = LocomotionExecutorScript.new() as MobLocomotionExecutor
	locomotion.name = "SwimmingController"
	var configuration: Dictionary = locomotion.configure_species(
		species_id,
		initial_locomotion_mode
	)
	if not bool(configuration.get("ok", false)):
		push_error(
			"GenericAnimalActor could not configure locomotion for "
			+ species_id
			+ ": "
			+ str(configuration.get("failures", []))
		)
	add_child(locomotion)


func _build_vitals() -> void:
	vitals = VitalsScript.new() as MobVitalsComponent
	vitals.name = "MobVitalsComponent"
	vitals.configure(species_id)
	add_child(vitals)


func _build_conditions() -> void:
	condition_state = ConditionScript.new()
	condition_state.name = "StatusReceiver"
	add_child(condition_state)


func _build_brain() -> void:
	brain = MobBrainComponent.new()
	brain.name = "MobBrainComponent"
	brain.species_id = species_id
	brain.personality_profile_id = personality_profile_id
	brain.automatic_decisions = false
	brain.decision_interval = decision_interval
	brain.intention_commitment_seconds = 1.6
	brain.intention_score_tolerance = 0.35
	brain.context_provider_path = NodePath("..")
	brain.move_selected.connect(_on_move_selected)
	add_child(brain)

	effect_executor = EffectExecutorScript.new() as MobMoveEffectExecutor
	effect_executor.name = "MobMoveEffectExecutor"
	effect_executor.target_provider_path = NodePath("..")
	effect_executor.bind_brain(brain)
	effect_executor.effect_execution_completed.connect(
		_on_effect_execution_completed
	)
	add_child(effect_executor)


func get_mob_effect_targets(request: Dictionary) -> Array[Node]:
	var targets: Array[Node] = []
	var target_mode: String = str(
		request.get("target_mode", "")
	).to_lower().strip_edges()
	match target_mode:
		"self":
			targets.append(self)
		"enemy", "area":
			var grace: Node3D = _get_grace_target()
			if grace != null:
				targets.append(grace)
		"allies":
			for candidate: Node in get_tree().get_nodes_in_group(
				"generic_animals"
			):
				if candidate == self:
					continue
				if str(candidate.get("species_id")) == species_id:
					targets.append(candidate)
	return targets


func get_mob_effect_origin(_request: Dictionary) -> Vector3:
	if head_root != null:
		return head_root.global_position
	return global_position + Vector3.UP * 0.72


func _on_effect_execution_completed(
	request: Dictionary,
	result: Dictionary
) -> void:
	last_effect_result = result.duplicate(true)
	action_effect_resolved.emit(
		str(request.get("move_id", "")),
		last_effect_result
	)


func _build_social_state() -> void:
	var traits: Dictionary = MobPersonalityAdapter.apply_profile_to_species(
		species_id,
		personality_profile_id
	)
	perception = AnimalPerceptionMemory.create_for_species(species_id, traits)
	relationship = AnimalRelationshipState.create_for_species(species_id, traits)
	perception_snapshot = perception.to_dictionary()
	relationship_label = relationship.get_relationship_label(get_drive("fear"))
	previous_relationship_label = relationship_label
	previous_stimulus_kind = "none"


func _update_perception_and_relationship(delta: float) -> void:
	if perception == null or relationship == null:
		return
	var grace: Node3D = _get_grace_target()
	var grace_speed: float = 0.0
	if grace is CharacterBody3D:
		var grace_velocity: Vector3 = (grace as CharacterBody3D).velocity
		grace_speed = Vector2(grace_velocity.x, grace_velocity.z).length()
	var noise_position: Vector3 = _get_lab_position(
		"get_animal_noise_position",
		grace.global_position if grace != null else global_position
	)
	var noise_strength: float = _get_lab_float("get_animal_noise_strength", 0.0)
	perception_snapshot = perception.update(
		self,
		grace,
		delta,
		noise_position,
		noise_strength,
		grace_speed
	)
	var grace_distance: float = (
		global_position.distance_to(grace.global_position)
		if grace != null
		else 999.0
	)
	relationship.tick(
		delta,
		perception_snapshot,
		grace_distance,
		_is_grace_threatening(),
		grace_speed,
		get_drive("fear")
	)
	relationship_label = relationship.get_relationship_label(get_drive("fear"))
	_apply_perception_to_drives(delta, grace_distance)
	_maybe_interrupt_ambient_action_for_threat(grace_distance)
	_maybe_share_alert()
	if relationship_label != previous_relationship_label:
		previous_relationship_label = relationship_label
		relationship_changed.emit(relationship_label, relationship.trust)
	var stimulus: String = str(perception_snapshot.get("stimulus_kind", "none"))
	if stimulus != previous_stimulus_kind:
		previous_stimulus_kind = stimulus
		perception_changed.emit(stimulus, perception.awareness)


func _apply_perception_to_drives(delta: float, grace_distance: float) -> void:
	if brain == null or perception == null or relationship == null or delta <= 0.0:
		return
	var aware: bool = perception.can_see_target or perception.can_hear_target or perception.remembers_target
	var grace_threat: bool = _grace_is_current_threat(grace_distance)
	if aware and grace_threat:
		if species_id == "wolf" or relationship_label == "hostile":
			brain.add_drive("territorial_pressure", delta * 0.12 * perception.awareness)
			brain.add_drive("fear", delta * 0.015)
		else:
			brain.add_drive("fear", delta * 0.18 * perception.awareness)
	elif perception.can_see_target and ["curious", "trusting"].has(relationship_label):
		brain.add_drive("curiosity", delta * 0.055)
		brain.add_drive("fear", -delta * 0.065)
	elif not aware:
		brain.add_drive("fear", -delta * 0.025)


func _grace_is_current_threat(grace_distance: float) -> bool:
	if perception == null or relationship == null:
		return false
	var aware: bool = perception.can_see_target or perception.can_hear_target or perception.remembers_target
	if not aware:
		return false
	if _is_grace_threatening():
		return true
	if relationship_label == "hostile" or relationship_label == "afraid":
		return true
	if relationship_label == "wary" and grace_distance < relationship.get_comfort_distance():
		return true
	return (
		species_id != "wolf"
		and grace_distance < relationship.get_personal_space()
		and relationship.trust < 0.45
	)


func _maybe_interrupt_ambient_action_for_threat(grace_distance: float) -> void:
	if brain == null or not brain.has_active_move() or not _grace_is_current_threat(grace_distance):
		return
	var execution: Dictionary = brain.get_active_execution()
	var move_data: Dictionary = execution.get("move", {}) as Dictionary
	var tags: Array = move_data.get("tags", []) as Array
	var ambient_response: bool = false
	for tag: String in ["ambient", "calm", "forage", "habitat"]:
		if tags.has(tag):
			ambient_response = true
			break
	if not ambient_response:
		return
	var interruption: Dictionary = _interrupt_current_action("new_threat")
	if bool(interruption.get("interrupted", false)):
		decision_time_remaining = 0.0


func _maybe_share_alert() -> void:
	if perception == null or alert_broadcast_cooldown > 0.0:
		return
	var grace_distance: float = global_position.distance_to(perception.last_known_position)
	if not _grace_is_current_threat(grace_distance):
		return
	if perception.awareness < 0.62:
		return
	var severity: float = clampf(
		0.45 + perception.awareness * 0.35 + get_drive("fear") * 0.2,
		0.0,
		1.0
	)
	_broadcast_alert(perception.last_known_position, severity)
	alert_broadcast_cooldown = 2.6


func _broadcast_alert(position: Vector3, severity: float) -> void:
	var lab: Node = get_parent()
	if lab != null and lab.has_method("broadcast_animal_alert"):
		lab.call("broadcast_animal_alert", self, position, severity)


func _on_move_selected(move_id: String, decision: Dictionary) -> void:
	if move_id == "" or brain == null:
		return
	var execution_action: String = _resolve_execution_action(move_id)
	var execution_context: Dictionary = {
		"actor_instance_id": get_instance_id(),
		"animal_name": animal_name,
		"source_name": animal_name + " • " + str(
			decision.get("display_name", move_id)
		),
		"decision": decision.duplicate(true),
	}
	if execution_action != move_id:
		var move_data: Dictionary = decision.get("move", {}) as Dictionary
		var effect: Dictionary = move_data.get("effect", {}) as Dictionary
		execution_context["duration_override"] = _action_duration(execution_action, effect)
	var started: Dictionary = brain.begin_move(move_id, execution_context)
	if not bool(started.get("ok", false)):
		return
	current_move_id = move_id
	current_action_id = execution_action
	current_intention_id = str(
		decision.get("intention_id", MobIntentionResolver.get_intention_id(decision))
	)
	if current_action_id == "investigate":
		current_intention_id = "investigate"
	var execution: Dictionary = started.get("execution", {}) as Dictionary
	action_time_remaining = float(execution.get("total_duration", 0.0))
	if ["bite", "headbutt", "pounce", "tail_sweep"].has(current_action_id):
		flash_time_remaining = 0.22
	action_changed.emit(current_action_id, current_intention_id)


func _resolve_execution_action(move_id: String) -> String:
	if move_id != "idle" or perception == null:
		return move_id
	if (
		perception.can_hear_target
		or perception.social_alert_remaining > 0.0
		or (
			perception.can_see_target
			and ["curious", "trusting", "wary"].has(relationship_label)
			and not _grace_is_current_threat(global_position.distance_to(perception.last_known_position))
		)
	):
		return "investigate"
	return "idle"


func _execute_current_action(delta: float) -> void:
	var direction: Vector3 = Vector3.ZERO
	match current_action_id:
		"graze":
			direction = _direction_to(_get_lab_position("get_animal_forage_position", home_position))
		"wade":
			direction = _direction_to(_get_lab_position("get_animal_water_position", home_position))
		"investigate":
			direction = _investigate_direction()
		"flee", "backstep":
			direction = _movement_direction(
				global_position - _remembered_grace_position()
			)
		"bite", "headbutt", "pounce", "tail_sweep", "stone_gaze", "mire_spit":
			direction = _direction_to(_remembered_grace_position())
		"howl":
			direction = Vector3.ZERO
		_:
			direction = _wander_direction()
	var speed_multiplier: float = 1.0
	if current_action_id == "flee":
		speed_multiplier = 1.55
	elif current_action_id == "pounce":
		speed_multiplier = 1.7
	elif current_action_id == "investigate":
		speed_multiplier = 0.82
	elif current_action_id in ["graze", "wade", "idle"]:
		speed_multiplier = 0.72
	_resolve_locomotion_velocity(direction, delta, speed_multiplier)
	if Vector2(direction.x, direction.z).length_squared() > 0.001:
		var target_yaw: float = atan2(-direction.x, -direction.z)
		var locomotion_turn: float = (
			locomotion.get_turn_multiplier()
			if locomotion != null
			else 1.0
		)
		rotation.y = lerp_angle(
			rotation.y,
			target_yaw,
			clampf(delta * turn_speed * locomotion_turn, 0.0, 1.0)
		)


func _finish_current_action() -> void:
	current_action_id = "idle"
	current_move_id = "idle"
	action_time_remaining = 0.0
	action_changed.emit(current_action_id, current_intention_id)


func _interrupt_current_action(reason: String, force: bool = false) -> Dictionary:
	if brain == null or not brain.has_active_move():
		return {"ok": false, "error": "no active move"}
	var interrupted: Dictionary = brain.interrupt_active_move(reason, force)
	if bool(interrupted.get("interrupted", false)):
		current_action_id = "idle"
		current_move_id = "idle"
		action_time_remaining = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		action_changed.emit(current_action_id, current_intention_id)
	return interrupted


func _investigate_direction() -> Vector3:
	if perception == null:
		return Vector3.ZERO
	var target_position: Vector3 = perception.get_target_position(home_position)
	var distance: float = global_position.distance_to(target_position)
	var preferred_distance: float = relationship.get_comfort_distance() if relationship != null else 3.0
	if relationship_label == "trusting":
		preferred_distance = maxf(preferred_distance * 0.55, 1.2)
	if distance <= preferred_distance:
		return Vector3.ZERO
	return _direction_to(target_position)


func _remembered_grace_position() -> Vector3:
	var grace: Node3D = _get_grace_target()
	if perception != null and perception.remembers_target:
		return perception.last_known_position
	return grace.global_position if grace != null else home_position


func _wander_direction() -> Vector3:
	if wander_time_remaining <= 0.0 or global_position.distance_to(wander_target) < 0.35:
		wander_time_remaining = randf_range(1.4, 3.2)
		var angle: float = randf() * TAU
		var radius: float = randf_range(0.35, wander_radius)
		wander_target = home_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	return _direction_to(wander_target)


func _direction_to(target_position: Vector3) -> Vector3:
	return _movement_direction(target_position - global_position)


func _movement_direction(offset: Vector3) -> Vector3:
	if locomotion != null:
		return locomotion.project_direction(offset)
	return _flat_direction(offset)


func _flat_direction(offset: Vector3) -> Vector3:
	offset.y = 0.0
	return offset.normalized() if offset.length_squared() > 0.01 else Vector3.ZERO


func _apply_gravity(delta: float) -> void:
	if locomotion != null and not locomotion.should_use_gravity():
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1


func _keep_inside_lab() -> void:
	var lab: Node = get_parent()
	if lab != null and lab.has_method("clamp_animal_position"):
		global_position = lab.call("clamp_animal_position", global_position)


func _action_duration(move_id: String, effect: Dictionary) -> float:
	if effect.has("duration") and move_id != "investigate":
		return clampf(float(effect.get("duration", 1.0)), 0.4, 3.0)
	match move_id:
		"graze": return 1.8
		"wade": return 2.2
		"investigate": return 1.35
		"howl": return 1.4
		"bite", "headbutt", "pounce", "tail_sweep": return 0.8
		_: return 1.0


func _resolve_locomotion_velocity(
	direction: Vector3,
	delta: float,
	action_speed_multiplier: float
) -> void:
	if locomotion == null:
		var target_velocity: Vector3 = (
			direction
			* move_speed
			* action_speed_multiplier
			* get_status_movement_multiplier()
		)
		velocity.x = move_toward(
			velocity.x,
			target_velocity.x,
			move_speed * 4.0 * delta
		)
		velocity.z = move_toward(
			velocity.z,
			target_velocity.z,
			move_speed * 4.0 * delta
		)
		return
	last_locomotion_solution = locomotion.resolve_velocity(
		direction,
		velocity,
		move_speed
			* action_speed_multiplier
			* get_status_movement_multiplier(),
		move_speed * 4.0,
		delta
	)
	var solved_velocity: Variant = last_locomotion_solution.get(
		"velocity",
		velocity
	)
	if solved_velocity is Vector3:
		velocity = solved_velocity as Vector3


func get_active_locomotion_mode() -> String:
	return locomotion.active_mode if locomotion != null else "ground"


func request_locomotion_mode(
	mode_id: String,
	context: Dictionary = {}
) -> Dictionary:
	if locomotion == null:
		return {
			"ok": false,
			"error": "animal locomotion executor unavailable",
		}
	return locomotion.request_mode(mode_id, context)


func _same_species_ally_count() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("generic_animals"):
		if node == self or not node is GenericAnimalActor:
			continue
		if (node as GenericAnimalActor).species_id == species_id:
			count += 1
	return count


func _get_grace_target() -> Node3D:
	var target: Node3D = _get_lab_node("get_animal_grace_target")
	if target == null:
		target = _get_lab_node("get_animal_threat_target")
	return target


func _is_grace_threatening() -> bool:
	var lab: Node = get_parent()
	if lab != null and lab.has_method("is_grace_threatening"):
		return bool(lab.call("is_grace_threatening", self))
	return _get_lab_bool("is_animal_threat_mode_enabled")


func _get_lab_node(method_name: String) -> Node3D:
	var lab: Node = get_parent()
	if lab != null and lab.has_method(method_name):
		var value: Variant = lab.call(method_name, self)
		if value is Node3D:
			return value as Node3D
	return null


func _get_lab_position(method_name: String, fallback: Vector3) -> Vector3:
	var lab: Node = get_parent()
	if lab != null and lab.has_method(method_name):
		var value: Variant = lab.call(method_name, self)
		if value is Vector3:
			return value as Vector3
	return fallback


func _get_lab_bool(method_name: String) -> bool:
	var lab: Node = get_parent()
	return bool(lab.call(method_name, self)) if lab != null and lab.has_method(method_name) else false


func _get_lab_float(method_name: String, fallback: float) -> float:
	var lab: Node = get_parent()
	return float(lab.call(method_name, self)) if lab != null and lab.has_method(method_name) else fallback


func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.15
	collision.shape = shape
	collision.position.y = 0.58
	add_child(collision)


func _build_visual() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	body_material = StandardMaterial3D.new()
	accent_material = StandardMaterial3D.new()
	body_material.roughness = 0.82
	accent_material.roughness = 0.72
	match species_id:
		"sheep":
			body_material.albedo_color = Color(0.82, 0.84, 0.78)
			accent_material.albedo_color = Color(0.18, 0.16, 0.14)
			_build_quadruped(Vector3(0.62, 0.48, 0.84), 0.34, true, false)
		"capybara":
			body_material.albedo_color = Color(0.48, 0.28, 0.14)
			accent_material.albedo_color = Color(0.22, 0.11, 0.06)
			_build_quadruped(Vector3(0.58, 0.48, 0.9), 0.4, false, false)
		"wolf":
			body_material.albedo_color = Color(0.28, 0.34, 0.4)
			accent_material.albedo_color = Color(0.08, 0.1, 0.13)
			_build_quadruped(Vector3(0.54, 0.46, 0.86), 0.32, false, true)
		_:
			body_material.albedo_color = Color(0.45, 0.48, 0.5)
			accent_material.albedo_color = Color(0.12, 0.14, 0.16)
			_build_quadruped(Vector3(0.55, 0.48, 0.78), 0.34, false, false)
	selection_marker = MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0.72
	marker_mesh.bottom_radius = 0.72
	marker_mesh.height = 0.035
	selection_marker.mesh = marker_mesh
	selection_marker.position.y = 0.04
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.78, 0.12, 0.7)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.emission_enabled = true
	marker_material.emission = Color(1.0, 0.52, 0.04)
	marker_material.emission_energy_multiplier = 1.8
	selection_marker.material_override = marker_material
	selection_marker.visible = false
	add_child(selection_marker)
	state_label = Label3D.new()
	state_label.position = Vector3(0.0, 2.05, 0.0)
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.font_size = 18
	state_label.pixel_size = 0.006
	state_label.outline_size = 7
	state_label.modulate = Color(0.96, 0.96, 0.9)
	add_child(state_label)


func _build_quadruped(
	body_scale: Vector3,
	head_radius: float,
	woolly: bool,
	pointed: bool
) -> void:
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.58
	body_mesh.height = 1.16
	body.mesh = body_mesh
	body.scale = body_scale
	body.position = Vector3(0.0, 0.82, 0.0)
	body.material_override = body_material
	visual_root.add_child(body)
	if woolly:
		for offset: Vector3 in [Vector3(-0.28, 0.92, 0.0), Vector3(0.28, 0.92, 0.0), Vector3(0.0, 1.05, 0.2)]:
			var puff := MeshInstance3D.new()
			var puff_mesh := SphereMesh.new()
			puff_mesh.radius = 0.33
			puff_mesh.height = 0.66
			puff.mesh = puff_mesh
			puff.position = offset
			puff.material_override = body_material
			visual_root.add_child(puff)
	head_root = Node3D.new()
	head_root.position = Vector3(0.0, 1.02, -0.72)
	visual_root.add_child(head_root)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = head_radius
	head_mesh.height = head_radius * 2.0
	head.mesh = head_mesh
	head.scale = Vector3(0.82, 0.9, 1.0)
	head.material_override = accent_material if species_id == "sheep" else body_material
	head_root.add_child(head)
	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var ear_mesh := PrismMesh.new()
		ear_mesh.size = Vector3(0.16, 0.1, 0.3 if pointed else 0.2)
		ear.mesh = ear_mesh
		ear.position = Vector3(side * head_radius * 0.72, head_radius * 0.45, 0.0)
		ear.rotation_degrees = Vector3(0.0, 0.0, side * -24.0)
		ear.material_override = accent_material
		head_root.add_child(ear)
	for x: float in [-0.3, 0.3]:
		for z: float in [-0.38, 0.38]:
			var leg := MeshInstance3D.new()
			var leg_mesh := CylinderMesh.new()
			leg_mesh.top_radius = 0.075
			leg_mesh.bottom_radius = 0.09
			leg_mesh.height = 0.62
			leg.mesh = leg_mesh
			leg.position = Vector3(x, 0.36, z)
			leg.material_override = accent_material
			visual_root.add_child(leg)
	if pointed:
		var tail := MeshInstance3D.new()
		var tail_mesh := PrismMesh.new()
		tail_mesh.size = Vector3(0.18, 0.18, 0.6)
		tail.mesh = tail_mesh
		tail.position = Vector3(0.0, 0.9, 0.72)
		tail.rotation_degrees.x = -20.0
		tail.material_override = body_material
		visual_root.add_child(tail)


func _update_visual(delta: float) -> void:
	if visual_root != null:
		var movement_amount: float = Vector2(velocity.x, velocity.z).length()
		visual_root.position.y = absf(sin(elapsed * 8.0)) * movement_amount * 0.018
	if head_root != null:
		var target_pitch: float = 0.0
		if current_action_id == "graze":
			target_pitch = 48.0 + sin(elapsed * 5.0) * 8.0
		elif current_action_id == "howl":
			target_pitch = -28.0
		head_root.rotation_degrees.x = lerpf(head_root.rotation_degrees.x, target_pitch, clampf(delta * 6.0, 0.0, 1.0))
	if body_material != null:
		body_material.emission_enabled = flash_time_remaining > 0.0
		body_material.emission = Color(1.0, 0.18, 0.08)
		body_material.emission_energy_multiplier = 2.4
	if state_label != null:
		var stimulus: String = str(perception_snapshot.get("stimulus_kind", "none"))
		var condition_ids: Array[String] = _get_condition_ids()
		var condition_line: String = (
			"\nStatus " + ", ".join(condition_ids)
			if not condition_ids.is_empty()
			else ""
		)
		state_label.text = (
			animal_name + " • " + relationship_label.capitalize()
			+ "\n" + current_intention_id.capitalize()
			+ " • " + current_action_id.replace("_", " ").capitalize()
			+ "\n" + stimulus.replace("_", " ").capitalize()
			+ "  Trust " + _signed_percent(relationship.trust if relationship != null else 0.0)
			+ "\nHP " + _percent(
				vitals.get_health_ratio() if vitals != null else 1.0
			)
			+ "  H " + _percent(get_drive("hunger"))
			+ "  F " + _percent(get_drive("fear"))
			+ "  S " + _percent(get_drive("social_need"))
			+ condition_line
		)
		state_label.modulate = Color(1.0, 0.82, 0.28) if selected else _relationship_color()


func _relationship_color() -> Color:
	match relationship_label:
		"hostile": return Color(1.0, 0.28, 0.18)
		"afraid": return Color(1.0, 0.66, 0.22)
		"wary": return Color(1.0, 0.88, 0.4)
		"curious": return Color(0.46, 0.88, 1.0)
		"trusting": return Color(0.42, 1.0, 0.62)
		_: return Color(0.96, 0.96, 0.9)


func _percent(value: float) -> String:
	return str(int(round(clampf(value, 0.0, 1.0) * 100.0)))


func _signed_percent(value: float) -> String:
	var amount: int = int(round(clampf(value, -1.0, 1.0) * 100.0))
	return ("+" if amount >= 0 else "") + str(amount)
