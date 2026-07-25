extends CharacterBody3D
class_name ResearchableGoose

signal studied(action: String, result: Dictionary)
signal temperament_changed(temperament: String)

@export var goose_name: String = "Wild Goose"
@export var temperament: String = "CURIOUS"
@export var wander_radius: float = 3.0
@export var move_speed: float = 1.6
@export var gravity: float = 18.0

var home_position: Vector3
var wander_target: Vector3
var wander_timer: float = 0.0
var fed: bool = false
var soothed: bool = false
var observed_moving: bool = false
var honk_count: int = 0
var elapsed: float = 0.0
var visual_root: Node3D
var state_label: Label3D
var species_knowledge: Node


func _ready() -> void:
	species_knowledge = get_node_or_null("/root/SpeciesKnowledge")
	home_position = global_position
	wander_target = home_position
	add_to_group("study_animals")
	add_to_group("debuggable")
	_build_goose()


func _physics_process(delta: float) -> void:
	elapsed += delta
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 4.5)
		var angle: float = randf() * TAU
		var radius: float = randf_range(0.4, wander_radius)
		wander_target = home_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
	var offset: Vector3 = wander_target - global_position
	offset.y = 0.0
	if offset.length() > 0.25:
		var direction: Vector3 = offset.normalized()
		velocity.x = move_toward(velocity.x, direction.x * move_speed, 5.0 * delta)
		velocity.z = move_toward(velocity.z, direction.z * move_speed, 5.0 * delta)
		var target_yaw: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 5.0, 0.0, 1.0))
		observed_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1
	move_and_slide()
	_update_visual()


func perform_study_action(action: String, researcher: Node3D = null) -> Dictionary:
	var discovery_id: String = ""
	var label: String = ""
	var points: int = 1
	match action:
		"observe":
			if fed:
				discovery_id = "feeding_posture"
				label = "Observed how geese feed"
			elif observed_moving:
				discovery_id = "walking_gait"
				label = "Observed the goose walking gait"
			else:
				discovery_id = "alert_posture"
				label = "Observed the goose alert posture"
		"feed":
			fed = true
			temperament = "FRIENDLY"
			discovery_id = "preferred_food"
			label = "Learned the goose's preferred food"
			points = 2
			temperament_changed.emit(temperament)
		"soothe":
			soothed = true
			temperament = "CALM"
			discovery_id = "social_bond"
			label = "Earned a goose's trust"
			points = 2
			temperament_changed.emit(temperament)
		"honk":
			honk_count += 1
			temperament = "ALARMED"
			discovery_id = "alarm_call"
			label = "Studied the territorial alarm cry"
			points = 2
			temperament_changed.emit(temperament)
		_:
			return {}
	if species_knowledge == null or not species_knowledge.has_method("add_discovery"):
		push_warning("SpeciesKnowledge service is unavailable.")
		return {}
	var result: Dictionary = species_knowledge.call("add_discovery", "goose", discovery_id, label, points)
	result["action"] = action
	result["goose"] = goose_name
	studied.emit(action, result)
	_show_message((label + "!") if bool(result.get("new_discovery", false)) else goose_name + " is already familiar with that interaction.")
	if researcher != null:
		_face_researcher(researcher)
	return result


func get_context_actions() -> Array[Dictionary]:
	return [
		{"id": "observe", "label": "Observe", "direction": "LEFT"},
		{"id": "feed", "label": "Feed", "direction": "UP"},
		{"id": "soothe", "label": "Soothe", "direction": "RIGHT"},
	]


func reset_goose() -> void:
	global_position = home_position
	velocity = Vector3.ZERO
	fed = false
	soothed = false
	observed_moving = false
	honk_count = 0
	temperament = "CURIOUS"


func get_debug_data() -> Dictionary:
	return {
		"name": goose_name,
		"temperament": temperament,
		"fed": fed,
		"soothed": soothed,
		"honk_count": honk_count,
	}


func _face_researcher(researcher: Node3D) -> void:
	var direction: Vector3 = researcher.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		rotation.y = atan2(-direction.normalized().x, -direction.normalized().z)


func _build_goose() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 0.9
	collision.shape = shape
	collision.position.y = 0.45
	add_child(collision)
	visual_root = Node3D.new()
	add_child(visual_root)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.78, 0.76, 0.68)
	white.roughness = 0.88
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.035, 0.045, 0.04)
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.96, 0.42, 0.04)
	var body := MeshInstance3D.new()
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.38
	body_mesh.height = 0.76
	body.mesh = body_mesh
	body.scale = Vector3(0.9, 0.75, 1.35)
	body.position = Vector3(0, 0.56, 0.08)
	body.material_override = white
	visual_root.add_child(body)
	var neck := MeshInstance3D.new()
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.13
	neck_mesh.bottom_radius = 0.18
	neck_mesh.height = 0.72
	neck.mesh = neck_mesh
	neck.position = Vector3(0, 1.03, -0.28)
	neck.rotation_degrees.x = -14
	neck.material_override = black
	visual_root.add_child(neck)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position = Vector3(0, 1.42, -0.42)
	head.material_override = black
	visual_root.add_child(head)
	var beak := MeshInstance3D.new()
	var beak_mesh := PrismMesh.new()
	beak_mesh.size = Vector3(0.18, 0.12, 0.35)
	beak.mesh = beak_mesh
	beak.position = Vector3(0, 1.39, -0.68)
	beak.rotation_degrees.x = 90
	beak.material_override = orange
	visual_root.add_child(beak)
	for side: float in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wing_mesh := SphereMesh.new()
		wing_mesh.radius = 0.26
		wing_mesh.height = 0.52
		wing.mesh = wing_mesh
		wing.scale = Vector3(0.42, 0.48, 1.18)
		wing.position = Vector3(side * 0.32, 0.62, 0.08)
		wing.material_override = white
		visual_root.add_child(wing)
	state_label = Label3D.new()
	state_label.position = Vector3(0, 1.9, 0)
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.font_size = 20
	state_label.pixel_size = 0.006
	state_label.outline_size = 7
	state_label.modulate = Color(1.0, 0.84, 0.38)
	visual_root.add_child(state_label)


func _update_visual() -> void:
	if visual_root != null:
		visual_root.position.y = absf(sin(elapsed * 5.0)) * velocity.length() * 0.012
	if state_label != null:
		state_label.text = goose_name + "\n" + temperament


func _show_message(message: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", message)
	else:
		print(message)
