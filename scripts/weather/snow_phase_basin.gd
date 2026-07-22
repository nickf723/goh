extends Node3D
class_name SnowPhaseBasin

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var basin_label: String = "PHASE BASIN"
@export_range(0.1, 5.0, 0.1) var freeze_threshold: float = 1.4
@export_range(0.0, 1.0, 0.01) var passive_thaw_per_second: float = 0.08

var frost_load: float = 0.0
var recent_cold_timer: float = 0.0
var water_mesh: MeshInstance3D = null
var ice_mesh: MeshInstance3D = null
var state_label: Label3D = null


func _ready() -> void:
	add_to_group("weather_exposed")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	build_visuals()
	update_visuals()


func _process(delta: float) -> void:
	if recent_cold_timer > 0.0:
		recent_cold_timer -= delta
		return
	if frost_load <= 0.0:
		return
	frost_load = max(frost_load - passive_thaw_per_second * max(delta, 0.0), 0.0)
	update_visuals()


func build_visuals() -> void:
	ElementVisuals.add_torus(self, "BasinRim", 1.45, 1.7, Color(0.42, 0.46, 0.52, 1.0), Vector3(0.0, 0.34, 0.0), Vector3.ZERO, 0.2, 1.0)
	ElementVisuals.add_box(self, "BasinBase", Vector3(3.2, 0.32, 3.2), Color(0.22, 0.25, 0.29, 1.0), Vector3(0.0, 0.12, 0.0), Vector3.ZERO, 0.1, 1.0)

	water_mesh = MeshInstance3D.new()
	water_mesh.name = "Water"
	var water_shape := CylinderMesh.new()
	water_shape.top_radius = 1.42
	water_shape.bottom_radius = 1.42
	water_shape.height = 0.08
	water_shape.radial_segments = 28
	water_mesh.mesh = water_shape
	water_mesh.position = Vector3(0.0, 0.38, 0.0)
	water_mesh.material_override = ElementVisuals.make_material(Color(0.1, 0.52, 0.98, 1.0), 1.25, 0.74, true)
	add_child(water_mesh)

	ice_mesh = MeshInstance3D.new()
	ice_mesh.name = "IceCap"
	var ice_shape := CylinderMesh.new()
	ice_shape.top_radius = 1.43
	ice_shape.bottom_radius = 1.43
	ice_shape.height = 0.11
	ice_shape.radial_segments = 28
	ice_mesh.mesh = ice_shape
	ice_mesh.position = Vector3(0.0, 0.405, 0.0)
	ice_mesh.material_override = ElementVisuals.make_material(Color(0.65, 0.92, 1.0, 1.0), 2.0, 0.82, true)
	add_child(ice_mesh)

	state_label = Label3D.new()
	state_label.name = "StateLabel"
	state_label.position = Vector3(0.0, 2.0, 0.0)
	state_label.font_size = 30
	state_label.pixel_size = 0.007
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.outline_size = 5
	add_child(state_label)

	var collision_body := StaticBody3D.new()
	collision_body.name = "CollisionBody"
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.65
	shape.height = 0.55
	collision.shape = shape
	collision.position = Vector3(0.0, 0.28, 0.0)
	collision_body.add_child(collision)
	add_child(collision_body)


func receive_weather_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	var tags: Array[String] = []
	for raw_tag: String in payload.tags:
		tags.append(raw_tag.to_lower().strip_edges())
	if payload.element.to_lower().strip_edges() != "ice" and not tags.has("snow") and not tags.has("cold"):
		return {}

	frost_load = min(frost_load + max(payload.status_strength, 0.2), freeze_threshold * 1.25)
	recent_cold_timer = max(payload.status_duration, 1.2)
	update_visuals()
	return {
		"message": basin_label + " gathers atmospheric Ice.",
		"frost_load": frost_load,
		"frozen": is_frozen(),
	}


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	var element: String = payload.element.to_lower().strip_edges()
	var tags: Array[String] = []
	for raw_tag: String in payload.tags:
		tags.append(raw_tag.to_lower().strip_edges())

	if element == "fire" or tags.has("heat") or tags.has("melt"):
		frost_load = max(frost_load - max(float(abs(payload.amount)) * 0.55, 0.8), 0.0)
		recent_cold_timer = 0.0
		update_visuals()
		return {
			"message": payload.source_name + " melts the basin ice.",
			"frost_load": frost_load,
			"frozen": is_frozen(),
		}

	if element == "ice" or tags.has("snow") or tags.has("cold"):
		return receive_weather_payload(payload)
	return {}


func is_frozen() -> bool:
	return frost_load >= freeze_threshold


func update_visuals() -> void:
	var ratio: float = clampf(frost_load / max(freeze_threshold, 0.1), 0.0, 1.0)
	if ice_mesh != null:
		ice_mesh.visible = ratio > 0.01
		ice_mesh.scale = Vector3(lerpf(0.12, 1.0, ratio), lerpf(0.16, 1.0, ratio), lerpf(0.12, 1.0, ratio))
	if water_mesh != null:
		water_mesh.scale.y = lerpf(1.0, 0.55, ratio)
	if state_label != null:
		if is_frozen():
			state_label.text = basin_label + "\nFROZEN • FIRE MELTS IT"
			state_label.modulate = Color(0.76, 0.96, 1.0, 1.0)
		elif frost_load > 0.0:
			state_label.text = basin_label + "\nFREEZING " + str(int(round(ratio * 100.0))) + "%"
			state_label.modulate = Color(0.62, 0.84, 1.0, 1.0)
		else:
			state_label.text = basin_label + "\nLIQUID WATER"
			state_label.modulate = Color(0.32, 0.7, 1.0, 1.0)


func reset_target() -> void:
	frost_load = 0.0
	recent_cold_timer = 0.0
	update_visuals()


func get_debug_data() -> Dictionary:
	return {
		"snow_phase_basin": basin_label,
		"frost_load": snapped(frost_load, 0.1),
		"freeze_threshold": freeze_threshold,
		"frozen": is_frozen(),
	}
