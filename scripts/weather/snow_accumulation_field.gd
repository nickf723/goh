extends Node3D
class_name SnowAccumulationField

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var field_size: Vector2 = Vector2(16.0, 16.0)
@export_range(0.01, 0.5, 0.01) var accumulation_per_pulse: float = 0.08
@export_range(0.0, 0.25, 0.01) var passive_melt_per_second: float = 0.018
@export_range(0.1, 1.0, 0.05) var footprint_threshold: float = 0.32
@export_range(0.1, 1.0, 0.05) var footprint_interval: float = 0.28
@export_range(0.5, 12.0, 0.5) var footprint_lifetime: float = 5.0

var coverage: float = 0.0
var recent_snow_timer: float = 0.0
var footprint_timer: float = 0.0
var player: Node3D = null
var snow_layer: MeshInstance3D = null
var snow_material: StandardMaterial3D = null
var footprint_root: Node3D = null
var footprint_count: int = 0


func _ready() -> void:
	add_to_group("weather_exposed")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	build_visuals()
	update_visual()


func _process(delta: float) -> void:
	if recent_snow_timer > 0.0:
		recent_snow_timer -= delta
	elif coverage > 0.0:
		coverage = max(coverage - passive_melt_per_second * max(delta, 0.0), 0.0)
		update_visual()

	footprint_timer -= delta
	if coverage >= footprint_threshold and footprint_timer <= 0.0:
		footprint_timer = max(footprint_interval, 0.1)
		try_spawn_footprint()


func build_visuals() -> void:
	if snow_layer != null:
		return

	snow_layer = MeshInstance3D.new()
	snow_layer.name = "AccumulatedSnow"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(field_size.x, 0.1, field_size.y)
	snow_layer.mesh = mesh
	snow_layer.position = Vector3(0.0, 0.045, 0.0)
	snow_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow_material = ElementVisuals.make_material(Color(0.86, 0.94, 1.0, 1.0), 0.5, 0.01, false)
	snow_layer.material_override = snow_material
	add_child(snow_layer)

	var collision_body := StaticBody3D.new()
	collision_body.name = "SpellCollisionBody"
	var collision := CollisionShape3D.new()
	var collision_shape := BoxShape3D.new()
	collision_shape.size = Vector3(field_size.x, 0.08, field_size.y)
	collision.shape = collision_shape
	collision.position = Vector3(0.0, 0.04, 0.0)
	collision_body.add_child(collision)
	add_child(collision_body)

	footprint_root = Node3D.new()
	footprint_root.name = "Footprints"
	add_child(footprint_root)


func receive_weather_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	var tags: Array[String] = []
	for raw_tag: String in payload.tags:
		tags.append(raw_tag.to_lower().strip_edges())
	if payload.element.to_lower().strip_edges() != "ice" and not tags.has("snow"):
		return {}

	var strength: float = max(payload.status_strength, 0.2)
	coverage = clampf(coverage + accumulation_per_pulse * strength, 0.0, 1.0)
	recent_snow_timer = max(payload.status_duration, 1.2)
	update_visual()
	return {
		"message": "Snow accumulates across " + name + ".",
		"snow_coverage": coverage,
	}


func receive_damage_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	var element: String = payload.element.to_lower().strip_edges()
	var tags: Array[String] = []
	for raw_tag: String in payload.tags:
		tags.append(raw_tag.to_lower().strip_edges())

	if element == "fire" or tags.has("heat") or tags.has("melt"):
		coverage = max(coverage - max(float(abs(payload.amount)) * 0.16, 0.28), 0.0)
		recent_snow_timer = 0.0
		update_visual()
		return {
			"message": payload.source_name + " melts the accumulated snow.",
			"snow_coverage": coverage,
		}

	if element == "ice" or tags.has("snow") or tags.has("cold"):
		return receive_weather_payload(payload)
	return {}


func update_visual() -> void:
	if snow_layer == null or snow_material == null:
		return
	snow_layer.visible = coverage > 0.005
	snow_layer.scale.y = lerpf(0.12, 1.0, coverage)
	var alpha: float = clampf(0.08 + coverage * 0.86, 0.01, 0.94)
	snow_material.albedo_color = Color(0.86, 0.94, 1.0, alpha)
	snow_material.emission = Color(0.7, 0.84, 1.0, 1.0)
	snow_material.emission_energy_multiplier = 0.2 + coverage * 0.65


func try_spawn_footprint() -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null or footprint_root == null:
		return

	var local_position: Vector3 = to_local(player.global_position)
	if abs(local_position.x) > field_size.x * 0.5 or abs(local_position.z) > field_size.y * 0.5:
		return

	var footprint := MeshInstance3D.new()
	footprint.name = "Footprint" + str(footprint_count)
	footprint_count += 1
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.24, 0.014, 0.42)
	footprint.mesh = mesh
	footprint.position = Vector3(local_position.x, 0.104, local_position.z)
	footprint.rotation.y = player.global_rotation.y
	footprint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	footprint.material_override = ElementVisuals.make_material(Color(0.18, 0.36, 0.54, 1.0), 0.18, 0.55, true)
	footprint_root.add_child(footprint)

	var tween := footprint.create_tween()
	tween.tween_interval(footprint_lifetime)
	tween.tween_property(footprint, "scale", Vector3.ZERO, 0.35)
	tween.tween_callback(Callable(footprint, "queue_free"))


func reset_target() -> void:
	coverage = 0.0
	recent_snow_timer = 0.0
	footprint_timer = 0.0
	footprint_count = 0
	if footprint_root != null:
		for child: Node in footprint_root.get_children():
			child.queue_free()
	update_visual()


func get_debug_data() -> Dictionary:
	return {
		"snow_accumulation_field": name,
		"coverage": snapped(coverage, 0.01),
		"recent_snow_time": snapped(recent_snow_timer, 0.1),
		"footprints": footprint_root.get_child_count() if footprint_root != null else 0,
	}
