extends "res://scripts/levels/prototype_green_grotto_shadow_pass.gd"
class_name PrototypeGreenGrottoReflectionPass

const VisualBenchmarkDirectorScript = preload(
	"res://scripts/testing/visual_benchmark_director.gd"
)
const EnvironmentalMotionInfluencerScript = preload(
	"res://scripts/environmental_motion/environmental_motion_influencer_3d.gd"
)

var reflection_fidelity_director: ReflectionFidelityDirector3D = null
var visual_benchmark_director: VisualBenchmarkDirector = null
var grace_motion_influencer: EnvironmentalMotionInfluencer3D = null


func _ready() -> void:
	super._ready()
	reflection_fidelity_director = get_node_or_null(
		"ReflectionFidelityDirector"
	) as ReflectionFidelityDirector3D
	if reflection_fidelity_director != null:
		reflection_fidelity_director.call_deferred("synchronize_now")
	_ensure_grace_motion_influencer()
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
	set_meta("grace_environment_interaction", grace_motion_influencer != null)


func _ensure_grace_motion_influencer() -> void:
	var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
	if player == null:
		return
	grace_motion_influencer = player.get_node_or_null(
		"EnvironmentalMotionInfluencer"
	) as EnvironmentalMotionInfluencer3D
	if grace_motion_influencer == null:
		grace_motion_influencer = (
			EnvironmentalMotionInfluencerScript.new()
			as EnvironmentalMotionInfluencer3D
		)
		grace_motion_influencer.name = "EnvironmentalMotionInfluencer"
		grace_motion_influencer.channel = "green_grotto_motion"
		grace_motion_influencer.radius = 1.85
		grace_motion_influencer.body_radius = 0.38
		grace_motion_influencer.vertical_half_extent = 1.55
		grace_motion_influencer.base_strength = 0.48
		grace_motion_influencer.velocity_strength = 0.56
		grace_motion_influencer.velocity_reference = 5.4
		grace_motion_influencer.maximum_strength = 1.48
		grace_motion_influencer.wake_direction_influence = 0.34
		player.add_child(grace_motion_influencer)
	var motion_director: EnvironmentalMotionDirector3D = get_node_or_null(
		"EnvironmentalMotionDirector"
	) as EnvironmentalMotionDirector3D
	if motion_director != null:
		motion_director.call_deferred("_refresh_influencers")


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
	data["grace_environment_interaction"] = grace_motion_influencer != null
	data["environment_interaction_strategy"] = (
		"player proximity + velocity feed the existing motion authority"
	)
	return data
