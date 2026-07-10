extends Node3D
class_name WeaponController

@export var equipped_weapon: WeaponDefinition
@export var hit_mask: int = 0xFFFFFFFF
@export var attack_origin_height: float = 1.0
@export var attack_center_forward_offset: float = 1.15
@export var use_camera_direction: bool = true
@export var show_debug_prints: bool = true

@export var sweep_duration: float = 0.14
@export var sweep_start_alpha: float = 0.75
@export var sweep_end_alpha: float = 0.0
@export var sweep_start_scale: Vector3 = Vector3(0.35, 0.75, 1.0)
@export var sweep_end_scale: Vector3 = Vector3(0.85, 1.35, 1.0)

var cooldown_timer: float = 0.0
var swing_tween: Tween
var sweep_tween: Tween

@onready var weapon_visual_pivot: Node3D = get_node_or_null("HandAnchor/WeaponVisualPivot")
@onready var slash_trail: MeshInstance3D = get_node_or_null("HandAnchor/WeaponVisualPivot/SlashTrail")
@onready var action_state: PlayerActionState = get_parent().get_node_or_null("PlayerActionState")

@export var hit_stop_duration: float = 0.055
@export var hit_stop_time_scale: float = 0.05
@export var hit_stop_on_success: bool = true
@export var close_range_auto_hit_radius: float = 0.85
@export var print_attack_debug: bool = false

@export var default_weapon_path: String = "res://data/weapons/practice_sword.tres"

func _ready() -> void:
	add_to_group("debuggable")

	if equipped_weapon == null and default_weapon_path != "":
		var loaded_weapon: Resource = load(default_weapon_path)

		if loaded_weapon is WeaponDefinition:
			equipped_weapon = loaded_weapon as WeaponDefinition

	print("WeaponController ready: ", get_path(), " weapon=", equipped_weapon.display_name if equipped_weapon != null else "none")

	setup_slash_trail()

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_light_attack"):
		try_light_attack()

func try_light_attack() -> void:
	if action_state != null and not action_state.can_attack():
		return

	if equipped_weapon == null:
		show_message("No weapon equipped.")
		return

	if cooldown_timer > 0.0:
		return

	if equipped_weapon.stamina_cost > 0:
		if not GameState.spend_stamina(equipped_weapon.stamina_cost):
			show_message("Not enough stamina.")
			return

	cooldown_timer = equipped_weapon.cooldown

	if action_state != null:
		action_state.begin_attack(equipped_weapon.cooldown)

	play_swing_visual()
	play_slash_trail()

	var payload: DamagePayload = equipped_weapon.get_light_payload()
	var targets: Array[Node] = find_targets()

	if targets.size() == 0:
		show_message(equipped_weapon.display_name + " swings through empty air.")
		return

	var messages: Array[String] = []

	for target: Node in targets:
		var result: Dictionary = send_payload_to_target(target, payload)

		if result.has("message") and result["message"] != "":
			messages.append(str(result["message"]))

	if hit_stop_on_success and targets.size() > 0:
		HitStop.request(hit_stop_duration, hit_stop_time_scale)

	if messages.size() > 0:
		show_message("\n".join(messages))
	if action_state != null and not action_state.can_attack():
		return

	if equipped_weapon == null:
		show_message("No weapon equipped.")
		return

	if cooldown_timer > 0.0:
		return

	if equipped_weapon.stamina_cost > 0:
		if not GameState.spend_stamina(equipped_weapon.stamina_cost):
			show_message("Not enough stamina.")
			return

	cooldown_timer = equipped_weapon.cooldown

	if action_state != null:
		action_state.begin_attack(equipped_weapon.cooldown)

	play_swing_visual()
	play_slash_trail()
	if action_state != null and not action_state.can_attack():
		return
	if equipped_weapon == null:
		show_message("No weapon equipped.")
		return

	if cooldown_timer > 0.0:
		return

	if equipped_weapon.stamina_cost > 0:
		if not GameState.spend_stamina(equipped_weapon.stamina_cost):
			show_message("Not enough stamina.")
			return

	cooldown_timer = equipped_weapon.cooldown
	play_swing_visual()
	play_slash_trail()


	if targets.size() == 0:
		show_message(equipped_weapon.display_name + " swings through empty air.")
		return


	for target: Node in targets:
		var result: Dictionary = send_payload_to_target(target, payload)

		if result.has("message") and result["message"] != "":
			messages.append(str(result["message"]))
	if hit_stop_on_success and targets.size() > 0:
		HitStop.request(hit_stop_duration, hit_stop_time_scale)
	
	if messages.size() > 0:
		show_message("\n".join(messages))

func find_targets() -> Array[Node]:
	var actor: Node3D = get_actor()

	if actor == null or equipped_weapon == null:
		return []

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = equipped_weapon.range

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), get_attack_center())
	query.collision_mask = hit_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true

	if actor is CollisionObject3D:
		query.exclude = [actor.get_rid()]

	var results: Array[Dictionary] = space_state.intersect_shape(query, 32)
	var targets: Array[Node] = []
	var seen_ids: Dictionary = {}

	for result: Dictionary in results:
		if not result.has("collider"):
			continue

		var collider: Node = result["collider"]
		var target: Node = find_payload_target(collider)

		if print_attack_debug:
			print("Sword collider: ", collider.name, " target: ", target.name if target != null else "none")

		if target == null:
			continue

		if target == actor:
			continue

		if not is_target_in_front(target):
			if print_attack_debug:
				print("Sword rejected target, not in front: ", target.name)
			continue

		var target_id: int = target.get_instance_id()

		if seen_ids.has(target_id):
			continue

		seen_ids[target_id] = true
		targets.append(target)

		if targets.size() >= equipped_weapon.max_targets:
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
		"message": equipped_weapon.display_name + " hits " + target.name + ", but nothing receives it.",
		"objective": ""
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

func is_payload_target(node: Node) -> bool:
	if node.get_node_or_null("PayloadReceiver") != null:
		return true

	if node.get_node_or_null("HitReceiver") != null:
		return true

	if node.has_method("receive_damage_payload"):
		return true

	return false

func is_target_in_front(target: Node) -> bool:
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
	var minimum_dot: float = cos(deg_to_rad(equipped_weapon.cone_angle_degrees * 0.5))

	return forward.dot(direction) >= minimum_dot

func get_attack_origin() -> Vector3:
	var actor: Node3D = get_actor()

	if actor == null:
		return global_position

	return actor.global_position + Vector3.UP * attack_origin_height

func get_attack_center() -> Vector3:
	return get_attack_origin() + get_attack_forward() * attack_center_forward_offset

func get_attack_forward() -> Vector3:
	if use_camera_direction:
		var camera: Camera3D = get_viewport().get_camera_3d()

		if camera != null:
			var camera_forward: Vector3 = -camera.global_transform.basis.z
			camera_forward.y = 0.0

			if camera_forward.length() > 0.01:
				return camera_forward.normalized()

	var actor: Node3D = get_actor()

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
		return parent

	return null

func play_swing_visual() -> void:
	if weapon_visual_pivot == null:
		return

	if swing_tween != null:
		swing_tween.kill()

	weapon_visual_pivot.visible = true
	weapon_visual_pivot.rotation_degrees = Vector3(0.0, -55.0, 0.0)

	swing_tween = create_tween()
	swing_tween.tween_property(
		weapon_visual_pivot,
		"rotation_degrees",
		Vector3(0.0, 65.0, 0.0),
		max(0.08, equipped_weapon.cooldown * 0.35)
	)
	swing_tween.tween_property(
		weapon_visual_pivot,
		"rotation_degrees",
		Vector3(0.0, 0.0, 0.0),
		max(0.08, equipped_weapon.cooldown * 0.25)
	)

func setup_slash_trail() -> void:
	if slash_trail == null:
		return

	slash_trail.visible = false

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.9, 0.95, 1.0, 0.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	slash_trail.material_override = material

func play_slash_trail() -> void:
	if slash_trail == null:
		return

	if sweep_tween != null:
		sweep_tween.kill()

	slash_trail.visible = true
	slash_trail.scale = sweep_start_scale
	set_slash_trail_alpha(sweep_start_alpha)

	sweep_tween = create_tween()
	sweep_tween.parallel().tween_property(
		slash_trail,
		"scale",
		sweep_end_scale,
		sweep_duration
	)
	sweep_tween.parallel().tween_method(
		set_slash_trail_alpha,
		sweep_start_alpha,
		sweep_end_alpha,
		sweep_duration
	)
	sweep_tween.finished.connect(_on_sweep_finished)

func _on_sweep_finished() -> void:
	if slash_trail != null:
		slash_trail.visible = false

func set_slash_trail_alpha(alpha: float) -> void:
	if slash_trail == null:
		return

	var material: StandardMaterial3D = slash_trail.material_override as StandardMaterial3D

	if material == null:
		return

	var color: Color = material.albedo_color
	color.a = alpha
	material.albedo_color = color

func show_message(text: String) -> void:
	if show_debug_prints:
		print(text)

	var ui: Node = get_tree().get_first_node_in_group("game_ui")

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)

func get_debug_data() -> Dictionary:
	var weapon_name: String = "none"

	if equipped_weapon != null:
		weapon_name = equipped_weapon.display_name

	return {
		"weapon": weapon_name,
		"cooldown": snapped(cooldown_timer, 0.01),
		"range": equipped_weapon.range if equipped_weapon != null else 0.0,
	}

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
