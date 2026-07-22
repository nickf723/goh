extends "res://scripts/airflow/airflow_field_3d.gd"
class_name GustSpell

const GustElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var lifetime: float = 0.9
@export var travel_speed: float = 10.0
@export var gust_strength: float = 18.0
@export var gust_half_width: float = 2.2
@export var gust_half_height: float = 1.8
@export var gust_half_length: float = 3.8

var source_actor: Node3D = null
var travel_direction: Vector3 = Vector3.FORWARD
var remaining_lifetime: float = 0.0
var visual_root: Node3D = null


func _ready() -> void:
	field_id = "gust:" + str(get_instance_id())
	field_kind = FieldKind.DIRECTIONAL
	volume_shape = VolumeShape.BOX
	local_direction = Vector3(0.0, 0.0, -1.0)
	box_extents = Vector3(gust_half_width, gust_half_height, gust_half_length)
	edge_fade_fraction = 0.45
	falloff_exponent = 0.8
	strength = gust_strength
	turbulence_strength = 1.2
	turbulence_spatial_frequency = 1.1
	turbulence_time_frequency = 2.4
	remaining_lifetime = lifetime
	super._ready()
	build_visuals()


func _process(delta: float) -> void:
	super._process(delta)
	remaining_lifetime -= delta
	if remaining_lifetime <= 0.0:
		queue_free()
		return
	global_position += travel_direction * travel_speed * max(delta, 0.0)
	var life_ratio: float = clampf(remaining_lifetime / max(lifetime, 0.01), 0.0, 1.0)
	strength = gust_strength * (0.35 + life_ratio * 0.65)
	update_visuals(life_ratio, delta)


func set_source_actor(new_source_actor: Node) -> void:
	source_actor = new_source_actor as Node3D


func execute(player: Node3D, cast_direction: Vector3) -> void:
	source_actor = player
	travel_direction = cast_direction.normalized() if cast_direction.length() > 0.01 else -player.global_transform.basis.z
	if travel_direction.length() <= 0.01:
		travel_direction = Vector3.FORWARD
	global_position = player.global_position + Vector3.UP * 0.85 + travel_direction * 2.1
	look_at(global_position + travel_direction, Vector3.UP)
	show_message("Gust becomes a moving vector field. Props, projectiles, tracers, and mechanisms sample the same air.")


func build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "GustVisualRoot"
	add_child(visual_root)
	for index: int in range(4):
		var ring := GustElementVisuals.add_torus(
			visual_root,
			"PressureRing" + str(index),
			0.42 + float(index) * 0.18,
			0.48 + float(index) * 0.18,
			Color(0.52, 0.9, 1.0, 1.0),
			Vector3(0.0, 0.0, -float(index) * 0.65),
			Vector3(90.0, 0.0, 0.0),
			1.5,
			0.42 - float(index) * 0.06
		)
		ring.scale = Vector3.ONE * (0.7 + float(index) * 0.18)
	GustElementVisuals.add_capsule(
		visual_root,
		"FlowCore",
		0.18,
		2.4,
		Color(0.72, 0.96, 1.0, 1.0),
		Vector3(0.0, 0.0, -1.0),
		Vector3(1.0, 1.0, 1.0),
		Vector3(90.0, 0.0, 0.0),
		1.8,
		0.28
	)


func update_visuals(life_ratio: float, delta: float) -> void:
	if visual_root == null:
		return
	visual_root.rotate_z(delta * 2.4)
	visual_root.scale = Vector3.ONE * lerpf(1.35, 0.72, life_ratio)
	visual_root.modulate = Color(1.0, 1.0, 1.0, clampf(life_ratio * 1.4, 0.0, 1.0))


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)
