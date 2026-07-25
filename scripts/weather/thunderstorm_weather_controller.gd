extends "res://scripts/weather/weather_controller.gd"
class_name ThunderstormWeatherController

signal storm_charge_started(world_position: Vector3, target_name: String)
signal storm_struck(world_position: Vector3, target_name: String, chain_count: int)
signal thunder_heard(world_position: Vector3, distance: float, delay_seconds: float)

const STRIKE_INTERVAL_MIN: float = 3.4
const STRIKE_INTERVAL_MAX: float = 5.8
const TELEGRAPH_SECONDS: float = 1.15
const SKY_HEIGHT: float = 34.0
const STRIKE_DAMAGE: int = 18
const STRIKE_STANCE_DAMAGE: int = 24
const IMPACT_RADIUS: float = 2.8
const CHAIN_RADIUS: float = 11.0
const MAXIMUM_CHAINS: int = 3
const SPEED_OF_SOUND: float = 343.0

@export var lightning_renderer_path: NodePath
@export var lighting_rig_path: NodePath

var lightning_renderer: LightningArcRenderer = null
var lighting_rig: Node = null
var strike_timer: float = 0.0
var telegraph_timer: float = 0.0
var pending_target: Node3D = null
var pending_position: Vector3 = Vector3.ZERO
var telegraph_root: Node3D = null
var telegraph_material: StandardMaterial3D = null
var telegraph_light: OmniLight3D = null
var thunder_queue: Array[Dictionary] = []
var thunder_stream: AudioStreamWAV = null
var storm_profile: LightningProfile = null
var strike_count: int = 0
var chain_count: int = 0
var last_target_name: String = "none"


func _process(delta: float) -> void:
	super._process(delta)
	_update_thunder_queue(delta)
	if not active:
		return

	if pending_target != null or telegraph_root != null:
		telegraph_timer -= max(delta, 0.0)
		_update_telegraph()
		if telegraph_timer <= 0.0:
			_execute_pending_strike()
		return

	strike_timer -= max(delta, 0.0)
	if strike_timer <= 0.0:
		_begin_strike()


func start_weather(source_player: Node3D = null) -> bool:
	resolve_dependencies(source_player)
	if weather_definition == null or concentration_manager == null:
		show_message("Thunderstorm cannot form without a weather definition and concentration manager.")
		return false

	stop_other_weather_controllers()
	var ability_caster: Node = player.get_node_or_null("AbilityCaster") if player != null else null
	if not concentration_manager.has_method("activate_effect"):
		return false
	if not bool(concentration_manager.call("activate_effect", weather_definition, ability_caster)):
		return false

	resolve_storm_dependencies()
	active = true
	exposure_timer = 0.0
	pulse_count = 0
	strike_count = 0
	chain_count = 0
	last_target_name = "none"
	last_exposed_targets.clear()
	thunder_queue.clear()
	strike_timer = random.randf_range(1.6, 2.4)
	set_rain_visuals_visible(true)
	apply_weather_environment()
	reset_all_drops()
	weather_started.emit(get_weather_id())

	if show_messages:
		show_message("Thunderstorm answers Grace. Lightning spells draw freely from the charged sky.")
	return true


func stop_weather(show_feedback: bool = true) -> void:
	if not active:
		return
	_clear_pending_strike()
	super.stop_weather(false)
	if show_feedback and show_messages:
		show_message("The storm charge breaks and the reserved mana ceiling is released.")


func _on_concentration_effect_deactivated(effect_id: String) -> void:
	if not active or effect_id != get_weather_id():
		return
	_clear_pending_strike()
	super._on_concentration_effect_deactivated(effect_id)


func resolve_storm_dependencies() -> void:
	if lightning_renderer == null and not lightning_renderer_path.is_empty():
		lightning_renderer = get_node_or_null(lightning_renderer_path) as LightningArcRenderer
	if lightning_renderer == null:
		for candidate: Node in get_tree().get_nodes_in_group("lightning_arc_renderer"):
			if candidate is LightningArcRenderer:
				lightning_renderer = candidate as LightningArcRenderer
				break
	if lightning_renderer == null:
		lightning_renderer = LightningArcRenderer.new()
		lightning_renderer.name = "ThunderstormArcRenderer"
		lightning_renderer.add_to_group("lightning_arc_renderer")
		add_child(lightning_renderer)

	if lighting_rig == null and not lighting_rig_path.is_empty():
		lighting_rig = get_node_or_null(lighting_rig_path)
	if lighting_rig == null:
		lighting_rig = get_tree().get_first_node_in_group("cinematic_lighting")

	if storm_profile == null:
		storm_profile = LightningProfile.new()
		storm_profile.core_color = Color(0.96, 0.99, 1.0, 1.0)
		storm_profile.glow_color = Color(0.24, 0.48, 1.0, 0.82)
		storm_profile.impact_color = Color(0.70, 0.88, 1.0, 1.0)
		storm_profile.thickness = 0.072
		storm_profile.glow_width_multiplier = 4.2
		storm_profile.duration_seconds = 0.26
		storm_profile.subdivision_count = 6
		storm_profile.jitter_amplitude = 0.72
		storm_profile.branch_chance = 0.48
		storm_profile.branch_depth = 2
		storm_profile.branch_length_ratio = 0.42
		storm_profile.maximum_branches = 22
		storm_profile.flicker_frequency = 46.0
		storm_profile.light_energy = 8.5
		storm_profile.light_range = 12.0
		storm_profile.impact_flash_scale = 0.34


func _begin_strike() -> void:
	var selection: Dictionary = _choose_strike_target()
	pending_target = selection.get("target") as Node3D
	pending_position = selection.get("position", _safe_ground_position()) as Vector3
	last_target_name = pending_target.name if pending_target != null else "open ground"
	telegraph_timer = TELEGRAPH_SECONDS
	_create_telegraph(pending_position)
	storm_charge_started.emit(pending_position, last_target_name)


func _choose_strike_target() -> Dictionary:
	var candidates: Array[Node3D] = []
	var seen: Dictionary = {}
	for group_name: String in [
		"lightning_attractor",
		"conductive_water_volumes",
		"lightning_chain_target",
		"conductive",
		"metal",
		"enemy",
	]:
		for raw_candidate: Node in get_tree().get_nodes_in_group(group_name):
			var candidate: Node3D = raw_candidate as Node3D
			if candidate == null or candidate == player or not is_instance_valid(candidate):
				continue
			var key: int = candidate.get_instance_id()
			if seen.has(key):
				continue
			seen[key] = true
			candidates.append(candidate)

	if candidates.is_empty():
		return {"target": null, "position": _safe_ground_position()}

	var center: Vector3 = player.global_position if player != null else global_position
	var best_target: Node3D = null
	var best_score: float = -INF
	for candidate: Node3D in candidates:
		var target_position: Vector3 = _get_target_position(candidate)
		var distance: float = center.distance_to(target_position)
		if distance > 58.0:
			continue
		var score: float = 62.0 - distance
		score += max(target_position.y - center.y, 0.0) * 2.4
		if candidate.is_in_group("lightning_attractor"):
			score += 48.0
		if candidate.is_in_group("conductive_water_volumes"):
			score += 38.0
		if candidate.is_in_group("conductive") or candidate.is_in_group("metal"):
			score += 24.0
		if candidate.has_method("is_wet_by_weather") and bool(candidate.call("is_wet_by_weather")):
			score += 22.0
		score += random.randf_range(0.0, 12.0)
		if score > best_score:
			best_score = score
			best_target = candidate

	if best_target == null:
		return {"target": null, "position": _safe_ground_position()}
	return {"target": best_target, "position": _get_target_position(best_target)}


func _safe_ground_position() -> Vector3:
	var center: Vector3 = player.global_position if player != null else global_position
	var angle: float = random.randf_range(0.0, TAU)
	var radius: float = random.randf_range(7.0, 13.0)
	var candidate: Vector3 = center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	var world: World3D = get_world_3d()
	if world == null:
		return candidate
	var query := PhysicsRayQueryParameters3D.create(
		candidate + Vector3.UP * 18.0,
		candidate + Vector3.DOWN * 24.0
	)
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	return hit.get("position", candidate) as Vector3


func _create_telegraph(world_position: Vector3) -> void:
	_clear_telegraph()
	telegraph_root = Node3D.new()
	telegraph_root.name = "StormStrikeTelegraph"
	add_child(telegraph_root)
	telegraph_root.global_position = world_position + Vector3.UP * 0.05

	telegraph_material = StandardMaterial3D.new()
	telegraph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_material.emission_enabled = true
	telegraph_material.emission = Color(0.32, 0.62, 1.0, 1.0)
	telegraph_material.emission_energy_multiplier = 3.2
	telegraph_material.albedo_color = Color(0.42, 0.72, 1.0, 0.72)

	var ring := MeshInstance3D.new()
	ring.name = "ChargeRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.08
	torus.rings = 20
	torus.ring_segments = 8
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = telegraph_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	telegraph_root.add_child(ring)

	for index: int in range(4):
		var spark := MeshInstance3D.new()
		spark.name = "GroundLeader" + str(index)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 1.2 + float(index % 2) * 0.5, 0.035)
		spark.mesh = mesh
		spark.material_override = telegraph_material
		var angle: float = TAU * float(index) / 4.0
		spark.position = Vector3(cos(angle) * 0.72, 0.65, sin(angle) * 0.72)
		spark.rotation_degrees.z = -10.0 + float(index) * 7.0
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		telegraph_root.add_child(spark)

	telegraph_light = OmniLight3D.new()
	telegraph_light.name = "ChargeLight"
	telegraph_light.position = Vector3.UP * 1.0
	telegraph_light.light_color = Color(0.35, 0.62, 1.0, 1.0)
	telegraph_light.light_energy = 1.8
	telegraph_light.omni_range = 5.5
	telegraph_light.shadow_enabled = false
	telegraph_root.add_child(telegraph_light)


func _update_telegraph() -> void:
	if telegraph_root == null:
		return
	if pending_target != null and is_instance_valid(pending_target):
		pending_position = _get_target_position(pending_target)
		telegraph_root.global_position = pending_position + Vector3.UP * 0.05
	var progress: float = clampf(1.0 - telegraph_timer / TELEGRAPH_SECONDS, 0.0, 1.0)
	var pulse: float = 1.0 + sin(progress * TAU * 5.0) * 0.10
	telegraph_root.scale = Vector3.ONE * lerpf(1.25, 0.62, progress) * pulse
	if telegraph_material != null:
		telegraph_material.emission_energy_multiplier = lerpf(2.2, 8.0, progress)
	if telegraph_light != null:
		telegraph_light.light_energy = lerpf(1.2, 5.5, progress) * pulse


func _execute_pending_strike() -> void:
	if pending_target != null and is_instance_valid(pending_target):
		pending_position = _get_target_position(pending_target)
	var target: Node3D = pending_target
	var position_value: Vector3 = pending_position
	_clear_telegraph()
	pending_target = null
	force_storm_strike(position_value, target)
	strike_timer = random.randf_range(STRIKE_INTERVAL_MIN, STRIKE_INTERVAL_MAX)


func force_storm_strike(world_position: Vector3, target: Node3D = null) -> int:
	resolve_storm_dependencies()
	var sky_offset := Vector3(
		random.randf_range(-4.5, 4.5),
		SKY_HEIGHT,
		random.randf_range(-4.5, 4.5)
	)
	var strike_event := LightningArcEvent.make(
		LightningArcEvent.KIND_STORM,
		world_position + sky_offset,
		world_position,
		2.6,
		7232026 + strike_count * 97,
		"thunderstorm_weather",
		["lightning", "storm", "weather", "electrical", "charged"]
	)
	lightning_renderer.render_arc(strike_event, storm_profile)
	if lighting_rig != null and lighting_rig.has_method("flash_lightning"):
		lighting_rig.call("flash_lightning", 1.0, world_position)

	var affected: int = _apply_primary_impact(world_position, target)
	var chained: int = _chain_from(world_position, target)
	strike_count += 1
	chain_count += chained
	_queue_thunder(world_position)
	storm_struck.emit(
		world_position,
		target.name if target != null and is_instance_valid(target) else "open ground",
		chained
	)
	return affected + chained


func _apply_primary_impact(world_position: Vector3, target: Node3D) -> int:
	var affected: int = 0
	if target != null and is_instance_valid(target) and target != player:
		if _deliver_lightning_payload(target, STRIKE_DAMAGE, STRIKE_STANCE_DAMAGE, 1.0):
			affected += 1

	for raw_enemy: Node in get_tree().get_nodes_in_group("enemy"):
		var enemy: Node3D = raw_enemy as Node3D
		if enemy == null or enemy == player or enemy == target or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(world_position) > IMPACT_RADIUS:
			continue
		if _deliver_lightning_payload(enemy, STRIKE_DAMAGE, STRIKE_STANCE_DAMAGE, 1.0):
			affected += 1
	return affected


func _chain_from(start_position: Vector3, primary_target: Node3D) -> int:
	var candidates: Array[Node3D] = []
	var seen: Dictionary = {}
	if primary_target != null:
		seen[primary_target.get_instance_id()] = true
	if player != null:
		seen[player.get_instance_id()] = true

	for group_name: String in [
		"lightning_chain_target",
		"conductive_water_volumes",
		"conductive",
		"metal",
		"enemy",
	]:
		for raw_candidate: Node in get_tree().get_nodes_in_group(group_name):
			var candidate: Node3D = raw_candidate as Node3D
			if candidate == null or not is_instance_valid(candidate):
				continue
			var key: int = candidate.get_instance_id()
			if seen.has(key):
				continue
			seen[key] = true
			candidates.append(candidate)

	var current_position: Vector3 = start_position
	var chained: int = 0
	while chained < MAXIMUM_CHAINS and not candidates.is_empty():
		var best_index: int = -1
		var best_distance: float = CHAIN_RADIUS + 0.001
		for index: int in range(candidates.size()):
			var distance: float = current_position.distance_to(_get_target_position(candidates[index]))
			if distance < best_distance:
				best_distance = distance
				best_index = index
		if best_index < 0:
			break

		var target: Node3D = candidates[best_index]
		candidates.remove_at(best_index)
		var next_position: Vector3 = _get_target_position(target)
		var chain_event := LightningArcEvent.make(
			LightningArcEvent.KIND_CHAIN,
			current_position,
			next_position,
			1.15 - float(chained) * 0.16,
			7232123 + strike_count * 101 + chained * 17,
			"thunderstorm_chain",
			["lightning", "chain", "conductive", "weather"]
		)
		lightning_renderer.render_arc(chain_event, storm_profile)
		_deliver_lightning_payload(
			target,
			max(STRIKE_DAMAGE - 5 - chained * 3, 4),
			max(STRIKE_STANCE_DAMAGE - 7 - chained * 4, 5),
			0.75
		)
		current_position = next_position
		chained += 1
	return chained


func _deliver_lightning_payload(
	target: Node,
	damage: int,
	stance_damage: int,
	strength: float
) -> bool:
	if target == null or target == player or not is_instance_valid(target):
		return false
	var payload := DamagePayload.new()
	payload.amount = damage
	payload.stance_damage = stance_damage
	payload.element = "lightning"
	payload.source_name = "Thunderstorm"
	payload.hit_type = "weather"
	payload.status_effect = "stunned"
	payload.status_duration = 0.55
	payload.status_strength = strength
	payload.tags = [
		"lightning",
		"shock",
		"electrical",
		"weather",
		"storm",
		"wet_shock",
		"conductive",
	]

	if target.has_method("receive_damage_payload"):
		target.call("receive_damage_payload", payload)
		return true
	var receiver: Node = target.get_node_or_null("PayloadReceiver")
	if receiver != null and receiver.has_method("receive_payload"):
		receiver.call("receive_payload", payload)
		return true
	return false


func _get_target_position(target: Node3D) -> Vector3:
	if target != null and target.has_method("get_lightning_target_position"):
		var value: Variant = target.call("get_lightning_target_position")
		if value is Vector3:
			return value as Vector3
	return target.global_position if target != null else pending_position


func _queue_thunder(world_position: Vector3) -> void:
	var listener_position: Vector3 = player.global_position if player != null else world_position
	var distance: float = listener_position.distance_to(world_position)
	thunder_queue.append({
		"position": world_position,
		"distance": distance,
		"delay": max(distance / SPEED_OF_SOUND, 0.03),
		"original_delay": max(distance / SPEED_OF_SOUND, 0.03),
	})


func _update_thunder_queue(delta: float) -> void:
	for index: int in range(thunder_queue.size() - 1, -1, -1):
		var entry: Dictionary = thunder_queue[index]
		entry["delay"] = float(entry.get("delay", 0.0)) - max(delta, 0.0)
		thunder_queue[index] = entry
		if float(entry["delay"]) > 0.0:
			continue
		thunder_queue.remove_at(index)
		_play_thunder(
			entry.get("position", global_position) as Vector3,
			float(entry.get("distance", 0.0)),
			float(entry.get("original_delay", 0.0))
		)


func _play_thunder(world_position: Vector3, distance: float, delay_seconds: float) -> void:
	if thunder_stream == null:
		thunder_stream = _build_thunder_stream()
	var audio := AudioStreamPlayer3D.new()
	audio.name = "ProceduralThunder"
	audio.stream = thunder_stream
	audio.volume_db = clampf(-2.0 - distance * 0.035, -13.0, -2.0)
	audio.unit_size = 28.0
	audio.max_distance = 160.0
	add_child(audio)
	audio.global_position = world_position + Vector3.UP * 5.0
	audio.finished.connect(audio.queue_free)
	audio.play()

	var manager: Node = get_tree().get_first_node_in_group("perception_stimulus_manager")
	if manager != null and manager.has_method("emit_stimulus"):
		manager.call(
			"emit_stimulus",
			world_position,
			32.0,
			"thunder",
			2.0,
			self,
			"Thunder",
			2.4,
			["weather", "storm", "thunder", "hazard"]
		)
	thunder_heard.emit(world_position, distance, delay_seconds)


func _build_thunder_stream() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 16000
	stream.stereo = false
	var duration: float = 1.45
	var sample_count: int = int(float(stream.mix_rate) * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for sample_index: int in range(sample_count):
		var time: float = float(sample_index) / float(stream.mix_rate)
		var envelope: float = pow(max(1.0 - time / duration, 0.0), 1.45)
		var crack: float = sin(time * 920.0) * exp(-time * 18.0)
		var rumble: float = (
			sin(TAU * 43.0 * time)
			+ sin(TAU * 57.0 * time + 0.7)
			+ 0.55 * sin(TAU * 71.0 * time + 1.9)
		) / 2.55
		var grit: float = sin(time * 1379.0 + sin(time * 211.0) * 4.0) * 0.10
		var value: float = clampf((rumble * 0.68 + crack * 0.52 + grit) * envelope, -1.0, 1.0)
		bytes.encode_s16(sample_index * 2, int(value * 32767.0))
	stream.data = bytes
	return stream


func _clear_pending_strike() -> void:
	pending_target = null
	telegraph_timer = 0.0
	_clear_telegraph()


func _clear_telegraph() -> void:
	if telegraph_root != null and is_instance_valid(telegraph_root):
		telegraph_root.queue_free()
	telegraph_root = null
	telegraph_material = null
	telegraph_light = null


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["thunderstorm"] = true
	data["strike_count"] = strike_count
	data["chain_count"] = chain_count
	data["charging"] = telegraph_root != null
	data["last_target"] = last_target_name
	data["queued_thunder"] = thunder_queue.size()
	data["infinite_lightning"] = is_generating_element("lightning")
	return data
