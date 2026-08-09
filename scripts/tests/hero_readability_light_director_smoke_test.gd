extends Node

const GreenScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_green_grotto_art_target_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var target: Node = GreenScene.instantiate()
	add_child(target)
	for _index: int in range(6):
		await get_tree().process_frame

	var director: HeroReadabilityLightDirector3D = target.get_node_or_null(
		"HeroReadabilityLightDirector"
	) as HeroReadabilityLightDirector3D
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	_expect(director != null, "Green installs HeroReadabilityLightDirector")
	_expect(lighting != null, "readability test resolves LightingDirector")
	if director != null and lighting != null:
		director.synchronize_now()
		_validate_contract(target, director)
		_validate_layer_isolation(target, director)
		_validate_quality_ladder(director, lighting)
		_validate_restore(director)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(
	target: Node,
	director: HeroReadabilityLightDirector3D
) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("hero_readability_light_director", false)), "readability director publishes debug contract")
	_expect(bool(data.get("initialized", false)), "readability director resolves Grace and private render layer")
	_expect(str(data.get("profile_id", "")) == "grace_readability_light", "Green uses dedicated Grace readability profile")
	_expect(int(data.get("character_render_layer", 0)) == 2, "Grace readability uses private render layer 2")
	_expect(int(data.get("light_cull_mask", 0)) == 2, "readability light cull mask targets only layer 2")
	_expect(int(data.get("target_mesh_count", 0)) >= 27, "readability layer covers Grace visible meshes")
	_expect(bool(data.get("indirect_energy_zero", false)), "readability light contributes no indirect GI energy")
	_expect(bool(data.get("volumetric_energy_zero", false)), "readability light contributes no volumetric fog energy")
	_expect(bool(data.get("shadow_free", false)), "readability light spends no shadow map")
	_expect(bool(data.get("camera_relative", false)), "readability direction is camera-relative")
	_expect(bool(data.get("follows_lighting_quality", false)), "readability light follows F7")
	_expect(bool(data.get("world_lighting_isolated_by_cull_mask", false)), "readability light declares render-layer isolation")
	_expect(bool(data.get("geometry_unchanged", false)), "readability light leaves geometry unchanged")
	_expect(not bool(data.get("gameplay_authority", true)), "readability light owns no gameplay state")
	_expect(director.readability_light != null, "readability director owns one DirectionalLight3D")
	if director.readability_light != null:
		_expect(director.readability_light.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY, "readability light never affects sky")
		_expect(not director.readability_light.shadow_enabled, "readability light remains shadow-free")
		_expect(absf(director.readability_light.light_indirect_energy) < 0.001, "readability light indirect energy stays zero")
		_expect(absf(director.readability_light.light_volumetric_fog_energy) < 0.001, "readability light volumetric energy stays zero")

	var pass_data: Dictionary = {}
	if target.has_method("get_debug_data"):
		pass_data = _dictionary_value(target.call("get_debug_data"))
	_expect(bool(pass_data.get("grace_material_presentation", false)), "Grace material presentation remains installed beside readability light")


func _validate_layer_isolation(
	target: Node,
	director: HeroReadabilityLightDirector3D
) -> void:
	var grace_head: VisualInstance3D = target.get_node_or_null(
		"Player/GraceVisualV1/VisualRoot/HeadRoot/Head"
	) as VisualInstance3D
	_expect(grace_head != null, "layer test resolves Grace head")
	if grace_head != null:
		_expect(grace_head.get_layer_mask_value(1), "Grace retains ordinary render layer 1")
		_expect(grace_head.get_layer_mask_value(2), "Grace gains private readability layer 2")
		_expect(director.original_layers.has(grace_head.get_instance_id()), "readability director remembers Grace head original layers")

	var world_mesh: VisualInstance3D = target.get_node_or_null(
		"GreenGrottoArt/Terrain/ArrivalShelf/Visual"
	) as VisualInstance3D
	_expect(world_mesh != null, "layer test resolves representative world mesh")
	if world_mesh != null:
		_expect(world_mesh.get_layer_mask_value(1), "world mesh stays on normal render layer")
		_expect(not world_mesh.get_layer_mask_value(2), "world mesh never joins Grace private readability layer")


func _validate_quality_ladder(
	director: HeroReadabilityLightDirector3D,
	lighting: LightingDirector3D
) -> void:
	var light: DirectionalLight3D = director.readability_light
	if light == null:
		return

	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	director.synchronize_now()
	_expect(not light.visible, "Performance disables Grace rim light")
	_expect(absf(light.light_energy) < 0.001, "Performance readability energy is zero")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	director.synchronize_now()
	_expect(light.visible, "Balanced enables Grace rim light")
	_expect(absf(light.light_energy - director.profile.balanced_energy) < 0.001, "Balanced uses authored low readability energy")
	var balanced_energy: float = light.light_energy

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	director.synchronize_now()
	_expect(light.visible, "Cinematic retains Grace rim light")
	_expect(light.light_energy > balanced_energy, "Cinematic strengthens readability over Balanced")
	_expect(absf(light.light_energy - director.profile.cinematic_energy) < 0.001, "Cinematic uses authored readability energy")
	_expect(light.light_energy < lighting.sun.light_energy, "readability remains subordinate to main authored sun")


func _validate_restore(director: HeroReadabilityLightDirector3D) -> void:
	var grace_head: VisualInstance3D = null
	if director.grace_visual != null:
		grace_head = director.grace_visual.get_node_or_null(
			"VisualRoot/HeadRoot/Head"
		) as VisualInstance3D
	_expect(grace_head != null, "restore test resolves Grace head")
	if grace_head == null:
		return
	var record: Dictionary = director.original_layers.get(
		grace_head.get_instance_id(),
		{}
	) as Dictionary
	_expect(not record.is_empty(), "restore test has original Grace layer record")
	if record.is_empty():
		return
	var original_mask: int = int(record.get("layers", 1))
	director.set_enabled(false)
	_expect(grace_head.layers == original_mask, "disabling readability restores exact original Grace layer mask")
	_expect(not director.readability_light.visible, "disabling readability hides private light")
	_expect(absf(director.readability_light.light_energy) < 0.001, "disabling readability zeros private light energy")
	director.set_enabled(true)
	director.synchronize_now()
	_expect(grace_head.get_layer_mask_value(2), "reenabling readability restores Grace private render layer")


func _dictionary_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("HERO_READABILITY_LIGHT_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("HERO_READABILITY_LIGHT_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
