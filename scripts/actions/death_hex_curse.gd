extends Node3D
class_name DeathHexCurse

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export_group("Curse")
@export_range(1.0, 20.0, 0.1) var curse_duration: float = 6.6
@export_range(0.2, 3.0, 0.05) var pulse_interval: float = 1.2
@export var pulse_damage_curve: Array[int] = [1, 1, 2, 2, 3]

@export_group("Presentation")
@export_range(0.1, 1.0, 0.01) var dissolve_duration: float = 0.28

var target: Node3D = null
var source_actor: Node = null
var runtime_payload: DamagePayload = null
var remaining: float = 0.0
var pulse_timer: float = 0.0
var pulse_index: int = 0
var elapsed: float = 0.0
var released: bool = false
var visual_root: Node3D = null
var rune_material: StandardMaterial3D = null
var pale_material: StandardMaterial3D = null
var dark_material: StandardMaterial3D = null
var status_receiver: Node = null

const HEX_RED: Color = Color(0.66, 0.035, 0.055, 0.82)
const HEX_PALE: Color = Color(1.0, 0.48, 0.44, 0.88)
const HEX_DARK: Color = Color(0.065, 0.008, 0.018, 0.92)


func _ready() -> void:
	add_to_group("death_hex_curses")
	add_to_group("debuggable")


func bind_to_target(
	new_target: Node3D,
	new_source_actor: Node,
	new_payload: DamagePayload,
	duration: float = -1.0
) -> bool:
	if new_target == null or not is_instance_valid(new_target):
		return false
	target = new_target
	source_actor = (
		new_source_actor
		if new_source_actor != null and is_instance_valid(new_source_actor)
		else null
	)
	runtime_payload = (
		new_payload.duplicate(true) as DamagePayload
		if new_payload != null
		else _make_fallback_payload()
	)
	remaining = curse_duration if duration <= 0.0 else maxf(duration, 0.25)
	pulse_timer = pulse_interval
	pulse_index = 0
	released = false
	status_receiver = target.get_node_or_null("StatusReceiver")
	_apply_hex_state()
	_build_visual()
	return true


func refresh_hex(
	duration: float = -1.0,
	new_source_actor: Node = null,
	new_payload: DamagePayload = null
) -> void:
	if released:
		return
	remaining = maxf(
		remaining,
		curse_duration if duration <= 0.0 else maxf(duration, 0.25)
	)
	if new_source_actor != null and is_instance_valid(new_source_actor):
		source_actor = new_source_actor
	if new_payload != null:
		runtime_payload = new_payload.duplicate(true) as DamagePayload
	_apply_hex_state()
	_pulse_visual(1.18)


func _process(delta: float) -> void:
	if released:
		return
	if not _target_is_alive():
		release_hex(false)
		return

	var step: float = maxf(delta, 0.0)
	elapsed += step
	remaining -= step
	pulse_timer -= step

	if visual_root != null:
		_update_visual()

	if pulse_timer <= 0.0:
		pulse_timer += pulse_interval
		_apply_decay_pulse()

	if remaining <= 0.0:
		release_hex(true)


func _apply_decay_pulse() -> void:
	if released or not _target_is_alive():
		return
	var damage: int = get_damage_for_pulse(pulse_index)
	var payload_to_send: DamagePayload = (
		runtime_payload.duplicate(true) as DamagePayload
		if runtime_payload != null
		else _make_fallback_payload()
	)
	payload_to_send.amount = maxi(damage, 1)
	payload_to_send.stance_damage = 0
	payload_to_send.element = "death"
	payload_to_send.source_name = "Death Hex"
	payload_to_send.hit_type = "death_hex_pulse"
	payload_to_send.status_effect = ""
	payload_to_send.status_duration = 0.0
	payload_to_send.suppress_reactions = true
	if not payload_to_send.tags.has("hexed"):
		payload_to_send.tags.append("hexed")
	if not payload_to_send.tags.has("decay"):
		payload_to_send.tags.append("decay")

	_send_health_decay(payload_to_send)
	pulse_index += 1
	_apply_hex_state()
	_spawn_decay_motes()
	_pulse_visual(1.0 + float(damage) * 0.08)


func get_damage_for_pulse(index: int) -> int:
	if pulse_damage_curve.is_empty():
		return 1 + floori(float(maxi(index, 0)) / 2.0)
	return maxi(
		pulse_damage_curve[clampi(index, 0, pulse_damage_curve.size() - 1)],
		1
	)


func _send_health_decay(payload: DamagePayload) -> void:
	if target == null or not is_instance_valid(target) or payload == null:
		return
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		var original_hit_mode: Variant = hit_receiver.get("hit_mode")
		if original_hit_mode != null:
			hit_receiver.set("hit_mode", 2)
			hit_receiver.call("receive_payload", payload)
			hit_receiver.set("hit_mode", original_hit_mode)
			return
		hit_receiver.call("receive_payload", payload)
		return

	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		payload_receiver.call("receive_payload", payload)
		return
	if target.has_method("receive_damage_payload"):
		target.call("receive_damage_payload", payload)
		return
	if target.has_method("receive_magic_hit"):
		target.call("receive_magic_hit", payload.amount)


func _apply_hex_state() -> void:
	if status_receiver == null or not is_instance_valid(status_receiver):
		return
	if not status_receiver.has_method("sustain_status"):
		return
	var next_damage: float = float(get_damage_for_pulse(pulse_index))
	status_receiver.call(
		"sustain_status",
		"hexed",
		maxf(remaining, 0.05),
		next_damage,
		"Death Hex"
	)


func release_hex(show_dissolve: bool = true) -> void:
	if released:
		return
	released = true
	if status_receiver != null and is_instance_valid(status_receiver):
		if status_receiver.has_method("remove_status"):
			status_receiver.call("remove_status", "hexed")

	if show_dissolve and visual_root != null and is_instance_valid(visual_root):
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(visual_root, "scale", Vector3.ZERO, dissolve_duration)
		tween.tween_property(
			visual_root,
			"rotation:y",
			visual_root.rotation.y + PI,
			dissolve_duration
		)
		tween.set_parallel(false)
		tween.tween_callback(Callable(self, "queue_free"))
	else:
		queue_free()


func _target_is_alive() -> bool:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return false
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		var health_value: Variant = hit_receiver.get("current_health")
		if health_value != null and int(health_value) <= 0:
			return false
	return true


func _build_visual() -> void:
	if visual_root != null:
		return
	visual_root = Node3D.new()
	visual_root.name = "DeathHexVisual"
	add_child(visual_root)

	var height: float = clampf(
		ElementVisuals.estimate_target_height(target),
		0.7,
		3.2
	)
	visual_root.position.y = height * 0.62
	var radius: float = clampf(height * 0.32, 0.34, 0.9)

	rune_material = _make_material(HEX_RED, 1.8, 0.8)
	pale_material = _make_material(HEX_PALE, 2.7, 0.9)
	dark_material = _make_material(HEX_DARK, 0.55, 0.88)

	for index: int in range(3):
		var ring := MeshInstance3D.new()
		ring.name = "HexOrbit" + str(index + 1)
		var torus := TorusMesh.new()
		torus.inner_radius = radius * (0.62 + float(index) * 0.1)
		torus.outer_radius = radius * (0.7 + float(index) * 0.1)
		torus.rings = 20
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = rune_material if index != 1 else dark_material
		ring.rotation_degrees = Vector3(
			90.0 if index == 0 else 28.0 + float(index) * 22.0,
			float(index) * 57.0,
			18.0 * float(index)
		)
		visual_root.add_child(ring)

	for index: int in range(6):
		var spoke := MeshInstance3D.new()
		spoke.name = "HexRune" + str(index + 1)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, radius * 0.58, 0.025)
		spoke.mesh = mesh
		spoke.material_override = pale_material if index % 3 == 0 else rune_material
		var angle: float = TAU * float(index) / 6.0
		spoke.position = Vector3(
			cos(angle) * radius * 0.62,
			sin(angle * 2.0) * radius * 0.09,
			sin(angle) * radius * 0.62
		)
		spoke.rotation = Vector3(0.0, -angle, angle * 0.18)
		visual_root.add_child(spoke)

	var core := MeshInstance3D.new()
	core.name = "HexCore"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = radius * 0.12
	core_mesh.height = radius * 0.24
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	core.mesh = core_mesh
	core.material_override = pale_material
	visual_root.add_child(core)

	visual_root.scale = Vector3.ONE * 0.12
	var grow := create_tween()
	grow.set_trans(Tween.TRANS_BACK)
	grow.set_ease(Tween.EASE_OUT)
	grow.tween_property(visual_root, "scale", Vector3.ONE, 0.22)


func _update_visual() -> void:
	if visual_root == null:
		return
	var escalation_steps: int = maxi(pulse_damage_curve.size(), 1)
	var depth_ratio: float = clampf(
		float(pulse_index) / float(escalation_steps),
		0.0,
		1.0
	)
	visual_root.rotation.y = elapsed * (0.55 + depth_ratio * 0.52)
	visual_root.rotation.z = sin(elapsed * 1.9) * (0.04 + depth_ratio * 0.08)
	var pulse: float = 1.0 + sin(elapsed * (4.0 + depth_ratio * 3.0)) * (0.035 + depth_ratio * 0.035)
	visual_root.scale = Vector3.ONE * pulse
	if rune_material != null:
		rune_material.emission_energy_multiplier = 1.8 + depth_ratio * 1.6
		rune_material.albedo_color = HEX_RED.lerp(HEX_DARK, depth_ratio * 0.42)


func _pulse_visual(scale_multiplier: float) -> void:
	if visual_root == null or not is_instance_valid(visual_root):
		return
	visual_root.scale = Vector3.ONE
	var tween := create_tween()
	tween.tween_property(
		visual_root,
		"scale",
		Vector3.ONE * maxf(scale_multiplier, 1.06),
		0.08
	)
	tween.tween_property(visual_root, "scale", Vector3.ONE, 0.14)


func _spawn_decay_motes() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var center: Vector3 = (
		visual_root.global_position
		if visual_root != null and is_instance_valid(visual_root)
		else global_position
	)
	for index: int in range(4):
		var mote := MeshInstance3D.new()
		mote.name = "DeathHexDecayMote"
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh := SphereMesh.new()
		mesh.radius = 0.045 + float(index % 2) * 0.018
		mesh.height = 0.09
		mesh.radial_segments = 6
		mesh.rings = 3
		mote.mesh = mesh
		mote.material_override = _make_material(
			HEX_RED if index % 2 == 0 else HEX_DARK,
			0.8,
			0.52
		)
		get_tree().current_scene.add_child(mote)
		mote.global_position = center + Vector3(
			(float(index) - 1.5) * 0.11,
			0.12 + float(index % 2) * 0.09,
			sin(float(index) * 2.1) * 0.12
		)
		var drift := Vector3(
			(float(index) - 1.5) * 0.08,
			-0.42 - float(index % 2) * 0.11,
			cos(float(index) * 1.7) * 0.11
		)
		var tween := mote.create_tween()
		tween.set_parallel(true)
		tween.tween_property(mote, "global_position", mote.global_position + drift, 0.34)
		tween.tween_property(mote, "scale", Vector3.ZERO, 0.34)
		tween.set_parallel(false)
		tween.tween_callback(Callable(mote, "queue_free"))


func _make_material(
	color: Color,
	emission_energy: float,
	alpha: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.4
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _make_fallback_payload() -> DamagePayload:
	var payload := DamagePayload.new()
	payload.amount = 1
	payload.stance_damage = 0
	payload.element = "death"
	payload.source_name = "Death Hex"
	payload.hit_type = "death_hex_pulse"
	payload.tags = ["death", "hexed", "decay", "curse"]
	return payload


func get_debug_data() -> Dictionary:
	return {
		"spell": "death_hex",
		"target": target.name if _target_is_alive() else "none",
		"remaining": snappedf(maxf(remaining, 0.0), 0.01),
		"pulse_index": pulse_index,
		"next_damage": get_damage_for_pulse(pulse_index),
		"escalation_steps": pulse_damage_curve.size(),
		"damage_curve": pulse_damage_curve.duplicate(),
		"escalating": true,
		"direct_health_decay": true,
		"single_instance_per_target": true,
		"refresh_preserves_decay_stage": true,
	}
