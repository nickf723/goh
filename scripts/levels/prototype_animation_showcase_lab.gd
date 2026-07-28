extends Node3D
class_name PrototypeAnimationShowcaseLab

const POSE_STATES: Array[String] = [
	"idle", "locomotion", "jump", "fall", "landing", "swim_surface", "swim_underwater", "climb", "mantle",
	"attack", "guard", "dodge", "hit", "cast", "flight", "exhausted", "defeated",
]

var player: CharacterBody3D
var visual: StylizedActorVisual
var feedback: PlayerMotionFeedback
var climbing: PlayerClimbingController
var ground_motion: PlayerGroundMotionMotor
var dodge_motion: PlayerDodgeController
var status_label: Label
var pose_index: int = -1


func _ready() -> void:
	_build_environment()
	_build_course()
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		visual = player.get_node_or_null("GraceVisualV1") as StylizedActorVisual
		feedback = player.get_node_or_null("PlayerMotionFeedback") as PlayerMotionFeedback
		climbing = player.get_node_or_null("ClimbingController") as PlayerClimbingController
		ground_motion = player.get_node_or_null("GroundMotionMotor") as PlayerGroundMotionMotor
		dodge_motion = player.get_node_or_null("PlayerDodgeController") as PlayerDodgeController
	_configure_player()
	_build_hud()
	GameState.set_objective("Accelerate, stop, reverse, dodge, recover, fight, and inspect Grace's transitions.")


func _process(_delta: float) -> void:
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		_reset_lab()
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_P:
		_cycle_pose()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_O:
		_clear_pose()
		get_viewport().set_input_as_handled()


func _configure_player() -> void:
	GameState.set_stat("max_health", 80)
	GameState.set_stat("health", 80)
	GameState.set_stat("max_stamina", 60)
	GameState.set_stat("stamina", 60)
	GameState.set_stat("max_stance", 35)
	GameState.set_stat("stance", 35)
	if player == null:
		return
	var weapon := player.get_node_or_null("WeaponController") as WeaponController
	if weapon != null:
		weapon.show_debug_prints = false
		weapon.print_attack_debug = false
	if dodge_motion != null:
		dodge_motion.show_debug_prints = false


func _cycle_pose() -> void:
	if visual == null:
		return
	pose_index = (pose_index + 1) % POSE_STATES.size()
	visual.set_debug_forced_state(POSE_STATES[pose_index])
	_show_message("Pose preview: " + POSE_STATES[pose_index].to_upper())


func _clear_pose() -> void:
	pose_index = -1
	if visual != null:
		visual.clear_debug_forced_state()
	_show_message("Pose preview cleared; live animation restored.")


func _reset_lab() -> void:
	_clear_pose()
	if climbing != null:
		climbing.reset_climbing()
	if ground_motion != null:
		ground_motion.reset_motion()
	if dodge_motion != null:
		dodge_motion.cancel_dodge("lab_reset")
		dodge_motion.cooldown_timer = 0.0
		dodge_motion.chain_count = 0
	if player != null:
		player.global_position = Vector3(0, 1.1, 8.0)
		player.rotation = Vector3.ZERO
		player.velocity = Vector3.ZERO
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.018, 0.032)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38, 0.46, 0.66)
	environment.ambient_light_energy = 0.86
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.62
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color(0.74, 0.86, 1.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 5, -2)
	rim.light_color = Color(1.0, 0.48, 0.18)
	rim.light_energy = 5.0
	rim.omni_range = 13.0
	add_child(rim)


func _build_course() -> void:
	_add_box_body("Floor", Vector3(22, 0.8, 24), Vector3(0, -0.4, 0), Color(0.065, 0.08, 0.13))
	for index: int in range(5):
		var height: float = 0.35 + float(index) * 0.28
		_add_box_body(
			"LandingStep" + str(index),
			Vector3(2.2, height, 1.5),
			Vector3(-5.5, height * 0.5, 4.0 - float(index) * 1.5),
			Color(0.12, 0.28 + float(index) * 0.035, 0.48)
		)
	var wall := _add_box_body("ClimbWall", Vector3(4.2, 5.2, 0.5), Vector3(5.5, 2.6, 0), Color(0.32, 0.24, 0.15))
	wall.add_to_group("climbable")
	wall.set_meta("climb_surface", "wood")
	_add_box_body("ClimbTop", Vector3(4.2, 0.4, 3.4), Vector3(5.5, 5.0, -1.7), Color(0.32, 0.24, 0.15))

	# Long lanes expose start, stop, and reversal response. The offset gates invite
	# figure-eight turns without adding collision noise to the movement test.
	_add_box_body("TurnMarkerLeft", Vector3(0.16, 0.04, 8.0), Vector3(-2.2, 0.03, 1.5), Color(0.12, 0.52, 0.9), false)
	_add_box_body("TurnMarkerRight", Vector3(0.16, 0.04, 8.0), Vector3(2.2, 0.03, 1.5), Color(0.12, 0.52, 0.9), false)
	_add_box_body("StartLine", Vector3(4.6, 0.045, 0.13), Vector3(0, 0.035, 6.4), Color(0.18, 0.82, 0.48), false)
	_add_box_body("BrakeLine", Vector3(4.6, 0.045, 0.13), Vector3(0, 0.035, 3.8), Color(1.0, 0.48, 0.18), false)
	_add_box_body("ReverseLine", Vector3(4.6, 0.045, 0.13), Vector3(0, 0.035, 1.2), Color(0.88, 0.28, 0.86), false)
	for marker_data: Dictionary in [
		{"name": "FigureEightNW", "position": Vector3(-2.4, 0.06, -2.0)},
		{"name": "FigureEightNE", "position": Vector3(2.4, 0.06, -2.0)},
		{"name": "FigureEightSW", "position": Vector3(-2.4, 0.06, -5.0)},
		{"name": "FigureEightSE", "position": Vector3(2.4, 0.06, -5.0)},
	]:
		_add_box_body(
			str(marker_data["name"]),
			Vector3(0.32, 0.12, 0.32),
			marker_data["position"] as Vector3,
			Color(0.38, 0.72, 1.0),
			false
		)

	# The dodge lane makes launch, protected travel, recovery, wall collision, and
	# sideways exits legible without building a separate laboratory.
	_add_box_body("DodgeLaunchLine", Vector3(4.8, 0.045, 0.13), Vector3(0, 0.035, -6.3), Color(0.28, 0.9, 0.95), false)
	_add_box_body("DodgeIFrameLine", Vector3(4.8, 0.045, 0.13), Vector3(0, 0.035, -7.25), Color(0.96, 0.9, 0.28), false)
	_add_box_body("DodgeRecoveryLine", Vector3(4.8, 0.045, 0.13), Vector3(0, 0.035, -8.15), Color(0.86, 0.34, 0.96), false)
	_add_box_body("DodgeStopWall", Vector3(5.6, 1.8, 0.36), Vector3(0, 0.9, -9.55), Color(0.56, 0.12, 0.18))
	_add_box_body("SideDodgeLeft", Vector3(0.13, 0.045, 2.3), Vector3(-3.0, 0.035, -7.45), Color(0.24, 0.74, 1.0), false)
	_add_box_body("SideDodgeRight", Vector3(0.13, 0.045, 2.3), Vector3(3.0, 0.035, -7.45), Color(1.0, 0.36, 0.72), false)

	var title := Label3D.new()
	title.text = "GRACE MOTION SHOWCASE"
	title.position = Vector3(0, 7.0, -7.2)
	title.font_size = 38
	title.pixel_size = 0.008
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 8
	title.modulate = Color(0.72, 0.88, 1.0)
	add_child(title)
	var instructions := Label3D.new()
	instructions.text = "START • BRAKE • REVERSE • FIGURE 8 • STAIRS   |   DODGE / CHAIN / ATTACK / CAST / GUARD   |   P POSES • O LIVE • F8 RESET"
	instructions.position = Vector3(0, 6.2, -7.1)
	instructions.font_size = 17
	instructions.pixel_size = 0.008
	instructions.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instructions.outline_size = 6
	instructions.modulate = Color(0.86, 0.93, 1.0)
	add_child(instructions)


func _add_box_body(
	body_name: String,
	size: Vector3,
	position: Vector3,
	color: Color,
	with_collision: bool = true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = position
	if with_collision:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.3
	material.roughness = 0.58
	material.emission_enabled = true
	material.emission = color.darkened(0.3)
	material.emission_energy_multiplier = 0.32
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	add_child(body)
	return body


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(700, 168)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.022, 0.043, 0.9)
	style.border_color = Color(0.3, 0.66, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0))
	panel.add_child(status_label)


func _update_hud() -> void:
	if status_label == null or visual == null:
		return
	var animation: Dictionary = visual.get_animation_debug_data()
	var feedback_data: Dictionary = feedback.get_debug_data() if feedback != null else {}
	var motor: Dictionary = ground_motion.get_debug_data() if ground_motion != null else {}
	var dodge: Dictionary = dodge_motion.get_debug_data() if dodge_motion != null else {}
	var acceleration: Vector3 = animation.get("acceleration", Vector3.ZERO)
	status_label.text = (
		"ANIMATION  •  " + str(animation.get("presentation_state", "idle")).to_upper()
		+ "  •  " + str(animation.get("state_elapsed", 0.0)) + "s"
		+ "     FORCED " + str(animation.get("forced_state", "none")).to_upper()
		+ "\nMOTOR  •  " + str(motor.get("state", "legacy")).to_upper()
		+ "     TARGET " + str(motor.get("target_speed", 0.0))
		+ "     ACTUAL " + str(motor.get("actual_speed", 0.0))
		+ "     INPUT " + str(motor.get("input_strength", 0.0))
		+ "\nDODGE  •  " + str(dodge.get("phase", "idle")).to_upper()
		+ "     " + str(dodge.get("kind", "forward")).to_upper()
		+ "     PROGRESS " + str(dodge.get("progress", 0.0))
		+ "     SPEED " + str(dodge.get("speed", 0.0))
		+ "     I-FRAME " + ("YES" if bool(dodge.get("iframe", false)) else "NO")
		+ "     CHAIN " + str(dodge.get("chain_count", 0))
		+ "\nWINDOWS  •  ATTACK " + ("OPEN" if bool(dodge.get("attack_cancel_ready", false)) else "-")
		+ "     CAST " + ("OPEN" if bool(dodge.get("cast_cancel_ready", false)) else "-")
		+ "     GUARD " + ("OPEN" if bool(dodge.get("guard_cancel_ready", false)) else "-")
		+ "     NEXT DODGE " + ("OPEN" if bool(dodge.get("chain_ready", false)) else "-")
		+ "     BUFFER " + str(dodge.get("buffered_follow_up", ""))
		+ "\nINTENT  •  TURN " + str(motor.get("turn_angle_degrees", 0.0)) + "°"
		+ "     BRAKE " + str(motor.get("braking_weight", 0.0))
		+ "     REVERSE " + str(motor.get("reversal_weight", 0.0))
		+ "     ACCEL " + str(snappedf(acceleration.length(), 0.1))
		+ "\nFEEDBACK  •  FOOT " + str(feedback_data.get("footstep_side", "left")).to_upper()
		+ "     LIVE EFFECTS " + str(feedback_data.get("live_effects", 0))
		+ "     LANDING " + str(animation.get("landing", 0.0)) + "s"
	)


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
