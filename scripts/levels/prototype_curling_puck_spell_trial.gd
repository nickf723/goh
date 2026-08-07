extends Node3D
class_name PrototypeCurlingPuckSpellTrial

signal curl_route_completed(cast_serial: int)
signal frozen_crossing_completed(cast_serial: int)
signal momentum_runway_completed(
	trail_serial: int,
	boulder_serial: int,
	supported_mass_kg: float
)
signal trial_completed
signal trial_reset

const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const PressurePlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
)
const WaterVolumeScript = preload(
	"res://scripts/water/swimming_water_volume.gd"
)

enum TrialStage {
	CURL_ROUTE,
	FROZEN_CROSSING,
	MOMENTUM_RUNWAY,
	MASTERY,
	COMPLETE,
}

@export var completion_flag: String = (
	"rime_rink_curling_puck_trial_complete"
)
@export_range(0.02, 0.5, 0.01) var evaluation_interval: float = 0.08
@export_range(0.4, 3.0, 0.05) var checkpoint_radius: float = 1.15
@export_range(1, 64, 1) var required_water_segments: int = 12
@export_range(1.0, 1000.0, 1.0) var required_plate_mass_kg: float = 120.0
@export var mana_regeneration_note: String = (
	"This development trial regenerates Mana between Curling Puck casts."
)

var environment_root: Node3D = null
var actors_root: Node3D = null
var player: CharacterBody3D = null
var initial_player_transform: Transform3D

var curl_gate: MechanismSlidingGate = null
var crossing_gate: MechanismSlidingGate = null
var momentum_gate: MechanismSlidingGate = null
var bridge_arrival_area: Area3D = null
var mastery_area: Area3D = null
var momentum_plate: PressurePlateSwitch = null
var water_volume: SwimmingWaterVolume = null

var curl_checkpoints: Array[Vector3] = [
	Vector3(0.0, 0.06, -0.2),
	Vector3(0.42, 0.06, 3.15),
	Vector3(1.30, 0.06, 6.75),
]
var stage: TrialStage = TrialStage.CURL_ROUTE
var evaluation_remaining: float = 0.0
var trial_complete: bool = false
var curl_serial_baseline: int = 0
var crossing_serial_baseline: int = 0
var momentum_puck_serial_baseline: int = 0
var momentum_boulder_serial_baseline: int = 0
var curl_success_serial: int = 0
var crossing_success_serial: int = 0
var momentum_success_trail_serial: int = 0
var momentum_success_boulder_serial: int = 0
var momentum_success_mass: float = 0.0
var curl_completion_count: int = 0
var crossing_completion_count: int = 0
var momentum_completion_count: int = 0

var floor_material: StandardMaterial3D = null
var wall_material: StandardMaterial3D = null
var ice_material: StandardMaterial3D = null
var water_material: StandardMaterial3D = null
var earth_material: StandardMaterial3D = null
var gold_material: StandardMaterial3D = null
var checkpoint_material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("rime_rink_spell_trial")
	add_to_group("curling_puck_spell_trial")
	add_to_group("spell_trials")
	add_to_group("lab_resource_regeneration")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as CharacterBody3D
	if player != null:
		initial_player_transform = player.transform
	_build_roots()
	_build_materials()
	_build_environment()
	_build_curl_route()
	_build_frozen_crossing()
	_build_momentum_runway()
	_build_mastery_landing()
	_restore_player_resources()
	_set_stage(TrialStage.CURL_ROUTE)
	set_process(true)
	_show_message(
		"Rime Rink: hold right while casting to curl through three marks, freeze a straight bridge across the pool, then lay an ice runway for Boulder. "
		+ mana_regeneration_note
	)
	call_deferred("_equip_spell", "curling_puck")


func _process(delta: float) -> void:
	evaluation_remaining -= maxf(delta, 0.0)
	if evaluation_remaining > 0.0:
		return
	evaluation_remaining = maxf(evaluation_interval, 0.02)
	if stage == TrialStage.CURL_ROUTE:
		_evaluate_curl_route()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		reset_trial()


func _build_roots() -> void:
	environment_root = Node3D.new()
	environment_root.name = "RimeRinkEnvironment"
	add_child(environment_root)
	actors_root = Node3D.new()
	actors_root.name = "RimeRinkActors"
	add_child(actors_root)


func _build_materials() -> void:
	floor_material = _make_material(
		Color(0.075, 0.105, 0.135, 1.0),
		0.16,
		0.82
	)
	wall_material = _make_material(
		Color(0.035, 0.055, 0.085, 1.0),
		0.28,
		0.68
	)
	ice_material = _make_emissive_material(
		Color(0.28, 0.68, 0.94, 0.78),
		Color(0.12, 0.52, 1.0),
		2.4,
		true
	)
	water_material = _make_emissive_material(
		Color(0.025, 0.22, 0.48, 0.72),
		Color(0.03, 0.34, 0.78),
		1.65,
		true
	)
	earth_material = _make_emissive_material(
		Color(0.42, 0.25, 0.085, 0.94),
		Color(0.92, 0.48, 0.08),
		2.45
	)
	gold_material = _make_emissive_material(
		Color(0.68, 0.48, 0.08, 0.94),
		Color(1.0, 0.78, 0.14),
		3.7
	)
	checkpoint_material = _make_emissive_material(
		Color(0.46, 0.84, 1.0, 0.88),
		Color(0.18, 0.68, 1.0),
		3.0,
		true
	)


func _build_environment() -> void:
	_create_static_box(
		"CurlRouteFloor",
		Vector3(0.0, -0.5, 2.0),
		Vector3(14.0, 1.0, 18.0),
		floor_material
	)
	_create_static_box(
		"NearPoolShore",
		Vector3(0.0, -0.5, 13.25),
		Vector3(14.0, 1.0, 5.5),
		floor_material
	)
	_create_static_box(
		"RinkPoolBottom",
		Vector3(0.0, -3.5, 23.0),
		Vector3(14.0, 1.0, 14.0),
		floor_material
	)
	_create_static_box(
		"FarPoolShore",
		Vector3(0.0, -0.5, 33.0),
		Vector3(14.0, 1.0, 6.0),
		floor_material
	)
	_create_static_box(
		"MomentumRunwayFloor",
		Vector3(0.0, -0.5, 49.0),
		Vector3(14.0, 1.0, 27.0),
		floor_material
	)
	_create_static_box(
		"MasteryFloor",
		Vector3(0.0, -0.5, 67.0),
		Vector3(14.0, 1.0, 10.0),
		floor_material
	)
	_create_static_box(
		"RimeRinkLeftWall",
		Vector3(-7.5, 2.5, 32.0),
		Vector3(1.0, 6.0, 80.0),
		wall_material
	)
	_create_static_box(
		"RimeRinkRightWall",
		Vector3(7.5, 2.5, 32.0),
		Vector3(1.0, 6.0, 80.0),
		wall_material
	)
	_create_static_box(
		"RimeRinkBackWall",
		Vector3(0.0, 2.5, -8.0),
		Vector3(14.0, 6.0, 1.0),
		wall_material
	)
	_create_static_box(
		"RimeRinkFrontWall",
		Vector3(0.0, 2.5, 72.5),
		Vector3(14.0, 6.0, 1.0),
		wall_material
	)

	_create_label(
		"THE RIME RINK",
		Vector3(0.0, 5.0, -5.6),
		Color(0.66, 0.88, 1.0),
		34
	)
	_create_label(
		"One puck writes the route. Everything else inherits it.",
		Vector3(0.0, 3.95, -3.4),
		Color(0.72, 0.84, 0.96),
		20
	)
	_create_label(
		"I • THE CURLING LINE",
		Vector3(0.0, 4.15, -0.8),
		Color(0.48, 0.82, 1.0),
		27
	)
	_create_label(
		"II • THE FROZEN CROSSING",
		Vector3(0.0, 4.15, 12.3),
		Color(0.48, 0.82, 1.0),
		27
	)
	_create_label(
		"III • THE LONG SLIDE",
		Vector3(0.0, 4.15, 38.0),
		Color(0.48, 0.82, 1.0),
		27
	)


func _build_curl_route() -> void:
	_create_visual_box(
		"CurlCastingMark",
		Vector3(0.0, 0.06, -4.5),
		Vector3(3.0, 0.12, 1.35),
		ice_material
	)
	for checkpoint_index: int in range(curl_checkpoints.size()):
		_create_floor_disc(
			"CurlCheckpoint" + str(checkpoint_index + 1),
			curl_checkpoints[checkpoint_index],
			0.72,
			checkpoint_material
		)
		_create_label(
			"CURL " + str(checkpoint_index + 1),
			curl_checkpoints[checkpoint_index] + Vector3.UP * 1.25,
			Color(0.72, 0.92, 1.0),
			14
		)
	_create_label(
		"HOLD RIGHT WHILE CASTING • ONE TRAIL • THREE MARKS",
		Vector3(0.6, 3.0, 7.8),
		Color(0.74, 0.9, 1.0),
		17
	)
	curl_gate = _spawn_gate_with_dividers(
		"CurlRouteGate",
		"Curl Route Gate",
		Vector3(0.0, 0.0, 10.5)
	)


func _build_frozen_crossing() -> void:
	water_volume = WaterVolumeScript.new() as SwimmingWaterVolume
	water_volume.name = "FreezableRinkPool"
	water_volume.position = Vector3(0.0, -1.5, 23.0)
	water_volume.surface_height_offset = 1.5
	water_volume.water_label = "Rime Rink Pool"
	var water_collision := CollisionShape3D.new()
	var water_shape := BoxShape3D.new()
	water_shape.size = Vector3(12.5, 3.0, 14.0)
	water_collision.shape = water_shape
	water_volume.add_child(water_collision)
	actors_root.add_child(water_volume)

	_create_visual_box(
		"RinkPoolSurface",
		Vector3(0.0, -0.03, 23.0),
		Vector3(12.5, 0.06, 14.0),
		water_material
	)
	_create_visual_box(
		"CrossingCastingMark",
		Vector3(0.0, 0.06, 13.8),
		Vector3(3.0, 0.12, 1.35),
		ice_material
	)
	_create_label(
		"NEUTRAL CAST GOES STRAIGHT • FOLLOW THE ICE BEFORE IT MELTS",
		Vector3(0.0, 3.0, 27.5),
		Color(0.74, 0.9, 1.0),
		17
	)
	bridge_arrival_area = _create_trigger_area(
		"FrozenCrossingArrival",
		Vector3(0.0, 1.0, 32.4),
		Vector3(8.0, 2.5, 2.6)
	)
	bridge_arrival_area.body_entered.connect(
		_on_bridge_arrival_entered
	)
	crossing_gate = _spawn_gate_with_dividers(
		"FrozenCrossingGate",
		"Frozen Crossing Gate",
		Vector3(0.0, 0.0, 35.5)
	)


func _build_momentum_runway() -> void:
	_create_visual_box(
		"MomentumIceMark",
		Vector3(-1.7, 0.06, 39.0),
		Vector3(2.5, 0.12, 1.35),
		ice_material
	)
	_create_visual_box(
		"MomentumBoulderMark",
		Vector3(1.7, 0.06, 39.0),
		Vector3(2.5, 0.12, 1.35),
		earth_material
	)
	_create_label(
		"PUCK FIRST • BOULDER SECOND • THE ICE MUST CARRY 160 KG",
		Vector3(0.0, 3.0, 52.0),
		Color(0.78, 0.9, 1.0),
		17
	)
	momentum_plate = (
		PressurePlateScene.instantiate() as PressurePlateSwitch
	)
	momentum_plate.name = "CurlingMomentumPlate"
	momentum_plate.position = Vector3(0.0, 0.0, 56.5)
	momentum_plate.display_name = "120 kg Ice Momentum Plate"
	momentum_plate.accept_any_physics_body = true
	momentum_plate.default_non_rigid_body_mass_kg = 70.0
	momentum_plate.maximum_reported_mass_kg = 220.0
	momentum_plate.show_weight_in_label = true
	actors_root.add_child(momentum_plate)
	momentum_plate.mechanism_value_changed.connect(
		_on_momentum_plate_value_changed
	)
	momentum_gate = _spawn_gate_with_dividers(
		"MomentumRunwayGate",
		"Momentum Runway Gate",
		Vector3(0.0, 0.0, 62.0)
	)


func _build_mastery_landing() -> void:
	mastery_area = _create_trigger_area(
		"CurlingPuckMasteryArea",
		Vector3(0.0, 1.0, 68.0),
		Vector3(7.0, 2.6, 4.0)
	)
	mastery_area.body_entered.connect(_on_mastery_area_entered)
	_create_visual_box(
		"CurlingPuckMasterySeal",
		Vector3(0.0, 0.06, 68.0),
		Vector3(5.2, 0.14, 3.2),
		gold_material
	)
	_create_label(
		"CURL • FREEZE • CARRY MOMENTUM",
		Vector3(0.0, 3.8, 69.6),
		Color(1.0, 0.84, 0.28),
		25
	)


func _evaluate_curl_route() -> void:
	if player == null:
		return
	for trail: Node in get_tree().get_nodes_in_group("curling_ice_trails"):
		if not _is_fresh_player_trail(trail, curl_serial_baseline):
			continue
		var serial: int = int(trail.get("cast_serial"))
		var curl_sign_value: float = float(
			player.get_meta("curling_puck_last_curl_sign", 0.0)
		)
		if curl_sign_value < 0.5:
			continue
		var positions: Array[Vector3] = _get_trail_positions(trail)
		if positions.is_empty():
			continue
		var all_marks_reached: bool = true
		for checkpoint: Vector3 in curl_checkpoints:
			if not _trail_reaches_checkpoint(positions, checkpoint):
				all_marks_reached = false
				break
		if not all_marks_reached:
			continue
		curl_success_serial = serial
		curl_completion_count += 1
		curl_gate.set_gate_open(
			true,
			false,
			{"reason": "curl_route_complete"}
		)
		_set_stage(TrialStage.FROZEN_CROSSING)
		curl_route_completed.emit(serial)
		_show_message(
			"The right-hand curl threads all three marks. The next route has no floor, so write one across the water."
		)
		call_deferred("_clear_curling_effects")
		return


func _on_bridge_arrival_entered(body: Node) -> void:
	if body != player or stage != TrialStage.FROZEN_CROSSING:
		return
	var qualifying_trail: Node = _find_fresh_water_trail(
		crossing_serial_baseline
	)
	if qualifying_trail == null:
		_show_message(
			"The crossing requires one fresh Curling Puck trail with at least "
			+ str(required_water_segments)
			+ " frozen water segments."
		)
		return
	var swimming_controller: Node = player.get_node_or_null(
		"SwimmingController"
	)
	if (
		swimming_controller != null
		and bool(swimming_controller.get("swimming"))
	):
		_show_message(
			"Grace reached the far side through the water, not across the frozen path."
		)
		return
	crossing_success_serial = int(qualifying_trail.get("cast_serial"))
	crossing_completion_count += 1
	crossing_gate.set_gate_open(
		true,
		false,
		{"reason": "frozen_crossing_complete"}
	)
	_set_stage(TrialStage.MOMENTUM_RUNWAY)
	frozen_crossing_completed.emit(crossing_success_serial)
	_show_message(
		"The pool holds a temporary road. Now draw a straight ice runway, switch to Boulder, and let low traction preserve its momentum."
	)
	call_deferred("_clear_curling_effects")


func _on_momentum_plate_value_changed(
	value: float,
	packet: Dictionary
) -> void:
	if stage != TrialStage.MOMENTUM_RUNWAY:
		return
	if value < required_plate_mass_kg:
		return
	var boulder: Node = _find_boulder_from_mass_packet(packet)
	if boulder == null:
		return
	var boulder_serial: int = int(
		boulder.get_meta("boulder_cast_serial", 0)
	)
	if boulder_serial <= momentum_boulder_serial_baseline:
		return
	var trail_serial: int = int(
		boulder.get_meta("ice_curl_last_trail_serial_contact", 0)
	)
	if trail_serial <= momentum_puck_serial_baseline:
		return
	var trail: Node = _find_player_trail_by_serial(trail_serial)
	if trail == null:
		return
	var trail_debug: Dictionary = trail.call("get_debug_data") as Dictionary
	if int(trail_debug.get("ground_segments", 0)) < 10:
		return

	momentum_success_trail_serial = trail_serial
	momentum_success_boulder_serial = boulder_serial
	momentum_success_mass = value
	momentum_completion_count += 1
	momentum_gate.set_gate_open(
		true,
		false,
		{"reason": "ice_carried_boulder"}
	)
	_set_stage(TrialStage.MASTERY)
	momentum_runway_completed.emit(
		trail_serial,
		boulder_serial,
		value
	)
	_show_message(
		"The Boulder crossed the 120 kg plate after touching the puck's ice. The trail changed another spell's physics instead of dealing the answer itself."
	)


func _on_mastery_area_entered(body: Node) -> void:
	if body != player or stage != TrialStage.MASTERY:
		return
	trial_complete = true
	GameState.set_flag(completion_flag, true)
	_set_stage(TrialStage.COMPLETE)
	trial_completed.emit()
	_show_message(
		"Curling Puck mastered: CURL • FREEZE • CARRY MOMENTUM."
	)


func _set_stage(next_stage: TrialStage) -> void:
	stage = next_stage
	match stage:
		TrialStage.CURL_ROUTE:
			curl_serial_baseline = _get_player_serial(
				"curling_puck_cast_serial"
			)
			_set_objective(
				"Curling Puck: hold right while casting and pass one trail through all three curling marks."
			)
		TrialStage.FROZEN_CROSSING:
			crossing_serial_baseline = _get_player_serial(
				"curling_puck_cast_serial"
			)
			_set_objective(
				"Curling Puck: cast straight across the pool, then cross the temporary ice bridge."
			)
		TrialStage.MOMENTUM_RUNWAY:
			momentum_puck_serial_baseline = _get_player_serial(
				"curling_puck_cast_serial"
			)
			momentum_boulder_serial_baseline = _get_player_serial(
				"boulder_cast_serial"
			)
			_set_objective(
				"Curling Puck + Boulder: lay a straight ice runway, switch spells, and roll a fresh Boulder onto the 120 kg plate."
			)
		TrialStage.MASTERY:
			_set_objective(
				"Curling Puck: cross the open gate and enter the gold mastery seal."
			)
		TrialStage.COMPLETE:
			_set_objective(
				"Rime Rink complete: CURL • FREEZE • CARRY MOMENTUM."
			)


func _get_player_serial(meta_key: String) -> int:
	return (
		int(player.get_meta(meta_key, 0))
		if player != null
		else 0
	)


func _is_fresh_player_trail(trail: Node, baseline: int) -> bool:
	if (
		trail == null
		or not is_instance_valid(trail)
		or trail.is_queued_for_deletion()
		or not trail.has_method("belongs_to_source")
		or not bool(trail.call("belongs_to_source", player))
	):
		return false
	return int(trail.get("cast_serial")) > baseline


func _get_trail_positions(trail: Node) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if trail == null or not trail.has_method("get_segment_positions"):
		return positions
	var value: Variant = trail.call("get_segment_positions")
	if not value is Array:
		return positions
	for raw_position: Variant in value as Array:
		if raw_position is Vector3:
			positions.append(raw_position as Vector3)
	return positions


func _trail_reaches_checkpoint(
	positions: Array[Vector3],
	checkpoint: Vector3
) -> bool:
	for position_value: Vector3 in positions:
		var planar_distance: float = Vector2(
			position_value.x - checkpoint.x,
			position_value.z - checkpoint.z
		).length()
		if planar_distance <= checkpoint_radius:
			return true
	return false


func _find_fresh_water_trail(baseline: int) -> Node:
	var best: Node = null
	var best_serial: int = baseline
	for trail: Node in get_tree().get_nodes_in_group("curling_ice_trails"):
		if not _is_fresh_player_trail(trail, baseline):
			continue
		var debug: Dictionary = trail.call("get_debug_data") as Dictionary
		if int(debug.get("water_segments", 0)) < required_water_segments:
			continue
		var serial: int = int(trail.get("cast_serial"))
		if serial > best_serial:
			best = trail
			best_serial = serial
	return best


func _find_player_trail_by_serial(serial: int) -> Node:
	for trail: Node in get_tree().get_nodes_in_group("curling_ice_trails"):
		if (
			trail != null
			and is_instance_valid(trail)
			and not trail.is_queued_for_deletion()
			and int(trail.get("cast_serial")) == serial
			and trail.has_method("belongs_to_source")
			and bool(trail.call("belongs_to_source", player))
		):
			return trail
	return null


func _find_boulder_from_mass_packet(packet: Dictionary) -> Node:
	var rows_value: Variant = packet.get("body_masses", [])
	if not rows_value is Array:
		return null
	for row_value: Variant in rows_value as Array:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		var body_name: String = str(row.get("name", ""))
		for candidate: Node in get_tree().get_nodes_in_group(
			"earth_boulder_effects"
		):
			if (
				candidate != null
				and is_instance_valid(candidate)
				and not candidate.is_queued_for_deletion()
				and str(candidate.name) == body_name
			):
				return candidate
	return null


func _equip_spell(spell_id: String) -> void:
	if player == null:
		return
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null or not caster.has_method("select_ability"):
		return
	var loadout_value: Variant = caster.get("loadout")
	if not loadout_value is AbilityLoadout:
		return
	var loadout: AbilityLoadout = loadout_value as AbilityLoadout
	for ability_index: int in range(loadout.get_equipped_ability_count()):
		var ability: AbilityDefinition = loadout.get_equipped_ability(
			ability_index
		)
		if ability != null and ability.get_spell_id() == spell_id:
			caster.call("select_ability", ability_index, false)
			return


func reset_trial() -> void:
	trial_complete = false
	curl_success_serial = 0
	crossing_success_serial = 0
	momentum_success_trail_serial = 0
	momentum_success_boulder_serial = 0
	momentum_success_mass = 0.0
	curl_completion_count = 0
	crossing_completion_count = 0
	momentum_completion_count = 0
	GameState.set_flag(completion_flag, false)
	_clear_curling_effects()
	_clear_boulders()
	if player != null:
		var swimming_controller: Node = player.get_node_or_null(
			"SwimmingController"
		)
		if (
			swimming_controller != null
			and swimming_controller.has_method("reset_swimming")
		):
			swimming_controller.call("reset_swimming")
		player.transform = initial_player_transform
		player.velocity = Vector3.ZERO
		player.set_meta("curling_puck_cast_serial", 0)
		player.set_meta("boulder_cast_serial", 0)
		player.remove_meta("curling_puck_last_curl_sign")
		player.remove_meta("boulder_last_spawn_position")
	if curl_gate != null:
		curl_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if crossing_gate != null:
		crossing_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if momentum_gate != null:
		momentum_gate.set_gate_open(false, true, {"reason": "trial_reset"})
	if momentum_plate != null:
		momentum_plate.reset_target()
	_restore_player_resources()
	_set_stage(TrialStage.CURL_ROUTE)
	call_deferred("_equip_spell", "curling_puck")
	trial_reset.emit()


func _clear_curling_effects() -> void:
	for puck: Node in get_tree().get_nodes_in_group("curling_puck_effects"):
		if puck == null or not is_instance_valid(puck):
			continue
		if puck.has_method("force_dissipate"):
			puck.call("force_dissipate", "trial_stage_cleanup")
		else:
			puck.queue_free()
	for trail: Node in get_tree().get_nodes_in_group("curling_ice_trails"):
		if trail == null or not is_instance_valid(trail):
			continue
		if trail.has_method("force_dissipate"):
			trail.call("force_dissipate", "trial_stage_cleanup")
		else:
			trail.queue_free()


func _clear_boulders() -> void:
	for boulder: Node in get_tree().get_nodes_in_group(
		"earth_boulder_effects"
	):
		if boulder == null or not is_instance_valid(boulder):
			continue
		if boulder.has_method("reset_target"):
			boulder.call("reset_target")
		else:
			boulder.queue_free()


func _restore_player_resources() -> void:
	GameState.set_stat("health", GameState.get_stat("max_health"))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	GameState.set_stat("stamina", GameState.get_stat("max_stamina"))
	GameState.set_stat("stance", GameState.get_stat("max_stance"))


func _spawn_gate_with_dividers(
	node_name: String,
	display_name_value: String,
	position_value: Vector3
) -> MechanismSlidingGate:
	var gate: MechanismSlidingGate = (
		GateScene.instantiate() as MechanismSlidingGate
	)
	gate.name = node_name
	gate.display_name = display_name_value
	gate.position = position_value
	gate.scale = Vector3(1.3, 1.0, 1.0)
	gate.open_offset = Vector3(0.0, 4.5, 0.0)
	gate.transition_seconds = 0.45
	actors_root.add_child(gate)
	var state_label: Label3D = gate.get_node_or_null(
		"StateLabel"
	) as Label3D
	if state_label != null:
		state_label.visible = false
	_create_static_box(
		node_name + "LeftDivider",
		Vector3(-4.7, 2.2, position_value.z),
		Vector3(5.0, 5.4, 0.8),
		wall_material
	)
	_create_static_box(
		node_name + "RightDivider",
		Vector3(4.7, 2.2, position_value.z),
		Vector3(5.0, 5.4, 0.8),
		wall_material
	)
	return gate


func _create_trigger_area(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3
) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = position_value
	area.collision_layer = 0
	area.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	area.add_child(collision)
	actors_root.add_child(area)
	return area


func _create_static_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	environment_root.add_child(body)
	return body


func _create_visual_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	material: Material
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = material
	environment_root.add_child(visual)
	return visual


func _create_floor_disc(
	node_name: String,
	position_value: Vector3,
	radius: float,
	material: Material
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.08
	mesh.radial_segments = 24
	visual.mesh = mesh
	visual.material_override = material
	environment_root.add_child(visual)
	return visual


func _create_label(
	text_value: String,
	position_value: Vector3,
	color: Color,
	font_size_value: int
) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.modulate = color
	label.font_size = font_size_value
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.visibility_range_end = 54.0
	label.visibility_range_end_margin = 4.0
	environment_root.add_child(label)
	return label


func _make_material(
	color: Color,
	metallic_value: float,
	roughness_value: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic_value
	material.roughness = roughness_value
	return material


func _make_emissive_material(
	color: Color,
	emission_color: Color,
	emission_energy: float,
	transparent: bool = false
) -> StandardMaterial3D:
	var material: StandardMaterial3D = _make_material(
		color,
		0.2,
		0.42
	)
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = emission_energy
	return material


func _set_objective(text_value: String) -> void:
	if GameState.has_method("set_objective"):
		GameState.call("set_objective", text_value)
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("set_objective"):
		ui.call("set_objective", text_value)
	elif ui != null and ui.has_method("set_objective_text"):
		ui.call("set_objective_text", text_value)


func _show_message(text_value: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text_value)
	else:
		print(text_value)


func get_debug_data() -> Dictionary:
	return {
		"curling_puck_trial": true,
		"stage": TrialStage.keys()[stage].to_lower(),
		"trial_complete": trial_complete,
		"curl_serial_baseline": curl_serial_baseline,
		"crossing_serial_baseline": crossing_serial_baseline,
		"momentum_puck_serial_baseline": momentum_puck_serial_baseline,
		"momentum_boulder_serial_baseline": momentum_boulder_serial_baseline,
		"curl_success_serial": curl_success_serial,
		"crossing_success_serial": crossing_success_serial,
		"momentum_success_trail_serial": momentum_success_trail_serial,
		"momentum_success_boulder_serial": momentum_success_boulder_serial,
		"momentum_success_mass": momentum_success_mass,
		"curl_completions": curl_completion_count,
		"crossing_completions": crossing_completion_count,
		"momentum_completions": momentum_completion_count,
		"active_pucks": get_tree().get_node_count_in_group(
			"curling_puck_effects"
		),
		"active_ice_trails": get_tree().get_node_count_in_group(
			"curling_ice_trails"
		),
		"active_boulders": get_tree().get_node_count_in_group(
			"earth_boulder_effects"
		),
		"plate_mass": (
			momentum_plate.get_mechanism_value()
			if momentum_plate != null
			else 0.0
		),
		"completion_flag": GameState.get_flag(completion_flag),
	}
