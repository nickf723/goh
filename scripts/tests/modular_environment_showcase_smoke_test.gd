extends Node

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn")
const Catalog = preload("res://scripts/environment/modular_environment_catalog.gd")
const StylizedMaterialLibrary = preload("res://scripts/environment/stylized_pbr_material_library.gd")
const BuilderScript = preload("res://scripts/environment/authored_environment_builder.gd")
const ComposerScript = preload("res://scripts/environment/authored_set_composer.gd")
const SetClearanceAuditor = preload("res://scripts/environment/authored_set_clearance_auditor.gd")
const ChapelPalette = preload("res://data/environment_palettes/drowned_chapel_palette.tres")
const PlayableSpaceAuditorScript = preload("res://scripts/quality/playable_space_auditor.gd")
const WATER_SHADER_PATH := "res://shaders/environment/modular_water.gdshader"
const STYLIZED_SHADER_PATH := "res://shaders/environment/stylized_pbr_surface_v1.gdshader"
const STYLIZED_MATERIAL_PATH := "res://art/materials/environment/modular/stylized_pbr_stone_study.tres"
const OUTDOOR_PIECE_IDS: Array[String] = [
	"weathered_village_road_4m",
	"weathered_low_wall_4m",
	"weathered_ruined_corner_4m",
	"weathered_ruined_facade_6m",
	"weathered_timber_fence_4m",
	"weathered_rubble_cluster",
	"weathered_olive_tree_cluster",
]

var failures: Array[String] = []
var elapsed: float = 0.0
var finished: bool = false
var current_step: String = "startup"


func _process(delta: float) -> void:
	if finished:
		return
	elapsed += maxf(delta, 0.0)
	if elapsed >= 30.0:
		push_error("Modular environment showcase test stalled during: " + current_step)
		print("MODULAR_ENVIRONMENT_SHOWCASE_SMOKE_TEST: STALLED AT " + current_step)
		get_tree().quit(1)


func _ready() -> void:
	GameState.reset_run()
	current_step = "validate water shader"
	var shader_source: String = FileAccess.get_file_as_string(WATER_SHADER_PATH)
	check(not shader_source.is_empty(), "modular water shader source loads")
	check(not shader_source.contains("depth_draw_alpha_prepass"), "modular water shader does not use the Godot 3 alpha prepass token")
	check(shader_source.contains("depth_prepass_alpha"), "modular water shader uses the Godot 4 alpha depth prepass token")
	var water_shader: Shader = load(WATER_SHADER_PATH) as Shader
	check(water_shader != null, "modular water shader parses as a Shader resource")


	current_step = "validate stylized PBR shader"
	var stylized_shader_source: String = FileAccess.get_file_as_string(
		STYLIZED_SHADER_PATH
	)
	check(not stylized_shader_source.is_empty(), "stylized PBR shader source loads")
	check(
		stylized_shader_source.contains("void light()"),
		"stylized PBR shader owns a direct-light processor"
	)
	check(
		stylized_shader_source.contains("painterly_diffuse_band"),
		"stylized PBR shader exposes soft diffuse banding"
	)
	check(
		stylized_shader_source.contains("DIFFUSE_LIGHT +="),
		"stylized PBR shader writes painterly diffuse light"
	)
	check(
		stylized_shader_source.contains("SPECULAR_LIGHT +="),
		"stylized PBR shader preserves an independent specular lobe"
	)
	for uniform_name: String in [
		"band_softness",
		"rim_color",
		"rim_intensity",
		"saturation",
		"roughness_value",
		"metallic_value",
		"normal_strength",
	]:
		check(
			stylized_shader_source.contains("uniform") and stylized_shader_source.contains(uniform_name),
			"stylized PBR shader exposes " + uniform_name
		)
	var stylized_shader: Shader = load(STYLIZED_SHADER_PATH) as Shader
	check(stylized_shader != null, "stylized PBR shader parses as a Shader resource")
	var stylized_material: ShaderMaterial = load(
		STYLIZED_MATERIAL_PATH
	) as ShaderMaterial
	check(stylized_material != null, "stone study material loads")
	if stylized_material != null:
		check(
			float(stylized_material.get_shader_parameter("saturation")) > 1.0,
			"stone study material uses a restrained saturation lift"
		)
		check(
			float(stylized_material.get_shader_parameter("rim_intensity")) > 0.0,
			"stone study material enables its cool rim"
		)


	current_step = "validate stylized PBR material family"
	for error: String in StylizedMaterialLibrary.validate_library():
		failures.append("stylized material library: " + error)
	var material_family_ids: Array[String] = (
		StylizedMaterialLibrary.get_family_ids()
	)
	check(
		material_family_ids == [
			"stone",
			"wet_stone",
			"dry_earth",
			"aged_wood",
			"aged_metal",
		],
		"stylized PBR library exposes the five approved broad material families"
	)
	var wet_stone_material: ShaderMaterial = (
		StylizedMaterialLibrary.get_material("wet_stone")
	)
	var aged_wood_material: ShaderMaterial = (
		StylizedMaterialLibrary.get_material("aged_wood")
	)
	var aged_metal_material: ShaderMaterial = (
		StylizedMaterialLibrary.get_material("aged_metal")
	)
	check(
		wet_stone_material != null
		and float(
			wet_stone_material.get_shader_parameter("roughness_value")
		) < float(
			stylized_material.get_shader_parameter("roughness_value")
		),
		"wet stone keeps a sharper physical highlight than dry stone"
	)
	check(
		aged_wood_material != null
		and float(
			aged_wood_material.get_shader_parameter(
				"broad_variation_strength"
			)
		) > 0.0,
		"aged wood retains broad painted material breakup"
	)
	check(
		aged_metal_material != null
		and float(
			aged_metal_material.get_shader_parameter("metallic_value")
		) > 0.7,
		"aged metal preserves a genuinely metallic PBR response"
	)

	current_step = "validate catalog"
	var catalog_errors: Array[String] = Catalog.validate_catalog()
	for error: String in catalog_errors:
		failures.append("catalog: " + error)
	var piece_ids: Array[String] = Catalog.get_piece_ids()
	check(piece_ids.size() == 19, "catalog exposes the twelve-piece cloister kit plus seven outdoor pieces")
	for outdoor_piece_id: String in OUTDOOR_PIECE_IDS:
		check(piece_ids.has(outdoor_piece_id), "catalog exposes " + outdoor_piece_id)
		check(not Catalog.get_definition(outdoor_piece_id).is_empty(), outdoor_piece_id + " has catalog metadata")

	current_step = "instantiate kit pieces"
	var kit_sandbox := Node3D.new()
	kit_sandbox.name = "KitSandbox"
	add_child(kit_sandbox)
	var instantiated: Array[Node3D] = []
	var stairs_piece: Node3D
	for piece_id: String in piece_ids:
		var piece: Node3D = Catalog.instantiate_piece(piece_id)
		check(piece != null, piece_id + " instantiates")
		if piece == null:
			continue
		kit_sandbox.add_child(piece)
		instantiated.append(piece)
		if piece_id == "weathered_stone_stairs_4m":
			stairs_piece = piece
	await get_tree().process_frame
	for piece: Node3D in instantiated:
		var piece_id: String = str(piece.get("piece_id"))
		check(piece.is_in_group("modular_environment_piece"), piece_id + " joins the modular piece group")
		check(str(piece.get_meta("piece_id", "")) == piece_id, piece_id + " publishes canonical metadata")
		var requires_collision: bool = bool(piece.get("requires_collision"))
		var collision_count: int = int(piece.call("get_collision_shape_count")) if piece.has_method("get_collision_shape_count") else 0
		if requires_collision:
			check(collision_count > 0, piece_id + " has collision")

	current_step = "inspect stair traversal contract"
	check(stairs_piece != null, "catalog exposes the modular stair piece")
	if stairs_piece != null:
		var walk_ramp: StaticBody3D = stairs_piece.get_node_or_null("WalkRamp") as StaticBody3D
		var top_landing: StaticBody3D = stairs_piece.get_node_or_null("TopLanding") as StaticBody3D
		check(walk_ramp != null, "stairs provide one continuous walk ramp")
		check(top_landing != null, "stairs provide a flat upper landing")
		if walk_ramp != null:
			check(bool(walk_ramp.get_meta("walkable_ramp", false)), "stair ramp publishes its traversal role")
			check(walk_ramp.rotation.x < -0.1, "stair ramp rises toward the gallery")
			check(walk_ramp.get_node_or_null("CollisionShape3D") != null, "stair ramp has physical collision")
		if top_landing != null:
			check(bool(top_landing.get_meta("walkable_landing", false)), "stair landing publishes its traversal role")
	kit_sandbox.queue_free()
	await get_tree().process_frame

	current_step = "compose a set from compact layout data"
	var composed_sandbox := Node3D.new()
	composed_sandbox.name = "ComposedSetSandbox"
	add_child(composed_sandbox)
	var builder: AuthoredEnvironmentBuilder = BuilderScript.new(composed_sandbox, ChapelPalette) as AuthoredEnvironmentBuilder
	var composer: RefCounted = ComposerScript.new(builder) as RefCounted
	var plan: Dictionary = {
		"layout_id": "composer_smoke_set",
		"corridors": [{
			"id": "SwimCorridor",
			"floor_center": Vector3(0.0, 0.0, 0.0),
			"forward": Vector3(0.0, 0.0, 1.0),
			"length": 8.0,
			"clear_width": 5.7,
			"clear_height": 5.0,
			"traversal": "swim",
			"material": "stone_dark",
		}],
		"walls": [{
			"id": "OpeningWall",
			"base_center": Vector3(0.0, 0.0, 4.0),
			"normal": Vector3(0.0, 0.0, 1.0),
			"length": 12.0,
			"height": 5.5,
			"depth": 0.5,
			"openings": [{
				"id": "AlignedOpening",
				"center_offset": 0.0,
				"width": 5.7,
				"height": 5.0,
				"traversal": "swim",
			}],
		}],
		"stairs": [{
			"id": "WalkableStairs",
			"low_origin": Vector3(7.0, 0.0, -2.0),
			"forward": Vector3(0.0, 0.0, 1.0),
			"step_count": 6,
			"width": 4.0,
			"step_run": 0.6,
			"total_rise": 1.5,
			"landing_length": 1.0,
		}],
		"modules": [{
			"id": "LayoutCrate",
			"piece_id": "weathered_crate",
			"position": Vector3(-5.0, 0.0, 0.0),
			"collision_mode": "own",
			"variant_seed": 8,
		}],
	}
	var raw_compose_result: Variant = composer.call("compose_plan", composed_sandbox, plan)
	var compose_result: Dictionary = raw_compose_result as Dictionary if raw_compose_result is Dictionary else {}
	await get_tree().physics_frame
	check(str(compose_result.get("layout_id", "")) == "composer_smoke_set", "composer preserves the layout id")
	var counts: Dictionary = compose_result.get("counts", {})
	check(int(counts.get("corridors", 0)) == 1, "composer builds a corridor from one data row")
	check(int(counts.get("walls", 0)) == 1, "composer builds an opening-aware wall from one data row")
	check(int(counts.get("stairs", 0)) == 1, "composer builds walkable stairs from one data row")
	check(int(counts.get("modules", 0)) == 1, "composer places a catalog module from one data row")
	check(composed_sandbox.get_node_or_null("SwimCorridor") != null, "composed corridor has a stable authored id")
	check(composed_sandbox.get_node_or_null("OpeningWall") != null, "composed wall has a stable authored id")
	check(composed_sandbox.get_node_or_null("WalkableStairs/WalkRamp") != null, "composed stairs own continuous ramp collision")
	check(composed_sandbox.get_node_or_null("LayoutCrate") != null, "composed modular prop has a stable authored id")
	var set_audit: Dictionary = SetClearanceAuditor.audit(composed_sandbox)
	for error: String in set_audit.get("errors", []):
		failures.append("set composer: " + error)
	check(bool(set_audit.get("passed", false)), "compact set plan passes clearance auditing")
	composed_sandbox.queue_free()
	await get_tree().process_frame

	current_step = "instantiate showcase"
	var showcase := SceneUnderTest.instantiate()
	add_child(showcase)
	for _index: int in range(5):
		await get_tree().process_frame
	await get_tree().physics_frame
	check(showcase.get_node_or_null("Player") != null, "showcase uses the shared player")
	check(showcase.get_node_or_null("PlayableSpace") != null, "showcase declares a PlayableSpace3D")
	check(showcase.get_node_or_null("PlayableSpace/ShowcaseRecoveryVolume") != null, "showcase has explicit recovery coverage")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet") != null, "dedicated Weathered Cloister set exists")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/EntranceArch") != null, "set has a readable entrance arch")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/WaterChannel_0_0") != null, "set demonstrates water transitions")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/RaisedGalleryStairs") != null, "set demonstrates a reusable stair run")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/ShowcaseGate") != null, "set demonstrates the operable gate")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/HeroPedestal") != null, "set demonstrates prop staging")


	var study: Node3D = showcase.get_node_or_null(
		"World/WeatheredCloisterSet/StylizedSurfaceStudy"
	) as Node3D
	check(study != null, "showcase contains one contained stylized surface study")
	if study != null:
		check(
			str(study.get_meta("rollout_scope", "")) == "showcase_material_family",
			"style study records its showcase-only material-family rollout"
		)
		check(study.get_child_count() == 3, "style study composes one three-lobe rock")
		var study_core: MeshInstance3D = study.get_node_or_null(
			"Core"
		) as MeshInstance3D
		check(study_core != null, "style study exposes its core mesh")
		if study_core != null:
			var core_material: ShaderMaterial = (
				study_core.material_override as ShaderMaterial
			)
			check(core_material != null, "style study uses a shader material")
			if core_material != null:
				check(
					core_material.shader != null
					and core_material.shader.resource_path == STYLIZED_SHADER_PATH,
					"style study uses the shared provisional stylized PBR shader"
				)

	var environment_node: WorldEnvironment = showcase.get_node_or_null(
		"WorldEnvironment"
	) as WorldEnvironment
	var environment: Environment = (
		environment_node.environment if environment_node != null else null
	)
	check(environment != null, "showcase publishes its style-calibration environment")
	if environment != null:
		check(
			environment.background_mode == Environment.BG_SKY
			and environment.sky != null
			and environment.sky.sky_material is ProceduralSkyMaterial,
			"showcase uses a procedural warm-cool sky"
		)
		check(
			environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY,
			"cool sky supplies ambient light"
		)
		check(
			environment.tonemap_mode == Environment.TONE_MAPPER_ACES,
			"showcase uses ACES highlight rolloff"
		)
		check(
			environment.adjustment_enabled
			and environment.adjustment_saturation > 1.0
			and environment.adjustment_contrast > 1.0,
			"showcase applies restrained saturation and contrast grading"
		)
		check(environment.ssao_enabled, "showcase enables moderate ambient occlusion")
	var key_light: DirectionalLight3D = showcase.get_node_or_null(
		"DirectionalLight3D"
	) as DirectionalLight3D
	check(
		key_light != null
		and key_light.light_color.r > key_light.light_color.b
		and key_light.shadow_enabled,
		"showcase contrasts a warm shadow-casting key against the cool sky"
	)


	current_step = "inspect stylized material comparison"
	var comparison: Dictionary = showcase.call(
		"get_stylized_comparison_stats"
	)
	check(
		int(comparison.get("total", 0)) >= 20,
		"right wing receives a meaningful bounded material-family rollout"
	)
	var comparison_families: Dictionary = comparison.get("families", {})
	for represented_family: String in [
		"stone",
		"wet_stone",
		"aged_wood",
		"aged_metal",
	]:
		check(
			int(comparison_families.get(represented_family, 0)) > 0,
			"showcase comparison represents " + represented_family
		)
	var comparison_roots: Array = comparison.get("roots", [])
	check(
		comparison_roots.has("StorageBarrel"),
		"right-side prop proves styled wood and metal"
	)
	check(
		not comparison_roots.has("SupplyCrate"),
		"left-side prop remains a legacy material baseline"
	)
	var left_floor: Node = showcase.get_node_or_null(
		"World/WeatheredCloisterSet/FloorLeft_-4_0"
	)
	var right_floor: Node = showcase.get_node_or_null(
		"World/WeatheredCloisterSet/FloorRight_-4_0"
	)
	check(left_floor != null and right_floor != null, "A/B floor roots resolve")
	if left_floor != null and right_floor != null:
		var left_stylized_count: int = 0
		for candidate: Node in left_floor.find_children(
			"*",
			"MeshInstance3D",
			true,
			false
		):
			var mesh_instance: MeshInstance3D = candidate as MeshInstance3D
			var material: ShaderMaterial = (
				mesh_instance.material_override as ShaderMaterial
			)
			if (
				material != null
				and material.shader != null
				and material.shader.resource_path == STYLIZED_SHADER_PATH
			):
				left_stylized_count += 1
		var right_stylized_count: int = 0
		for candidate: Node in right_floor.find_children(
			"*",
			"MeshInstance3D",
			true,
			false
		):
			var mesh_instance: MeshInstance3D = candidate as MeshInstance3D
			var material: ShaderMaterial = (
				mesh_instance.material_override as ShaderMaterial
			)
			if (
				material != null
				and material.shader != null
				and material.shader.resource_path == STYLIZED_SHADER_PATH
			):
				right_stylized_count += 1
		check(
			left_stylized_count == 0,
			"left floor keeps the legacy shader for direct comparison"
		)
		check(
			right_stylized_count > 0,
			"right floor uses the stylized PBR material family"
		)

	current_step = "switch lighting dialect"
	var lighting_console: Area3D = showcase.get_node_or_null(
		"World/WeatheredCloisterSet/StyleLightingConsole"
	) as Area3D
	check(lighting_console != null, "showcase exposes an in-world lighting console")
	if lighting_console != null:
		lighting_console.interact()
		await get_tree().process_frame
		var twilight_stats: Dictionary = showcase.call(
			"get_showcase_stats"
		)
		check(
			str(twilight_stats.get("environment_profile", ""))
			== "violet_twilight_v1",
			"lighting console activates the contrasting violet dialect"
		)
		check(
			key_light != null
			and key_light.light_color.b > key_light.light_color.r,
			"violet twilight replaces the warm key with a cool key"
		)
		check(
			environment != null
			and environment.adjustment_saturation > 1.0,
			"twilight retains restrained stylized color grading"
		)
		lighting_console.interact()
		await get_tree().process_frame
		var restored_stats: Dictionary = showcase.call(
			"get_showcase_stats"
		)
		check(
			str(restored_stats.get("environment_profile", ""))
			== "warm_key_cool_sky_v1",
			"lighting console restores the approved daylight dialect"
		)

	current_step = "inspect showcase composition"
	var stats: Dictionary = showcase.call("get_showcase_stats")
	check(bool(stats.get("stylized_surface_study", false)), "showcase reports the style study")
	check(bool(stats.get("style_lighting_console", false)), "showcase reports the lighting console")
	check(str(stats.get("environment_profile", "")) == "warm_key_cool_sky_v1", "showcase reports its restored lighting profile")
	check(int((stats.get("stylized_comparison", {}) as Dictionary).get("total", 0)) >= 20, "showcase reports the bounded material comparison")
	check(int(stats.get("placed_count", 0)) >= 35, "showcase composes a full set from repeated modules")
	var categories: Array = stats.get("categories", [])
	for required_category: String in ["architecture", "prop", "lighting", "water"]:
		check(categories.has(required_category), "showcase includes " + required_category + " pieces")
	var scene_piece_count: int = 0
	for candidate: Node in get_tree().get_nodes_in_group("modular_environment_piece"):
		if showcase == candidate or showcase.is_ancestor_of(candidate):
			scene_piece_count += 1
	check(scene_piece_count >= 35, "showcase registers every placed module")

	current_step = "operate gate"
	var gate: Node = showcase.get_node("World/WeatheredCloisterSet/ShowcaseGate")
	var lever: Area3D = showcase.get_node("World/WeatheredCloisterSet/GateLever") as Area3D
	check(not bool(gate.get("target_open")), "gate begins closed")
	lever.interact()
	await get_tree().process_frame
	check(bool(gate.get("target_open")), "physical lever opens the gate")
	gate.call("set_open", true, true)
	await get_tree().physics_frame
	check(bool(gate.call("is_open")), "gate supports deterministic authored state restoration")
	check(bool(gate.call("is_passage_clear")), "fully open gate clears its panel collision from the doorway")
	var gate_panel: AnimatableBody3D = gate.get_node_or_null("GatePivot/GatePanel") as AnimatableBody3D
	check(gate_panel != null and gate_panel.collision_layer == 0, "open gate panel no longer blocks the player")
	gate.call("set_open", false, true)
	await get_tree().physics_frame
	check(not bool(gate.call("is_passage_clear")), "closed gate restores its blocking collision")
	check(gate_panel != null and gate_panel.collision_layer != 0, "closed gate panel blocks the doorway")
	gate.call("set_open", true, true)

	current_step = "audit playable space"
	var audit: Dictionary = PlayableSpaceAuditorScript.audit_scene(showcase)
	for error: String in audit.get("errors", []):
		failures.append("auditor: " + error)
	check(bool(audit.get("passed", false)), "showcase passes the global playable-space audit")

	showcase.queue_free()
	await get_tree().process_frame
	finished = true
	if failures.is_empty():
		print("MODULAR_ENVIRONMENT_SHOWCASE_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("MODULAR_ENVIRONMENT_SHOWCASE_SMOKE_TEST: " + failure)
		print("MODULAR_ENVIRONMENT_SHOWCASE_SMOKE_TEST: FAIL")
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
