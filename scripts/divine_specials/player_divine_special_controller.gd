extends Node
class_name PlayerDivineSpecialController

signal charge_changed(current: float, maximum: float, reason: String)
signal selected_special_changed(definition: DivineSpecialDefinition)
signal special_started(definition: DivineSpecialDefinition, effect: DivineSpecialEffect)
signal special_finished(definition: DivineSpecialDefinition, success: bool, result: Dictionary)
signal special_failed(special_id: String, reason: String)

@export_group("Catalog")
@export var special_definitions: Array[DivineSpecialDefinition] = []
@export_range(1.0, 100.0, 1.0) var maximum_charge: float = 100.0
@export_range(5.0, 300.0, 1.0) var fallback_recharge_seconds: float = 75.0
@export var passive_recharge_enabled: bool = true
@export var start_fully_charged_in_debug: bool = true

@export_group("Combat Recharge")
@export_range(0.0, 20.0, 0.1) var connected_attack_charge: float = 3.0
@export_range(0.0, 20.0, 0.1) var heavy_attack_charge_bonus: float = 1.5
@export_range(0.0, 20.0, 0.1) var deep_combo_charge_bonus: float = 1.0
@export_range(0.0, 20.0, 0.1) var spell_cast_charge: float = 1.5

@export_group("Debug Access")
@export var debug_input_enabled: bool = true
@export var activate_key: Key = KEY_F11
@export var refill_key: Key = KEY_F6

var actor: CharacterBody3D
var action_state: PlayerActionState
var avatar_manager: PlayerAvatarManager
var manifestation_manager: PlayerManifestationManager
var weapon_controller: WeaponController
var authority_controller: PlayerElementalAuthorityController
var combat_footwork_controller: PlayerCombatFootworkController
var dodge_controller: PlayerDodgeController

var selected_index: int = 0
var divine_charge: float = 0.0
var active_recharge_seconds: float = 75.0
var active_definition: DivineSpecialDefinition
var active_effect: DivineSpecialEffect
var active_timeout_remaining: float = 0.0
var last_result: String = "not_initialized"
var last_failure: String = ""
var last_charge_reason: String = "none"
var last_effect_result: Dictionary = {}
var total_activations: int = 0
var total_completions: int = 0
var total_failures: int = 0
var total_charge_awarded: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	actor = get_parent() as CharacterBody3D
	_resolve_bindings()
	_connect_signals()
	add_to_group("player_divine_special_controller")
	add_to_group("divine_special_controller")
	add_to_group("debuggable")
	active_recharge_seconds = maxf(fallback_recharge_seconds, 1.0)
	divine_charge = (
		maximum_charge
		if OS.is_debug_build() and start_fully_charged_in_debug
		else 0.0
	)
	_ensure_valid_selection(OS.is_debug_build())
	last_result = "ready"
	charge_changed.emit(divine_charge, maximum_charge, "initialization")


func _exit_tree() -> void:
	_disconnect_signals()
	if active_effect != null and is_instance_valid(active_effect):
		active_effect.cancel_special("controller_exit")
	active_effect = null
	active_definition = null


func _process(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	if active_effect != null and not is_instance_valid(active_effect):
		active_effect = null
		active_definition = null
		active_timeout_remaining = 0.0
		last_result = "effect_lost"
	if active_effect != null:
		active_timeout_remaining = maxf(
			active_timeout_remaining - step,
			0.0
		)
		if active_timeout_remaining <= 0.0:
			cancel_active_special("action_timeout")
		return
	if passive_recharge_enabled and divine_charge < maximum_charge:
		var recharge_per_second: float = (
			maximum_charge / maxf(active_recharge_seconds, 1.0)
		)
		award_charge(recharge_per_second * step, "passive_recharge", false)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_input_enabled or not OS.is_debug_build():
		return
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == refill_key:
		force_full_charge("debug_refill")
		get_viewport().set_input_as_handled()
		return
	if key_event.physical_keycode != activate_key:
		return
	if key_event.shift_pressed:
		cycle_special(1, true)
	else:
		activate_selected_special(true)
	get_viewport().set_input_as_handled()


func _resolve_bindings() -> void:
	if actor == null:
		return
	action_state = actor.get_node_or_null("PlayerActionState") as PlayerActionState
	avatar_manager = actor.get_node_or_null("AvatarManager") as PlayerAvatarManager
	manifestation_manager = actor.get_node_or_null(
		"ManifestationManager"
	) as PlayerManifestationManager
	weapon_controller = actor.get_node_or_null(
		"WeaponController"
	) as WeaponController
	authority_controller = actor.get_node_or_null(
		"ElementalAuthorityController"
	) as PlayerElementalAuthorityController
	combat_footwork_controller = actor.get_node_or_null(
		"CombatFootworkController"
	) as PlayerCombatFootworkController
	dodge_controller = actor.get_node_or_null(
		"PlayerDodgeController"
	) as PlayerDodgeController


func _connect_signals() -> void:
	if weapon_controller != null and not weapon_controller.attack_finished.is_connected(
		_on_attack_finished
	):
		weapon_controller.attack_finished.connect(_on_attack_finished)
	if authority_controller != null and not authority_controller.authority_cast_finished.is_connected(
		_on_authority_cast_finished
	):
		authority_controller.authority_cast_finished.connect(
			_on_authority_cast_finished
		)
	if avatar_manager != null:
		if not avatar_manager.avatar_transition_started.is_connected(
			_on_avatar_transition_started
		):
			avatar_manager.avatar_transition_started.connect(
				_on_avatar_transition_started
			)
		if not avatar_manager.avatar_dismissed.is_connected(_on_avatar_dismissed):
			avatar_manager.avatar_dismissed.connect(_on_avatar_dismissed)
	if manifestation_manager != null and not manifestation_manager.manifestation_started.is_connected(
		_on_manifestation_started
	):
		manifestation_manager.manifestation_started.connect(
			_on_manifestation_started
		)
	if not GameState.player_defeated.is_connected(_on_player_defeated):
		GameState.player_defeated.connect(_on_player_defeated)
	if not GameState.unlock_changed.is_connected(_on_unlock_changed):
		GameState.unlock_changed.connect(_on_unlock_changed)


func _disconnect_signals() -> void:
	if weapon_controller != null and weapon_controller.attack_finished.is_connected(
		_on_attack_finished
	):
		weapon_controller.attack_finished.disconnect(_on_attack_finished)
	if authority_controller != null and authority_controller.authority_cast_finished.is_connected(
		_on_authority_cast_finished
	):
		authority_controller.authority_cast_finished.disconnect(
			_on_authority_cast_finished
		)
	if avatar_manager != null:
		if avatar_manager.avatar_transition_started.is_connected(
			_on_avatar_transition_started
		):
			avatar_manager.avatar_transition_started.disconnect(
				_on_avatar_transition_started
			)
		if avatar_manager.avatar_dismissed.is_connected(_on_avatar_dismissed):
			avatar_manager.avatar_dismissed.disconnect(_on_avatar_dismissed)
	if manifestation_manager != null and manifestation_manager.manifestation_started.is_connected(
		_on_manifestation_started
	):
		manifestation_manager.manifestation_started.disconnect(
			_on_manifestation_started
		)
	if GameState.player_defeated.is_connected(_on_player_defeated):
		GameState.player_defeated.disconnect(_on_player_defeated)
	if GameState.unlock_changed.is_connected(_on_unlock_changed):
		GameState.unlock_changed.disconnect(_on_unlock_changed)


func get_available_specials(
	force_debug: bool = false
) -> Array[DivineSpecialDefinition]:
	var available: Array[DivineSpecialDefinition] = []
	for definition_index: int in range(special_definitions.size()):
		var definition: DivineSpecialDefinition = special_definitions[definition_index]
		if definition == null:
			continue
		if definition.validate_definition().is_empty() and definition.is_unlocked(
			force_debug
		):
			available.append(definition)
	return available


func get_selected_special(
	force_debug: bool = false
) -> DivineSpecialDefinition:
	var available: Array[DivineSpecialDefinition] = get_available_specials(force_debug)
	if available.is_empty():
		return null
	selected_index = posmod(selected_index, available.size())
	return available[selected_index]


func cycle_special(direction: int = 1, force_debug: bool = false) -> bool:
	var available: Array[DivineSpecialDefinition] = get_available_specials(force_debug)
	if available.is_empty():
		return _fail("none", "No Divine Specials are unlocked.")
	selected_index = posmod(
		selected_index + (1 if direction >= 0 else -1),
		available.size()
	)
	var selected: DivineSpecialDefinition = available[selected_index]
	last_result = "selection_changed"
	last_failure = ""
	selected_special_changed.emit(selected)
	_show_message("Divine Special: " + selected.display_name)
	return true


func select_special_by_id(
	special_id: String,
	force_debug: bool = false
) -> bool:
	var available: Array[DivineSpecialDefinition] = get_available_specials(force_debug)
	for available_index: int in range(available.size()):
		var definition: DivineSpecialDefinition = available[available_index]
		if definition.special_id != special_id:
			continue
		selected_index = available_index
		last_result = "selection_changed"
		last_failure = ""
		selected_special_changed.emit(definition)
		return true
	return _fail(special_id, "That Divine Special is not unlocked.")


func activate_selected_special(force_debug: bool = false) -> bool:
	var definition: DivineSpecialDefinition = get_selected_special(force_debug)
	if definition == null:
		return _fail("none", "No Divine Special is available.")
	var target_data: Dictionary = resolve_special_target(definition)
	if not bool(target_data.get("valid", false)):
		return _fail(
			definition.special_id,
			str(target_data.get("reason", "No valid target."))
		)
	return activate_special_at(
		definition,
		target_data.get("position", actor.global_position) as Vector3,
		target_data.get("direction", Vector3.FORWARD) as Vector3,
		force_debug
	)


func activate_special_by_id_at(
	special_id: String,
	world_position: Vector3,
	direction: Vector3,
	force_debug: bool = false
) -> bool:
	var definition: DivineSpecialDefinition = get_definition_by_id(special_id)
	if definition == null:
		return _fail(special_id, "Unknown Divine Special.")
	return activate_special_at(
		definition,
		world_position,
		direction,
		force_debug
	)


func activate_special_at(
	definition: DivineSpecialDefinition,
	world_position: Vector3,
	direction: Vector3,
	force_debug: bool = false
) -> bool:
	if actor == null or definition == null:
		return _fail(
			definition.special_id if definition != null else "none",
			"Divine Special owner or definition is missing."
		)
	var failures: Array[String] = definition.validate_definition()
	if not definition.is_unlocked(force_debug):
		failures.append(definition.display_name + " is not unlocked.")
	if active_effect != null:
		failures.append("A Divine Special is already active.")
	if divine_charge + 0.001 < definition.required_charge:
		failures.append(
			"Divine Charge is only "
			+ str(roundi(divine_charge))
			+ "% ready."
		)
	if action_state != null and (
		action_state.is_defeated or action_state.is_staggered
	):
		failures.append("Grace cannot call a patron while incapacitated.")
	var performer: Node3D = _resolve_performer(definition)
	if definition.performer_mode == "active_avatar_only" and performer == null:
		failures.append(
			definition.display_name + " requires direct Divine Incarnation."
		)
	if not failures.is_empty():
		return _fail(definition.special_id, "; ".join(failures))

	if manifestation_manager != null and manifestation_manager.has_active_manifestation():
		manifestation_manager.dismiss_manifestation("divine_special_activation")
	_quiesce_player_actions()

	var instance: Node = definition.effect_scene.instantiate()
	if not (instance is DivineSpecialEffect):
		if instance != null:
			instance.queue_free()
		return _fail(
			definition.special_id,
			"The Divine Special scene does not produce DivineSpecialEffect."
		)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		instance.queue_free()
		return _fail(definition.special_id, "No active scene can receive the Special.")
	var effect: DivineSpecialEffect = instance as DivineSpecialEffect
	scene_root.add_child(effect)
	var configure_failures: Array[String] = effect.configure_special(
		definition,
		actor,
		world_position,
		direction,
		performer
	)
	if not configure_failures.is_empty():
		effect.queue_free()
		return _fail(definition.special_id, "; ".join(configure_failures))
	if not effect.special_finished.is_connected(_on_effect_finished):
		effect.special_finished.connect(_on_effect_finished)
	if not effect.begin_special():
		effect.queue_free()
		return _fail(definition.special_id, "The Divine Special refused to begin.")

	active_definition = definition
	active_effect = effect
	active_timeout_remaining = maxf(definition.action_timeout, 0.1)
	active_recharge_seconds = maxf(definition.recharge_seconds, 1.0)
	set_charge(
		maxf(divine_charge - definition.required_charge, 0.0),
		"special_activation"
	)
	if definition.invulnerability_seconds > 0.0:
		GameState.begin_player_invulnerability(
			definition.invulnerability_seconds
		)
	if action_state != null and definition.activation_lock_seconds > 0.0:
		action_state.begin_cast(definition.activation_lock_seconds)
	total_activations += 1
	last_result = "active"
	last_failure = ""
	last_effect_result.clear()
	special_started.emit(definition, effect)
	_show_message(definition.display_name + "!")
	return true


func cancel_active_special(reason: String = "cancelled") -> bool:
	if active_effect == null or not is_instance_valid(active_effect):
		active_effect = null
		active_definition = null
		active_timeout_remaining = 0.0
		return false
	active_effect.cancel_special(reason)
	return true


func award_charge(
	amount: float,
	reason: String = "combat",
	emit_every_frame: bool = true
) -> float:
	if amount <= 0.0 or divine_charge >= maximum_charge:
		return 0.0
	var previous: float = divine_charge
	divine_charge = clampf(divine_charge + amount, 0.0, maximum_charge)
	var awarded: float = divine_charge - previous
	if awarded <= 0.0:
		return 0.0
	total_charge_awarded += awarded
	last_charge_reason = reason
	if emit_every_frame or is_ready():
		charge_changed.emit(divine_charge, maximum_charge, reason)
	return awarded


func set_charge(value: float, reason: String = "set") -> void:
	divine_charge = clampf(value, 0.0, maximum_charge)
	last_charge_reason = reason
	charge_changed.emit(divine_charge, maximum_charge, reason)


func force_full_charge(reason: String = "debug_refill") -> void:
	set_charge(maximum_charge, reason)
	last_result = "charge_full"
	_show_message("Divine Charge restored.")


func get_charge_ratio() -> float:
	return clampf(divine_charge / maxf(maximum_charge, 0.001), 0.0, 1.0)


func is_ready() -> bool:
	var selected: DivineSpecialDefinition = get_selected_special(
		OS.is_debug_build()
	)
	return (
		selected != null
		and active_effect == null
		and divine_charge + 0.001 >= selected.required_charge
	)


func is_special_active() -> bool:
	return active_effect != null and is_instance_valid(active_effect)


func get_definition_by_id(special_id: String) -> DivineSpecialDefinition:
	for definition_index: int in range(special_definitions.size()):
		var definition: DivineSpecialDefinition = special_definitions[definition_index]
		if definition != null and definition.special_id == special_id:
			return definition
	return null


func resolve_special_target(
	definition: DivineSpecialDefinition
) -> Dictionary:
	if actor == null or definition == null:
		return {"valid": false, "reason": "Special targeting is unavailable."}
	var direction: Vector3 = _get_aim_direction()
	var target: Node3D = _get_locked_target()
	if target == null and definition.targeting_mode in [
		"locked_or_aim_ground",
		"locked_or_cluster",
	]:
		target = _find_nearest_enemy(definition.maximum_target_range)
	var position: Vector3 = actor.global_position
	match definition.targeting_mode:
		"owner":
			position = _project_to_floor(actor.global_position)
		"locked_or_aim_ground":
			if target != null:
				position = _project_to_floor(target.global_position)
				direction = _planar_direction(actor.global_position, target.global_position)
			else:
				position = _project_to_floor(
					actor.global_position
					+ direction * definition.maximum_target_range
				)
		"locked_or_cluster":
			if target == null:
				return {
					"valid": false,
					"reason": "No hostile cluster is within range.",
				}
			position = _get_cluster_center(target, 4.0)
			position = _project_to_floor(position)
			direction = _planar_direction(actor.global_position, position)
		"aim_line":
			position = _project_to_floor(
				actor.global_position
				+ direction * definition.maximum_target_range
			)
		_:
			return {"valid": false, "reason": "Unknown targeting mode."}
	return {
		"valid": true,
		"position": position,
		"direction": direction,
		"target": target,
		"mode": definition.targeting_mode,
	}


func _resolve_performer(
	definition: DivineSpecialDefinition
) -> Node3D:
	if definition == null or avatar_manager == null:
		return null
	if (
		avatar_manager.is_incarnated()
		and avatar_manager.get_active_avatar_id() == definition.patron_id
		and definition.performer_mode != "projection_only"
	):
		return actor
	return null


func _quiesce_player_actions() -> void:
	if weapon_controller != null and weapon_controller.current_attack != null:
		weapon_controller.cancel_current_attack("divine_special")
	if dodge_controller != null and dodge_controller.is_dodge_active():
		dodge_controller.cancel_dodge("divine_special")
	if combat_footwork_controller != null:
		combat_footwork_controller.cancel_footwork("divine_special")
	if action_state != null:
		action_state.clear_action_locks()


func _get_aim_direction() -> Vector3:
	if actor == null:
		return Vector3.FORWARD
	var origin: Vector3 = actor.global_position + Vector3.UP * 1.0
	if actor.has_method("get_combat_aim_direction"):
		var direction_value: Variant = actor.call(
			"get_combat_aim_direction",
			origin,
			true
		)
		if direction_value is Vector3:
			var resolved: Vector3 = direction_value as Vector3
			resolved.y = 0.0
			if resolved.length_squared() > 0.0001:
				return resolved.normalized()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var camera_forward: Vector3 = -camera.global_transform.basis.z
		camera_forward.y = 0.0
		if camera_forward.length_squared() > 0.0001:
			return camera_forward.normalized()
	var forward: Vector3 = -actor.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD


func _get_locked_target() -> Node3D:
	if actor == null or not actor.has_method("has_lock_on_target"):
		return null
	if not bool(actor.call("has_lock_on_target")):
		return null
	var target_value: Variant = actor.get("lock_on_target")
	if target_value is Node3D and _valid_enemy(target_value as Node3D):
		return target_value as Node3D
	return null


func _find_nearest_enemy(maximum_range: float) -> Node3D:
	var best: Node3D
	var best_distance: float = INF
	for candidate_node: Node in get_tree().get_nodes_in_group("enemy"):
		if not (candidate_node is Node3D):
			continue
		var candidate: Node3D = candidate_node as Node3D
		if not _valid_enemy(candidate):
			continue
		var distance: float = actor.global_position.distance_to(
			candidate.global_position
		)
		if distance <= maximum_range and distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _valid_enemy(candidate: Node3D) -> bool:
	return (
		candidate != null
		and is_instance_valid(candidate)
		and not candidate.is_queued_for_deletion()
		and candidate != actor
		and not candidate.is_in_group("friendly_actor")
		and not candidate.is_in_group("player")
		and (
			not candidate.has_method("is_target_defeated")
			or not bool(candidate.call("is_target_defeated"))
		)
	)


func _get_cluster_center(primary: Node3D, radius: float) -> Vector3:
	if primary == null:
		return actor.global_position
	var total: Vector3 = primary.global_position
	var count: int = 1
	for candidate_node: Node in get_tree().get_nodes_in_group("enemy"):
		if not (candidate_node is Node3D):
			continue
		var candidate: Node3D = candidate_node as Node3D
		if candidate == primary or not _valid_enemy(candidate):
			continue
		if candidate.global_position.distance_to(primary.global_position) <= radius:
			total += candidate.global_position
			count += 1
	return total / float(maxi(count, 1))


func _project_to_floor(point: Vector3) -> Vector3:
	if actor == null or actor.get_world_3d() == null:
		return point
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 5.0,
		point + Vector3.DOWN * 12.0,
		1
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [actor.get_rid()]
	var result: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return point
	return result.get("position", point) as Vector3


func _planar_direction(from: Vector3, to: Vector3) -> Vector3:
	var direction: Vector3 = to - from
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		return _get_aim_direction()
	return direction.normalized()


func _on_effect_finished(success: bool, result: Dictionary) -> void:
	var completed_definition: DivineSpecialDefinition = active_definition
	active_effect = null
	active_definition = null
	active_timeout_remaining = 0.0
	last_effect_result = result.duplicate(true)
	last_result = "completed" if success else "cancelled"
	if success:
		total_completions += 1
	else:
		total_failures += 1
	if completed_definition != null:
		special_finished.emit(completed_definition, success, result)


func _on_attack_finished(attack_id: String) -> void:
	if weapon_controller == null or not weapon_controller.last_attack_connected:
		return
	var amount: float = connected_attack_charge
	var moveset: WeaponMovesetDefinition = weapon_controller.get_moveset()
	var attack: WeaponAttackDefinition = (
		moveset.get_attack(attack_id)
		if moveset != null
		else null
	)
	if attack != null and attack.input_kind == WeaponController.INPUT_HEAVY:
		amount += heavy_attack_charge_bonus
	if weapon_controller.combo_history.size() >= 3:
		amount += deep_combo_charge_bonus
	award_charge(amount, "connected_attack")


func _on_authority_cast_finished(_ability_id: String) -> void:
	award_charge(spell_cast_charge, "authority_spell")


func _on_avatar_transition_started(
	_from_avatar_id: String,
	_to_avatar_id: String
) -> void:
	cancel_active_special("avatar_transition")


func _on_avatar_dismissed(
	_previous_avatar_id: String,
	_reason: String
) -> void:
	cancel_active_special("avatar_dismissal")


func _on_manifestation_started(
	_actor: ManifestedAvatarActor,
	_definition: PlayableAvatarDefinition
) -> void:
	cancel_active_special("manifestation_started")


func _on_player_defeated() -> void:
	cancel_active_special("player_defeated")


func _on_unlock_changed(_unlock_id: String, _value: bool) -> void:
	_ensure_valid_selection(OS.is_debug_build())


func _ensure_valid_selection(force_debug: bool = false) -> void:
	var available: Array[DivineSpecialDefinition] = get_available_specials(force_debug)
	if available.is_empty():
		selected_index = 0
		return
	selected_index = posmod(selected_index, available.size())
	selected_special_changed.emit(available[selected_index])


func _fail(special_id: String, reason: String) -> bool:
	last_result = "failed"
	last_failure = reason
	total_failures += 1
	special_failed.emit(special_id, reason)
	_show_message(reason)
	return false


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	elif OS.is_debug_build():
		print(text)


func get_debug_data() -> Dictionary:
	var selected: DivineSpecialDefinition = get_selected_special(
		OS.is_debug_build()
	)
	var rows: Array[Dictionary] = []
	for definition_index: int in range(special_definitions.size()):
		var definition: DivineSpecialDefinition = special_definitions[definition_index]
		if definition != null:
			rows.append(definition.get_debug_summary())
	return {
		"charge": snappedf(divine_charge, 0.01),
		"maximum_charge": maximum_charge,
		"charge_ratio": snappedf(get_charge_ratio(), 0.01),
		"ready": is_ready(),
		"recharge_seconds": active_recharge_seconds,
		"last_charge_reason": last_charge_reason,
		"selected_index": selected_index,
		"selected_id": selected.special_id if selected != null else "none",
		"selected_name": selected.display_name if selected != null else "None",
		"selected_patron": selected.patron_id if selected != null else "none",
		"available_count": get_available_specials(OS.is_debug_build()).size(),
		"catalog_count": special_definitions.size(),
		"active": is_special_active(),
		"active_id": active_definition.special_id if active_definition != null else "none",
		"active_timeout": snappedf(active_timeout_remaining, 0.01),
		"last_result": last_result,
		"last_failure": last_failure,
		"last_effect": last_effect_result.duplicate(true),
		"total_activations": total_activations,
		"total_completions": total_completions,
		"total_failures": total_failures,
		"total_charge_awarded": snappedf(total_charge_awarded, 0.01),
		"definitions": rows,
	}
