extends "res://scripts/actions/generic_projectile_safe.gd"
class_name DeathHexProjectile

const DeathHexCurseScene: PackedScene = preload(
	"res://scenes/actions/death_hex_curse.tscn"
)
const SpellPresentation = preload(
	"res://scripts/presentation/spell_presentation_bridge.gd"
)

@export_group("Delivery")
@export_range(6.0, 40.0, 0.5) var projectile_speed: float = 18.5
@export_range(0.5, 5.0, 0.05) var projectile_lifetime: float = 2.8
@export_range(1.0, 12.0, 0.1) var curse_duration: float = 6.6

var rune_material: StandardMaterial3D = null
var core_material: StandardMaterial3D = null

const HEX_RED: Color = Color(0.67, 0.025, 0.05, 0.82)
const HEX_PALE: Color = Color(1.0, 0.48, 0.43, 0.94)


func _ready() -> void:
	speed = projectile_speed
	max_lifetime = projectile_lifetime
	respond_to_airflow = false
	show_miss_feedback = true
	trail_interval = 0.075
	super._ready()


func configure_element_visual() -> void:
	if not is_node_ready() or element_visual_root == null:
		return
	for child: Node in element_visual_root.get_children():
		child.queue_free()

	rune_material = _make_hex_material(HEX_RED, 1.8, 0.8)
	core_material = _make_hex_material(HEX_PALE, 3.0, 0.94)

	for index: int in range(2):
		var ring := MeshInstance3D.new()
		ring.name = "FlyingHexRing" + str(index + 1)
		var torus := TorusMesh.new()
		torus.inner_radius = 0.13 + float(index) * 0.04
		torus.outer_radius = 0.19 + float(index) * 0.04
		torus.rings = 16
		torus.ring_segments = 7
		ring.mesh = torus
		ring.material_override = rune_material
		ring.rotation_degrees = Vector3(
			90.0 if index == 0 else 35.0,
			float(index) * 50.0,
			28.0 * float(index)
		)
		element_visual_root.add_child(ring)

	for index: int in range(4):
		var rune := MeshInstance3D.new()
		rune.name = "FlyingHexRune" + str(index + 1)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.028, 0.24, 0.022)
		rune.mesh = mesh
		rune.material_override = rune_material
		var angle: float = TAU * float(index) / 4.0
		rune.position = Vector3(cos(angle) * 0.14, sin(angle) * 0.14, 0.0)
		rune.rotation.z = angle
		element_visual_root.add_child(rune)

	var core := MeshInstance3D.new()
	core.name = "FlyingHexCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.065
	core_mesh.height = 0.13
	core_mesh.radial_segments = 7
	core_mesh.rings = 4
	core.mesh = core_mesh
	core.material_override = core_material
	element_visual_root.add_child(core)
	configured_element = "death"


func _process(delta: float) -> void:
	super._process(delta)
	if is_queued_for_deletion() or element_visual_root == null:
		return
	element_visual_root.rotation.z += maxf(delta, 0.0) * 3.2
	element_visual_root.rotation.x = sin(elapsed * 5.8) * 0.18


func update_element_trail(delta: float) -> void:
	trail_timer -= delta
	if trail_timer > 0.0:
		return
	trail_timer = maxf(trail_interval, 0.03)
	if get_tree() == null or get_tree().current_scene == null:
		return
	var mote := MeshInstance3D.new()
	mote.name = "DeathHexTrail"
	mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := SphereMesh.new()
	mesh.radius = 0.045
	mesh.height = 0.09
	mesh.radial_segments = 6
	mesh.rings = 3
	mote.mesh = mesh
	mote.material_override = _make_hex_material(HEX_RED, 0.8, 0.36)
	get_tree().current_scene.add_child(mote)
	mote.global_position = global_position - direction * 0.13
	var tween := mote.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mote, "scale", Vector3.ZERO, 0.28)
	tween.tween_property(mote, "global_position", mote.global_position + Vector3(0.0, -0.16, 0.0), 0.28)
	tween.set_parallel(false)
	tween.tween_callback(Callable(mote, "queue_free"))


func try_hit(raw_target: Node) -> void:
	var target_node: Node = find_payload_target(raw_target)
	if target_node == null or not is_instance_valid(target_node):
		return
	if should_ignore_target(target_node):
		return
	var target_3d: Node3D = _resolve_target_3d(target_node)
	if target_3d == null:
		return
	var target_id: int = target_3d.get_instance_id()
	if hit_targets.has(target_id):
		return
	hit_targets[target_id] = true
	hit_count += 1
	_attach_or_refresh_hex(target_3d)
	_spawn_attachment_flash()
	queue_free()


func _attach_or_refresh_hex(target_3d: Node3D) -> void:
	if target_3d == null or not is_instance_valid(target_3d):
		return
	var existing: Node = target_3d.get_node_or_null("DeathHexCurse")
	if existing != null and is_instance_valid(existing) and existing.has_method("refresh_hex"):
		existing.call("refresh_hex", curse_duration, source_actor, get_payload())
		_present_hex_phase("resolve", target_3d, "curse_refreshed", 0.42)
		return

	var curse: DeathHexCurse = DeathHexCurseScene.instantiate() as DeathHexCurse
	if curse == null:
		return
	curse.name = "DeathHexCurse"
	target_3d.add_child(curse)
	if not curse.bind_to_target(target_3d, source_actor, get_payload(), curse_duration):
		curse.queue_free()
		return
	_present_hex_phase("manifest", target_3d, "curse_attached", 0.7)


func _present_hex_phase(
	phase: String,
	target_3d: Node3D,
	detail: String,
	intensity: float
) -> void:
	var position: Vector3 = global_position
	if target_3d != null and is_instance_valid(target_3d):
		position = target_3d.global_position + Vector3.UP * 0.8
	SpellPresentation.present(self, phase, {
		"actor": source_actor,
		"target": target_3d,
		"position": position,
		"spell_id": "death_hex",
		"spell_name": "Death Hex",
		"element": "death",
		"delivery_type": "projectile_curse",
		"targeting_style": "aimed",
		"detail": detail,
		"intensity": intensity,
	})


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
	ring.name = "DeathHexAttachmentFlash"
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.18
	mesh.outer_radius = 0.29
	mesh.rings = 16
	mesh.ring_segments = 7
	ring.mesh = mesh
	ring.material_override = _make_hex_material(HEX_PALE, 2.2, 0.76)
	get_tree().current_scene.add_child(ring)
	ring.global_position = global_position
	ring.scale = Vector3.ONE * 0.35
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 1.55, 0.2)
	tween.tween_property(ring, "rotation:y", PI, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(Callable(ring, "queue_free"))


func _make_hex_material(
	color: Color,
	emission_energy: float,
	alpha: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.36
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func get_debug_data() -> Dictionary:
	var data: Dictionary = get_airflow_debug_data()
	data["spell"] = "death_hex_projectile"
	data["delivery_only"] = true
	data["direct_hit_damage"] = 0
	data["curse_duration"] = curse_duration
	data["attaches_escalating_hex"] = true
	data["presentation_handoff"] = true
	return data
