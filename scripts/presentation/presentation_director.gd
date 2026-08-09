extends Node
class_name GamePresentationDirector

signal event_presented(event_type: String, data: Dictionary)

const PresentationAudioScript = preload(
	"res://scripts/presentation/presentation_audio.gd"
)
const GameFeedbackScript = preload(
	"res://scripts/systems/game_feedback.gd"
)
const ElementVisuals = preload(
	"res://scripts/visuals/element_visuals.gd"
)

const HISTORY_LIMIT: int = 24
const ELEMENT_ACCENT_ELEMENTS: Array[String] = [
	"fire", "water", "ice", "lightning", "life", "death", "space", "sound",
]

var audio: PresentationAudio = null
var event_counter: int = 0
var event_history: Array[Dictionary] = []
var event_counts: Dictionary = {}
var last_event: Dictionary = {}
var last_channel_msec: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("presentation_director")
	add_to_group("debuggable")
	audio = PresentationAudioScript.new() as PresentationAudio
	audio.name = "PresentationAudio"
	add_child(audio)


func present(event_type: String, context: Dictionary = {}) -> Dictionary:
	match event_type.strip_edges().to_lower():
		"impact":
			return present_impact(context)
		"reaction":
			return present_reaction(context)
		"break":
			return present_break(context)
		"footstep", "jump", "landing":
			return present_movement(event_type, context)
		_:
			return _record_event(event_type, context.duplicate(true))


func present_impact(context: Dictionary = {}) -> Dictionary:
	var target: Node = _valid_node(context.get("target"))
	var position: Vector3 = _resolve_position(context, target)
	var material_id: String = str(
		context.get("material", infer_material(target))
	).strip_edges().to_lower()
	if material_id == "" or material_id == "auto":
		material_id = infer_material(target)
	var element: String = str(context.get("element", "neutral")).strip_edges().to_lower()
	var intensity: float = _resolve_impact_intensity(context)
	var result_value: Variant = context.get("result", {})
	var result: Dictionary = (
		(result_value as Dictionary).duplicate(true)
		if result_value is Dictionary
		else {}
	)
	var message: String = str(result.get("message", "")).to_lower()
	var critical: bool = bool(result.get("critical", false)) or bool(context.get("critical", false))
	var defeated: bool = message.contains("defeat") or bool(context.get("defeated", false))
	var resisted: bool = (
		message.contains("immune")
		or message.contains("ignore")
		or message.contains("resist")
		or bool(context.get("resisted", false))
	)
	var tier: String = "heavy" if critical or defeated else ("medium" if intensity >= 0.52 else "light")
	if resisted:
		tier = "resist"

	var material_cue: String = "impact_" + _normalize_material_cue(material_id)
	var audio_rows: Array[Dictionary] = []
	if audio != null:
		var material_audio: Dictionary = audio.play_cue(
			material_cue,
			position,
			clampf(0.28 + intensity * 0.7, 0.0, 1.0),
			0.055
		)
		if not material_audio.is_empty():
			audio_rows.append(material_audio)
		if element in ELEMENT_ACCENT_ELEMENTS and not resisted:
			var accent_audio: Dictionary = audio.play_cue(
				"element_" + element,
				position,
				clampf(0.12 + intensity * 0.32, 0.0, 0.55),
				0.045
			)
			if not accent_audio.is_empty():
				audio_rows.append(accent_audio)

	var haptic_id: String = "impact_resist" if resisted else (
		"impact_medium" if tier in ["medium", "heavy"] else "impact_light"
	)
	var haptic_played: bool = false
	if not bool(context.get("suppress_haptics", false)):
		haptic_played = _play_haptic_throttled(
			haptic_id,
			"impact",
			42 if tier == "light" else 28
		)

	var data: Dictionary = {
		"target": target,
		"position": position,
		"material": material_id,
		"element": element,
		"intensity": snappedf(intensity, 0.01),
		"tier": tier,
		"critical": critical,
		"defeated": defeated,
		"resisted": resisted,
		"audio": audio_rows,
		"haptic": haptic_id if haptic_played else "throttled",
		"source_name": str(context.get("source_name", "impact")),
	}
	return _record_event("impact", data)


func present_reaction(context: Dictionary = {}) -> Dictionary:
	var target: Node = _valid_node(context.get("target"))
	var reaction: String = str(context.get("reaction", "RESIST")).strip_edges().to_upper()
	var impact: float = maxf(float(context.get("impact", 0.0)), 0.0)
	var position: Vector3 = _resolve_position(context, target)
	var payload: DamagePayload = _valid_payload(context.get("payload"))
	var element: String = (
		payload.element.to_lower()
		if payload != null and payload.element != ""
		else str(context.get("element", "neutral")).to_lower()
	)
	var is_weapon: bool = payload != null and (
		payload.tags.has("weapon") or payload.tags.has("melee")
	)
	var tier: String = _reaction_tier(reaction)
	var cue_id: String = _reaction_cue(reaction)
	var haptic_id: String = _reaction_haptic(reaction)
	var intensity: float = clampf(impact / 11.0, 0.18, 1.0)
	if tier == "heavy":
		intensity = maxf(intensity, 0.72)
	elif tier == "medium":
		intensity = maxf(intensity, 0.48)

	var audio_data: Dictionary = {}
	if audio != null and cue_id != "":
		audio_data = audio.play_cue(cue_id, position, intensity, 0.035)
	var haptic_played: bool = false
	if haptic_id != "":
		haptic_played = _play_haptic_throttled(haptic_id, "reaction", 45)

	# WeaponController already owns authored melee hit stop and camera impact.
	# Reactions still add contact texture, haptics and VFX, but do not double the
	# large temporal/camera layer for weapon hits.
	var hit_stop_requested: bool = false
	var camera_requested: bool = false
	if not is_weapon:
		var hit_stop_profile: Dictionary = _reaction_hit_stop(reaction)
		if not hit_stop_profile.is_empty():
			hit_stop_requested = _request_hit_stop(
				float(hit_stop_profile.get("duration", 0.0)),
				float(hit_stop_profile.get("time_scale", 1.0))
			)
		var camera_strength: float = _reaction_camera_strength(reaction)
		if camera_strength > 0.0:
			camera_requested = _request_camera_impulse(
				context.get("direction", Vector3.ZERO) as Vector3,
				camera_strength
			)

	var visual_spawned: bool = false
	if target != null and target.get_tree() != null and tier in ["medium", "heavy"]:
		ElementVisuals.spawn_reaction_burst(
			target.get_tree(),
			position + Vector3.UP * 0.35,
			"presentation_" + reaction.to_lower().replace(" ", "_"),
			_get_element_color(element),
			1.1 if tier == "medium" else 1.5,
			0.28 if tier == "medium" else 0.4
		)
		visual_spawned = true

	return _record_event("reaction", {
		"target": target,
		"position": position,
		"reaction": reaction,
		"tier": tier,
		"impact": snappedf(impact, 0.1),
		"element": element,
		"weapon_owned_temporal_feedback": is_weapon,
		"audio": audio_data,
		"haptic": haptic_id if haptic_played else "throttled",
		"hit_stop": hit_stop_requested,
		"camera": camera_requested,
		"visual": visual_spawned,
	})


func present_break(context: Dictionary = {}) -> Dictionary:
	var target: Node = _valid_node(context.get("target"))
	var position: Vector3 = _resolve_position(context, target)
	var material_id: String = str(
		context.get("material", infer_material(target))
	).to_lower()
	var cue_id: String = "break_" + _normalize_material_cue(material_id)
	var audio_data: Dictionary = {}
	if audio != null:
		audio_data = audio.play_cue(cue_id, position, 0.88, 0.055)
	var haptic_played: bool = _play_haptic_throttled("break_heavy", "break", 75)
	_request_camera_impulse(Vector3.DOWN, 0.28)
	return _record_event("break", {
		"target": target,
		"position": position,
		"material": material_id,
		"audio": audio_data,
		"haptic": "break_heavy" if haptic_played else "throttled",
	})


func present_movement(kind: String, context: Dictionary = {}) -> Dictionary:
	var normalized: String = kind.strip_edges().to_lower()
	var actor: Node = _valid_node(context.get("actor"))
	var position: Vector3 = _resolve_position(context, actor)
	var material_id: String = str(context.get("material", "auto")).to_lower()
	if material_id in ["", "auto"]:
		material_id = infer_floor_material(actor, position)
	var strength: float = clampf(float(context.get("strength", 0.5)), 0.0, 1.0)
	var cue_id: String = normalized
	if normalized == "footstep":
		# Footsteps use the material timbre at low intensity, layered with the
		# compact footstep transient.
		if audio != null:
			audio.play_cue(
				"impact_" + _normalize_material_cue(material_id),
				position,
				0.11,
				0.075
			)
		strength = minf(strength, 0.28)
	var audio_data: Dictionary = {}
	if audio != null:
		audio_data = audio.play_cue(cue_id, position, strength, 0.06)
	var haptic_id: String = ""
	if normalized == "landing" and strength >= 0.42:
		haptic_id = "landing_impact"
		_play_haptic_throttled(haptic_id, "landing", 90)
	return _record_event(normalized, {
		"actor": actor,
		"position": position,
		"material": material_id,
		"strength": snappedf(strength, 0.01),
		"audio": audio_data,
		"haptic": haptic_id,
	})


func infer_material(target: Node) -> String:
	if target == null or not is_instance_valid(target):
		return "soft"
	var current: Node = target
	while current != null and is_instance_valid(current):
		if current.has_method("get_presentation_material"):
			var method_value: String = str(current.call("get_presentation_material")).to_lower()
			if method_value not in ["", "auto"]:
				return method_value
		if current.has_meta("presentation_material"):
			var meta_value: String = str(current.get_meta("presentation_material")).to_lower()
			if meta_value not in ["", "auto"]:
				return meta_value
		for material_id: String in ["metal", "stone", "wood", "glass", "flesh", "soft"]:
			if current.is_in_group("presentation_material_" + material_id):
				return material_id
		var lower_name: String = current.name.to_lower()
		if "glass" in lower_name or "crystal" in lower_name:
			return "glass"
		if "metal" in lower_name or "armor" in lower_name or "copper" in lower_name or "iron" in lower_name:
			return "metal"
		if "stone" in lower_name or "rock" in lower_name or "urn" in lower_name:
			return "stone"
		if "wood" in lower_name or "crate" in lower_name or "barrel" in lower_name:
			return "wood"
		if current.is_in_group("enemy") or current is CharacterBody3D:
			return "flesh"
		current = current.get_parent()
	return "soft"


func infer_floor_material(actor: Node, position: Vector3) -> String:
	if actor == null or not is_instance_valid(actor) or not actor is Node3D:
		return "stone"
	var actor_3d := actor as Node3D
	var world: World3D = actor_3d.get_world_3d()
	if world == null:
		return "stone"
	var query := PhysicsRayQueryParameters3D.create(
		position + Vector3.UP * 0.2,
		position + Vector3.DOWN * 1.35
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return "stone"
	var collider: Node = _valid_node(hit.get("collider"))
	return infer_material(collider) if collider != null else "stone"


func preview_impact(
	material_id: String,
	reaction: String = "FLINCH",
	element: String = "neutral",
	position: Vector3 = Vector3.ZERO
) -> Dictionary:
	var impact_data: Dictionary = present_impact({
		"position": position,
		"material": material_id,
		"element": element,
		"intensity": 0.55,
		"source_name": "Polish Studio Preview",
	})
	present_reaction({
		"position": position,
		"reaction": reaction,
		"impact": 6.0,
		"element": element,
		"direction": Vector3.BACK,
	})
	return impact_data


func _resolve_impact_intensity(context: Dictionary) -> float:
	if context.has("intensity"):
		return clampf(float(context.get("intensity", 0.4)), 0.0, 1.0)
	var damage: float = maxf(float(context.get("damage", 0.0)), 0.0)
	var stance: float = maxf(float(context.get("stance_damage", 0.0)), 0.0)
	var payload: DamagePayload = _valid_payload(context.get("payload"))
	if payload != null:
		damage = maxf(damage, float(payload.amount))
		stance = maxf(stance, float(payload.stance_damage))
	return clampf((damage * 0.09) + (stance * 0.07) + 0.18, 0.12, 1.0)


func _reaction_tier(reaction: String) -> String:
	match reaction:
		"STAGGER", "GUARD BREAK", "LAUNCH":
			return "heavy"
		"FLINCH":
			return "medium"
		_:
			return "light"


func _reaction_cue(reaction: String) -> String:
	match reaction:
		"FLINCH":
			return "reaction_stagger"
		"STAGGER":
			return "reaction_stagger"
		"LAUNCH":
			return "reaction_launch"
		"GUARD BREAK":
			return "reaction_break"
		"RESIST", "SUPER ARMOR", "ADAPTED":
			return "reaction_resist"
		_:
			return "reaction_resist"


func _reaction_haptic(reaction: String) -> String:
	match reaction:
		"STAGGER":
			return "impact_stagger"
		"LAUNCH":
			return "impact_launch"
		"GUARD BREAK":
			return "impact_break"
		"FLINCH":
			return "impact_medium"
		"RESIST", "SUPER ARMOR", "ADAPTED":
			return "impact_resist"
		_:
			return "impact_light"


func _reaction_hit_stop(reaction: String) -> Dictionary:
	match reaction:
		"STAGGER":
			return {"duration": 0.038, "time_scale": 0.09}
		"LAUNCH":
			return {"duration": 0.052, "time_scale": 0.055}
		"GUARD BREAK":
			return {"duration": 0.06, "time_scale": 0.045}
		_:
			return {}


func _reaction_camera_strength(reaction: String) -> float:
	match reaction:
		"FLINCH":
			return 0.12
		"STAGGER":
			return 0.28
		"LAUNCH":
			return 0.4
		"GUARD BREAK":
			return 0.46
		_:
			return 0.0


func _play_haptic_throttled(
	feedback_id: String,
	channel: String,
	cooldown_msec: int
) -> bool:
	var now: int = Time.get_ticks_msec()
	var last: int = int(last_channel_msec.get("haptic:" + channel, -999999))
	if now - last < maxi(cooldown_msec, 0):
		return false
	last_channel_msec["haptic:" + channel] = now
	GameFeedbackScript.play(feedback_id, {"source": "presentation_director"})
	return true


func _request_hit_stop(duration: float, time_scale: float) -> bool:
	if duration <= 0.0:
		return false
	var hit_stop: Node = get_node_or_null("/root/HitStop")
	if hit_stop == null or not hit_stop.has_method("request"):
		return false
	hit_stop.call("request", duration, time_scale)
	return true


func _request_camera_impulse(direction_value: Variant, strength: float) -> bool:
	if strength <= 0.0 or get_tree() == null:
		return false
	var direction: Vector3 = direction_value as Vector3 if direction_value is Vector3 else Vector3.ZERO
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return false
	var feedback: Node = player.get_node_or_null("PlayerMotionFeedback")
	if feedback == null or not feedback.has_method("apply_presentation_camera_impulse"):
		return false
	feedback.call("apply_presentation_camera_impulse", direction, strength)
	return true


func _resolve_position(context: Dictionary, target: Node) -> Vector3:
	var position_value: Variant = context.get("position")
	if position_value is Vector3:
		return position_value as Vector3
	if target != null and is_instance_valid(target):
		if target is Node3D:
			return (target as Node3D).global_position
		var parent: Node = target.get_parent()
		if parent is Node3D:
			return (parent as Node3D).global_position
	return Vector3.ZERO


func _normalize_material_cue(material_id: String) -> String:
	match material_id:
		"metal":
			return "metal"
		"stone":
			return "stone"
		"wood":
			return "wood"
		"glass", "crystal":
			return "glass"
		"flesh":
			return "flesh"
		_:
			return "soft"


func _get_element_color(element: String) -> Color:
	match element:
		"fire":
			return Color(1.0, 0.25, 0.05, 1.0)
		"water":
			return Color(0.08, 0.58, 1.0, 1.0)
		"ice":
			return Color(0.56, 0.94, 1.0, 1.0)
		"lightning":
			return Color(0.72, 0.72, 1.0, 1.0)
		"life":
			return Color(0.28, 0.88, 0.18, 1.0)
		"death":
			return Color(0.78, 0.08, 0.12, 1.0)
		"space":
			return Color(0.63, 0.24, 1.0, 1.0)
		"sound":
			return Color(1.0, 0.43, 0.74, 1.0)
		_:
			return Color(0.82, 0.86, 0.94, 1.0)


func _valid_node(value: Variant) -> Node:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as Node if value is Node else null


func _valid_payload(value: Variant) -> DamagePayload:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	return value as DamagePayload if value is DamagePayload else null


func _record_event(event_type: String, data: Dictionary) -> Dictionary:
	event_counter += 1
	var record: Dictionary = data.duplicate(true)
	record["event_id"] = event_counter
	record["event_type"] = event_type.strip_edges().to_lower()
	record["time_msec"] = Time.get_ticks_msec()
	last_event = record.duplicate(true)
	event_history.append(record.duplicate(true))
	while event_history.size() > HISTORY_LIMIT:
		event_history.pop_front()
	var normalized: String = str(record["event_type"])
	event_counts[normalized] = int(event_counts.get(normalized, 0)) + 1
	event_presented.emit(normalized, record.duplicate(true))
	return record


func clear_history() -> void:
	event_history.clear()
	event_counts.clear()
	last_event.clear()


func get_debug_data() -> Dictionary:
	return {
		"presentation_director": true,
		"events": event_counter,
		"event_counts": event_counts.duplicate(true),
		"history_size": event_history.size(),
		"last_event": last_event.duplicate(true),
		"audio": audio.get_debug_data() if audio != null else {},
		"semantic_events": ["impact", "reaction", "break", "footstep", "jump", "landing"],
	}
