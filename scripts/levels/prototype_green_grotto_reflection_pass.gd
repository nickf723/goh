extends "res://scripts/levels/prototype_green_grotto_shadow_pass.gd"
class_name PrototypeGreenGrottoReflectionPass

const VisualBenchmarkDirectorScript = preload(
	"res://scripts/testing/visual_benchmark_director.gd"
)
const EnvironmentalMotionInfluencerScript = preload(
	"res://scripts/environmental_motion/environmental_motion_influencer_3d.gd"
)
const AtmosphericDetailDirectorScript = preload(
	"res://scripts/atmosphere/atmospheric_detail_director_3d.gd"
)
const GreenGrottoAtmosphereProfile = preload(
	"res://data/atmosphere/green_grotto_atmospheric_detail.tres"
)

var reflection_fidelity_director: ReflectionFidelityDirector3D = null
var visual_benchmark_director: VisualBenchmarkDirector = null
var grace_motion_influencer: EnvironmentalMotionInfluencer3D = null
var atmospheric_detail_director: AtmosphericDetailDirector3D = null


func _ready() -> void:
	super._ready()
	reflection_fidelity_director = get_node_or_null(
		"ReflectionFidelityDirector"
	) as ReflectionFidelityDirector3D
	if reflection_fidelity_director != null:
		reflection_fidelity_director.call_deferred("synchronize_now")
	_ensure_grace_motion_influencer()
	_ensure_atmospheric_detail_director()
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
	set_meta("atmospheric_detail", atmospheric_detail_director != null)


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


func _ensure_atmospheric_detail_director() -> void:
	atmospheric_detail_director = get_node_or_null(
		"AtmosphericDetailDirector"
	) as AtmosphericDetailDirector3D
	if atmospheric_detail_director != null:
		return
	atmospheric_detail_director = (
		AtmosphericDetailDirectorScript.new()
		as AtmosphericDetailDirector3D
	)
	atmospheric_detail_director.name = "AtmosphericDetailDirector"
	atmospheric_detail_director.profile = GreenGrottoAtmosphereProfile
	add_child(atmospheric_detail_director)

	atmospheric_detail_director.add_field(
		"EntranceDustField",
		Vector3(0.0, 4.2, 12.5),
		Vector3(6.2, 3.4, 5.2),
		"dust",
		70,
		Color(0.82, 0.70, 0.45, 0.11),
		0.028,
		0.058,
		0.20,
		0.008,
		1
	)
	atmospheric_detail_director.add_field(
		"CanopyPollenField",
		Vector3(0.0, 7.0, 0.5),
		Vector3(8.0, 5.5, 9.5),
		"pollen",
		170,
		Color(1.0, 0.71, 0.25, 0.16),
		0.034,
		0.074,
		0.36,
		0.018,
		1
	)
	atmospheric_detail_director.add_field(
		"WaterfallMistField",
		Vector3(5.8, -0.8, -9.2),
		Vector3(4.2, 5.0, 4.2),
		"mist",
		150,
		Color(0.62, 0.88, 0.80, 0.085),
		0.075,
		0.17,
		0.24,
		0.14,
		1
	)
	atmospheric_detail_director.add_field(
		"ShrineMoteField",
		Vector3(0.0, 5.2, -15.0),
		Vector3(6.8, 3.8, 5.8),
		"dust",
		70,
		Color(1.0, 0.58, 0.24, 0.095),
		0.026,
		0.055,
		0.16,
		0.006,
		2
	)


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
	data["atmospheric_detail"] = atmospheric_detail_director != null
	data["atmospheric_detail_strategy"] = (
		"quality-scaled MultiMesh motes sampling the environment motion wind"
	)
	return data
