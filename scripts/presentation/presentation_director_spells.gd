extends "res://scripts/presentation/presentation_director.gd"
class_name SpellPresentationDirector

const SPELL_ELEMENTS: Array[String] = [
	"water", "earth", "fire", "air",
	"ice", "metal", "lightning", "poison",
	"life", "death", "body", "soul",
	"dreams", "sound", "space", "time",
]


func present(event_type: String, context: Dictionary = {}) -> Dictionary:
	if event_type.strip_edges().to_lower() == "spell":
		return present_spell(context)
	return super.present(event_type, context)


func present_spell(context: Dictionary = {}) -> Dictionary:
	var phase: String = str(context.get("phase", "release")).strip_edges().to_lower()
	if phase == "":
		phase = "release"
	var actor: Node = _valid_node(context.get("actor"))
	var target: Node = _valid_node(context.get("target"))
	var subject: Node = target if target != null else actor
	var position: Vector3 = _resolve_position(context, subject)
	var element: String = str(context.get("element", "neutral")).strip_edges().to_lower()
	var spell_name: String = str(context.get("spell_name", context.get("source_name", "Spell"))).strip_edges()
	var spell_id: String = str(context.get("spell_id", "")).strip_edges().to_lower()
	if spell_id == "":
		spell_id = spell_name.to_lower().replace(" ", "_")
	var delivery_type: String = str(context.get("delivery_type", "unknown")).strip_edges().to_lower()
	var power_ratio: float = clampf(float(context.get("power_ratio", 0.0)), 0.0, 1.0)
	var intensity: float = clampf(
		float(context.get("intensity", _spell_phase_intensity(phase)))
		+ power_ratio * 0.28,
		0.05,
		1.0
	)
	var subtle: bool = bool(context.get("subtle", false))

	var audio_rows: Array[Dictionary] = []
	var phase_cue: String = _spell_phase_cue(phase)
	if audio != null and phase_cue != "" and _allow_spell_channel(
		"audio:" + spell_id + ":" + phase,
		_spell_phase_cooldown(phase)
	):
		var phase_audio: Dictionary = audio.play_cue(
			phase_cue,
			position,
			intensity * (0.52 if subtle else 1.0),
			0.035
		)
		if not phase_audio.is_empty():
			audio_rows.append(phase_audio)

	if (
		audio != null
		and element in SPELL_ELEMENTS
		and phase in ["prepare", "release", "manifest", "handoff", "resolve"]
		and _allow_spell_channel(
			"accent:" + spell_id + ":" + phase,
			_spell_phase_cooldown(phase)
		)
	):
		var accent_strength: float = clampf(
			0.12 + intensity * (0.34 if phase in ["release", "manifest", "handoff"] else 0.2),
			0.08,
			0.52
		)
		var accent_audio: Dictionary = audio.play_cue(
			"element_" + element,
			position,
			accent_strength,
			0.045
		)
		if not accent_audio.is_empty():
			audio_rows.append(accent_audio)

	var haptic_id: String = _spell_phase_haptic(phase)
	var haptic_played: bool = false
	if (
		haptic_id != ""
		and not bool(context.get("suppress_haptics", false))
	):
		haptic_played = _play_haptic_throttled(
			haptic_id,
			"spell:" + spell_id + ":" + phase,
			_spell_phase_cooldown(phase)
		)

	var visual_spawned: bool = false
	var light_spawned: bool = false
	if not subtle and not bool(context.get("suppress_visual", false)):
		visual_spawned = _spawn_spell_phase_visual(
			position,
			_get_element_color(element),
			phase,
			intensity
		)
		if phase in ["release", "manifest", "handoff", "resolve"]:
			light_spawned = _spawn_spell_light(
				position,
				_get_element_color(element),
				intensity,
				phase
			)

	return _record_event("spell", {
		"actor": actor,
		"target": target,
		"position": position,
		"phase": phase,
		"spell_id": spell_id,
		"spell_name": spell_name,
		"element": element,
		"delivery_type": delivery_type,
		"targeting_style": str(context.get("targeting_style", "")),
		"power_ratio": snappedf(power_ratio, 0.01),
		"intensity": snappedf(intensity, 0.01),
		"audio": audio_rows,
		"haptic": haptic_id if haptic_played else (
			"suppressed" if bool(context.get("suppress_haptics", false)) else (
				"none" if haptic_id == "" else "throttled"
			)
		),
		"visual": visual_spawned,
		"light": light_spawned,
		"subtle": subtle,
		"detail": str(context.get("detail", context.get("resolution_kind", ""))),
	})


func _spell_phase_cue(phase: String) -> String:
	match phase:
		"prepare":
			return "spell_prepare"
		"release":
			return "spell_release"
		"travel":
			return "spell_travel"
		"manifest":
			return "spell_manifest"
		"latch":
			return "spell_latch"
		"sustain":
			return "spell_sustain"
		"resolve":
			return "spell_resolve"
		"handoff":
			return "spell_handoff"
		"cancel":
			return "spell_cancel"
		_:
			return "spell_release"


func _spell_phase_haptic(phase: String) -> String:
	match phase:
		"prepare":
			return "spell_prepare"
		"release":
			return "spell_release"
		"manifest", "handoff":
			return "spell_manifest"
		"latch":
			return "spell_latch"
		"resolve":
			return "spell_resolve"
		_:
			return ""


func _spell_phase_intensity(phase: String) -> float:
	match phase:
		"prepare":
			return 0.28
		"release":
			return 0.52
		"travel":
			return 0.16
		"manifest":
			return 0.62
		"latch":
			return 0.46
		"sustain":
			return 0.2
		"resolve":
			return 0.58
		"handoff":
			return 0.68
		"cancel":
			return 0.14
		_:
			return 0.35


func _spell_phase_cooldown(phase: String) -> int:
	match phase:
		"sustain":
			return 360
		"resolve":
			return 90
		"travel":
			return 180
		_:
			return 55


func _allow_spell_channel(channel: String, cooldown_msec: int) -> bool:
	var now: int = Time.get_ticks_msec()
	var key: String = "spell:" + channel
	var last: int = int(last_channel_msec.get(key, -999999))
	if now - last < maxi(cooldown_msec, 0):
		return false
	last_channel_msec[key] = now
	return true


func _spawn_spell_phase_visual(
	position: Vector3,
	color: Color,
	phase: String,
	intensity: float
) -> bool:
	if get_tree() == null or get_tree().current_scene == null:
		return false
	if phase in ["travel", "cancel"]:
		return false

	var root := Node3D.new()
	root.name = "SpellPhase_" + phase.capitalize()
	get_tree().current_scene.add_child(root)
	root.global_position = position

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 0.66)
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 1.0 + intensity * 2.1
	material.roughness = 0.25

	var ring := MeshInstance3D.new()
	ring.name = "PhaseRing"
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var torus := TorusMesh.new()
	var base_radius: float = lerpf(0.13, 0.34, intensity)
	torus.inner_radius = base_radius
	torus.outer_radius = base_radius + 0.045 + intensity * 0.035
	torus.rings = 18
	torus.ring_segments = 7
	ring.mesh = torus
	ring.material_override = material
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	root.add_child(ring)

	if phase in ["prepare", "manifest", "handoff", "latch"]:
		var core := MeshInstance3D.new()
		core.name = "PhaseCore"
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sphere := SphereMesh.new()
		sphere.radius = 0.045 + intensity * 0.055
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		core.mesh = sphere
		core.material_override = material
		root.add_child(core)

	var start_scale: float = 0.28 if phase == "prepare" else 0.5
	var peak_scale: float = (
		1.18 + intensity * 0.55
		if phase in ["release", "manifest", "handoff", "resolve"]
		else 1.0 + intensity * 0.22
	)
	root.scale = Vector3.ONE * start_scale
	var duration: float = 0.22 if phase == "prepare" else 0.3
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector3.ONE * peak_scale, duration)
	tween.tween_property(root, "rotation:y", PI * (0.55 + intensity * 0.45), duration)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.set_parallel(false)
	tween.tween_callback(Callable(root, "queue_free"))
	return true


func _spawn_spell_light(
	position: Vector3,
	color: Color,
	intensity: float,
	phase: String
) -> bool:
	if get_tree() == null or get_tree().current_scene == null:
		return false
	var light := OmniLight3D.new()
	light.name = "SpellLight_" + phase.capitalize()
	light.light_color = Color(color.r, color.g, color.b, 1.0)
	light.light_energy = 0.8 + intensity * 2.4
	light.omni_range = 2.2 + intensity * 2.8
	light.shadow_enabled = false
	get_tree().current_scene.add_child(light)
	light.global_position = position
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.18 + intensity * 0.12)
	tween.tween_callback(Callable(light, "queue_free"))
	return true


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["spell_lifecycle_presentation"] = true
	data["spell_phases"] = [
		"prepare", "release", "travel", "manifest", "latch", "sustain", "resolve", "handoff", "cancel",
	]
	data["spell_elements"] = SPELL_ELEMENTS.duplicate()
	data["semantic_events"] = [
		"impact", "reaction", "break", "footstep", "jump", "landing", "spell",
	]
	return data
