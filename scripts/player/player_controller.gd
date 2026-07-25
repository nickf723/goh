extends CharacterBody3D

@export var move_speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 18.0
@export var mouse_sensitivity: float = 0.0025
@export var controller_camera_sensitivity: float = 3.0
@export var controller_camera_deadzone: float = 0.18
@export var allow_controller_camera_during_focus_menu: bool = false
@export var spell_mana_cost: int = 1

@export var lock_on_range: float = 18.0
@export var lock_on_forward_score_bonus: float = 8.0
@export var lock_on_turn_speed: float = 8.0
@export var lock_on_marker_height: float = 2.1
@export var lock_on_marker_size: float = 0.34
@export var lock_on_marker_pulse_speed: float = 7.0
@export var lock_on_marker_pulse_size: float = 0.18
@export var lock_on_camera_pitch: float = -12.0
@export var lock_on_camera_pitch_strength: float = 4.0
@export var lock_on_switch_deadzone: float = 0.72
@export var lock_on_switch_cooldown: float = 0.34
@export var lock_on_default_aim_height: float = 0.78
@export var lock_on_aim_height_ratio: float = 0.48
@export var lock_on_min_aim_height: float = 0.55
@export var lock_on_max_aim_height: float = 1.05
@export var lock_on_cast_origin_height: float = 1.05
@export_range(0.1, 3.0, 0.05) var lock_on_visibility_grace_seconds: float = 0.85
@export var lock_on_dynamic_camera_pitch: bool = true

@onready var camera_pivot: Node3D = $CameraPivot
@onready var interaction_area: Area3D = $InteractionArea
@onready var ability_caster: Node3D = $AbilityCaster
@onready var spell_label: Label = $SpellLabel
@onready var targeting_assist: CombatTargetingAssist = get_node_or_null("CombatTargetingAssist") as CombatTargetingAssist
@onready var stealth_controller: Node = get_node_or_null("StealthController")

var dodge_controller: PlayerDodgeController
var quick_item_controller: Node

var camera_pitch: float = deg_to_rad(-15.0)
var min_pitch: float = deg_to_rad(-60.0)
var max_pitch: float = deg_to_rad(25.0)

var nearby_interactables: Array[Area3D] = []
var current_interactable: Area3D = null

var is_defeated: bool = false
var lock_on_target: Node3D = null
var lock_on_marker: MeshInstance3D = null
var lock_on_switch_timer: float = 0.0
var lock_on_visibility_timer: float = 0.0


func _ready() -> void:
	dodge_controller = find_dodge_controller()
	quick_item_controller = get_node_or_null("PlayerQuickItemController")
	print("Player found dodge controller: ", dodge_controller.get_path() if dodge_controller != null else "none")

	ensure_runtime_lock_on_input_map()
	create_lock_on_marker()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_pivot.rotation.x = camera_pitch

	interaction_area.area_entered.connect(_on_interaction_area_entered)
	interaction_area.area_exited.connect(_on_interaction_area_exited)
	GameState.player_defeated.connect(_on_player_defeated)


func _process(delta: float) -> void:
	update_lock_on_switch_timer(delta)

	if has_lock_on_target():
		handle_lock_on_target_switch_input()
		update_lock_on(delta)
	else:
		update_controller_camera(delta)


func _unhandled_input(event: InputEvent) -> void:
	if is_defeated:
		if event.is_action_pressed("restart_scene"):
			GameState.reset_run()
			get_tree().reload_current_scene()
		return

	if event.is_action_pressed("lock_on"):
		toggle_lock_on()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("lock_on_previous"):
		cycle_lock_on_target(-1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("lock_on_next"):
		cycle_lock_on_target(1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("spell_menu"):
		if is_focus_spell_menu_open():
			if ability_caster.has_method("close_focus_spell_menu"):
				ability_caster.call("close_focus_spell_menu")
		else:
			if ability_caster.has_method("open_focus_spell_menu"):
				ability_caster.call("open_focus_spell_menu")
		get_viewport().set_input_as_handled()
		return

	if is_focus_spell_menu_open():
		if ability_caster.has_method("handle_focus_menu_input"):
			if ability_caster.handle_focus_menu_input(event):
				get_viewport().set_input_as_handled()
				return

		if event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
			return

		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion:
		if has_lock_on_target():
			clear_lock_on("Lock-on released.")
		rotate_y(-event.relative.x * mouse_sensitivity)

		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, min_pitch, max_pitch)
		camera_pivot.rotation.x = camera_pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("interact"):
		interact_with_current()
		
	if event.is_action_pressed("ability_slot_1"):
		ability_caster.select_ability(0)

	if event.is_action_pressed("ability_slot_2"):
		ability_caster.select_ability(1)
		
	if event.is_action_pressed("ability_slot_3"):
		ability_caster.select_ability(2)
		
	if event.is_action_pressed("ability_slot_4"):
		ability_caster.select_ability(3)
		
	if event.is_action_pressed("ability_slot_5"):
		ability_caster.select_ability(4)
		
	if event.is_action_pressed("ability_slot_6"):
		ability_caster.select_ability(5)
		
	if event.is_action_pressed("ability_slot_7"):
		ability_caster.select_ability(6)
		
	if event.is_action_pressed("ability_slot_8"):
		ability_caster.select_ability(7)
		
	if event.is_action_pressed("ability_slot_9"):
		ability_caster.select_ability(8)
		
	if event.is_action_pressed("ability_slot_0"):
		ability_caster.select_ability(9)
		
	if event.is_action_pressed("next_ability"):
		ability_caster.select_next_ability()

	if event.is_action_pressed("cast_spell"):
		ability_caster.cast_from_player(self)


func update_controller_camera(delta: float) -> void:
	if is_defeated:
		return

	if is_focus_spell_menu_open() and not allow_controller_camera_during_focus_menu:
		return

	var look_vector: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)

	if look_vector.length() < controller_camera_deadzone:
		return

	rotate_y(-look_vector.x * controller_camera_sensitivity * delta)

	camera_pitch -= look_vector.y * controller_camera_sensitivity * delta
	camera_pitch = clamp(camera_pitch, min_pitch, max_pitch)
	camera_pivot.rotation.x = camera_pitch


func _physics_process(delta: float) -> void:
	if dodge_controller != null and dodge_controller.is_dodge_active():
		var dodge_velocity: Vector3 = dodge_controller.get_dodge_velocity()

		velocity.x = dodge_velocity.x
		velocity.z = dodge_velocity.z

		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			if velocity.y < 0.0:
				velocity.y = -0.1

		move_and_slide()
		return
	if is_defeated:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	var direction := Vector3.ZERO

	if input_vector.length() > 0.0:
		direction = (
			global_transform.basis.x * input_vector.x
			+ global_transform.basis.z * input_vector.y
		)
		direction.y = 0.0
		direction = direction.normalized()

	var movement_multiplier: float = 1.0
	if quick_item_controller != null and quick_item_controller.has_method("get_movement_multiplier"):
		movement_multiplier = float(quick_item_controller.call("get_movement_multiplier"))
	if stealth_controller != null and stealth_controller.has_method("get_movement_multiplier"):
		movement_multiplier *= float(stealth_controller.call("get_movement_multiplier"))

	velocity.x = direction.x * move_speed * movement_multiplier
	velocity.z = direction.z * move_speed * movement_multiplier

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		var item_allows_jump: bool = true
		if quick_item_controller != null and quick_item_controller.has_method("allows_jump"):
			item_allows_jump = bool(quick_item_controller.call("allows_jump"))
		if item_allows_jump and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity

	move_and_slide()


func ensure_runtime_lock_on_input_map() -> void:
	ensure_input_action("lock_on")
	ensure_input_action("lock_on_previous")
	ensure_input_action("lock_on_next")

	if not input_action_has_key("lock_on", KEY_T):
		var key_event: InputEventKey = InputEventKey.new()
		key_event.physical_keycode = KEY_T
		InputMap.action_add_event("lock_on", key_event)

	if not input_action_has_key("lock_on_previous", KEY_COMMA):
		var previous_key_event: InputEventKey = InputEventKey.new()
		previous_key_event.physical_keycode = KEY_COMMA
		InputMap.action_add_event("lock_on_previous", previous_key_event)

	if not input_action_has_key("lock_on_next", KEY_PERIOD):
		var next_key_event: InputEventKey = InputEventKey.new()
		next_key_event.physical_keycode = KEY_PERIOD
		InputMap.action_add_event("lock_on_next", next_key_event)

	# Godot's standard right-stick click / R3 button. If a controller driver reports
	# this differently, we can swap the button index after one test.
	if not input_action_has_joy_button("lock_on", 8):
		var joy_event: InputEventJoypadButton = InputEventJoypadButton.new()
		joy_event.button_index = 8
		InputMap.action_add_event("lock_on", joy_event)


func ensure_input_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.2)


func input_action_has_key(action_name: String, physical_keycode: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.physical_keycode == physical_keycode:
				return true

	return false


func input_action_has_joy_button(action_name: String, button_index: int) -> bool:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
			if joy_event.button_index == button_index:
				return true

	return false


func update_lock_on_switch_timer(delta: float) -> void:
	if lock_on_switch_timer > 0.0:
		lock_on_switch_timer -= delta


func handle_lock_on_target_switch_input() -> void:
	if lock_on_switch_timer > 0.0:
		return

	var look_vector: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_up",
		"camera_down"
	)

	if abs(look_vector.x) < lock_on_switch_deadzone:
		return

	var direction: int = 1

	if look_vector.x < 0.0:
		direction = -1

	cycle_lock_on_target(direction)
	lock_on_switch_timer = lock_on_switch_cooldown


func toggle_lock_on() -> void:
	if has_lock_on_target():
		clear_lock_on("Lock-on released.")
		return

	var found_target: Node3D = find_best_lock_on_target()

	if found_target == null:
		show_game_message("No target in range.")
		return

	set_lock_on_target(found_target)


func set_lock_on_target(target: Node3D, switched: bool = false) -> void:
	lock_on_target = target
	lock_on_visibility_timer = 0.0
	if targeting_assist != null:
		targeting_assist.set_hard_target(target)
	update_lock_on_marker()

	if switched:
		show_game_message("Switched: " + get_target_display_name(target))
	else:
		show_game_message("Locked: " + get_target_display_name(target))


func clear_lock_on(message: String = "") -> void:
	lock_on_target = null
	lock_on_visibility_timer = 0.0
	if targeting_assist != null:
		targeting_assist.clear_hard_target()

	if lock_on_marker != null:
		lock_on_marker.visible = false

	if message != "":
		show_game_message(message)


func has_lock_on_target() -> bool:
	return lock_on_target != null and is_instance_valid(lock_on_target) and not is_target_defeated(lock_on_target)


func update_lock_on(delta: float) -> void:
	if not has_lock_on_target():
		clear_lock_on()
		return

	if global_position.distance_to(lock_on_target.global_position) > lock_on_range * 1.25:
		clear_lock_on("Target lost.")
		return

	if targeting_assist != null:
		var target_visible: bool = targeting_assist.is_target_visible(lock_on_target)
		var target_on_screen: bool = targeting_assist.is_target_on_screen(lock_on_target)
		if target_visible and target_on_screen:
			lock_on_visibility_timer = 0.0
		else:
			lock_on_visibility_timer += max(delta, 0.0)
			if lock_on_visibility_timer > lock_on_visibility_grace_seconds:
				clear_lock_on("Target lost behind cover.")
				return

	face_lock_on_target(delta)
	update_lock_on_camera_pitch(delta)
	update_lock_on_marker()


func face_lock_on_target(delta: float) -> void:
	var to_target: Vector3 = lock_on_target.global_position - global_position
	to_target.y = 0.0

	if to_target.length() <= 0.01:
		return

	var target_angle: float = atan2(-to_target.normalized().x, -to_target.normalized().z)
	var turn_amount: float = clamp(lock_on_turn_speed * delta, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, target_angle, turn_amount)


func update_lock_on_camera_pitch(delta: float) -> void:
	var target_pitch: float = deg_to_rad(lock_on_camera_pitch)
	if lock_on_dynamic_camera_pitch and targeting_assist != null:
		target_pitch = targeting_assist.get_dynamic_camera_pitch(lock_on_target)
	var pitch_amount: float = clamp(lock_on_camera_pitch_strength * delta, 0.0, 1.0)
	camera_pitch = lerp(camera_pitch, target_pitch, pitch_amount)
	camera_pitch = clamp(camera_pitch, min_pitch, max_pitch)
	camera_pivot.rotation.x = camera_pitch


func cycle_lock_on_target(direction: int) -> void:
	if direction == 0:
		return

	if not has_lock_on_target():
		var found_target: Node3D = find_best_lock_on_target()

		if found_target != null:
			set_lock_on_target(found_target)
		else:
			show_game_message("No target in range.")
		return

	var next_target: Node3D = find_directional_cycle_target(direction)

	if next_target == null:
		next_target = find_best_lock_on_target(lock_on_target)

	if next_target == null or next_target == lock_on_target:
		show_game_message("No other target.")
		return

	set_lock_on_target(next_target, true)


func find_best_lock_on_target(exclude_target: Node3D = null) -> Node3D:
	if targeting_assist != null:
		targeting_assist.hard_lock_range = lock_on_range
		return targeting_assist.find_best_hard_target(exclude_target)

	var best_target: Node3D = null
	var best_score: float = INF
	var camera: Camera3D = get_viewport().get_camera_3d()

	for candidate: Node3D in get_lock_on_candidates(exclude_target):
		var distance: float = global_position.distance_to(candidate.global_position)
		var score: float = distance

		if camera != null:
			var to_target: Vector3 = get_target_aim_point(candidate) - camera.global_position

			if to_target.length() > 0.01:
				var camera_forward: Vector3 = -camera.global_transform.basis.z
				var forward_dot: float = camera_forward.normalized().dot(to_target.normalized())

				if forward_dot < -0.25:
					continue

				score -= forward_dot * lock_on_forward_score_bonus

		if score < best_score:
			best_score = score
			best_target = candidate

	return best_target


func find_directional_cycle_target(direction: int) -> Node3D:
	if not has_lock_on_target():
		return null
	if targeting_assist != null:
		return targeting_assist.find_directional_target(lock_on_target, direction)

	var camera: Camera3D = get_viewport().get_camera_3d()
	var side_axis: Vector3 = global_transform.basis.x

	if camera != null:
		side_axis = camera.global_transform.basis.x

	side_axis.y = 0.0

	if side_axis.length() <= 0.01:
		side_axis = global_transform.basis.x

	side_axis = side_axis.normalized()

	var current_point: Vector3 = get_target_aim_point(lock_on_target)
	var best_target: Node3D = null
	var best_score: float = -INF

	for candidate: Node3D in get_lock_on_candidates(lock_on_target):
		var offset: Vector3 = get_target_aim_point(candidate) - current_point
		offset.y = 0.0

		if offset.length() <= 0.01:
			continue

		var side_score: float = side_axis.dot(offset.normalized()) * float(direction)

		if side_score <= 0.12:
			continue

		var distance_penalty: float = clamp(offset.length() / lock_on_range, 0.0, 1.0) * 0.25
		var score: float = side_score - distance_penalty

		if score > best_score:
			best_score = score
			best_target = candidate

	return best_target


func get_lock_on_candidates(exclude_target: Node3D = null) -> Array[Node3D]:
	if targeting_assist != null:
		targeting_assist.hard_lock_range = lock_on_range
		return targeting_assist.get_hard_candidates(exclude_target)

	var candidates: Array[Node3D] = []

	for candidate_node: Node in get_tree().get_nodes_in_group("enemy"):
		if not candidate_node is Node3D:
			continue

		var candidate: Node3D = candidate_node as Node3D

		if candidate == exclude_target:
			continue

		if not is_instance_valid(candidate):
			continue

		if is_target_defeated(candidate):
			continue

		var distance: float = global_position.distance_to(candidate.global_position)

		if distance > lock_on_range:
			continue

		candidates.append(candidate)

	return candidates


func is_target_defeated(target: Node) -> bool:
	if target == null:
		return true

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver == null:
		return false

	var current_health = hit_receiver.get("current_health")

	if current_health != null and int(current_health) <= 0:
		return true

	return false


func get_target_aim_point(target: Node3D) -> Vector3:
	if target == null:
		return global_position
	if targeting_assist != null:
		return targeting_assist.get_target_aim_point(target)

	return target.global_position + Vector3.UP * get_target_center_mass_height(target)


func get_target_center_mass_height(target: Node3D) -> float:
	var body_height: float = get_target_collision_height(target)

	if body_height > 0.01:
		return clamp(
			body_height * lock_on_aim_height_ratio,
			lock_on_min_aim_height,
			lock_on_max_aim_height
		)

	return lock_on_default_aim_height


func get_target_collision_height(node: Node) -> float:
	if node == null:
		return 0.0

	var best_height: float = 0.0

	if node is CollisionShape3D:
		var collision_shape: CollisionShape3D = node as CollisionShape3D
		best_height = max(best_height, get_shape_height(collision_shape.shape))

	for child: Node in node.get_children():
		best_height = max(best_height, get_target_collision_height(child))

	return best_height


func get_shape_height(shape: Shape3D) -> float:
	if shape == null:
		return 0.0

	if shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = shape as CapsuleShape3D
		return max(capsule.height, capsule.radius * 2.0)

	if shape is BoxShape3D:
		var box: BoxShape3D = shape as BoxShape3D
		return box.size.y

	if shape is SphereShape3D:
		var sphere: SphereShape3D = shape as SphereShape3D
		return sphere.radius * 2.0

	if shape is CylinderShape3D:
		var cylinder: CylinderShape3D = shape as CylinderShape3D
		return cylinder.height

	return 0.0


func get_lock_on_cast_direction(cast_origin: Vector3 = Vector3.ZERO) -> Vector3:
	if not has_lock_on_target():
		return Vector3.ZERO

	var origin: Vector3 = cast_origin

	if origin == Vector3.ZERO:
		origin = global_position + Vector3.UP * lock_on_cast_origin_height

	var direction: Vector3 = get_target_aim_point(lock_on_target) - origin

	if direction.length() <= 0.01:
		return Vector3.ZERO

	return direction.normalized()


func get_soft_aim_cast_direction(cast_origin: Vector3 = Vector3.ZERO) -> Vector3:
	if targeting_assist == null:
		return Vector3.ZERO
	var origin: Vector3 = cast_origin
	if origin == Vector3.ZERO:
		origin = global_position + Vector3.UP * lock_on_cast_origin_height
	return targeting_assist.get_soft_aim_direction(origin)


func get_combat_aim_direction(
	aim_origin: Vector3 = Vector3.ZERO,
	allow_soft_aim: bool = true
) -> Vector3:
	if has_lock_on_target():
		return get_lock_on_cast_direction(aim_origin)
	if allow_soft_aim:
		return get_soft_aim_cast_direction(aim_origin)
	return Vector3.ZERO


func get_target_display_name(target: Node) -> String:
	if target == null:
		return "Target"
	if targeting_assist != null and target is Node3D:
		return targeting_assist.get_target_display_name(target)

	var brain: Node = target.get_node_or_null("EnemyBrain")

	if brain != null and brain.has_method("get_definition"):
		var definition = brain.get_definition()

		if definition != null and "display_name" in definition:
			return str(definition.display_name)

	return target.name.capitalize()


func create_lock_on_marker() -> void:
	if lock_on_marker != null:
		return

	lock_on_marker = MeshInstance3D.new()
	lock_on_marker.name = "LockOnMarker"
	lock_on_marker.visible = false
	lock_on_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var marker_mesh: SphereMesh = SphereMesh.new()
	marker_mesh.radius = lock_on_marker_size
	marker_mesh.height = lock_on_marker_size * 2.0
	lock_on_marker.mesh = marker_mesh

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.86, 0.18, 0.82)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.72, 0.08, 1.0)
	material.emission_energy_multiplier = 1.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lock_on_marker.material_override = material

	add_child(lock_on_marker)


func update_lock_on_marker() -> void:
	if lock_on_marker == null:
		return

	if not has_lock_on_target():
		lock_on_marker.visible = false
		return

	lock_on_marker.visible = true
	lock_on_marker.global_position = get_target_aim_point(lock_on_target) + Vector3.UP * 0.32
	update_lock_on_marker_color()

	var pulse_age: float = float(Time.get_ticks_msec()) * 0.001
	var pulse: float = 1.0 + sin(pulse_age * lock_on_marker_pulse_speed) * lock_on_marker_pulse_size
	lock_on_marker.scale = Vector3.ONE * max(pulse, 0.25)

	var camera: Camera3D = get_viewport().get_camera_3d()

	if camera != null:
		lock_on_marker.look_at(camera.global_position, Vector3.UP)


func update_lock_on_marker_color() -> void:
	if lock_on_marker == null:
		return
	var material: StandardMaterial3D = lock_on_marker.material_override as StandardMaterial3D
	if material == null:
		return
	var color: Color = Color(1.0, 0.76, 0.12, 0.92)
	if targeting_assist != null:
		color = targeting_assist.get_target_color(lock_on_target, false)
	material.albedo_color = color
	material.emission = Color(color.r, color.g, color.b, 1.0)


func show_game_message(text: String) -> void:
	var ui: Node = get_game_ui()

	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func _on_interaction_area_entered(area: Area3D) -> void:
	print("Area entered: ", area.name)

	if area.has_method("interact"):
		print("Interactable detected: ", area.name)
		nearby_interactables.append(area)
		current_interactable = area
		update_interaction_prompt()
	else:
		print("Area does not have interact(): ", area.name)


func _on_interaction_area_exited(area: Area3D) -> void:
	print("Area exited: ", area.name)

	if nearby_interactables.has(area):
		nearby_interactables.erase(area)

	if current_interactable == area:
		current_interactable = nearby_interactables.back() if nearby_interactables.size() > 0 else null

	update_interaction_prompt()


func update_interaction_prompt() -> void:
	var game_ui := get_game_ui()

	if game_ui == null:
		return

	if current_interactable == null:
		game_ui.hide_prompt()
		return

	var prompt := "Interact"

	if "prompt_text" in current_interactable:
		prompt = current_interactable.prompt_text

	game_ui.show_prompt(prompt)


func interact_with_current() -> void:
	print("Pressed interact.")

	if current_interactable == null:
		print("No current interactable.")
		return

	print("Interacting with: ", current_interactable.name)

	var interaction_result: Dictionary = current_interactable.interact()
	print("Interaction result: ", interaction_result)

	var ui: Node = get_game_ui()

	if ui == null:
		print("No game UI found.")
		return

	if interaction_result.has("message"):
		ui.show_message(interaction_result["message"])

	if interaction_result.has("objective") and interaction_result["objective"] != "":
		ui.set_objective(interaction_result["objective"])

	if interaction_result.has("show_prologue_choice") and interaction_result["show_prologue_choice"]:
		ui.show_prologue_choice()


func get_game_ui() -> Node:
	return get_tree().get_first_node_in_group("game_ui")
	
	var spent_mana: bool = GameState.spend_mana(spell_mana_cost)

	if not spent_mana:
		print("Not enough mana.")
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	var cast_direction: Vector3 = -global_transform.basis.z

	if camera != null:
		cast_direction = -camera.global_transform.basis.z

	print("Cast Arcane Spark. Mana: ", GameState.get_stat("mana"), " / ", GameState.get_stat("max_mana"))


func set_spell_label(ability_name: String) -> void:
	spell_label.text = "Spell: " + ability_name


func is_focus_spell_menu_open() -> bool:
	if ability_caster == null:
		return false

	if not ability_caster.has_method("is_focus_spell_menu_open"):
		return false

	return ability_caster.is_focus_spell_menu_open()


func _on_player_defeated() -> void:
	is_defeated = true
	clear_lock_on()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func find_dodge_controller() -> PlayerDodgeController:
	var direct_node: Node = get_node_or_null("DodgeController")

	if direct_node is PlayerDodgeController:
		return direct_node as PlayerDodgeController

	for child: Node in get_children():
		if child is PlayerDodgeController:
			return child as PlayerDodgeController

	return null
