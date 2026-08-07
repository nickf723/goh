extends "res://scripts/levels/prototype_curling_puck_spell_trial_ready.gd"
class_name PrototypeCurlingPuckSpellTrialReliable

# Spell trials are teaching spaces, not one-frame signal traps. Every Rime Rink
# gate now re-evaluates its completed physical state on a small interval in
# addition to listening to the original signals. This covers missed Area3D entry
# frames, pressure-plate metadata arriving one physics frame late, and a valid
# curling route passing close to the authored marks without touching their exact
# centers.

@export_range(0.02, 0.5, 0.01) var reliable_gate_retry_interval: float = 0.08
@export_range(0.5, 3.0, 0.05) var reliable_checkpoint_radius: float = 1.8
@export_range(1, 32, 1) var reliable_minimum_curl_segments: int = 7
@export_range(1.0, 20.0, 0.25) var reliable_minimum_curl_span: float = 5.5
@export_range(0.0, 4.0, 0.05) var reliable_minimum_lateral_bend: float = 0.28
@export_range(1, 32, 1) var reliable_minimum_water_segments: int = 8
@export_range(1, 32, 1) var reliable_minimum_runway_segments: int = 8
@export_range(-100.0, 100.0, 0.1) var reliable_far_shore_z: float = 31.0

var reliable_gate_retry_remaining: float = 0.0
var reliable_gate_open_count: int = 0
var reliable_retry_count: int = 0
var curl_marks_last_hit: int = 0
var last_reliable_reason: String = "none"


func _ready() -> void:
	super._ready()
	checkpoint_radius = maxf(checkpoint_radius, reliable_checkpoint_radius)
	required_water_segments = mini(
		required_water_segments,
		reliable_minimum_water_segments
	)
	reliable_gate_retry_remaining = 0.0


func _process(delta: float) -> void:
	reliable_gate_retry_remaining -= maxf(delta, 0.0)
	if reliable_gate_retry_remaining > 0.0:
		return
	reliable_gate_retry_remaining = maxf(
		reliable_gate_retry_interval,
		0.02
	)
	reliable_retry_count += 1
	evaluate_gate_progression_now()


func evaluate_gate_progression_now() -> bool:
	match stage:
		TrialStage.CURL_ROUTE:
			return _evaluate_reliable_curl_route()
		TrialStage.FROZEN_CROSSING:
			return _evaluate_reliable_frozen_crossing(false)
		TrialStage.MOMENTUM_RUNWAY:
			return _evaluate_reliable_momentum_runway()
	return false


func _evaluate_curl_route() -> void:
	_evaluate_reliable_curl_route()


func _evaluate_reliable_curl_route() -> bool:
	if player == null or stage != TrialStage.CURL_ROUTE:
		return false
	for trail: Node in get_tree().get_nodes_in_group("curling_ice_trails"):
		if not _is_fresh_player_trail(trail, curl_serial_baseline):
			continue
		var curl_sign_value: float = float(
			trail.get_meta(
				"curling_puck_curl_sign",
				player.get_meta("curling_puck_last_curl_sign", 0.0)
			)
		)
		if curl_sign_value < 0.5:
			continue
		var positions: Array[Vector3] = _get_trail_positions(trail)
		if positions.size() < reliable_minimum_curl_segments:
			continue

		var marks_hit: int = 0
		for checkpoint: Vector3 in curl_checkpoints:
			if _trail_reaches_checkpoint_reliable(
				positions,
				checkpoint,
				reliable_checkpoint_radius
			):
				marks_hit += 1
		curl_marks_last_hit = marks_hit

		var first_position: Vector3 = positions[0]
		var last_position: Vector3 = positions[positions.size() - 1]
		var route_span: float = first_position.distance_to(last_position)
		var minimum_x: float = first_position.x
		var maximum_x: float = first_position.x
		for position_value: Vector3 in positions:
			minimum_x = minf(minimum_x, position_value.x)
			maximum_x = maxf(maximum_x, position_value.x)
		var lateral_bend: float = maximum_x - minimum_x
		if route_span < reliable_minimum_curl_span:
			continue
		if marks_hit < 2 and lateral_bend < reliable_minimum_lateral_bend:
			continue

		curl_success_serial = int(trail.get("cast_serial"))
		curl_completion_count += 1
		_open_gate_reliably(curl_gate, "reliable_curl_route")
		_set_stage(TrialStage.FROZEN_CROSSING)
		curl_route_completed.emit(curl_success_serial)
		_show_message(
			"The curling route is recognized. The Rime Rink checks the finished trail repeatedly, so the gate cannot miss a valid throw."
		)
		call_deferred("_clear_curling_effects")
		return true
	return false


func _trail_reaches_checkpoint_reliable(
	positions: Array[Vector3],
	checkpoint: Vector3,
	radius: float
) -> bool:
	for position_value: Vector3 in positions:
		var planar_distance: float = Vector2(
			position_value.x - checkpoint.x,
			position_value.z - checkpoint.z
		).length()
		if planar_distance <= radius:
			return true
	return false


func _on_bridge_arrival_entered(body: Node) -> void:
	if body != player:
		return
	_evaluate_reliable_frozen_crossing(true)


func _evaluate_reliable_frozen_crossing(
	arrival_signal_received: bool
) -> bool:
	if player == null or stage != TrialStage.FROZEN_CROSSING:
		return false
	if (
		not arrival_signal_received
		and player.global_position.z < reliable_far_shore_z
	):
		return false
	var qualifying_trail: Node = _find_fresh_water_trail(
		crossing_serial_baseline
	)
	if qualifying_trail == null:
		return false

	crossing_success_serial = int(qualifying_trail.get("cast_serial"))
	crossing_completion_count += 1
	_open_gate_reliably(crossing_gate, "reliable_frozen_crossing")
	_set_stage(TrialStage.MOMENTUM_RUNWAY)
	frozen_crossing_completed.emit(crossing_success_serial)
	_show_message(
		"The frozen route reaches the far shore. Arrival is polled as well as signaled, so a fast slide cannot skip the gate."
	)
	call_deferred("_clear_curling_effects")
	return true


func _on_momentum_plate_value_changed(
	value: float,
	packet: Dictionary
) -> void:
	_try_complete_reliable_momentum(value, packet)


func _evaluate_reliable_momentum_runway() -> bool:
	if momentum_plate == null or stage != TrialStage.MOMENTUM_RUNWAY:
		return false
	return _try_complete_reliable_momentum(
		momentum_plate.get_mechanism_value(),
		momentum_plate.get_mechanism_packet()
	)


func _try_complete_reliable_momentum(
	value: float,
	packet: Dictionary
) -> bool:
	if stage != TrialStage.MOMENTUM_RUNWAY:
		return false
	if value < required_plate_mass_kg:
		return false

	var boulder: Node = _find_boulder_from_mass_packet(packet)
	if boulder == null:
		boulder = _find_fresh_boulder_near_plate()
	if boulder == null:
		return false
	var boulder_serial: int = int(
		boulder.get_meta("boulder_cast_serial", 0)
	)
	if boulder_serial <= momentum_boulder_serial_baseline:
		return false

	var trail_serial: int = int(
		boulder.get_meta("ice_curl_last_trail_serial_contact", 0)
	)
	var trail: Node = null
	if trail_serial > momentum_puck_serial_baseline:
		trail = _find_player_trail_by_serial(trail_serial)
	if trail == null:
		trail = _find_newest_reliable_runway()
		if trail != null:
			trail_serial = int(trail.get("cast_serial"))
	if trail == null:
		return false

	var trail_debug: Dictionary = trail.call("get_debug_data") as Dictionary
	if int(trail_debug.get("ground_segments", 0)) < reliable_minimum_runway_segments:
		return false

	momentum_success_trail_serial = trail_serial
	momentum_success_boulder_serial = boulder_serial
	momentum_success_mass = value
	momentum_completion_count += 1
	_open_gate_reliably(momentum_gate, "reliable_ice_boulder_combo")
	_set_stage(TrialStage.MASTERY)
	momentum_runway_completed.emit(trail_serial, boulder_serial, value)
	_show_message(
		"The 160 kg Boulder completed the ice runway. The plate and trail are rechecked together, so late physics metadata can no longer strand the door."
	)
	return true


func _find_fresh_boulder_near_plate() -> Node:
	if momentum_plate == null:
		return null
	var best: Node = null
	var best_distance: float = INF
	for candidate: Node in get_tree().get_nodes_in_group(
		"earth_boulder_effects"
	):
		if (
			candidate == null
			or not is_instance_valid(candidate)
			or candidate.is_queued_for_deletion()
			or not candidate is Node3D
		):
			continue
		var serial: int = int(
			candidate.get_meta("boulder_cast_serial", 0)
		)
		if serial <= momentum_boulder_serial_baseline:
			continue
		var distance: float = (
			(candidate as Node3D).global_position.distance_to(
				momentum_plate.global_position
			)
		)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best if best_distance <= 4.0 else null


func _find_newest_reliable_runway() -> Node:
	var best: Node = null
	var best_serial: int = momentum_puck_serial_baseline
	for trail: Node in get_tree().get_nodes_in_group("curling_ice_trails"):
		if not _is_fresh_player_trail(
			trail,
			momentum_puck_serial_baseline
		):
			continue
		var debug: Dictionary = trail.call("get_debug_data") as Dictionary
		if int(debug.get("ground_segments", 0)) < reliable_minimum_runway_segments:
			continue
		var serial: int = int(trail.get("cast_serial"))
		if serial > best_serial:
			best = trail
			best_serial = serial
	return best


func _open_gate_reliably(
	gate: MechanismSlidingGate,
	reason: String
) -> void:
	if gate == null:
		return
	last_reliable_reason = reason
	reliable_gate_open_count += 1
	gate.set_gate_open(true, false, {
		"reason": reason,
		"reliable_retry": true,
	})
	call_deferred("_verify_gate_open", gate, reason)


func _verify_gate_open(
	gate: MechanismSlidingGate,
	reason: String
) -> void:
	if gate == null or not is_instance_valid(gate):
		return
	if not gate.is_mechanism_active():
		gate.set_gate_open(true, true, {
			"reason": reason + "_forced",
			"reliable_retry": true,
		})


func reset_trial() -> void:
	reliable_gate_retry_remaining = 0.0
	reliable_gate_open_count = 0
	reliable_retry_count = 0
	curl_marks_last_hit = 0
	last_reliable_reason = "none"
	super.reset_trial()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["reliable_gate_contract"] = true
	data["reliable_gate_retries"] = reliable_retry_count
	data["reliable_gate_opens"] = reliable_gate_open_count
	data["curl_marks_last_hit"] = curl_marks_last_hit
	data["last_reliable_reason"] = last_reliable_reason
	data["reliable_checkpoint_radius"] = reliable_checkpoint_radius
	data["reliable_water_segments"] = reliable_minimum_water_segments
	data["reliable_runway_segments"] = reliable_minimum_runway_segments
	return data
