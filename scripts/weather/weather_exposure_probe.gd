extends Node3D
class_name WeatherExposureProbe

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var probe_label: String = "WEATHER EXPOSURE"
@export var wet_duration: float = 3.2
@export var frozen_duration: float = 4.2
@export var snow_exposure_to_freeze: float = 1.2

var wet_timer: float = 0.0
var frozen_timer: float = 0.0
var snow_exposure: float = 0.0
var weather_state: String = "dry"

var body_mesh: MeshInstance3D = null
var state_label: Label3D = null
var dry_material: StandardMaterial3D = null
var wet_material: StandardMaterial3D = null
var frosting_material: StandardMaterial3D = null
var frozen_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("weather_exposed")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	build_visuals()
	set_weather_state("dry")


func _process(delta: float) -> void:
	if frozen_timer > 0.0:
		frozen_timer -= delta
		if frozen_timer <= 0.0:
			snow_exposure = 0.0
			set_weather_state("wet" if wet_timer > 0.0 else "dry")

	if wet_timer > 0.0:
		wet_timer -= delta
		if wet_timer <= 0.0 and frozen_timer <= 0.0:
			set_weather_state("dry")


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
	frosting_material = ElementVisuals.make_material(Color(0.62, 0.82, 0.94, 1.0), 1.1, 0.88, false)
	frozen_material = ElementVisuals.make_material(Color(0.72, 0.96, 1.0, 1.0), 2.1, 0.94, false)

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

	var element: String = payload.element.to_lower().strip_edges()
	var normalized_tags: Array[String] = []
	for raw_tag: String in payload.tags:
		normalized_tags.append(raw_tag.to_lower().strip_edges())

	if element == "ice" or "snow" in normalized_tags or "cold" in normalized_tags:
		wet_timer = 0.0
		frozen_timer = max(payload.status_duration, frozen_duration)
		snow_exposure += max(payload.status_strength, 0.2)
		var is_frozen: bool = snow_exposure >= max(snow_exposure_to_freeze, 0.1)
		set_weather_state("frozen" if is_frozen else "frosting")
		return {
			"message": probe_label + (" freezes under " if is_frozen else " gathers frost from ") + payload.source_name + ".",
			"frozen": is_frozen,
			"snow_exposure": snow_exposure,
		}

	if element == "water" or "rain" in normalized_tags:
		frozen_timer = 0.0
		snow_exposure = 0.0
		wet_timer = max(payload.status_duration, wet_duration)
		set_weather_state("wet")
		return {
			"message": probe_label + " is soaked by " + payload.source_name + ".",
			"wet": true,
		}

	return {}


func set_weather_state(next_state: String) -> void:
	weather_state = next_state
	if body_mesh != null:
		match weather_state:
			"wet":
				body_mesh.material_override = wet_material
			"frosting":
				body_mesh.material_override = frosting_material
			"frozen":
				body_mesh.material_override = frozen_material
			_:
				body_mesh.material_override = dry_material

	if state_label != null:
		match weather_state:
			"wet":
				state_label.text = probe_label + "\nWET"
				state_label.modulate = Color(0.45, 0.82, 1.0, 1.0)
			"frosting":
				state_label.text = probe_label + "\nFROSTING"
				state_label.modulate = Color(0.72, 0.9, 1.0, 1.0)
			"frozen":
				state_label.text = probe_label + "\nFROZEN"
				state_label.modulate = Color(0.82, 0.98, 1.0, 1.0)
			_:
				state_label.text = probe_label + "\nDRY"
				state_label.modulate = Color(0.86, 0.72, 0.52, 1.0)


func set_wet_state(is_wet: bool) -> void:
	set_weather_state("wet" if is_wet else "dry")


func reset_target() -> void:
	wet_timer = 0.0
	frozen_timer = 0.0
	snow_exposure = 0.0
	set_weather_state("dry")


func get_debug_data() -> Dictionary:
	return {
		"weather_probe": probe_label,
		"state": weather_state,
		"wet": wet_timer > 0.0,
		"wet_time": snapped(wet_timer, 0.1),
		"frozen_time": snapped(frozen_timer, 0.1),
		"snow_exposure": snapped(snow_exposure, 0.1),
	}
