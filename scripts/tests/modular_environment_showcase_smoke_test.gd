extends Node

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn")
const Catalog = preload("res://scripts/environment/modular_environment_catalog.gd")
const PlayableSpaceAuditorScript = preload("res://scripts/quality/playable_space_auditor.gd")
const WATER_SHADER_PATH := "res://shaders/environment/modular_water.gdshader"

var failures: Array[String] = []
var elapsed: float = 0.0
var finished: bool = false
var current_step: String = "startup"


func _process(delta: float) -> void:
	if finished:
		return
	elapsed += maxf(delta, 0.0)
	if elapsed >= 20.0:
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

	current_step = "validate catalog"
	var catalog_errors: Array[String] = Catalog.validate_catalog()
	for error: String in catalog_errors:
		failures.append("catalog: " + error)
	var piece_ids: Array[String] = Catalog.get_piece_ids()
	check(piece_ids.size() == 12, "catalog exposes the twelve-piece v1 kit")

	current_step = "instantiate kit pieces"
	var kit_sandbox := Node3D.new()
	kit_sandbox.name = "KitSandbox"
	add_child(kit_sandbox)
	var instantiated: Array[Node3D] = []
	for piece_id: String in piece_ids:
		var piece: Node3D = Catalog.instantiate_piece(piece_id)
		check(piece != null, piece_id + " instantiates")
		if piece == null:
			continue
		kit_sandbox.add_child(piece)
		instantiated.append(piece)
	await get_tree().process_frame
	for piece: Node3D in instantiated:
		var piece_id: String = str(piece.get("piece_id"))
		check(piece.is_in_group("modular_environment_piece"), piece_id + " joins the modular piece group")
		check(str(piece.get_meta("piece_id", "")) == piece_id, piece_id + " publishes canonical metadata")
		var requires_collision: bool = bool(piece.get("requires_collision"))
		var collision_count: int = int(piece.call("get_collision_shape_count")) if piece.has_method("get_collision_shape_count") else 0
		if requires_collision:
			check(collision_count > 0, piece_id + " has collision")
	kit_sandbox.queue_free()
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

	current_step = "inspect showcase composition"
	var stats: Dictionary = showcase.call("get_showcase_stats")
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
	check(bool(gate.call("is_open")), "gate supports deterministic authored state restoration")

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
