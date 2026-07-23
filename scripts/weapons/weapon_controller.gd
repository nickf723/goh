extends Node3D
class_name WeaponController

signal weapon_changed(weapon: WeaponDefinition)
signal attack_started(attack: WeaponAttackDefinition)
signal attack_finished(attack_id: String)
signal combo_state_changed(debug_data: Dictionary)

const INPUT_LIGHT: String = "light"
const INPUT_HEAVY: String = "heavy"

@export var equipped_weapon: WeaponDefinition
@export var hit_mask: int = 0xFFFFFFFF
@export var attack_origin_height: float = 1.0
@export var use_camera_direction: bool = true
@export var close_range_auto_hit_radius: float = 0.85

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

var swing_tween: Tween
var sweep_tween: Tween
var model_materials: Array[StandardMaterial3D] = []
var runtime_weapon_rig: Node3D

@onready var weapon_visual_pivot: Node3D = get_node_or_null("HandAnchor/WeaponVisualPivot")
@onready var weapon_model_root: Node3D = get_node_or_null("HandAnchor/WeaponVisualPivot/WeaponModelRoot")
@onready var slash_trail: MeshInstance3D = get_node_or_null("HandAnchor/WeaponVisualPivot/SlashTrail")
@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState")

var base_visual_position: Vector3 = Vector3.ZERO
var base_visual_rotation_degrees: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("debuggable")

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


func _process(delta: float) -> void:
	update_queued_input(delta)

	if current_attack != null:
		update_current_attack(delta)
	else:
		update_combo_timeout(delta)


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

	if action_state != null and not action_state.can_attack():
		return

	var requested_attack: WeaponAttackDefinition = resolve_idle_attack(input_kind)

	if requested_attack == null:
		show_message(equipped_weapon.display_name + " has no " + input_kind + " attack from this combo state.")
		reset_combo_chain()
		return

	start_attack(requested_attack)


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
		if action_state.is_defeated or action_state.is_casting or action_state.is_dodging:
			cancel_current_attack("cancelled")
			return

	current_attack_elapsed += delta
	var attack_speed: float = get_attack_speed()
	var startup_duration: float = current_attack.get_startup_duration(attack_speed)
	var active_end: float = startup_duration + current_attack.get_active_duration(attack_speed)
	var total_duration: float = current_attack.get_total_duration(attack_speed)

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

	if attack.stamina_cost > 0:
		if not GameState.spend_stamina(attack.stamina_cost):
			show_message("Not enough stamina for " + attack.display_name + ".")
			reset_combo_chain()
			return false

	current_attack = attack
	current_attack_elapsed = 0.0
	current_phase = "startup"
	attack_hit_applied = false
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
	return max(equipped_weapon.attack_speed, 0.05)


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
	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("modify_attack_payload"):
		runtime_weapon_rig.call("modify_attack_payload", payload, current_attack)

	var targets: Array[Node] = find_targets(current_attack)
	var messages: Array[String] = []

	for target: Node in targets:
		var result: Dictionary = send_payload_to_target(target, payload)

		if result.has("message") and result["message"] != "":
			messages.append(str(result["message"]))

	if runtime_weapon_rig != null and runtime_weapon_rig.has_method("on_weapon_targets_hit"):
		runtime_weapon_rig.call("on_weapon_targets_hit", targets, current_attack)

	if targets.size() > 0:
		HitStop.request(
			max(current_attack.hit_stop_duration, 0.0),
			clampf(current_attack.hit_stop_time_scale, 0.01, 1.0)
		)
	elif show_debug_prints:
		messages.append(equipped_weapon.display_name + " • " + current_attack.display_name + " misses.")

	if messages.size() > 0:
		show_message("\n".join(messages))

	if show_debug_hitboxes:
		show_attack_debug_wedge(current_attack)


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
				if resolved_targets.size() >= max(attack.max_targets, 1):
					break
			return resolved_targets

	var actor: Node3D = get_actor()

	if actor == null or attack == null:
		return []

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = max(attack.attack_range, 0.1)

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

		if targets.size() >= max(attack.max_targets, 1):
			break

	return targets


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
	var actor: Node3D = get_actor()

	if actor != null and actor.has_method("has_lock_on_target") and actor.has_lock_on_target():
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
	set_slash_trail_color(attack.trail_color, sweep_start_alpha)

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
			return
		rig_instance.queue_free()

	match equipped_weapon.weapon_class:
		"hammer":
			build_hammer_visual()
		"lance":
			build_spear_visual()
		_:
			build_sword_visual()


func clear_weapon_model() -> void:
	if weapon_model_root == null:
		return

	for child: Node in weapon_model_root.get_children():
		weapon_model_root.remove_child(child)
		child.queue_free()

	runtime_weapon_rig = null
	model_materials.clear()


func build_sword_visual() -> void:
	add_box_part("Grip", Vector3(0.09, 0.09, 0.34), Vector3(0.15, 0.0, 0.16), equipped_weapon.visual_secondary_color)
	add_box_part("Guard", Vector3(0.42, 0.08, 0.08), Vector3(0.15, 0.0, -0.04), equipped_weapon.visual_accent_color, true)
	add_box_part("Blade", Vector3(0.11, 0.055, 1.12), Vector3(0.15, 0.0, -0.64), equipped_weapon.visual_primary_color, true)


func build_hammer_visual() -> void:
	add_box_part("Shaft", Vector3(0.11, 0.11, 1.28), Vector3(0.12, 0.0, -0.42), equipped_weapon.visual_secondary_color)
	add_box_part("Head", Vector3(0.74, 0.42, 0.34), Vector3(0.12, 0.0, -1.02), equipped_weapon.visual_primary_color)
	add_box_part("HeadBand", Vector3(0.8, 0.12, 0.39), Vector3(0.12, 0.0, -1.02), equipped_weapon.visual_accent_color, true)


func build_spear_visual() -> void:
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
	}
