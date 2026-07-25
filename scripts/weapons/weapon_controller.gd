extends Node3D
class_name WeaponController

signal weapon_changed(weapon: WeaponDefinition)
signal attack_started(attack: WeaponAttackDefinition)
signal attack_finished(attack_id: String)
signal combo_state_changed(debug_data: Dictionary)

const EquipmentCatalogScript = preload("res://scripts/equipment/equipment_catalog.gd")
const WeaponMasteryCatalogScript = preload("res://scripts/weapons/weapon_mastery_catalog.gd")
const WeaponInfusionCatalogScript = preload("res://scripts/weapons/weapon_infusion_catalog.gd")
const WeaponTechniqueCatalogScript = preload("res://scripts/weapons/weapon_technique_catalog.gd")
const ElementVisualsScript = preload("res://scripts/visuals/element_visuals.gd")

const INPUT_LIGHT: String = "light"
const INPUT_HEAVY: String = "heavy"

@export var equipped_weapon: WeaponDefinition
@export var hit_mask: int = 0xFFFFFFFF
@export var attack_origin_height: float = 1.0
@export var use_camera_direction: bool = true
@export var close_range_auto_hit_radius: float = 0.85

@export_group("Attack Steering")
@export_range(0.0, 8.0, 0.1) var facing_assist_range: float = 3.8
@export_range(0.0, 180.0, 1.0) var facing_assist_angle_degrees: float = 72.0
@export_range(0.0, 1.0, 0.05) var facing_assist_strength: float = 0.72
@export_range(0.0, 90.0, 1.0) var facing_assist_max_turn_degrees: float = 38.0
@export_range(0.0, 1.0, 0.05) var movement_direction_weight: float = 0.78

@export_group("Contact Rhythm")
@export_range(0.0, 0.5, 0.01) var whiff_recovery_penalty: float = 0.11
@export_range(0.0, 0.4, 0.01) var camera_impact_amount: float = 0.075

@export_group("Input Buffer")
@export var input_buffer_seconds: float = 0.32

@export_group("Feedback")
@export var show_debug_prints: bool = false
@export var print_attack_debug: bool = false
@export var show_debug_hitboxes: bool = false
@export var debug_hitbox_lifetime: float = 0.18
@export var sweep_start_alpha: float = 0.76
@export var sweep_end_alpha: float = 0.0

@export_group("Fallback")
@export var default_weapon_path: String = "res://data/weapons/practice_sword.tres"

var current_attack: WeaponAttackDefinition
var current_attack_elapsed: float = 0.0
var current_phase: String = "idle"
var attack_hit_applied: bool = false

var queued_input: String = ""
var queued_input_timer: float = 0.0
var combo_timeout_timer: float = 0.0
var last_completed_attack_id: String = ""
var combo_history: Array[String] = []
var attack_forward_override: Vector3 = Vector3.ZERO
var pending_context_forward: Vector3 = Vector3.ZERO
var active_technique_id: String = ""
var plunge_landing_armed: bool = false
var plunge_max_fall_speed: float = 0.0
var current_attack_duration_bonus: float = 0.0
var last_attack_connected: bool = false
var camera_impact_tween: Tween

var swing_tween: Tween
var sweep_tween: Tween
var model_materials: Array[StandardMaterial3D] = []
var runtime_weapon_rig: Node3D

@onready var weapon_visual_pivot: Node3D = get_node_or_null("HandAnchor/WeaponVisualPivot")
@onready var weapon_model_root: Node3D = get_node_or_null("HandAnchor/WeaponVisualPivot/WeaponModelRoot")
@onready var slash_trail: MeshInstance3D = get_node_or_null("HandAnchor/WeaponVisualPivot/SlashTrail")
@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState")
@onready var dodge_controller: PlayerDodgeController = get_parent().get_node_or_null("PlayerDodgeController")

var base_visual_position: Vector3 = Vector3.ZERO
var base_visual_rotation_degrees: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("debuggable")
	if not GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.connect(_on_equipment_changed)
	if not GameState.weapon_infusion_changed.is_connected(_on_weapon_infusion_changed):
		GameState.weapon_infusion_changed.connect(_on_weapon_infusion_changed)
	var saved_weapon_id: String = GameState.get_equipped_item("weapon")
	var saved_weapon: WeaponDefinition = EquipmentCatalogScript.get_weapon(saved_weapon_id)
	if saved_weapon != null:
		equipped_weapon = saved_weapon

	if equipped_weapon == null and default_weapon_path != "":
		var loaded_weapon: Resource = load(default_weapon_path)
		if loaded_weapon is WeaponDefinition:
			equipped_weapon = loaded_weapon as WeaponDefinition

	if weapon_visual_pivot != null:
		base_visual_position = weapon_visual_pivot.position
		base_visual_rotation_degrees = weapon_visual_pivot.rotation_degrees

	setup_slash_trail()
	refresh_weapon_visual()
	emit_weapon_changed()

	if show_debug_prints:
		print(
			"WeaponController ready: ",
			get_path(),
			" weapon=",
			equipped_weapon.display_name if equipped_weapon != null else "none"
		)


func _exit_tree() -> void:
	if GameState.equipment_changed.is_connected(_on_equipment_changed):
		GameState.equipment_changed.disconnect(_on_equipment_changed)
	if GameState.weapon_infusion_changed.is_connected(_on_weapon_infusion_changed):
		GameState.weapon_infusion_changed.disconnect(_on_weapon_infusion_changed)


func _on_weapon_infusion_changed(_infusion_id: String) -> void:
	refresh_weapon_visual()
	emit_combo_state()


func _on_equipment_changed(slot_id: String, item_id: String) -> void:
	if slot_id != "weapon":
		return
	var weapon: WeaponDefinition = EquipmentCatalogScript.get_weapon(item_id)
	if weapon != null:
		equip_weapon(weapon)


func _process(delta: float) -> void:
	update_queued_input(delta)

	if current_attack != null:
		update_current_attack(delta)
	else:
		update_combo_timeout(delta)

	update_plunge_landing()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_light_attack"):
		queue_attack_input(INPUT_LIGHT)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("weapon_heavy_attack"):
		queue_attack_input(INPUT_HEAVY)
		get_viewport().set_input_as_handled()


func try_light_attack() -> void:
	queue_attack_input(INPUT_LIGHT)


func try_heavy_attack() -> void:
	queue_attack_input(INPUT_HEAVY)


func queue_attack_input(input_kind: String) -> void:
	if input_kind != INPUT_LIGHT and input_kind != INPUT_HEAVY:
		return

	if equipped_weapon == null:
		show_message("No weapon equipped.")
		return

	if current_attack != null:
		queued_input = input_kind
		queued_input_timer = max(input_buffer_seconds, 0.05)
		emit_combo_state()
		return

	var context_attack: WeaponAttackDefinition = resolve_context_attack(input_kind)
	if context_attack != null and active_technique_id == WeaponTechniqueCatalogScript.CONTEXT_DASH:
		var dash_direction: Vector3 = dodge_controller.cancel_into_weapon_technique()
		if dash_direction.length() > 0.01:
			pending_context_forward = dash_direction.normalized()
		reset_combo_chain(false)
		if not start_attack(context_attack):
			pending_context_forward = Vector3.ZERO
			active_technique_id = ""
		return

	if action_state != null and not action_state.can_attack():
		active_technique_id = ""
		return

	if context_attack != null:
		reset_combo_chain(false)
		var aerial_context: String = active_technique_id
		if not start_attack(context_attack):
			active_technique_id = ""
			return
		apply_aerial_technique_motion(aerial_context)
		return

	var requested_attack: WeaponAttackDefinition = resolve_idle_attack(input_kind)

	if requested_attack == null:
		show_message(equipped_weapon.display_name + " has no " + input_kind + " attack from this combo state.")
		reset_combo_chain()
		return

	start_attack(requested_attack)


func resolve_context_attack(input_kind: String) -> WeaponAttackDefinition:
	if equipped_weapon == null:
		return null
	var mastery_rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
	var moveset: WeaponMovesetDefinition = get_moveset()
	var base_attack: WeaponAttackDefinition
	if moveset != null:
		base_attack = moveset.get_entry_attack(input_kind)
	else:
		base_attack = build_legacy_attack(input_kind)

	if dodge_controller != null and dodge_controller.is_dodge_active():
		if WeaponTechniqueCatalogScript.is_context_unlocked(
			equipped_weapon.weapon_class,
			WeaponTechniqueCatalogScript.CONTEXT_DASH,
			mastery_rank
		):
			var dash_attack: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_dash_attack(
				base_attack,
				equipped_weapon.weapon_class
			)
			if dash_attack != null:
				active_technique_id = WeaponTechniqueCatalogScript.CONTEXT_DASH
			return dash_attack

	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return null
	var body: CharacterBody3D = actor as CharacterBody3D
	if body.is_on_floor():
		return null
	if action_state != null and action_state.flight_restrictions_apply():
		return null
	var movement_amount: float = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	).length()
	var aerial_context: String = WeaponTechniqueCatalogScript.get_aerial_context(
		input_kind,
		movement_amount
	)
	if not WeaponTechniqueCatalogScript.is_context_unlocked(
		equipped_weapon.weapon_class,
		aerial_context,
		mastery_rank
	):
		return null
	var aerial_attack: WeaponAttackDefinition = WeaponTechniqueCatalogScript.build_aerial_attack(
		base_attack,
		equipped_weapon.weapon_class,
		aerial_context
	)
	if aerial_attack != null:
		active_technique_id = aerial_context
	return aerial_attack


func apply_aerial_technique_motion(context_id: String) -> void:
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	match context_id:
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_NEUTRAL:
			body.velocity.y = maxf(body.velocity.y, -0.8)
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD:
			body.velocity.y = maxf(body.velocity.y, -2.0)
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_DOWN:
			body.velocity.y = minf(body.velocity.y, -7.5)
			plunge_landing_armed = true
			plunge_max_fall_speed = absf(minf(body.velocity.y, 0.0))


func apply_aerial_hit_followthrough(targets: Array[Node]) -> void:
	if targets.is_empty():
		return
	if active_technique_id not in [
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_NEUTRAL,
		WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD,
	]:
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	body.velocity.y = maxf(body.velocity.y, 0.65)
	if active_technique_id != WeaponTechniqueCatalogScript.CONTEXT_AERIAL_FORWARD:
		return
	var target_position: Vector3 = get_target_position(targets[0])
	var pursuit_direction: Vector3 = target_position - body.global_position
	pursuit_direction.y = 0.0
	if pursuit_direction.length() <= 0.01:
		return
	pursuit_direction = pursuit_direction.normalized()
	body.velocity.x = lerpf(body.velocity.x, pursuit_direction.x * 5.2, 0.72)
	body.velocity.z = lerpf(body.velocity.z, pursuit_direction.z * 5.2, 0.72)


func update_plunge_landing() -> void:
	if not plunge_landing_armed:
		return
	var actor: Node3D = get_actor()
	if not (actor is CharacterBody3D):
		plunge_landing_armed = false
		return
	var body: CharacterBody3D = actor as CharacterBody3D
	if not body.is_on_floor():
		plunge_max_fall_speed = maxf(plunge_max_fall_speed, absf(minf(body.velocity.y, 0.0)))
		return
	resolve_plunge_landing(body)
	plunge_landing_armed = false
	plunge_max_fall_speed = 0.0


func resolve_plunge_landing(body: CharacterBody3D) -> void:
	if equipped_weapon == null:
		return
	var fall_factor: float = clampf(plunge_max_fall_speed / 7.5, 1.0, 2.0)
	var landing_attack: WeaponAttackDefinition = WeaponAttackDefinition.new()
	landing_attack.attack_id = "technique_plunge_landing_" + equipped_weapon.weapon_class
	landing_attack.display_name = "Plunging Impact"
	landing_attack.input_kind = INPUT_HEAVY
	landing_attack.attack_range = 1.8 + fall_factor * 0.35
	landing_attack.cone_angle_degrees = 360.0
	landing_attack.attack_center_forward_offset = 0.0
	landing_attack.max_targets = 8
	landing_attack.damage_multiplier = 0.55 + fall_factor * 0.18
	landing_attack.stance_multiplier = 1.0 + fall_factor * 0.35
	landing_attack.knockback_multiplier = 1.0 + fall_factor * 0.2
	var payload: DamagePayload = landing_attack.build_payload(equipped_weapon)
	if not payload.tags.has("technique"):
		payload.tags.append("technique")
	if not payload.tags.has("plunge_landing"):
		payload.tags.append("plunge_landing")
	payload.knockback_up_strength += 1.2 + fall_factor
	WeaponInfusionCatalogScript.apply_to_payload(payload, GameState.get_weapon_infusion())
	var targets: Array[Node] = find_landing_targets(body.global_position, landing_attack.attack_range)
	for target: Node in targets:
		send_payload_to_target(target, payload)
		if target.has_method("receive_weapon_impact"):
			target.call("receive_weapon_impact", payload, get_attack_forward(), landing_attack)
	ElementVisualsScript.spawn_impact(
		get_tree(),
		body.global_position + Vector3.UP * 0.08,
		payload.element,
		0.75 + fall_factor * 0.2
	)
	if not targets.is_empty():
		HitStop.request(0.075 + fall_factor * 0.025, 0.035)


func find_landing_targets(center: Vector3, radius: float) -> Array[Node]:
	var targets: Array[Node] = []
	var actor: Node3D = get_actor()
	if actor == null:
		return targets
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = maxf(radius, 0.1)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), center + Vector3.UP * 0.35)
	query.collision_mask = hit_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if actor is CollisionObject3D:
		query.exclude = [actor.get_rid()]
	var seen_ids: Dictionary = {}
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 48):
		var collider: Node = result.get("collider") as Node
		var target: Node = find_payload_target(collider)
		if target == null or target == actor:
			continue
		var target_id: int = target.get_instance_id()
		if seen_ids.has(target_id):
			continue
		seen_ids[target_id] = true
		targets.append(target)
		if targets.size() >= 8:
			break
	return targets


func update_queued_input(delta: float) -> void:
	if queued_input_timer <= 0.0:
		return

	queued_input_timer -= delta

	if queued_input_timer <= 0.0:
		queued_input = ""
		queued_input_timer = 0.0
		emit_combo_state()


func update_combo_timeout(delta: float) -> void:
	if combo_timeout_timer <= 0.0:
		return

	combo_timeout_timer -= delta

	if combo_timeout_timer <= 0.0:
		reset_combo_chain(false)


func update_current_attack(delta: float) -> void:
	if current_attack == null:
		return

	if action_state != null:
		if (
			action_state.is_defeated
			or action_state.is_casting
			or action_state.is_dodging
			or action_state.is_staggered
		):
			cancel_current_attack("cancelled")
			return

	current_attack_elapsed += delta
	var attack_speed: float = get_attack_speed()
	var startup_duration: float = current_attack.get_startup_duration(attack_speed)
	var active_end: float = startup_duration + current_attack.get_active_duration(attack_speed)
	var total_duration: float = current_attack.get_total_duration(attack_speed) + current_attack_duration_bonus

	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("update_attack_pose"):
		runtime_weapon_rig.call(
			"update_attack_pose",
			current_attack,
			current_attack_elapsed,
			attack_speed
		)

	var next_phase: String = "recovery"
	if current_attack_elapsed < startup_duration:
		next_phase = "startup"
	elif current_attack_elapsed < active_end:
		next_phase = "active"

	if next_phase != current_phase:
		current_phase = next_phase
		emit_combo_state()

	update_cancel_permissions()

	if not attack_hit_applied and current_attack_elapsed >= startup_duration:
		attack_hit_applied = true
		execute_current_attack_hit()

	if current_attack_elapsed >= total_duration:
		finish_current_attack()


func update_cancel_permissions() -> void:
	if action_state == null or current_attack == null:
		return

	var cancel_window_open: bool = (
		current_attack_elapsed
		>= current_attack.get_cancel_window_start(get_attack_speed())
	)

	action_state.set_attack_cancel_permissions(
		cancel_window_open and current_attack.allow_spell_cancel,
		cancel_window_open and current_attack.allow_dodge_cancel
	)


func resolve_idle_attack(input_kind: String) -> WeaponAttackDefinition:
	var moveset: WeaponMovesetDefinition = get_moveset()

	if moveset == null:
		return build_legacy_attack(input_kind)

	if combo_timeout_timer > 0.0 and last_completed_attack_id != "":
		var previous_attack: WeaponAttackDefinition = moveset.get_attack(last_completed_attack_id)
		var follow_up: WeaponAttackDefinition = moveset.get_follow_up(previous_attack, input_kind)

		if follow_up != null:
			return follow_up

		reset_combo_chain(false)

	return moveset.get_entry_attack(input_kind)


func start_attack(attack: WeaponAttackDefinition) -> bool:
	if attack == null or equipped_weapon == null:
		return false

	var mastery_rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
	var mastery_stamina_multiplier: float = WeaponMasteryCatalogScript.get_stamina_multiplier(equipped_weapon.weapon_class, mastery_rank)
	var resolved_stamina_cost: int = ceili(float(attack.stamina_cost) * mastery_stamina_multiplier)
	if resolved_stamina_cost > 0:
		if not GameState.spend_stamina(resolved_stamina_cost):
			show_message("Not enough stamina for " + attack.display_name + ".")
			reset_combo_chain()
			return false

	current_attack = attack
	current_attack_elapsed = 0.0
	current_phase = "startup"
	attack_hit_applied = false
	current_attack_duration_bonus = 0.0
	last_attack_connected = false
	attack_forward_override = resolve_attack_forward(attack)
	if pending_context_forward.length() > 0.01:
		attack_forward_override = pending_context_forward.normalized()
	pending_context_forward = Vector3.ZERO
	apply_attack_facing(attack_forward_override)
	combo_timeout_timer = 0.0

	if not combo_history.has(attack.attack_id) or combo_history.size() == 0:
		combo_history.append(attack.attack_id)
	else:
		combo_history.append(attack.attack_id)

	var total_duration: float = attack.get_total_duration(get_attack_speed())

	if action_state != null:
		action_state.begin_attack(total_duration + 0.08)

	request_combat_motion(attack)
	play_attack_visual(attack)
	attack_started.emit(attack)
	emit_combo_state()

	if show_debug_prints:
		print("Attack started: ", attack.get_debug_summary())

	return true


func finish_current_attack() -> void:
	if current_attack == null:
		return

	var completed_attack: WeaponAttackDefinition = current_attack
	last_completed_attack_id = completed_attack.attack_id
	combo_timeout_timer = max(completed_attack.combo_timeout, 0.0)

	current_attack = null
	current_attack_elapsed = 0.0
	current_phase = "idle"
	attack_hit_applied = false
	current_attack_duration_bonus = 0.0
	attack_forward_override = Vector3.ZERO
	active_technique_id = ""

	if action_state != null:
		action_state.end_attack()

	attack_finished.emit(completed_attack.attack_id)

	var buffered_input: String = queued_input if queued_input_timer > 0.0 else ""
	queued_input = ""
	queued_input_timer = 0.0

	if buffered_input != "":
		var moveset: WeaponMovesetDefinition = get_moveset()
		var follow_up: WeaponAttackDefinition

		if moveset != null:
			follow_up = moveset.get_follow_up(completed_attack, buffered_input)

		if follow_up != null:
			start_attack(follow_up)
			return

	reset_visual_pose()
	emit_combo_state()


func cancel_current_attack(reason: String = "cancelled") -> void:
	if current_attack == null:
		return

	if show_debug_prints:
		print("Attack ", current_attack.attack_id, " ", reason, ".")

	current_attack = null
	current_attack_elapsed = 0.0
	current_phase = "idle"
	attack_hit_applied = false
	current_attack_duration_bonus = 0.0
	attack_forward_override = Vector3.ZERO
	pending_context_forward = Vector3.ZERO
	active_technique_id = ""

	if action_state != null and action_state.is_attacking:
		action_state.end_attack()

	var actor: Node3D = get_actor()
	if actor != null and actor.has_method("cancel_combat_motion"):
		actor.cancel_combat_motion()

	reset_combo_chain()
	reset_visual_pose()
	emit_combo_state()


func reset_combo_chain(clear_queue: bool = true) -> void:
	combo_timeout_timer = 0.0
	last_completed_attack_id = ""
	combo_history.clear()

	if clear_queue:
		queued_input = ""
		queued_input_timer = 0.0

	emit_combo_state()


func equip_weapon(new_weapon: WeaponDefinition) -> void:
	if new_weapon == null:
		return

	if current_attack != null:
		cancel_current_attack("interrupted by weapon change")
	else:
		reset_combo_chain()

	equipped_weapon = new_weapon
	refresh_weapon_visual()
	emit_weapon_changed()
	show_message("Equipped: " + equipped_weapon.display_name)


func emit_weapon_changed() -> void:
	weapon_changed.emit(equipped_weapon)
	emit_combo_state()


func get_moveset() -> WeaponMovesetDefinition:
	if equipped_weapon == null:
		return null
	return equipped_weapon.get_moveset()


func get_attack_speed() -> float:
	if equipped_weapon == null:
		return 1.0
	var mastery_rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
	var mastery_multiplier: float = WeaponMasteryCatalogScript.get_attack_speed_multiplier(
		equipped_weapon.weapon_class,
		mastery_rank
	)
	return max(equipped_weapon.attack_speed * mastery_multiplier, 0.05)


func build_legacy_attack(input_kind: String) -> WeaponAttackDefinition:
	if equipped_weapon == null:
		return null

	var attack: WeaponAttackDefinition = WeaponAttackDefinition.new()
	attack.attack_id = "legacy_" + input_kind
	attack.display_name = "Legacy " + input_kind.capitalize()
	attack.input_kind = input_kind
	attack.startup_time = max(0.08, equipped_weapon.cooldown * 0.32)
	attack.active_time = 0.08
	attack.recovery_time = max(0.1, equipped_weapon.cooldown * 0.5)
	attack.attack_range = equipped_weapon.range
	attack.cone_angle_degrees = equipped_weapon.cone_angle_degrees
	attack.max_targets = equipped_weapon.max_targets
	attack.stamina_cost = equipped_weapon.stamina_cost
	attack.damage_multiplier = 1.0 if input_kind == INPUT_LIGHT else 1.65
	attack.stance_multiplier = 1.0 if input_kind == INPUT_LIGHT else 1.8
	attack.extra_tags = ["force"] if input_kind == INPUT_HEAVY else []
	attack.allow_dodge_cancel = input_kind == INPUT_LIGHT
	attack.allow_spell_cancel = input_kind == INPUT_LIGHT
	attack.movement_distance = 0.25 if input_kind == INPUT_LIGHT else 0.1
	return attack


func execute_current_attack_hit() -> void:
	if current_attack == null or equipped_weapon == null:
		return

	var payload: DamagePayload = current_attack.build_payload(equipped_weapon)
	var mastery_rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
	WeaponTechniqueCatalogScript.apply_context_tags(payload, current_attack, combo_history.size(), active_technique_id)
	var actor: Node3D = get_actor()
	var actor_grounded: bool = actor is CharacterBody3D and (actor as CharacterBody3D).is_on_floor()
	WeaponTechniqueCatalogScript.apply_ground_launcher(
		payload,
		current_attack,
		equipped_weapon.weapon_class,
		combo_history.size(),
		mastery_rank,
		actor_grounded
	)
	WeaponMasteryCatalogScript.apply_payload_upgrades(
		payload,
		equipped_weapon.weapon_class,
		mastery_rank,
		current_attack,
		combo_history.size()
	)
	WeaponInfusionCatalogScript.apply_to_payload(payload, GameState.get_weapon_infusion())
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("modify_attack_payload"):
		runtime_weapon_rig.call("modify_attack_payload", payload, current_attack)

	var targets: Array[Node] = find_targets(current_attack)
	var messages: Array[String] = []
	var critical_landed: bool = false

	for target: Node in targets:
		var result: Dictionary = send_payload_to_target(target, payload)
		critical_landed = critical_landed or bool(result.get("critical", false))
		if GameState.get_weapon_infusion() != WeaponInfusionCatalogScript.DEFAULT_INFUSION_ID:
			ElementVisualsScript.spawn_impact(get_tree(), get_target_position(target), payload.element, 0.68)
		if target.has_method("receive_weapon_impact"):
			target.call("receive_weapon_impact", payload, get_attack_forward(), current_attack)
		elif target.has_method("receive_hit_reaction"):
			target.call("receive_hit_reaction", get_attack_forward(), payload.knockback_strength)

		if result.has("message") and result["message"] != "":
			messages.append(str(result["message"]))

	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("on_weapon_targets_hit"):
		runtime_weapon_rig.call("on_weapon_targets_hit", targets, current_attack)

	last_attack_connected = targets.size() > 0
	if targets.size() > 0:
		apply_aerial_hit_followthrough(targets)
		award_weapon_mastery(current_attack, critical_landed)
		apply_camera_impact(current_attack, critical_landed)
		HitStop.request(
			max(
				current_attack.hit_stop_duration * (1.85 if critical_landed else 1.0),
				0.0
			),
			clampf(
				current_attack.hit_stop_time_scale * (0.5 if critical_landed else 1.0),
				0.01,
				1.0
			)
		)
	else:
		current_attack_duration_bonus = maxf(whiff_recovery_penalty, 0.0)
		if show_debug_prints:
			messages.append(equipped_weapon.display_name + " • " + current_attack.display_name + " misses.")

	if messages.size() > 0:
		show_message("\n".join(messages))

	if show_debug_hitboxes:
		show_attack_debug_wedge(current_attack)


func award_weapon_mastery(attack: WeaponAttackDefinition, critical_landed: bool) -> void:
	if attack == null or equipped_weapon == null:
		return
	var points: int = 1
	var reasons: Array[String] = ["connected hit"]
	if attack.input_kind == INPUT_HEAVY:
		points += 1
		reasons.append("heavy technique")
	if combo_history.size() >= 3:
		points += 1
		reasons.append("deep combo")
	if critical_landed:
		points += 1
		reasons.append("critical")
	GameState.add_weapon_mastery_progress(
		equipped_weapon.weapon_class,
		points,
		", ".join(reasons)
	)


func get_effective_attack_range(attack: WeaponAttackDefinition) -> float:
	if attack == null:
		return 0.1
	var bonus: float = 0.0
	if equipped_weapon != null:
		var rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
		bonus = WeaponMasteryCatalogScript.get_range_bonus(equipped_weapon.weapon_class, rank)
	return maxf(attack.attack_range + bonus, 0.1)


func get_effective_max_targets(attack: WeaponAttackDefinition) -> int:
	if attack == null:
		return 1
	var extra_targets: int = 0
	if equipped_weapon != null:
		var rank: int = GameState.get_weapon_mastery_rank(equipped_weapon.weapon_class)
		extra_targets = WeaponMasteryCatalogScript.get_extra_targets(
			equipped_weapon.weapon_class,
			rank,
			attack,
			combo_history.size()
		)
	return maxi(attack.max_targets + extra_targets, 1)


func find_targets(attack: WeaponAttackDefinition) -> Array[Node]:
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("find_weapon_targets"):
		var runtime_targets: Variant = runtime_weapon_rig.call(
			"find_weapon_targets",
			self,
			attack,
			hit_mask
		)
		if runtime_targets is Array:
			var resolved_targets: Array[Node] = []
			for candidate: Variant in runtime_targets as Array:
				if candidate is Node and not resolved_targets.has(candidate as Node):
					resolved_targets.append(candidate as Node)
				if resolved_targets.size() >= get_effective_max_targets(attack):
					break
			return resolved_targets

	var actor: Node3D = get_actor()

	if actor == null or attack == null:
		return []

	var locked_part: Node = _get_locked_weak_point(actor, attack)
	if locked_part != null:
		var precise_targets: Array[Node] = [locked_part]
		return precise_targets

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = get_effective_attack_range(attack)

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), get_attack_center(attack))
	query.collision_mask = hit_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true

	if actor is CollisionObject3D:
		query.exclude = [actor.get_rid()]

	var results: Array[Dictionary] = space_state.intersect_shape(query, 48)
	var targets: Array[Node] = []
	var seen_ids: Dictionary = {}

	for result: Dictionary in results:
		if not result.has("collider"):
			continue

		var collider: Node = result["collider"]
		var target: Node = find_payload_target(collider)

		if print_attack_debug:
			print("Weapon collider: ", collider.name, " target: ", target.name if target != null else "none")

		if target == null or target == actor:
			continue

		if not is_target_in_attack_cone(target, attack):
			continue

		var target_id: int = target.get_instance_id()
		if seen_ids.has(target_id):
			continue

		seen_ids[target_id] = true
		targets.append(target)

		if targets.size() >= get_effective_max_targets(attack):
			break

	return targets


func _get_locked_weak_point(actor: Node3D, attack: WeaponAttackDefinition) -> Node:
	if actor == null or attack == null:
		return null
	var target_value: Variant = actor.get("lock_on_target")
	if not (target_value is Node3D):
		return null
	var target: Node3D = target_value as Node3D
	if not target.is_in_group("lock_on_weak_point"):
		return null
	if target.has_method("is_targeting_enabled") and not bool(target.call("is_targeting_enabled")):
		return null
	var target_position: Vector3 = get_target_position(target)
	var maximum_distance: float = get_effective_attack_range(attack) + 0.75
	if get_attack_origin().distance_to(target_position) > maximum_distance:
		return null
	if not is_target_in_attack_cone(target, attack):
		return null
	return target


func send_payload_to_target(target: Node, payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")

	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return payload_receiver.receive_payload(payload)

	if target.has_method("receive_damage_payload"):
		return target.receive_damage_payload(payload)

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			return hit_receiver.receive_payload(payload)
		if hit_receiver.has_method("receive_hit"):
			return hit_receiver.receive_hit(payload.amount)

	return {
		"message": payload.source_name + " hits " + target.name + ", but nothing receives it.",
		"objective": "",
	}


func find_payload_target(start_node: Node) -> Node:
	var current: Node = start_node

	while current != null:
		if is_payload_target(current):
			return current

		var child_target: Node = find_payload_target_in_children(current)
		if child_target != null:
			return child_target

		current = current.get_parent()

	return null


func find_payload_target_in_children(node: Node) -> Node:
	if node == null:
		return null

	for child: Node in node.get_children():
		if is_payload_target(child):
			return child

		var deeper_target: Node = find_payload_target_in_children(child)
		if deeper_target != null:
			return deeper_target

	return null


func is_payload_target(node: Node) -> bool:
	if node.get_node_or_null("PayloadReceiver") != null:
		return true
	if node.get_node_or_null("HitReceiver") != null:
		return true
	if node.has_method("receive_damage_payload"):
		return true
	return false


func is_target_in_attack_cone(target: Node, attack: WeaponAttackDefinition) -> bool:
	var target_position: Vector3 = get_target_position(target)
	var origin: Vector3 = get_attack_origin()
	var to_target: Vector3 = target_position - origin
	to_target.y = 0.0

	if to_target.length() <= close_range_auto_hit_radius:
		return true

	if to_target.length() <= 0.01:
		return true

	var forward: Vector3 = get_attack_forward()
	var direction: Vector3 = to_target.normalized()
	var minimum_dot: float = cos(deg_to_rad(clampf(attack.cone_angle_degrees, 1.0, 360.0) * 0.5))
	return forward.dot(direction) >= minimum_dot


func get_attack_origin() -> Vector3:
	var actor: Node3D = get_actor()
	if actor == null:
		return global_position
	return actor.global_position + Vector3.UP * attack_origin_height


func get_attack_center(attack: WeaponAttackDefinition) -> Vector3:
	if attack == null:
		return get_attack_origin()
	return get_attack_origin() + get_attack_forward() * attack.attack_center_forward_offset


func get_attack_forward() -> Vector3:
	if attack_forward_override.length_squared() > 0.001:
		return attack_forward_override.normalized()
	var actor: Node3D = get_actor()

	if actor != null and actor.has_method("get_combat_aim_direction"):
		var target_direction: Vector3 = actor.call(
			"get_combat_aim_direction",
			get_attack_origin(),
			true
		)
		target_direction.y = 0.0
		if target_direction.length() > 0.01:
			return target_direction.normalized()
	elif actor != null and actor.has_method("has_lock_on_target") and actor.has_lock_on_target():
		if actor.has_method("get_lock_on_cast_direction"):
			var lock_direction: Vector3 = actor.get_lock_on_cast_direction(get_attack_origin())
			lock_direction.y = 0.0
			if lock_direction.length() > 0.01:
				return lock_direction.normalized()

	if use_camera_direction:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera != null:
			var camera_forward: Vector3 = -camera.global_transform.basis.z
			camera_forward.y = 0.0
			if camera_forward.length() > 0.01:
				return camera_forward.normalized()

	if actor == null:
		var fallback_forward: Vector3 = -global_transform.basis.z
		fallback_forward.y = 0.0
		return fallback_forward.normalized()

	var actor_forward: Vector3 = -actor.global_transform.basis.z
	actor_forward.y = 0.0
	if actor_forward.length() <= 0.01:
		return Vector3.FORWARD
	return actor_forward.normalized()


func resolve_attack_forward(attack: WeaponAttackDefinition) -> Vector3:
	attack_forward_override = Vector3.ZERO
	var actor: Node3D = get_actor()
	var resolved: Vector3 = get_attack_forward()
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_vector.length() > 0.22 and actor != null:
		var camera: Camera3D = get_viewport().get_camera_3d()
		var right: Vector3 = actor.global_transform.basis.x
		var forward: Vector3 = -actor.global_transform.basis.z
		if camera != null:
			right = camera.global_transform.basis.x
			forward = -camera.global_transform.basis.z
		right.y = 0.0
		forward.y = 0.0
		if right.length_squared() > 0.001 and forward.length_squared() > 0.001:
			var movement_direction: Vector3 = (right.normalized() * input_vector.x + forward.normalized() * -input_vector.y).normalized()
			resolved = resolved.slerp(movement_direction, movement_direction_weight).normalized()
	var assist_target: Node3D = find_facing_assist_target(resolved, attack)
	if assist_target != null and actor != null:
		var target_direction: Vector3 = get_target_position(assist_target) - actor.global_position
		target_direction.y = 0.0
		if target_direction.length_squared() > 0.001:
			target_direction = target_direction.normalized()
			var angle: float = resolved.angle_to(target_direction)
			var maximum_turn: float = deg_to_rad(facing_assist_max_turn_degrees)
			var blend: float = facing_assist_strength
			if angle > 0.001:
				blend = minf(blend, maximum_turn / angle)
			resolved = resolved.slerp(target_direction, clampf(blend, 0.0, 1.0)).normalized()
	return resolved if resolved.length_squared() > 0.001 else Vector3.FORWARD


func find_facing_assist_target(forward: Vector3, attack: WeaponAttackDefinition) -> Node3D:
	var actor: Node3D = get_actor()
	if actor == null or facing_assist_range <= 0.0:
		return null
	var best: Node3D = null
	var best_score: float = INF
	var minimum_dot: float = cos(deg_to_rad(facing_assist_angle_degrees))
	var search_range: float = maxf(facing_assist_range, attack.attack_range if attack != null else 0.0)
	for candidate_node: Node in get_tree().get_nodes_in_group("enemy"):
		if not candidate_node is Node3D:
			continue
		var candidate: Node3D = candidate_node as Node3D
		if candidate == actor:
			continue
		var offset: Vector3 = get_target_position(candidate) - actor.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.01 or distance > search_range:
			continue
		var alignment: float = forward.normalized().dot(offset.normalized())
		if alignment < minimum_dot:
			continue
		var score: float = distance - alignment * 1.4
		if score < best_score:
			best_score = score
			best = candidate
	return best


func apply_attack_facing(direction: Vector3) -> void:
	var actor: Node3D = get_actor()
	if actor == null or direction.length_squared() <= 0.001:
		return
	# Movement-directed attacks already use the cached heading for hit geometry and
	# lunges. Rotating the player/camera rig here made strafing attacks appear to
	# teleport, so visible facing assist only settles an idle attacker.
	var movement_input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if movement_input.length() > 0.22:
		return
	var target_angle: float = atan2(-direction.x, -direction.z)
	actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, 0.38)


func apply_camera_impact(attack: WeaponAttackDefinition, critical: bool) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or camera_impact_amount <= 0.0:
		return
	if camera_impact_tween != null:
		camera_impact_tween.kill()
	var strength: float = camera_impact_amount
	if attack != null:
		strength *= clampf(attack.damage_multiplier, 0.8, 2.2)
	if critical:
		strength *= 1.65
	camera.h_offset = (-strength if combo_history.size() % 2 == 0 else strength)
	camera.v_offset = strength * 0.55
	camera_impact_tween = create_tween()
	camera_impact_tween.set_trans(Tween.TRANS_QUAD)
	camera_impact_tween.set_ease(Tween.EASE_OUT)
	camera_impact_tween.parallel().tween_property(camera, "h_offset", 0.0, 0.13)
	camera_impact_tween.parallel().tween_property(camera, "v_offset", 0.0, 0.13)


func get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return target.global_position

	var parent: Node = target.get_parent()
	if parent is Node3D:
		return parent.global_position
	return Vector3.ZERO


func get_actor() -> Node3D:
	var parent: Node = get_parent()
	if parent is Node3D:
		return parent as Node3D
	return null


func request_combat_motion(attack: WeaponAttackDefinition) -> void:
	if attack == null or attack.movement_distance <= 0.0:
		return

	var actor: Node3D = get_actor()
	if actor != null and actor.has_method("begin_combat_motion"):
		actor.begin_combat_motion(
			get_attack_forward(),
			attack.movement_distance,
			max(attack.movement_duration, 0.01)
		)


func play_attack_visual(attack: WeaponAttackDefinition) -> void:
	if weapon_visual_pivot == null or attack == null:
		return

	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("begin_attack"):
		reset_visual_pose()
		runtime_weapon_rig.call("begin_attack", attack, get_attack_speed())
		return

	if swing_tween != null:
		swing_tween.kill()

	weapon_visual_pivot.visible = true
	weapon_visual_pivot.rotation_degrees = attack.windup_rotation_degrees
	weapon_visual_pivot.position = base_visual_position + attack.windup_offset

	var attack_speed: float = get_attack_speed()
	var startup_duration: float = attack.get_startup_duration(attack_speed)
	var active_duration: float = attack.get_active_duration(attack_speed)
	var recovery_duration: float = attack.get_recovery_duration(attack_speed)

	swing_tween = create_tween()
	swing_tween.set_trans(Tween.TRANS_QUAD)
	swing_tween.set_ease(Tween.EASE_OUT)
	swing_tween.parallel().tween_property(
		weapon_visual_pivot,
		"rotation_degrees",
		attack.strike_rotation_degrees,
		startup_duration
	)
	swing_tween.parallel().tween_property(
		weapon_visual_pivot,
		"position",
		base_visual_position + attack.strike_offset,
		startup_duration
	)
	swing_tween.tween_interval(active_duration)
	swing_tween.set_ease(Tween.EASE_IN_OUT)
	swing_tween.parallel().tween_property(
		weapon_visual_pivot,
		"rotation_degrees",
		attack.recovery_rotation_degrees,
		recovery_duration
	)
	swing_tween.parallel().tween_property(
		weapon_visual_pivot,
		"position",
		base_visual_position + attack.recovery_offset,
		recovery_duration
	)

	play_slash_trail(attack)


func reset_visual_pose() -> void:
	if swing_tween != null:
		swing_tween.kill()

	if weapon_visual_pivot != null:
		weapon_visual_pivot.position = base_visual_position
		weapon_visual_pivot.rotation_degrees = base_visual_rotation_degrees

	if slash_trail != null:
		slash_trail.visible = false

	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("end_attack"):
		runtime_weapon_rig.call("end_attack")


func setup_slash_trail() -> void:
	if slash_trail == null:
		return

	slash_trail.visible = false
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.9, 0.95, 1.0, 0.0)
	material.emission_enabled = true
	material.emission = Color(0.9, 0.95, 1.0, 1.0)
	material.emission_energy_multiplier = 1.3
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	slash_trail.material_override = material


func play_slash_trail(attack: WeaponAttackDefinition) -> void:
	if slash_trail == null or attack == null:
		return

	if sweep_tween != null:
		sweep_tween.kill()

	slash_trail.visible = true
	slash_trail.scale = attack.trail_start_scale
	set_slash_trail_color(get_infusion_attack_color(attack.trail_color), sweep_start_alpha)

	var duration: float = max(
		0.08,
		attack.get_startup_duration(get_attack_speed())
		+ attack.get_active_duration(get_attack_speed())
	)

	sweep_tween = create_tween()
	sweep_tween.parallel().tween_property(
		slash_trail,
		"scale",
		attack.trail_end_scale,
		duration
	)
	sweep_tween.parallel().tween_method(
		set_slash_trail_alpha,
		sweep_start_alpha,
		sweep_end_alpha,
		duration
	)
	sweep_tween.finished.connect(_on_sweep_finished)


func _on_sweep_finished() -> void:
	if slash_trail != null:
		slash_trail.visible = false


func set_slash_trail_color(color: Color, alpha: float) -> void:
	if slash_trail == null:
		return

	var material: StandardMaterial3D = slash_trail.material_override as StandardMaterial3D
	if material == null:
		return

	var resolved_color: Color = color
	resolved_color.a = alpha
	material.albedo_color = resolved_color
	material.emission = Color(color.r, color.g, color.b, 1.0)


func set_slash_trail_alpha(alpha: float) -> void:
	if slash_trail == null:
		return

	var material: StandardMaterial3D = slash_trail.material_override as StandardMaterial3D
	if material == null:
		return

	var color: Color = material.albedo_color
	color.a = alpha
	material.albedo_color = color


func refresh_weapon_visual() -> void:
	if weapon_model_root == null or equipped_weapon == null:
		return

	clear_weapon_model()
	weapon_model_root.scale = Vector3.ONE * max(equipped_weapon.visual_scale, 0.1)

	if equipped_weapon.runtime_rig_scene != null:
		var rig_instance: Node = equipped_weapon.runtime_rig_scene.instantiate()
		if rig_instance is Node3D:
			runtime_weapon_rig = rig_instance as Node3D
			weapon_model_root.add_child(runtime_weapon_rig)
			if runtime_weapon_rig.has_method("configure_weapon"):
				runtime_weapon_rig.call("configure_weapon", equipped_weapon, self)
			apply_infusion_visuals()
			return
		rig_instance.queue_free()

	match equipped_weapon.weapon_class:
		"hammer":
			build_hammer_visual()
		"lance":
			build_spear_visual()
		_:
			build_sword_visual()

	apply_infusion_visuals()


func apply_infusion_visuals() -> void:
	var infusion_id: String = GameState.get_weapon_infusion()
	if infusion_id == WeaponInfusionCatalogScript.DEFAULT_INFUSION_ID:
		return
	var infusion_color: Color = WeaponInfusionCatalogScript.get_color(infusion_id)
	for material: StandardMaterial3D in model_materials:
		var base_color: Color = material.albedo_color
		var infused_color: Color = base_color.lerp(infusion_color, 0.42)
		material.albedo_color = infused_color
		material.emission_enabled = true
		material.emission = infusion_color
		material.emission_energy_multiplier = maxf(material.emission_energy_multiplier, 1.15)


func get_infusion_attack_color(base_color: Color) -> Color:
	var infusion_id: String = GameState.get_weapon_infusion()
	if infusion_id == WeaponInfusionCatalogScript.DEFAULT_INFUSION_ID:
		return base_color
	return base_color.lerp(WeaponInfusionCatalogScript.get_color(infusion_id), 0.78)


func clear_weapon_model() -> void:
	if weapon_model_root == null:
		return

	for child: Node in weapon_model_root.get_children():
		weapon_model_root.remove_child(child)
		child.queue_free()

	runtime_weapon_rig = null
	model_materials.clear()


func build_sword_visual() -> void:
	# The hand remains anatomically right-sided, while the blade sits nearer the
	# character's center line so its silhouette does not feel detached from Grace.
	if slash_trail != null:
		slash_trail.position.x = 0.03
	add_box_part("Grip", Vector3(0.09, 0.09, 0.34), Vector3(-0.02, 0.0, 0.16), equipped_weapon.visual_secondary_color)
	add_box_part("Guard", Vector3(0.42, 0.08, 0.08), Vector3(-0.02, 0.0, -0.04), equipped_weapon.visual_accent_color, true)
	add_box_part("Blade", Vector3(0.11, 0.055, 1.12), Vector3(-0.02, 0.0, -0.64), equipped_weapon.visual_primary_color, true)


func build_hammer_visual() -> void:
	if slash_trail != null:
		slash_trail.position.x = 0.2
	add_box_part("Shaft", Vector3(0.11, 0.11, 1.28), Vector3(0.12, 0.0, -0.42), equipped_weapon.visual_secondary_color)
	add_box_part("Head", Vector3(0.74, 0.42, 0.34), Vector3(0.12, 0.0, -1.02), equipped_weapon.visual_primary_color)
	add_box_part("HeadBand", Vector3(0.8, 0.12, 0.39), Vector3(0.12, 0.0, -1.02), equipped_weapon.visual_accent_color, true)


func build_spear_visual() -> void:
	if slash_trail != null:
		slash_trail.position.x = 0.2
	add_box_part("Shaft", Vector3(0.075, 0.075, 1.82), Vector3(0.12, 0.0, -0.68), equipped_weapon.visual_secondary_color)
	add_cone_part("Tip", 0.17, 0.0, 0.56, Vector3(0.12, 0.0, -1.86), Vector3(90.0, 0.0, 0.0), equipped_weapon.visual_primary_color, true)
	add_box_part("Collar", Vector3(0.2, 0.12, 0.16), Vector3(0.12, 0.0, -1.55), equipped_weapon.visual_accent_color, true)


func add_box_part(
	part_name: String,
	size: Vector3,
	local_position: Vector3,
	color: Color,
	emissive: bool = false
) -> void:
	if weapon_model_root == null:
		return

	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = local_position
	part.material_override = create_weapon_material(color, emissive)
	weapon_model_root.add_child(part)


func add_cone_part(
	part_name: String,
	bottom_radius: float,
	top_radius: float,
	height: float,
	local_position: Vector3,
	local_rotation_degrees: Vector3,
	color: Color,
	emissive: bool = false
) -> void:
	if weapon_model_root == null:
		return

	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 10
	part.mesh = mesh
	part.position = local_position
	part.rotation_degrees = local_rotation_degrees
	part.material_override = create_weapon_material(color, emissive)
	weapon_model_root.add_child(part)


func create_weapon_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.45
	material.roughness = 0.38

	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 0.75

	model_materials.append(material)
	return material


func show_attack_debug_wedge(attack: WeaponAttackDefinition) -> void:
	if attack == null or get_tree().current_scene == null:
		return

	var debug_mesh: MeshInstance3D = MeshInstance3D.new()
	debug_mesh.name = "WeaponAttackDebugWedge"
	debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material: StandardMaterial3D = StandardMaterial3D.new()
	var color: Color = Color(1.0, 0.32, 0.12, 0.28) if attack.input_kind == INPUT_HEAVY else Color(0.28, 0.72, 1.0, 0.24)
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var immediate_mesh: ImmediateMesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)

	var segments: int = 18
	var half_angle: float = deg_to_rad(clampf(attack.cone_angle_degrees, 1.0, 360.0) * 0.5)
	var radius: float = max(attack.attack_range, 0.1)

	for index: int in range(segments):
		var weight_a: float = float(index) / float(segments)
		var weight_b: float = float(index + 1) / float(segments)
		var angle_a: float = lerpf(-half_angle, half_angle, weight_a)
		var angle_b: float = lerpf(-half_angle, half_angle, weight_b)
		immediate_mesh.surface_add_vertex(Vector3.ZERO)
		immediate_mesh.surface_add_vertex(Vector3(sin(angle_a) * radius, 0.0, -cos(angle_a) * radius))
		immediate_mesh.surface_add_vertex(Vector3(sin(angle_b) * radius, 0.0, -cos(angle_b) * radius))

	immediate_mesh.surface_end()
	debug_mesh.mesh = immediate_mesh
	get_tree().current_scene.add_child(debug_mesh)
	debug_mesh.global_position = get_attack_origin() - Vector3.UP * (attack_origin_height - 0.06)
	debug_mesh.look_at(debug_mesh.global_position + get_attack_forward(), Vector3.UP)

	var tween: Tween = debug_mesh.create_tween()
	tween.tween_interval(max(debug_hitbox_lifetime, 0.05))
	tween.tween_callback(Callable(debug_mesh, "queue_free"))


func show_message(text: String) -> void:
	if show_debug_prints:
		print(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)


func emit_combo_state() -> void:
	combo_state_changed.emit(get_debug_data())


func get_debug_data() -> Dictionary:
	var weapon_name: String = "none"
	var moveset_name: String = "none"
	var attack_name: String = "none"
	var cast_cancel: bool = false
	var dodge_cancel: bool = false

	if equipped_weapon != null:
		weapon_name = equipped_weapon.display_name
		if equipped_weapon.moveset != null:
			moveset_name = equipped_weapon.moveset.display_name

	if current_attack != null:
		attack_name = current_attack.display_name

	if action_state != null:
		cast_cancel = action_state.attack_allows_cast_cancel
		dodge_cancel = action_state.attack_allows_dodge_cancel

	var runtime_data: Dictionary = {}
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("get_debug_data"):
		var rig_data: Variant = runtime_weapon_rig.call("get_debug_data")
		if rig_data is Dictionary:
			runtime_data = rig_data as Dictionary

	return {
		"weapon": weapon_name,
		"class": equipped_weapon.weapon_class if equipped_weapon != null else "none",
		"moveset": moveset_name,
		"attack": attack_name,
		"attack_id": current_attack.attack_id if current_attack != null else last_completed_attack_id,
		"phase": current_phase,
		"elapsed": snapped(current_attack_elapsed, 0.01),
		"queued": queued_input if queued_input != "" else "none",
		"queue_time": snapped(queued_input_timer, 0.01),
		"combo_time": snapped(combo_timeout_timer, 0.01),
		"chain": combo_history.duplicate(),
		"cast_cancel": cast_cancel,
		"dodge_cancel": dodge_cancel,
		"runtime_rig": runtime_data,
		"infusion": WeaponInfusionCatalogScript.get_display_name(GameState.get_weapon_infusion()),
		"technique": active_technique_id if active_technique_id != "" else "none",
	}
