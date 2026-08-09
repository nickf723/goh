extends "res://scripts/levels/prototype_green_grotto_shadow_pass.gd"
class_name PrototypeGreenGrottoReflectionPass

const VisualBenchmarkDirectorScript = preload(
	"res://scripts/testing/visual_benchmark_director.gd"
)

var reflection_fidelity_director: ReflectionFidelityDirector3D = null
var visual_benchmark_director: VisualBenchmarkDirector = null


func _ready() -> void:
	super._ready()
	reflection_fidelity_director = get_node_or_null(
		"ReflectionFidelityDirector"
	) as ReflectionFidelityDirector3D
	if reflection_fidelity_director != null:
		reflection_fidelity_director.call_deferred("synchronize_now")
	_ensure_visual_benchmark_director()
	set_meta("reflection_fidelity_pass", "reflection_fidelity_director_v1")
	set_meta("reflection_fidelity_authority", "ReflectionFidelityDirector")
	set_meta("reflection_regions", [
		"entrance_hollow",
		"canopy_vista",
		"waterfall_bowl",
		"shrine_court",
	])
	set_meta("visual_benchmark_presets", ["BASELINE", "BALANCED", "HERO"])


func _ensure_visual_benchmark_director() -> void:
	visual_benchmark_director = get_node_or_null(
		"VisualBenchmarkDirector"
	) as VisualBenchmarkDirector
	if visual_benchmark_director != null:
		return
	visual_benchmark_director = (
		VisualBenchmarkDirectorScript.new()
		as VisualBenchmarkDirector
	)
	visual_benchmark_director.name = "VisualBenchmarkDirector"
	visual_benchmark_director.debug_hotkeys_enabled = true
	visual_benchmark_director.overlay_enabled = true
	add_child(visual_benchmark_director)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_reflection_fidelity"] = true
	data["reflection_fidelity_authority"] = "ReflectionFidelityDirector"
	data["reflection_strategy"] = (
		"local update-once captures blended with SSR/SDFGI"
	)
	data["reflection_geometry_unchanged"] = true
	data["visual_benchmark_director"] = visual_benchmark_director != null
	return data
