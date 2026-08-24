extends Node3D
class_name PrototypeGoldenMeadowBenchmarkV1

const PlayableSpaceScript = preload(
	"res://scripts/quality/playable_space_3d.gd"
)
const RecoveryVolumeScript = preload(
	"res://scripts/quality/playable_recovery_volume_3d.gd"
)
const GRACE_GROUND_CLEARANCE: float = 0.12
const GRACE_PENETRATION_TOLERANCE: float = 0.035
const GRACE_RECOVERY_CLEARANCE: float = 0.08
const GRACE_GROUND_RAY_RISE: float = 5.0
const GRACE_GROUND_RAY_DROP: float = 4.0
const BENCHMARK_HUD_NODE_NAMES: Array[StringName] = [
	&"DivineSpecialHUD",
	&"PlayerHUDV2",
	&"QuickItemBeltUI",
	&"GameplayEffectStatusHUD",
	&"WeaponMasteryHUD",
	&"QuickSpellBeltPresentation",
]

var field_surface: MeadowFieldSurface
var style_environment: Environment
var style_sky_material: ProceduralSkyMaterial
var playable_space: PlayableSpace3D
var pollen_motes: GPUParticles3D
var hud_suppression_frames_remaining: int = 12
var benchmark_hud_hidden: bool = false
var grace_ground_snap_complete: bool = false
var grace_spawn_surface_y: float = 0.0
var grace_spawn_clearance: float = 0.0
var grace_ground_recovery_count: int = 0


func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	GameState.reset_run()
	add_to_group("golden_meadow_benchmark")
	add_to_group("debuggable")
	set_meta("benchmark_id", "golden_meadow_v1")
	set_meta("intended_read", "quiet_vibrant_global_adventure")
	set_meta("gameplay_clutter_free", true)

	field_surface = $GoldenMeadowSurface as MeadowFieldSurface
	_configure_environment()
	_place_grace()
	_prepare_benchmark_grace()
	_build_playable_space()
	_build_pollen_motes()
	call_deferred("_stabilize_grace_spawn")


func _process(_delta: float) -> void:
	if hud_suppression_frames_remaining <= 0:
		return
	hud_suppression_frames_remaining -= 1
	_hide_benchmark_hud()


func _physics_process(_delta: float) -> void:
	_recover_grace_from_terrain_penetration()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func _configure_environment() -> void:
	var environment_node: WorldEnvironment = $WorldEnvironment
	style_environment = Environment.new()
	style_sky_material = ProceduralSkyMaterial.new()
	style_sky_material.sky_top_color = Color(
		0.075,
		0.19,
		0.39,
		1.0
	)
	style_sky_material.sky_horizon_color = Color(
		0.58,
		0.49,
		0.38,
		1.0
	)
	style_sky_material.ground_horizon_color = Color(
		0.22,
		0.31,
		0.22,
		1.0
	)
	style_sky_material.ground_bottom_color = Color(
		0.045,
		0.075,
		0.05,
		1.0
	)
	style_sky_material.sky_curve = 0.19
	style_sky_material.ground_curve = 0.16
	style_sky_material.sky_energy_multiplier = 0.9
	style_sky_material.ground_energy_multiplier = 0.7
	style_sky_material.sun_angle_max = 7.5
	style_sky_material.sun_curve = 0.08

	var sky := Sky.new()
	sky.sky_material = style_sky_material
	style_environment.background_mode = Environment.BG_SKY
	style_environment.sky = sky
	style_environment.background_energy_multiplier = 0.9
	style_environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_SKY
	)
	style_environment.ambient_light_sky_contribution = 1.0
	style_environment.ambient_light_energy = 0.88
	style_environment.reflected_light_source = (
		Environment.REFLECTION_SOURCE_SKY
	)
	style_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	style_environment.tonemap_exposure = 1.04
	style_environment.adjustment_enabled = true
	style_environment.adjustment_brightness = 1.025
	style_environment.adjustment_contrast = 1.055
	style_environment.adjustment_saturation = 1.11
	style_environment.ssao_enabled = true
	style_environment.ssao_radius = 1.65
	style_environment.ssao_intensity = 1.18
	style_environment.ssao_power = 1.12
	style_environment.fog_enabled = true
	style_environment.fog_light_color = Color(
		0.61,
		0.65,
		0.61,
		1.0
	)
	style_environment.fog_light_energy = 0.68
	style_environment.fog_density = 0.0038
	style_environment.fog_height = 4.0
	style_environment.fog_height_density = 0.045
	style_environment.fog_sky_affect = 0.68
	style_environment.volumetric_fog_enabled = true
	style_environment.volumetric_fog_density = 0.012
	style_environment.volumetric_fog_length = 132.0
	style_environment.volumetric_fog_albedo = Color(
		0.68,
		0.70,
		0.59,
		1.0
	)
	style_environment.volumetric_fog_emission = Color(
		0.055,
		0.07,
		0.085,
		1.0
	)
	style_environment.volumetric_fog_emission_energy = 0.24
	style_environment.volumetric_fog_anisotropy = 0.54
	environment_node.environment = style_environment

	var sun: DirectionalLight3D = $GoldenSun
	sun.light_color = Color(1.0, 0.83, 0.62, 1.0)
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 145.0
	sun.directional_shadow_fade_start = 0.82
	sun.light_volumetric_fog_energy = 1.15

	var fill: DirectionalLight3D = $CoolSkyFill
	fill.light_color = Color(0.42, 0.58, 0.83, 1.0)
	fill.light_energy = 0.34
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.18


func _place_grace() -> void:
	var player: CharacterBody3D = $Player as CharacterBody3D
	if player == null or field_surface == null:
		return
	player.position = field_surface.get_spawn_position()
	player.rotation_degrees = Vector3.ZERO
	player.velocity = Vector3.ZERO


func _get_player_collision_half_height(
	player: CharacterBody3D
) -> float:
	if player == null:
		return 0.96
	var collision: CollisionShape3D = player.get_node_or_null(
		"CollisionShape3D"
	) as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		return (collision.shape as CapsuleShape3D).height * 0.5
	return maxf(
		float(player.get_meta("player_collision_height", 1.92)) * 0.5,
		0.46
	)


func _stabilize_grace_spawn() -> void:
	await get_tree().physics_frame
	var player: CharacterBody3D = $Player as CharacterBody3D
	if player == null or field_surface == null:
		return
	var ground_local: Vector3 = (
		field_surface.get_spawn_ground_position()
	)
	var ground_world: Vector3 = field_surface.to_global(ground_local)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = ground_world + Vector3.UP * GRACE_GROUND_RAY_RISE
	query.to = ground_world + Vector3.DOWN * GRACE_GROUND_RAY_DROP
	query.collision_mask = player.collision_mask
	query.collide_with_areas = false
	var exclusions: Array[RID] = [player.get_rid()]
	query.exclude = exclusions
	var hit: Dictionary = (
		get_world_3d().direct_space_state.intersect_ray(query)
	)
	var surface_position: Vector3 = ground_world
	var hit_position: Variant = hit.get("position", null)
	if hit_position is Vector3:
		surface_position = hit_position as Vector3
	var half_height: float = _get_player_collision_half_height(player)
	player.global_position = (
		surface_position
		+ Vector3.UP * (half_height + GRACE_GROUND_CLEARANCE)
	)
	player.velocity = Vector3.ZERO
	grace_spawn_surface_y = surface_position.y
	grace_spawn_clearance = GRACE_GROUND_CLEARANCE
	grace_ground_snap_complete = true

	var recovery: Node = player.get_node_or_null("RecoveryController")
	if (
		recovery != null
		and recovery.has_method("set_manual_recovery_transform")
	):
		recovery.call(
			"set_manual_recovery_transform",
			player.global_transform
		)


func _recover_grace_from_terrain_penetration() -> void:
	if not grace_ground_snap_complete or field_surface == null:
		return
	var player: CharacterBody3D = $Player as CharacterBody3D
	if player == null:
		return
	var local_player: Vector3 = field_surface.to_local(
		player.global_position
	)
	var ground_y: float = field_surface.get_height(
		local_player.x,
		local_player.z
	)
	var half_height: float = _get_player_collision_half_height(player)
	var foot_y: float = local_player.y - half_height
	if foot_y >= ground_y - GRACE_PENETRATION_TOLERANCE:
		return
	local_player.y += (
		ground_y
		- foot_y
		+ GRACE_RECOVERY_CLEARANCE
	)
	player.global_position = field_surface.to_global(local_player)
	player.velocity.y = 0.0
	player.set_meta("benchmark_free_roam", true)
	grace_ground_recovery_count += 1


func _prepare_benchmark_grace() -> void:
	var player: CharacterBody3D = $Player as CharacterBody3D
	if player == null:
		return
	player.set_meta("benchmark_presentation_mode", true)
	player.set_meta("benchmark_free_roam", true)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.set_physics_process(true)
	player.set("is_defeated", false)
	player.remove_meta("shared_placement_active")
	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null:
		if action_state.has_method("set_defeated"):
			action_state.call("set_defeated", false)
		if action_state.has_method("clear_action_locks"):
			action_state.call("clear_action_locks")
	hud_suppression_frames_remaining = 12
	_hide_benchmark_hud()


func _hide_benchmark_hud() -> void:
	var player: Node = get_node_or_null("Player")
	if player == null:
		benchmark_hud_hidden = false
		return
	benchmark_hud_hidden = true
	for hud_name: StringName in BENCHMARK_HUD_NODE_NAMES:
		var hud: Node = player.get_node_or_null(NodePath(str(hud_name)))
		if hud == null:
			continue
		if hud is CanvasLayer:
			(hud as CanvasLayer).visible = false
		elif hud is CanvasItem:
			(hud as CanvasItem).visible = false
		hud.process_mode = Node.PROCESS_MODE_DISABLED
		if (
			(hud is CanvasLayer and (hud as CanvasLayer).visible)
			or (hud is CanvasItem and (hud as CanvasItem).visible)
		):
			benchmark_hud_hidden = false


func _build_playable_space() -> void:
	if field_surface == null:
		return
	playable_space = PlayableSpaceScript.new() as PlayableSpace3D
	playable_space.name = "PlayableSpace"
	playable_space.use_bounds = true
	playable_space.bounds_center = Vector3(0.0, 4.0, 0.0)
	playable_space.bounds_size = Vector3(
		field_surface.field_width - 8.0,
		22.0,
		field_surface.field_depth - 10.0
	)
	playable_space.minimum_recovery_y = -5.0
	playable_space.generate_boundary_collision = true
	playable_space.boundary_thickness = 1.0
	playable_space.boundary_height = 18.0

	var anchor := Marker3D.new()
	anchor.name = "DefaultRecoveryAnchor"
	anchor.position = field_surface.get_spawn_position()
	playable_space.add_child(anchor)
	playable_space.default_recovery_path = NodePath(
		"DefaultRecoveryAnchor"
	)
	add_child(playable_space)

	var recovery_volume := Area3D.new()
	recovery_volume.name = "MeadowRecoveryVolume"
	recovery_volume.position = Vector3(0.0, -7.5, 0.0)
	recovery_volume.set_script(RecoveryVolumeScript)
	recovery_volume.set(
		"recovery_reason",
		"wandered beyond the golden meadow"
	)
	var collision := CollisionShape3D.new()
	collision.name = "RecoveryShape"
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		field_surface.field_width + 18.0,
		5.0,
		field_surface.field_depth + 18.0
	)
	collision.shape = shape
	recovery_volume.add_child(collision)
	playable_space.add_child(recovery_volume)


func _build_pollen_motes() -> void:
	pollen_motes = GPUParticles3D.new()
	pollen_motes.name = "GoldenPollenMotes"
	pollen_motes.amount = 150
	pollen_motes.lifetime = 9.0
	pollen_motes.randomness = 0.92
	pollen_motes.preprocess = 9.0
	pollen_motes.visibility_aabb = AABB(
		Vector3(-45.0, -1.0, -60.0),
		Vector3(90.0, 12.0, 120.0)
	)

	var process := ParticleProcessMaterial.new()
	process.emission_shape = (
		ParticleProcessMaterial.EMISSION_SHAPE_BOX
	)
	process.emission_box_extents = Vector3(42.0, 4.5, 56.0)
	process.direction = Vector3(0.8, 0.18, 0.32)
	process.spread = 24.0
	process.initial_velocity_min = 0.06
	process.initial_velocity_max = 0.22
	process.gravity = Vector3(0.0, 0.012, 0.0)
	process.scale_min = 0.55
	process.scale_max = 1.35
	process.color = Color(1.0, 0.72, 0.32, 0.34)
	pollen_motes.process_material = process

	var particle_material := StandardMaterial3D.new()
	particle_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)
	particle_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	particle_material.billboard_mode = (
		BaseMaterial3D.BILLBOARD_ENABLED
	)
	particle_material.albedo_color = Color(
		1.0,
		0.78,
		0.42,
		0.34
	)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.032, 0.032)
	quad.material = particle_material
	pollen_motes.draw_pass_1 = quad
	add_child(pollen_motes)


func get_debug_data() -> Dictionary:
	return {
		"benchmark_id": str(get_meta("benchmark_id", "")),
		"gameplay_clutter_free": bool(
			get_meta("gameplay_clutter_free", false)
		),
		"field": (
			field_surface.get_debug_data()
			if field_surface != null
			else {}
		),
		"environment": {
			"procedural_sky": style_sky_material != null,
			"aces": (
				style_environment != null
				and style_environment.tonemap_mode
				== Environment.TONE_MAPPER_ACES
			),
			"ssao": (
				style_environment != null
				and style_environment.ssao_enabled
			),
			"height_fog": (
				style_environment != null
				and style_environment.fog_enabled
			),
			"volumetric_fog": (
				style_environment != null
				and style_environment.volumetric_fog_enabled
			),
			"warm_key_cool_fill": (
				$GoldenSun.light_energy > 1.0
				and $CoolSkyFill.light_energy > 0.0
			),
		},
		"playable_space": playable_space != null,
		"session_unpaused": not get_tree().paused,
		"grace_input_ready": (
			$Player.is_physics_processing()
			and InputMap.has_action("move_forward")
			and InputMap.has_action("move_back")
			and InputMap.has_action("move_left")
			and InputMap.has_action("move_right")
		),
		"benchmark_hud_hidden": benchmark_hud_hidden,
		"grace_ground_snap_complete": grace_ground_snap_complete,
		"grace_spawn_surface_y": grace_spawn_surface_y,
		"grace_spawn_clearance": grace_spawn_clearance,
		"grace_ground_recovery_count": grace_ground_recovery_count,
		"grace_controller": (
			$Player.get_script().resource_path
			if $Player.get_script() != null
			else ""
		),
		"grace_status_locomotion": (
			$Player.call("get_status_locomotion_debug_data")
			if $Player.has_method(
				"get_status_locomotion_debug_data"
			)
			else {}
		),
		"pollen_motes": (
			pollen_motes.amount
			if pollen_motes != null
			else 0
		),
	}
