extends "res://scripts/levels/prototype_green_grotto_material_pass.gd"
class_name PrototypeGreenGrottoWaterPass

var water_presentation_director: WaterPresentationDirector3D = null
var water_presentation_counts: Dictionary = {
	"stream": 0,
	"basin": 0,
	"waterfall": 0,
}


func _ready() -> void:
	super._ready()
	water_presentation_director = get_node_or_null(
		"WaterPresentationDirector"
	) as WaterPresentationDirector3D
	_register_water_presentation()
	set_meta("water_presentation_pass", "water_presentation_director_v1")
	set_meta("water_presentation_authority", "WaterPresentationDirector")
	set_meta("water_presentation_counts", water_presentation_counts.duplicate(true))


func _register_water_presentation() -> void:
	if water_presentation_director == null:
		return
	var water_root: Node = get_node_or_null(
		"GreenGrottoArt/HeroPassV3/HeroWater"
	)
	if water_root == null:
		return

	var upper_stream: MeshInstance3D = water_root.get_node_or_null(
		"V3UpperStream"
	) as MeshInstance3D
	if upper_stream != null and water_presentation_director.register_surface(
		upper_stream,
		"stream",
		Vector2(0.08, -1.0),
		0.82
	):
		water_presentation_counts["stream"] = 1

	var lower_basin: MeshInstance3D = water_root.get_node_or_null(
		"V3LowerBasin"
	) as MeshInstance3D
	if lower_basin != null and water_presentation_director.register_surface(
		lower_basin,
		"basin",
		Vector2(-0.35, 0.48),
		0.24
	):
		water_presentation_counts["basin"] = 1

	for index: int in range(4):
		var waterfall: MeshInstance3D = water_root.get_node_or_null(
			"V3WaterfallSheet%02d" % index
		) as MeshInstance3D
		if waterfall == null:
			continue
		if water_presentation_director.register_surface(
			waterfall,
			"waterfall"
		):
			water_presentation_counts["waterfall"] = int(
				water_presentation_counts["waterfall"]
			) + 1


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_water_presentation"] = true
	data["water_presentation_authority"] = "WaterPresentationDirector"
	data["water_presentation_counts"] = water_presentation_counts.duplicate(true)
	data["water_chain"] = "upper stream -> directional fall -> depth-tinted basin"
	data["water_geometry_unchanged"] = true
	return data
