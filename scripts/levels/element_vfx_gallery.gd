extends Node3D
class_name ElementVfxGallery

@export var readout_refresh_interval: float = 0.08
@export var waterfall_event_interval: float = 0.55
@export var theater_motion_interval: float = 0.72

@onready var player: Node3D = get_node_or_null("Player") as Node3D

var impact_pool: FluidForceVolume
var motion_pool: FluidForceVolume
var theater_pool: FluidForceVolume
var waterfall: MeshInstance3D
var impact_readout: Label3D
var motion_readout: Label3D
var theater_readout: Label3D
var control_readout: Label3D
var element_bays: Array[Node3D] = []
var consoles: Dictionary = {}

var impact_exhibit: VfxGalleryExhibit
var motion_exhibit: VfxGalleryExhibit
var initial_player_transform: Transform3D
var initial_theater_flow: Vector3 = Vector3(2.4, 0.0, -0.35)
var intensity_levels: Array[float] = [0.55, 1.0, 1.75, 2.8]
var intensity_index: int = 1
var state_index: int = 0
var state_names: Array[String] = ["CALM", "STORM", "HOT", "ELECTRIFIED"]
var auto_replay_enabled: bool = true
var waterfall_enabled: bool = true
var slow_motion_enabled: bool = false
var waterfall_timer: float = 0.0
var theater_timer: float = 0.0
var readout_timer: float = 0.0
var preview_phase: float = 0.0
var theater_event_count: int = 0
var total_manual_triggers: int = 0


func _ready() -> void:
	add_to_group("element_vfx_gallery")
	add_to_group("debuggable")
	resolve_gallery(ElementVfxGalleryBuilder.build(self))
	build_exhibits()
	configure_player()
	apply_state_mode()
	set_auto_replay(true)
	GameState.set_objective("Explore the procedural Water wing and trigger each exhibit.")
	update_readouts()


func _process(delta: float) -> void:
	preview_phase += max(delta, 0.0)
	waterfall_timer -= max(delta, 0.0)
	theater_timer -= max(delta, 0.0)
	readout_timer -= max(delta, 0.0)

	if waterfall_enabled and waterfall_timer <= 0.0:
		waterfall_timer = max(waterfall_event_interval, 0.12)
		emit_waterfall_impact()
	if auto_replay_enabled and theater_timer <= 0.0:
		theater_timer = max(theater_motion_interval, 0.14)
		emit_theater_motion()
	if readout_timer <= 0.0:
		readout_timer = max(readout_refresh_interval, 0.03)
		update_readouts()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_gallery()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func resolve_gallery(data: Dictionary) -> void:
	impact_pool = data.get("impact_pool") as FluidForceVolume
	motion_pool = data.get("motion_pool") as FluidForceVolume
	theater_pool = data.get("theater_pool") as FluidForceVolume
	waterfall = data.get("waterfall") as MeshInstance3D
	impact_readout = data.get("impact_readout") as Label3D
	motion_readout = data.get("motion_readout") as Label3D
	theater_readout = data.get("theater_readout") as Label3D
	control_readout = data.get("control_readout") as Label3D
	consoles = data.get("consoles", {}) as Dictionary
	for node: Variant in data.get("element_bays", []):
		var bay := node as Node3D
		if bay != null:
			element_bays.append(bay)
	if theater_pool != null:
		initial_theater_flow = theater_pool.flow_velocity_m_s


func build_exhibits() -> void:
	impact_exhibit = VfxGalleryExhibit.new()
	impact_exhibit.name = "ImpactExhibit"
	impact_exhibit.auto_interval_seconds = 2.25
	impact_exhibit.configure(
		"water_impact",
		"water",
		"Water Impact",
		"Procedural rings and droplets generated from impact energy.",
		["ripple", "splash", "impact"],
		Color(0.16, 0.7, 1.0, 1.0),
		Callable(self, "trigger_water_exhibit")
	)
	add_child(impact_exhibit)

	motion_exhibit = VfxGalleryExhibit.new()
	motion_exhibit.name = "MotionExhibit"
	motion_exhibit.auto_interval_seconds = 1.2
	motion_exhibit.configure(
		"water_motion",
		"water",
		"Water Motion",
		"Directional wakes, churn, bubbles, and surface electricity.",
		["wake", "churn", "bubble", "electrical"],
		Color(0.08, 0.86, 1.0, 1.0),
		Callable(self, "trigger_water_exhibit")
	)
	add_child(motion_exhibit)


func configure_player() -> void:
	if player == null:
		push_warning("Element VFX Gallery could not find the player.")
		return
	player.add_to_group("player")
	initial_player_transform = player.transform
	GameState.set_stat("mana", 999)


func trigger_water_exhibit(exhibit: VfxGalleryExhibit, effect_kind: String, intensity: float) -> bool:
	if exhibit == null:
		return false
	var accepted: bool = false
	if exhibit == impact_exhibit:
		accepted = emit_impact_preview(effect_kind, intensity)
	elif exhibit == motion_exhibit:
		accepted = emit_motion_preview(effect_kind, intensity)
	if accepted and exhibit.auto_play:
		exhibit.cycle_kind()
	return accepted


func emit_impact_preview(effect_kind: String, intensity: float) -> bool:
	if impact_pool == null:
		return false
	var surface := Vector3(
		impact_pool.global_position.x + sin(preview_phase * 1.7) * 1.15,
		impact_pool.get_surface_y(),
		impact_pool.global_position.z + cos(preview_phase * 1.1) * 0.85
	)
	match effect_kind:
		"ripple":
			impact_pool.emit_disturbance(
				FluidDisturbanceEvent.KIND_RIPPLE,
				surface,
				Vector3.RIGHT,
				Vector3.ZERO,
				0.75 * intensity,
				0.5 * intensity,
				"gallery_ripple",
				["gallery", "water", "ripple"]
			)
		"splash":
			impact_pool.emit_disturbance(
				FluidDisturbanceEvent.KIND_ENTRY,
				surface,
				Vector3(0.35, 0.0, 0.7),
				Vector3(1.0, -4.2, 1.4) * intensity,
				1.35 * intensity,
				0.62 * intensity,
				"gallery_splash",
				["gallery", "water", "entry"]
			)
		"impact":
			impact_pool.emit_disturbance(
				FluidDisturbanceEvent.KIND_IMPACT,
				surface,
				Vector3.FORWARD,
				Vector3(0.0, -7.5, 0.0) * intensity,
				2.25 * intensity,
				0.82 * intensity,
				"gallery_heavy_impact",
				["gallery", "water", "impact", "heavy"]
			)
		_:
			return false
	return true


func emit_motion_preview(effect_kind: String, intensity: float) -> bool:
	if motion_pool == null:
		return false
	var direction: Vector3 = motion_pool.flow_velocity_m_s.normalized()
	if direction.length() <= 0.001:
		direction = Vector3.FORWARD
	var surface := Vector3(
		motion_pool.global_position.x + sin(preview_phase * 1.35) * 1.2,
		motion_pool.get_surface_y(),
		motion_pool.global_position.z + cos(preview_phase * 1.7) * 1.0
	)
	match effect_kind:
		"wake":
			motion_pool.emit_disturbance(
				FluidDisturbanceEvent.KIND_WAKE,
				surface,
				direction,
				direction * (3.4 * intensity),
				1.2 * intensity,
				0.72 * intensity,
				"gallery_wake",
				["gallery", "water", "wake"]
			)
		"churn":
			motion_pool.emit_disturbance(
				FluidDisturbanceEvent.KIND_CHURN,
				surface,
				direction,
				direction * (16.0 * intensity),
				1.65 * intensity,
				0.55 * intensity,
				"gallery_churn",
				["gallery", "water", "propeller", "churn"]
			)
		"bubble":
			motion_pool.emit_disturbance(
				FluidDisturbanceEvent.KIND_BUBBLE,
				Vector3(surface.x, surface.y - 0.65, surface.z),
				Vector3.UP,
				Vector3.UP * intensity,
				1.15 * intensity,
				0.48 * intensity,
				"gallery_bubble",
				["gallery", "water", "bubble"]
			)
		"electrical":
			motion_pool.set_visual_state(24.0, 1.0, 0.55)
			motion_pool.emit_disturbance(
				FluidDisturbanceEvent.KIND_ELECTRICAL,
				surface,
				direction,
				Vector3.ZERO,
				1.45 * intensity,
				0.9 * intensity,
				"gallery_electrical_surface",
				["gallery", "water", "electrical"]
			)
		_:
			return false
	return true


func emit_waterfall_impact() -> void:
	if theater_pool == null or not waterfall_enabled:
		return
	var position := Vector3(
		theater_pool.global_position.x + sin(preview_phase * 2.1) * 0.38,
		theater_pool.get_surface_y(),
		10.35 + cos(preview_phase * 1.4) * 0.18
	)
	theater_pool.emit_disturbance(
		FluidDisturbanceEvent.KIND_IMPACT,
		position,
		Vector3(0.0, 0.0, -1.0),
		Vector3(0.0, -8.0, -1.2),
		1.65 * get_intensity(),
		0.78 * get_intensity(),
		"gallery_waterfall",
		["gallery", "water", "waterfall", "continuous"]
	)
	theater_event_count += 1


func emit_theater_motion() -> void:
	if theater_pool == null:
		return
	var direction: Vector3 = theater_pool.flow_velocity_m_s.normalized()
	if direction.length() <= 0.001:
		direction = Vector3.RIGHT
	var position := Vector3(
		theater_pool.global_position.x + sin(preview_phase * 0.72) * 5.2,
		theater_pool.get_surface_y(),
		theater_pool.global_position.z + cos(preview_phase * 0.46) * 2.4
	)
	var kind: String = FluidDisturbanceEvent.KIND_WAKE if theater_event_count % 3 != 0 else FluidDisturbanceEvent.KIND_CHURN
	theater_pool.emit_disturbance(
		kind,
		position,
		direction,
		direction * (5.0 if kind == FluidDisturbanceEvent.KIND_WAKE else 13.0),
		1.0 * get_intensity(),
		0.7 * get_intensity(),
		"gallery_motion_loop",
		["gallery", "water", "motion", "automatic"]
	)
	theater_event_count += 1


func handle_gallery_action(action_id: String) -> Dictionary:
	var message: String = ""
	match action_id:
		"impact_trigger":
			if impact_exhibit != null and impact_exhibit.trigger_preview(get_intensity()):
				total_manual_triggers += 1
				message = "Impact preview: " + impact_exhibit.last_effect_kind.to_upper()
			else:
				message = "The impact exhibit did not respond."
		"impact_cycle":
			message = "Impact effect selected: " + impact_exhibit.cycle_kind().to_upper()
		"motion_trigger":
			if motion_exhibit != null and motion_exhibit.trigger_preview(get_intensity()):
				total_manual_triggers += 1
				message = "Motion preview: " + motion_exhibit.last_effect_kind.to_upper()
			else:
				message = "The motion exhibit did not respond."
		"motion_cycle":
			message = "Motion effect selected: " + motion_exhibit.cycle_kind().to_upper()
		"toggle_auto":
			set_auto_replay(not auto_replay_enabled)
			message = "Automatic replay " + ("enabled." if auto_replay_enabled else "paused.")
		"cycle_intensity":
			intensity_index = posmod(intensity_index + 1, intensity_levels.size())
			message = "Preview intensity: " + get_intensity_label()
		"reverse_flow":
			if theater_pool != null:
				theater_pool.flow_velocity_m_s *= -1.0
				theater_pool.refresh_presentation()
			message = "The theater current reverses direction."
		"cycle_state":
			state_index = posmod(state_index + 1, state_names.size())
			apply_state_mode()
			message = "Water visual state: " + get_state_name()
		"toggle_waterfall":
			waterfall_enabled = not waterfall_enabled
			if waterfall != null:
				waterfall.visible = waterfall_enabled
			message = "Waterfall " + ("enabled." if waterfall_enabled else "paused.")
		"toggle_slow_motion":
			slow_motion_enabled = not slow_motion_enabled
			Engine.time_scale = 0.35 if slow_motion_enabled else 1.0
			message = "Slow motion " + ("enabled." if slow_motion_enabled else "disabled.")
		"clear_effects":
			clear_active_effects()
			message = "Active procedural effects cleared."
		_:
			message = "Unknown gallery control: " + action_id
	update_readouts()
	return {
		"message": message,
		"objective": "Compare the generated effect at different intensities and water states.",
	}


func set_auto_replay(enabled: bool) -> void:
	auto_replay_enabled = enabled
	if impact_exhibit != null:
		impact_exhibit.set_auto_play(enabled)
	if motion_exhibit != null:
		motion_exhibit.set_auto_play(enabled)
	waterfall_timer = 0.0
	theater_timer = 0.0


func apply_state_mode() -> void:
	if theater_pool == null:
		return
	match get_state_name():
		"CALM":
			theater_pool.set_visual_state(20.0, 0.0, 0.12)
		"STORM":
			theater_pool.set_visual_state(20.0, 0.0, 0.92)
		"HOT":
			theater_pool.set_visual_state(125.0, 0.0, 0.52)
		"ELECTRIFIED":
			theater_pool.set_visual_state(24.0, 1.0, 0.62)


func clear_active_effects() -> void:
	for pool: FluidForceVolume in [impact_pool, motion_pool, theater_pool]:
		if pool != null and pool.presentation_renderer != null:
			pool.presentation_renderer.reset_target()


func reset_gallery() -> void:
	Engine.time_scale = 1.0
	slow_motion_enabled = false
	intensity_index = 1
	state_index = 0
	auto_replay_enabled = true
	waterfall_enabled = true
	preview_phase = 0.0
	waterfall_timer = 0.0
	theater_timer = 0.0
	readout_timer = 0.0
	theater_event_count = 0
	total_manual_triggers = 0
	if waterfall != null:
		waterfall.visible = true
	for pool: FluidForceVolume in [impact_pool, motion_pool, theater_pool]:
		if pool != null:
			pool.reset_target()
	if theater_pool != null:
		theater_pool.flow_velocity_m_s = initial_theater_flow
		theater_pool.refresh_presentation()
	if impact_exhibit != null:
		impact_exhibit.reset_target()
	if motion_exhibit != null:
		motion_exhibit.reset_target()
	apply_state_mode()
	set_auto_replay(true)
	if player != null:
		player.transform = initial_player_transform
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	GameState.set_stat("mana", 999)
	update_readouts()
	show_message("Element VFX Gallery reset.")


func get_intensity() -> float:
	if intensity_levels.is_empty():
		return 1.0
	intensity_index = posmod(intensity_index, intensity_levels.size())
	return intensity_levels[intensity_index]


func get_intensity_label() -> String:
	match intensity_index:
		0:
			return "SUBTLE"
		1:
			return "STANDARD"
		2:
			return "STRONG"
		_:
			return "EXTREME"


func get_state_name() -> String:
	if state_names.is_empty():
		return "CALM"
	state_index = posmod(state_index, state_names.size())
	return state_names[state_index]


func update_readouts() -> void:
	if impact_readout != null and impact_exhibit != null:
		impact_readout.text = (
			"IMPACT STAGE"
			+ "\nSELECTED: " + impact_exhibit.get_current_kind().to_upper()
			+ "  AUTO: " + ("ON" if impact_exhibit.auto_play else "OFF")
			+ "\nTRIGGERS: " + str(impact_exhibit.trigger_count)
			+ "  ACTIVE FX: " + str(get_active_effect_count(impact_pool))
		)
	if motion_readout != null and motion_exhibit != null:
		motion_readout.text = (
			"MOTION STAGE"
			+ "\nSELECTED: " + motion_exhibit.get_current_kind().to_upper()
			+ "  AUTO: " + ("ON" if motion_exhibit.auto_play else "OFF")
			+ "\nTRIGGERS: " + str(motion_exhibit.trigger_count)
			+ "  ACTIVE FX: " + str(get_active_effect_count(motion_pool))
		)
	if theater_readout != null and theater_pool != null:
		theater_readout.text = (
			"WATER MOTION THEATER"
			+ "\nSTATE: " + get_state_name()
			+ "  WATERFALL: " + ("ON" if waterfall_enabled else "OFF")
			+ "  CURRENT: " + str(theater_pool.flow_velocity_m_s)
			+ "\nEVENTS: " + str(theater_pool.disturbance_count)
			+ "  ACTIVE FX: " + str(get_active_effect_count(theater_pool))
		)
	if control_readout != null:
		control_readout.text = (
			"GALLERY CONTROLS"
			+ "\nAUTO: " + ("ON" if auto_replay_enabled else "OFF")
			+ "  INTENSITY: " + get_intensity_label()
			+ "  SLOW: " + ("ON" if slow_motion_enabled else "OFF")
			+ "\nMANUAL TRIGGERS: " + str(total_manual_triggers)
			+ "  ELEMENT BAYS: " + str(element_bays.size())
		)


func get_active_effect_count(pool: FluidForceVolume) -> int:
	if pool == null or pool.presentation_renderer == null:
		return 0
	pool.presentation_renderer.prune_effects()
	return pool.presentation_renderer.active_effects.size()


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"element_vfx_gallery": true,
		"auto_replay": auto_replay_enabled,
		"intensity": get_intensity(),
		"intensity_label": get_intensity_label(),
		"water_state": get_state_name(),
		"waterfall_enabled": waterfall_enabled,
		"slow_motion": slow_motion_enabled,
		"manual_triggers": total_manual_triggers,
		"element_bays": element_bays.size(),
		"impact_exhibit": impact_exhibit.get_debug_data() if impact_exhibit != null else {},
		"motion_exhibit": motion_exhibit.get_debug_data() if motion_exhibit != null else {},
		"impact_pool": impact_pool.get_debug_data() if impact_pool != null else {},
		"motion_pool": motion_pool.get_debug_data() if motion_pool != null else {},
		"theater_pool": theater_pool.get_debug_data() if theater_pool != null else {},
	}
