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
	for _index: int in range(5):
		await get_tree().process_frame

	var director: ProjectedCanopyLightDirector3D = target.get_node_or_null(
		"ProjectedCanopyLightDirector"
	) as ProjectedCanopyLightDirector3D
	var lighting: LightingDirector3D = target.get_node_or_null(
		"LightingDirector"
	) as LightingDirector3D
	_expect(director != null, "Green installs ProjectedCanopyLightDirector")
	_expect(lighting != null, "canopy-light test resolves LightingDirector")
	if director != null and lighting != null:
		_validate_contract(director)
		_validate_authored_placement(director)
		_validate_quality_ladder(director, lighting)

	target.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_contract(director: ProjectedCanopyLightDirector3D) -> void:
	var data: Dictionary = director.get_debug_data()
	_expect(bool(data.get("projected_canopy_light_director", false)), "dapple director publishes debug contract")
	_expect(bool(data.get("initialized", false)), "dapple director initializes with light and texture")
	_expect(str(data.get("profile_id", "")) == "green_grotto_projected_canopy_light", "Green owns dedicated dapple profile")
	_expect(bool(data.get("projector_texture", false)), "dapple director creates projector texture")
	_expect(int(data.get("projector_resolution", 0)) == 96, "Green dapple texture uses bounded 96px resolution")
	_expect(bool(data.get("runtime_generated_projector", false)), "projector mask is generated inside Godot")
	_expect(bool(data.get("indirect_energy_zero", false)), "dapple light never double-feeds GI")
	_expect(bool(data.get("follows_lighting_quality", false)), "dapple light follows F7")
	_expect(bool(data.get("geometry_unchanged", false)), "dapple light changes no geometry")
	_expect(not bool(data.get("gameplay_authority", true)), "dapple light owns no gameplay state")
	var average: float = float(data.get("mask_average", 0.0))
	var bright_fraction: float = float(data.get("mask_bright_fraction", 0.0))
	_expect(average > 0.03 and average < 0.75, "projector mask contains useful dark/light range")
	_expect(bright_fraction > 0.01 and bright_fraction < 0.55, "projector has sparse bright canopy openings")
	_expect(director.projector_texture is ImageTexture, "projector is a real runtime ImageTexture")


func _validate_authored_placement(director: ProjectedCanopyLightDirector3D) -> void:
	_expect(director.global_position.distance_to(Vector3(0.0, 18.0, 2.0)) < 0.01, "dapple light is authored high over canopy break")
	_expect(director.spot_light != null, "dapple director owns one SpotLight")
	if director.spot_light != null:
		_expect(director.spot_light.light_projector == director.projector_texture, "SpotLight owns generated projector texture")
		_expect(absf(director.spot_light.light_indirect_energy) < 0.001, "SpotLight indirect energy stays zero")
		_expect(absf(director.spot_light.light_specular - director.profile.light_specular) < 0.001, "dapple uses restrained specular contribution")


func _validate_quality_ladder(
	director: ProjectedCanopyLightDirector3D,
	lighting: LightingDirector3D
) -> void:
	var spot: SpotLight3D = director.spot_light
	if spot == null:
		return

	lighting.set_quality(LightingDirector3D.Quality.PERFORMANCE)
	director.synchronize_now()
	_expect(not spot.visible, "Performance disables dapple light")
	_expect(absf(spot.light_energy) < 0.001, "Performance dapple energy is zero")
	_expect(not spot.shadow_enabled, "Performance spends no projector shadow map")

	lighting.set_quality(LightingDirector3D.Quality.BALANCED)
	director.synchronize_now()
	_expect(spot.visible, "Balanced enables canopy dapple")
	_expect(spot.shadow_enabled, "Balanced enables projector shadow support")
	_expect(absf(spot.light_energy - director.profile.balanced_energy) < 0.001, "Balanced uses authored low dapple energy")
	_expect(absf(spot.light_volumetric_fog_energy - director.profile.balanced_volumetric_energy) < 0.001, "Balanced adds restrained volumetric dapple")
	var balanced_energy: float = spot.light_energy

	lighting.set_quality(LightingDirector3D.Quality.CINEMATIC)
	director.synchronize_now()
	_expect(spot.visible and spot.shadow_enabled, "Cinematic retains projected canopy light")
	_expect(spot.light_energy > balanced_energy, "Cinematic strengthens dapple over Balanced")
	_expect(spot.light_energy < lighting.sun.light_energy, "dapple remains subordinate to main authored sun")
	_expect(absf(spot.light_energy - director.profile.cinematic_energy) < 0.001, "Cinematic uses authored dapple energy")


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("PROJECTED_CANOPY_LIGHT_DIRECTOR_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PROJECTED_CANOPY_LIGHT_DIRECTOR_SMOKE_TEST: " + failure)
	get_tree().quit(1)
