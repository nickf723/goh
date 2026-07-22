extends Node3D
class_name WeatherExposureProbe

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var probe_label: String = "WEATHER EXPOSURE"
@export var wet_duration: float = 3.2

var wet_timer: float = 0.0
var body_mesh: MeshInstance3D = null
var state_label: Label3D = null
var dry_material: StandardMaterial3D = null
var wet_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("weather_exposed")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	build_visuals()
	set_wet_state(false)


func _process(delta: float) -> void:
	if wet_timer <= 0.0:
		return
	wet_timer -= delta
	if wet_timer <= 0.0:
		set_wet_state(false)


func build_visuals() -> void:
	if body_mesh != null:
		return

	body_mesh = MeshInstance3D.new()
	body_mesh.name = "ProbeBody"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.65
	mesh.bottom_radius = 0.75
	mesh.height = 1.4
	mesh.radial_segments = 18
	body_mesh.mesh = mesh
	body_mesh.position = Vector3(0.0, 0.7, 0.0)
	add_child(body_mesh)

	dry_material = ElementVisuals.make_material(Color(0.28, 0.24, 0.2, 1.0), 0.15, 1.0, false)
	wet_material = ElementVisuals.make_material(Color(0.12, 0.46, 0.86, 1.0), 1.6, 0.82, false)

	state_label = Label3D.new()
	state_label.name = "StateLabel"
	state_label.position = Vector3(0.0, 1.75, 0.0)
	state_label.font_size = 30
	state_label.pixel_size = 0.007
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.outline_size = 5
	add_child(state_label)

	var collision_body := StaticBody3D.new()
	collision_body.name = "CollisionBody"
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.72
	shape.height = 1.4
	collision.shape = shape
	collision.position = Vector3(0.0, 0.7, 0.0)
	collision_body.add_child(collision)
	add_child(collision_body)


func receive_weather_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	if payload.element.to_lower() != "water" and not payload.tags.has("rain"):
		return {}

	wet_timer = max(payload.status_duration, wet_duration)
	set_wet_state(true)
	return {
		"message": probe_label + " is soaked by " + payload.source_name + ".",
		"wet": true,
	}


func set_wet_state(is_wet: bool) -> void:
	if body_mesh != null:
		body_mesh.material_override = wet_material if is_wet else dry_material
	if state_label != null:
		state_label.text = probe_label + "\n" + ("WET" if is_wet else "DRY")
		state_label.modulate = Color(0.45, 0.82, 1.0, 1.0) if is_wet else Color(0.86, 0.72, 0.52, 1.0)


func reset_target() -> void:
	wet_timer = 0.0
	set_wet_state(false)


func get_debug_data() -> Dictionary:
	return {
		"weather_probe": probe_label,
		"wet": wet_timer > 0.0,
		"wet_time": snapped(wet_timer, 0.1),
	}
