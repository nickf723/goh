extends "res://scripts/actions/generic_projectile_safe.gd"
class_name DeathWraithProjectile

const PursuerSpiritScene: PackedScene = preload(
	"res://scenes/actions/death_pursuer_spirit.tscn"
)

@export_group("Delivery")
@export_range(6.0, 40.0, 0.5) var projectile_speed: float = 20.5
@export_range(0.5, 5.0, 0.05) var projectile_lifetime: float = 2.7

var wraith_material: StandardMaterial3D = null
var core_material: StandardMaterial3D = null

const WRAITH_RED: Color = Color(0.72, 0.08, 0.1, 0.78)
const WRAITH_CORE: Color = Color(1.0, 0.52, 0.48, 0.92)


func _ready() -> void:
	speed = projectile_speed
	max_lifetime = projectile_lifetime
	respond_to_airflow = false
	show_miss_feedback = true
	trail_interval = 0.07
	super._ready()


func configure_element_visual() -> void:
	if not is_node_ready() or element_visual_root == null:
		return
	for child: Node in element_visual_root.get_children():
		child.queue_free()

	wraith_material = _make_spirit_material(WRAITH_RED, 1.65, 0.72)
	core_material = _make_spirit_material(WRAITH_CORE, 3.0, 0.92)

	var shell := MeshInstance3D.new()
	shell.name = "WraithSeedShell"
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.19
	shell_mesh.height = 0.34
	shell_mesh.radial_segments = 10
	shell_mesh.rings = 5
	shell.mesh = shell_mesh
	shell.material_override = wraith_material
	shell.scale = Vector3(0.82, 1.0, 1.25)
	element_visual_root.add_child(shell)

	var core := MeshInstance3D.new()
	core.name = "WraithSeedCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.085
	core_mesh.height = 0.17
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	core.mesh = core_mesh
	core.material_override = core_material
	core.position.z = -0.06
	element_visual_root.add_child(core)

	for index: int in range(3):
		var streamer := MeshInstance3D.new()
		streamer.name = "DeathStreamer" + str(index + 1)
		var streamer_mesh := SphereMesh.new()
		streamer_mesh.radius = 0.065 - float(index) * 0.009
		streamer_mesh.height = 0.13
		streamer_mesh.radial_segments = 7
		streamer_mesh.rings = 4
		streamer.mesh = streamer_mesh
		streamer.material_override = wraith_material
		streamer.position = Vector3(
			(float(index) - 1.0) * 0.065,
			sin(float(index) * 2.0) * 0.035,
			0.18 + float(index) * 0.13
		)
		streamer.scale = Vector3(0.7, 0.7, 1.45 + float(index) * 0.25)
		element_visual_root.add_child(streamer)

	configured_element = "death"


func update_element_trail(delta: float) -> void:
	trail_timer -= delta
	if trail_timer > 0.0:
		return
	trail_timer = maxf(trail_interval, 0.03)
	if get_tree() == null or get_tree().current_scene == null:
		return
	var mote := MeshInstance3D.new()
	mote.name = "DeathProjectileMote"
	mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 7
	mesh.rings = 4
	mote.mesh = mesh
	mote.material_override = _make_spirit_material(WRAITH_RED, 0.9, 0.34)
	get_tree().current_scene.add_child(mote)
	mote.global_position = global_position - direction * 0.16
	var tween := mote.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mote, "scale", Vector3.ZERO, 0.26)
	tween.tween_property(mote, "global_position", mote.global_position + Vector3.UP * 0.14, 0.26)
	tween.set_parallel(false)
	tween.tween_callback(Callable(mote, "queue_free"))


func try_hit(raw_target: Node) -> void:
	var target: Node = find_payload_target(raw_target)
	if target == null or not is_instance_valid(target):
		return
	if should_ignore_target(target):
		return
	var target_3d: Node3D = _resolve_target_3d(target)
	if target_3d == null:
		return
	var target_id: int = target.get_instance_id()
	if hit_targets.has(target_id):
		return
	hit_targets[target_id] = true
	hit_count += 1
	_spawn_pursuer_spirit(target_3d)
	_spawn_attachment_flash()
	queue_free()


func _spawn_pursuer_spirit(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if get_tree() == null or get_tree().current_scene == null:
		return
	var spirit: DeathPursuerSpirit = PursuerSpiritScene.instantiate() as DeathPursuerSpirit
	if spirit == null:
		return
	get_tree().current_scene.add_child(spirit)
	spirit.global_position = global_position
	var active_payload: DamagePayload = get_payload()
	spirit.configure(
		target,
		source_actor,
		active_payload,
		direction
	)


func _resolve_target_3d(start_node: Node) -> Node3D:
	if start_node == null or not is_instance_valid(start_node):
		return null
	var current: Node = start_node
	while current != null:
		if not is_instance_valid(current):
			return null
		if current is Node3D:
			return current as Node3D
		current = current.get_parent()
	return null


func _spawn_attachment_flash() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var ring := MeshInstance3D.new()
	ring.name = "WraithAttachmentFlash"
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.16
	mesh.outer_radius = 0.27
	mesh.rings = 16
	mesh.ring_segments = 7
	ring.mesh = mesh
	ring.material_override = _make_spirit_material(WRAITH_CORE, 2.0, 0.72)
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	ring.scale = Vector3.ONE * 0.35
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 1.5, 0.18)
	tween.tween_callback(Callable(ring, "queue_free"))


func _make_spirit_material(
	color: Color,
	emission_energy: float,
	alpha: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.28
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func get_debug_data() -> Dictionary:
	var data: Dictionary = get_airflow_debug_data()
	data["spell"] = "wraith_pursuit_projectile"
	data["delivery_only"] = true
	data["initial_hit_damage"] = 0
	data["spawns_pursuer_spirit"] = true
	return data
