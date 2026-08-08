extends Node3D
class_name RepeatEchoActor

const GraceVisualScene: PackedScene = preload(
	"res://scenes/actors/player/grace_wire_visual_v1.tscn"
)

@export_range(0.05, 1.0, 0.01) var body_alpha: float = 0.46
@export_range(0.0, 8.0, 0.1) var emission_energy: float = 2.8

var echo_index: int = 0
var replay_delay: float = 1.0
var grace_visual: Node3D = null
var attack_pulse: MeshInstance3D = null
var attack_pulse_material: StandardMaterial3D = null
var applied_snapshot_count: int = 0
var attack_pulse_count: int = 0


func _ready() -> void:
	add_to_group("repeat_echoes")
	add_to_group("spell_effects")
	add_to_group("persistent_spell_effects")
	add_to_group("debuggable")
	_build_visual()
	_build_attack_pulse()
	call_deferred("_apply_echo_tint")


func configure(index: int, delay_seconds: float) -> void:
	echo_index = maxi(index, 0)
	replay_delay = maxf(delay_seconds, 0.05)
	name = "RepeatEcho_%02d" % (echo_index + 1)


func apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var actor_transform_value: Variant = snapshot.get("actor_transform")
	if actor_transform_value is Transform3D:
		global_transform = actor_transform_value as Transform3D
	if grace_visual == null:
		return
	var visual_transform_value: Variant = snapshot.get("visual_transform")
	if visual_transform_value is Transform3D:
		grace_visual.transform = visual_transform_value as Transform3D
	var poses_value: Variant = snapshot.get("poses", {})
	if poses_value is Dictionary:
		var poses: Dictionary = poses_value as Dictionary
		for path_value: Variant in poses.keys():
			var path_text: String = str(path_value)
			var target: Node3D = grace_visual.get_node_or_null(path_text) as Node3D
			var pose_value: Variant = poses[path_value]
			if target != null and pose_value is Transform3D:
				target.transform = pose_value as Transform3D
	applied_snapshot_count += 1


func pulse_attack(range_hint: float = 2.0) -> void:
	if attack_pulse == null:
		return
	attack_pulse_count += 1
	attack_pulse.visible = true
	attack_pulse.scale = Vector3.ONE * 0.28
	attack_pulse.transparency = 0.0
	var target_scale: float = clampf(range_hint * 0.48, 0.6, 2.3)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		attack_pulse,
		"scale",
		Vector3.ONE * target_scale,
		0.18
	)
	tween.tween_property(attack_pulse, "transparency", 1.0, 0.18)
	tween.finished.connect(func() -> void:
		if attack_pulse != null:
			attack_pulse.visible = false
			attack_pulse.transparency = 0.0
	)


func _build_visual() -> void:
	grace_visual = GraceVisualScene.instantiate() as Node3D
	if grace_visual == null:
		return
	grace_visual.name = "EchoGraceVisual"
	add_child(grace_visual)
	# The source Grace owns the pose. The echo wire renderer may continue sampling
	# its copied pivots, but the duplicate character animation script must not invent
	# a second independent walk cycle.
	grace_visual.set_process(false)
	grace_visual.set_physics_process(false)


func _build_attack_pulse() -> void:
	attack_pulse = MeshInstance3D.new()
	attack_pulse.name = "RepeatAttackPulse"
	attack_pulse.visible = false
	attack_pulse.position = Vector3(0.0, 0.85, 0.0)
	attack_pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	attack_pulse.mesh = sphere
	attack_pulse_material = StandardMaterial3D.new()
	attack_pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	attack_pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	attack_pulse_material.albedo_color = Color(0.38, 0.72, 1.0, 0.16)
	attack_pulse_material.emission_enabled = true
	attack_pulse_material.emission = Color(0.42, 0.58, 1.0, 1.0)
	attack_pulse_material.emission_energy_multiplier = 3.4
	attack_pulse.material_override = attack_pulse_material
	add_child(attack_pulse)


func _apply_echo_tint() -> void:
	if grace_visual == null:
		return
	_tint_geometry_recursive(grace_visual)


func _tint_geometry_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.transparency = 0.28
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.34, 0.56, 1.0, body_alpha)
		material.emission_enabled = true
		material.emission = Color(0.42, 0.5, 1.0, 1.0)
		material.emission_energy_multiplier = emission_energy
		mesh_instance.material_override = material
	for child: Node in node.get_children():
		_tint_geometry_recursive(child)


func get_debug_data() -> Dictionary:
	return {
		"repeat_echo": true,
		"echo_index": echo_index,
		"delay": replay_delay,
		"snapshots_applied": applied_snapshot_count,
		"attack_pulses": attack_pulse_count,
		"visual_ready": grace_visual != null,
		"world_position": global_position,
	}
