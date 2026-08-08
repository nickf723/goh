extends Node3D
class_name PlayerScaleController

signal scale_started(direction: Vector3)
signal scale_step(step_index: int, world_position: Vector3, pitch_ratio: float)
signal scale_ended(reason: String, completed_steps: int)

@export_group("Traversal")
@export_range(1, 16, 1) var total_steps: int = 8
@export_range(0.1, 1.5, 0.05) var step_height: float = 0.62
@export_range(0.2, 3.0, 0.05) var step_forward_distance: float = 1.18
@export_range(0.1, 1.0, 0.01) var step_interval: float = 0.32
@export_range(0.05, 0.3, 0.01) var rise_seconds: float = 0.11
@export_range(0.05, 1.0, 0.01) var blocked_cancel_seconds: float = 0.18

@export_group("Presentation")
@export_range(0.1, 1.5, 0.05) var note_lifetime: float = 0.48
@export_range(0.1, 2.0, 0.05) var note_ring_radius: float = 0.52
@export_range(0.1, 10.0, 0.1) var note_emission: float = 3.0
@export_range(0.01, 0.3, 0.01) var tone_seconds: float = 0.14
@export_range(8000, 48000, 1000) var tone_sample_rate: int = 22000
@export_range(0.0, 1.0, 0.01) var tone_volume: float = 0.23

const MAJOR_SCALE_RATIOS: Array[float] = [
	1.0,
	1.122462,
	1.259921,
	1.334840,
	1.498307,
	1.681793,
	1.887749,
	2.0,
]

var actor: CharacterBody3D = null
var active: bool = false
var ascent_direction: Vector3 = Vector3.FORWARD
var origin_position: Vector3 = Vector3.ZERO
var current_target_height: float = 0.0
var completed_steps: int = 0
var elapsed: float = 0.0
var step_elapsed: float = 0.0
var blocked_elapsed: float = 0.0
var actor_physics_was_enabled: bool = true
var saved_floor_snap_length: float = 0.0
var note_visuals: Array[Dictionary] = []
var tone_player: AudioStreamPlayer3D = null
var activation_count: int = 0
var completion_count: int = 0
var interruption_count: int = 0
var last_end_reason: String = "never_started"


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	name = "ScaleController"
	add_to_group("scale_controllers")
	add_to_group("debuggable")
	_build_audio()
	set_physics_process(false)
	set_process(false)


func _exit_tree() -> void:
	if active:
		_restore_actor_locomotion()
	_clear_note_visuals()


func activate_scale(initial_direction: Vector3 = Vector3.ZERO) -> Dictionary:
	if actor == null or not is_instance_valid(actor):
		return {"activated": false, "reason": "missing_actor"}
	if active:
		return {"activated": false, "reason": "already_active"}

	var direction: Vector3 = initial_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = -actor.global_transform.basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	ascent_direction = direction.normalized()

	actor_physics_was_enabled = actor.is_physics_processing()
	saved_floor_snap_length = actor.floor_snap_length
	actor.set_physics_process(false)
	actor.floor_snap_length = 0.0
	origin_position = actor.global_position
	current_target_height = origin_position.y
	completed_steps = 0
	elapsed = 0.0
	# Begin the first footfall immediately instead of making the player wait one beat.
	step_elapsed = step_interval
	blocked_elapsed = 0.0
	active = true
	activation_count += 1
	last_end_reason = "active"
	actor.set_meta("scale_traversal_active", true)
	actor.set_meta("scale_traversal_direction", ascent_direction)
	actor.set_meta("scale_traversal_step", 0)
	if not actor.is_in_group("scaling_actor"):
		actor.add_to_group("scaling_actor")
	_set_effect_groups(true)
	set_physics_process(true)
	set_process(true)
	scale_started.emit(ascent_direction)
	return {
		"activated": true,
		"direction": ascent_direction,
		"steps": total_steps,
		"vertical_gain": float(total_steps) * step_height,
		"forward_gain": float(total_steps) * step_forward_distance,
	}


func is_scale_active() -> bool:
	return active


func cancel_scale(reason: String = "cancelled") -> void:
	if not active:
		return
	active = false
	last_end_reason = reason
	if reason == "completed":
		completion_count += 1
	else:
		interruption_count += 1
	_restore_actor_locomotion()
	_set_effect_groups(false)
	set_physics_process(false)
	scale_ended.emit(reason, completed_steps)


func reset_target() -> void:
	cancel_scale("reset")
	_clear_note_visuals()
	completed_steps = 0
	elapsed = 0.0
	step_elapsed = 0.0
	blocked_elapsed = 0.0


func _physics_process(delta: float) -> void:
	advance_scale(delta)


func advance_scale(delta: float) -> bool:
	if not active:
		return false
	if actor == null or not is_instance_valid(actor):
		cancel_scale("missing_actor")
		return false
	var defeated_value: Variant = actor.get("is_defeated")
	if defeated_value != null and bool(defeated_value):
		cancel_scale("defeated")
		return false
	if _is_interrupting_state_active():
		cancel_scale("interrupted")
		return false

	var step: float = maxf(delta, 0.0)
	if step <= 0.0:
		return true
	elapsed += step
	step_elapsed += step

	if step_elapsed + 0.0001 >= step_interval and completed_steps < total_steps:
		step_elapsed = fmod(step_elapsed, step_interval)
		_begin_next_note_step()

	var forward_speed: float = step_forward_distance / maxf(step_interval, 0.01)
	var requested_vertical_speed: float = 0.0
	if actor.global_position.y < current_target_height - 0.015:
		requested_vertical_speed = minf(
			(current_target_height - actor.global_position.y) / maxf(step, 0.001),
			step_height / maxf(rise_seconds, 0.01)
		)

	var before_position: Vector3 = actor.global_position
	actor.velocity = ascent_direction * forward_speed
	actor.velocity.y = requested_vertical_speed
	actor.move_and_slide()
	var displacement: Vector3 = actor.global_position - before_position
	var planar_moved: float = Vector3(displacement.x, 0.0, displacement.z).length()
	var expected_planar: float = forward_speed * step
	if expected_planar > 0.001 and planar_moved < expected_planar * 0.18:
		blocked_elapsed += step
	else:
		blocked_elapsed = maxf(blocked_elapsed - step * 2.0, 0.0)
	if blocked_elapsed >= blocked_cancel_seconds:
		cancel_scale("blocked")
		return false

	# A ceiling can stop the requested rise even while forward travel remains free.
	if requested_vertical_speed > 0.1 and displacement.y <= 0.001:
		cancel_scale("ceiling_blocked")
		return false

	actor.set_meta("scale_traversal_step", completed_steps)
	_record_external_motion()
	if completed_steps >= total_steps and actor.global_position.y >= current_target_height - 0.04:
		cancel_scale("completed")
		return false
	return true


func _begin_next_note_step() -> void:
	completed_steps += 1
	current_target_height = origin_position.y + float(completed_steps) * step_height
	var ratio_index: int = clampi(completed_steps - 1, 0, MAJOR_SCALE_RATIOS.size() - 1)
	var pitch_ratio: float = MAJOR_SCALE_RATIOS[ratio_index]
	var note_position: Vector3 = actor.global_position + Vector3.UP * 0.06
	_spawn_note_visual(note_position, pitch_ratio)
	_play_scale_tone(pitch_ratio)
	scale_step.emit(completed_steps, note_position, pitch_ratio)


func _process(delta: float) -> void:
	if note_visuals.is_empty():
		if not active:
			set_process(false)
		return
	var remaining: Array[Dictionary] = []
	for row: Dictionary in note_visuals:
		var node_value: Variant = row.get("node")
		if not node_value is Node3D or not is_instance_valid(node_value):
			continue
		var node := node_value as Node3D
		var time_left: float = maxf(float(row.get("remaining", 0.0)) - delta, 0.0)
		var age: float = note_lifetime - time_left
		var ratio: float = clampf(time_left / maxf(note_lifetime, 0.01), 0.0, 1.0)
		node.scale = Vector3.ONE * (1.0 + age * 1.8)
		var mesh: MeshInstance3D = node.get_node_or_null("Ring") as MeshInstance3D
		if mesh != null:
			mesh.transparency = 1.0 - ratio
		if time_left <= 0.0:
			node.queue_free()
			continue
		row["remaining"] = time_left
		remaining.append(row)
	note_visuals = remaining
	if not active and note_visuals.is_empty():
		set_process(false)


func _spawn_note_visual(world_position: Vector3, pitch_ratio: float) -> void:
	var root := Node3D.new()
	root.name = "ScaleNote_%02d" % completed_steps
	var parent: Node = get_tree().current_scene
	if parent == null:
		parent = get_parent()
	if parent == null:
		return
	parent.add_child(root)
	root.global_position = world_position
	root.rotation.x = PI * 0.5
	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var torus := TorusMesh.new()
	torus.inner_radius = note_ring_radius * 0.82
	torus.outer_radius = note_ring_radius
	torus.rings = 18
	torus.ring_segments = 7
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var octave_mix: float = clampf((pitch_ratio - 1.0), 0.0, 1.0)
	var color := Color(1.0, 0.42 + octave_mix * 0.3, 0.16, 0.72)
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = note_emission
	ring.material_override = material
	root.add_child(ring)
	note_visuals.append({"node": root, "remaining": note_lifetime})
	set_process(true)


func _build_audio() -> void:
	tone_player = AudioStreamPlayer3D.new()
	tone_player.name = "ScaleTonePlayer"
	tone_player.unit_size = 5.0
	tone_player.max_distance = 28.0
	add_child(tone_player)


func _play_scale_tone(pitch_ratio: float) -> void:
	if tone_player == null:
		return
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = tone_sample_rate
	wav.stereo = false
	var frame_count: int = maxi(int(float(tone_sample_rate) * tone_seconds), 8)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var base_frequency: float = 261.625565
	var frequency: float = base_frequency * pitch_ratio
	for frame_index: int in range(frame_count):
		var t: float = float(frame_index) / float(tone_sample_rate)
		var phase: float = TAU * frequency * t
		var envelope_position: float = float(frame_index) / float(maxi(frame_count - 1, 1))
		var envelope: float = sin(PI * envelope_position)
		envelope *= envelope
		var sample: float = sin(phase) * envelope * tone_volume
		var sample_int: int = clampi(int(round(sample * 32767.0)), -32768, 32767)
		data[frame_index * 2] = sample_int & 0xff
		data[frame_index * 2 + 1] = (sample_int >> 8) & 0xff
	wav.data = data
	tone_player.stream = wav
	tone_player.global_position = actor.global_position if actor != null else global_position
	tone_player.play()


func _is_interrupting_state_active() -> bool:
	if actor == null:
		return false
	var defense: Node = actor.get_node_or_null("PlayerDefenseController")
	if defense != null and defense.has_method("is_hit_reaction_active"):
		if bool(defense.call("is_hit_reaction_active")):
			return true
	var dodge: Node = actor.get_node_or_null("PlayerDodgeController")
	return (
		dodge != null
		and dodge.has_method("is_dodge_active")
		and bool(dodge.call("is_dodge_active"))
	)


func _record_external_motion() -> void:
	if actor == null:
		return
	var motor: Node = actor.get_node_or_null("GroundMotionMotor")
	if motor == null:
		return
	var planar_velocity: Vector3 = ascent_direction * (
		step_forward_distance / maxf(step_interval, 0.01)
	)
	if motor.has_method("capture_external_velocity"):
		motor.call("capture_external_velocity", planar_velocity, "scale")
	if motor.has_method("record_post_move"):
		motor.call("record_post_move", planar_velocity)


func _restore_actor_locomotion() -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.remove_meta("scale_traversal_active")
	actor.remove_meta("scale_traversal_direction")
	actor.remove_meta("scale_traversal_step")
	if actor.is_in_group("scaling_actor"):
		actor.remove_from_group("scaling_actor")
	actor.floor_snap_length = saved_floor_snap_length
	# Preserve forward momentum and let ordinary gravity take over immediately.
	actor.velocity.x = ascent_direction.x * (
		step_forward_distance / maxf(step_interval, 0.01)
	)
	actor.velocity.z = ascent_direction.z * (
		step_forward_distance / maxf(step_interval, 0.01)
	)
	actor.velocity.y = 0.0
	actor.set_physics_process(actor_physics_was_enabled)


func _set_effect_groups(value: bool) -> void:
	for group_name: String in [
		"spell_effects",
		"persistent_spell_effects",
		"scale_spell_effects",
	]:
		if value and not is_in_group(group_name):
			add_to_group(group_name)
		elif not value and is_in_group(group_name):
			remove_from_group(group_name)


func _clear_note_visuals() -> void:
	for row: Dictionary in note_visuals:
		var value: Variant = row.get("node")
		if value is Node and is_instance_valid(value):
			(value as Node).queue_free()
	note_visuals.clear()


func get_debug_data() -> Dictionary:
	return {
		"scale_controller": true,
		"active": active,
		"direction": ascent_direction,
		"completed_steps": completed_steps,
		"total_steps": total_steps,
		"target_height": current_target_height,
		"vertical_gain": float(total_steps) * step_height,
		"forward_gain": float(total_steps) * step_forward_distance,
		"step_interval": step_interval,
		"activation_count": activation_count,
		"completion_count": completion_count,
		"interruption_count": interruption_count,
		"last_end_reason": last_end_reason,
		"note_visual_count": note_visuals.size(),
		"straight_line_commitment": true,
	}
