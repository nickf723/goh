extends Node

const MeadowScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_golden_meadow_benchmark_v1.tscn"
)
const GROUND_SHADER_PATH := (
	"res://shaders/environment/stylized_meadow_ground_v1.gdshader"
)
const GRASS_SHADER_PATH := (
	"res://shaders/environment/stylized_meadow_grass_v1.gdshader"
)

var failures: Array[String] = []
var benchmark: Node3D


func _ready() -> void:
	GameState.reset_run()
	benchmark = MeadowScene.instantiate() as Node3D
	if benchmark == null:
		failures.append("golden meadow scene failed to instantiate")
	else:
		add_child(benchmark)

	for _frame: int in range(6):
		await get_tree().process_frame
	await get_tree().physics_frame

	_validate_benchmark()
	_validate_surface()
	_validate_materials()
	_validate_empty_field_contract()
	_validate_benchmark_hud()
	await _validate_player_movement()

	if benchmark != null and is_instance_valid(benchmark):
		benchmark.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("GOLDEN_MEADOW_BENCHMARK_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error(
			"GOLDEN_MEADOW_BENCHMARK_SMOKE_TEST: " + failure
		)
	get_tree().quit(1)


func _validate_benchmark() -> void:
	if benchmark == null:
		return
	if not benchmark.is_in_group("golden_meadow_benchmark"):
		failures.append("benchmark root group is missing")
	if str(benchmark.get_meta("benchmark_id", "")) != "golden_meadow_v1":
		failures.append("benchmark id changed unexpectedly")
	if not bool(benchmark.get_meta("gameplay_clutter_free", false)):
		failures.append("empty-field contract metadata is missing")
	if not benchmark.has_method("get_debug_data"):
		failures.append("benchmark debug contract is missing")
		return

	var debug_data: Dictionary = benchmark.call(
		"get_debug_data"
	) as Dictionary
	var environment_data: Dictionary = debug_data.get(
		"environment",
		{}
	) as Dictionary
	for required_flag: String in [
		"procedural_sky",
		"aces",
		"ssao",
		"height_fog",
		"volumetric_fog",
		"warm_key_cool_fill",
	]:
		if not bool(environment_data.get(required_flag, false)):
			failures.append(
				"environment presentation flag is false: "
				+ required_flag
			)
	if not bool(debug_data.get("playable_space", false)):
		failures.append("playable-space safety is missing")
	if not bool(debug_data.get("session_unpaused", false)):
		failures.append("benchmark did not restore an unpaused session")
	if not bool(debug_data.get("grace_input_ready", false)):
		failures.append("Grace input is not physics-ready")
	if not bool(debug_data.get("benchmark_hud_hidden", false)):
		failures.append("benchmark HUD suppression is not active")
	if int(debug_data.get("pollen_motes", 0)) < 100:
		failures.append("atmospheric pollen layer is too sparse")
	if benchmark.get_node_or_null("Player") == null:
		failures.append("Grace is missing as the field scale reference")
	if benchmark.get_node_or_null("GameUI") != null:
		failures.append("benchmark should not add the full gameplay HUD")


func _validate_surface() -> void:
	if benchmark == null:
		return
	var surface: MeadowFieldSurface = benchmark.get_node_or_null(
		"GoldenMeadowSurface"
	) as MeadowFieldSurface
	if surface == null:
		failures.append("meadow surface is missing")
		return
	if not surface.is_in_group("authored_environment_composition"):
		failures.append("surface is outside authored environment ownership")
	var metrics: Dictionary = surface.get_debug_data()
	if not bool(metrics.get("built", false)):
		failures.append("meadow surface did not build")
	if float(metrics.get("field_width", 0.0)) < 100.0:
		failures.append("meadow width is below the benchmark target")
	if float(metrics.get("field_depth", 0.0)) < 150.0:
		failures.append("meadow depth is below the benchmark target")
	if int(metrics.get("terrain_vertices", 0)) < 7000:
		failures.append("terrain mesh is below the sculpting target")
	if int(metrics.get("terrain_triangles", 0)) < 14000:
		failures.append("terrain topology is below the benchmark target")
	if float(metrics.get("height_range", 0.0)) < 1.5:
		failures.append("terrain silhouette is too flat")
	if int(metrics.get("grass_instances", 0)) < 22000:
		failures.append("grass canopy density fell below the art target")
	if int(metrics.get("seed_heads", 0)) < 1500:
		failures.append("seed-head layer density fell below target")
	if int(metrics.get("wildflowers", 0)) < 400:
		failures.append("wildflower punctuation fell below target")
	if int(metrics.get("grass_blades_per_clump", 0)) != 5:
		failures.append("grass clumps lost their five-blade silhouette")
	if float(metrics.get("maximum_canopy_height", 99.0)) > 0.72:
		failures.append("main grass canopy is taller than the readability target")
	if str(metrics.get("ground_surface_detail", "")) != (
		"multi_scale_procedural_meadow"
	):
		failures.append("ground surface detail contract is missing")
	if int(metrics.get("horizon_layers", 0)) != 3:
		failures.append("layered horizon must contain three ridges")
	if not bool(metrics.get("gameplay_clutter_free", false)):
		failures.append("surface does not publish the empty-field contract")

	var terrain_collision: CollisionShape3D = surface.get_node_or_null(
		"MeadowTerrain/TerrainCollision"
	) as CollisionShape3D
	if (
		terrain_collision == null
		or terrain_collision.shape == null
		or terrain_collision.disabled
	):
		failures.append("sculpted terrain is not collision matched")
	var playable_space: Node = benchmark.get_node_or_null(
		"PlayableSpace"
	)
	if playable_space == null or not playable_space.is_in_group(
		"playable_space"
	):
		failures.append("field bounds are not owned by PlayableSpace3D")


func _validate_materials() -> void:
	if benchmark == null:
		return
	var terrain_visual: MeshInstance3D = benchmark.get_node_or_null(
		"GoldenMeadowSurface/MeadowTerrain/TerrainVisual"
	) as MeshInstance3D
	if terrain_visual == null:
		failures.append("terrain visual is missing")
	else:
		var ground_material: ShaderMaterial = (
			terrain_visual.material_override as ShaderMaterial
		)
		if (
			ground_material == null
			or ground_material.shader == null
			or ground_material.shader.resource_path
			!= GROUND_SHADER_PATH
		):
			failures.append(
				"ground does not use the approved stylized PBR shader"
			)

	var grass: MultiMeshInstance3D = benchmark.get_node_or_null(
		"GoldenMeadowSurface/GrassCanopy"
	) as MultiMeshInstance3D
	if grass == null or grass.multimesh == null:
		failures.append("grass canopy MultiMesh is missing")
		return
	if not grass.multimesh.use_custom_data:
		failures.append("grass canopy lost per-instance variation")
	var grass_material: ShaderMaterial = (
		grass.material_override as ShaderMaterial
	)
	if (
		grass_material == null
		or grass_material.shader == null
		or grass_material.shader.resource_path != GRASS_SHADER_PATH
	):
		failures.append("grass canopy does not use the meadow shader")
		return
	if float(grass_material.get_shader_parameter(
		"wind_strength"
	)) <= 0.0:
		failures.append("grass wind strength is disabled")
	if float(grass_material.get_shader_parameter(
		"wind_speed"
	)) <= 0.0:
		failures.append("grass wind speed is disabled")


func _validate_empty_field_contract() -> void:
	if benchmark == null:
		return
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if benchmark.is_ancestor_of(enemy):
			failures.append(
				"empty field unexpectedly contains an enemy"
			)
			break
	for interactable: Node in get_tree().get_nodes_in_group(
		"interactable"
	):
		if benchmark.is_ancestor_of(interactable):
			failures.append(
				"empty field unexpectedly contains an interactable"
			)
			break

	var surface: MeadowFieldSurface = benchmark.get_node_or_null(
		"GoldenMeadowSurface"
	) as MeadowFieldSurface
	var player: Node3D = benchmark.get_node_or_null(
		"Player"
	) as Node3D
	if surface != null and player != null:
		var spawn: Vector3 = surface.get_spawn_position()
		if Vector2(
			player.position.x - spawn.x,
			player.position.z - spawn.z
		).length() > 0.5:
			failures.append(
				"Grace no longer starts at the intended vista"
			)


func _validate_benchmark_hud() -> void:
	if benchmark == null:
		return
	var player: Node = benchmark.get_node_or_null("Player")
	if player == null:
		return
	for hud_name: String in [
		"DivineSpecialHUD",
		"PlayerHUDV2",
		"QuickItemBeltUI",
		"GameplayEffectStatusHUD",
		"WeaponMasteryHUD",
		"QuickSpellBeltPresentation",
	]:
		var hud: Node = player.get_node_or_null(NodePath(hud_name))
		if hud is CanvasLayer and (hud as CanvasLayer).visible:
			failures.append("benchmark HUD remains visible: " + hud_name)
		elif hud is CanvasItem and (hud as CanvasItem).visible:
			failures.append("benchmark HUD remains visible: " + hud_name)


func _validate_player_movement() -> void:
	if benchmark == null:
		return
	var player: CharacterBody3D = benchmark.get_node_or_null(
		"Player"
	) as CharacterBody3D
	if player == null:
		return
	if get_tree().paused:
		failures.append("scene tree is paused before locomotion test")
		return
	var start_position: Vector3 = player.global_position
	Input.action_press("move_forward", 1.0)
	for _frame: int in range(18):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	var horizontal_distance: float = Vector2(
		player.global_position.x - start_position.x,
		player.global_position.z - start_position.z
	).length()
	if horizontal_distance < 0.25:
		failures.append(
			"Grace did not traverse the meadow under movement input"
		)
