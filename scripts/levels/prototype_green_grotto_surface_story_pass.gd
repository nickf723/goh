extends "res://scripts/levels/prototype_green_grotto_motion_pass.gd"
class_name PrototypeGreenGrottoSurfaceStoryPass

var surface_story_director: SurfaceStoryDirector3D = null
var surface_story_counts: Dictionary = {
	"arrival": 0,
	"causeway": 0,
	"waterfall": 0,
	"shrine": 0,
	"ruins": 0,
}


func _ready() -> void:
	super._ready()
	surface_story_director = get_node_or_null(
		"SurfaceStoryDirector"
	) as SurfaceStoryDirector3D
	_build_surface_story()
	set_meta("surface_story_pass", "surface_story_director_v1")
	set_meta("surface_story_authority", "SurfaceStoryDirector")
	set_meta("surface_story_counts", surface_story_counts.duplicate(true))


func _build_surface_story() -> void:
	if surface_story_director == null:
		return
	_dress_arrival_history()
	_dress_causeway_history()
	_dress_water_geography()
	_dress_shrine_history()
	_dress_secondary_ruins()


func _dress_arrival_history() -> void:
	var wear_positions: Array[Vector3] = [
		Vector3(-1.9, 0.055, 15.1),
		Vector3(0.2, 0.055, 13.9),
		Vector3(1.8, 0.055, 12.6),
		Vector3(-1.1, 0.055, 11.3),
		Vector3(0.7, 0.055, 10.0),
	]
	for index: int in range(wear_positions.size()):
		_stamp_floor(
			"wear",
			wear_positions[index],
			Vector2(1.8, 1.25),
			0.18 + float(index) * 0.47,
			0.90,
			"ArrivalWear%02d" % index
		)
		surface_story_counts["arrival"] = int(surface_story_counts["arrival"]) + 1

	for index: int in range(4):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_stamp_floor(
			"grime",
			Vector3(side * (3.0 + float(index % 2) * 0.45), 0.06, 14.2 - float(index) * 1.55),
			Vector2(1.55, 1.15),
			float(index) * 0.81,
			0.72,
			"ArrivalEdgeGrime%02d" % index
		)
		surface_story_counts["arrival"] = int(surface_story_counts["arrival"]) + 1


func _dress_causeway_history() -> void:
	var slab_tops: Array[Vector3] = [
		Vector3(0.0, 0.315, 8.7),
		Vector3(-0.20, 0.435, 5.0),
		Vector3(0.18, 0.625, 2.05),
		Vector3(-0.28, 0.875, -0.55),
		Vector3(0.25, 1.065, -2.95),
		Vector3(0.04, 1.215, -5.15),
		Vector3(-0.12, 1.355, -7.20),
	]
	for index: int in range(slab_tops.size()):
		var center: Vector3 = slab_tops[index]
		_stamp_floor(
			"crack",
			center + Vector3(sin(float(index) * 1.4) * 0.65, 0.0, cos(float(index) * 0.9) * 0.32),
			Vector2(1.25 + float(index % 3) * 0.20, 1.70),
			float(index) * 0.69,
			0.94,
			"CausewayCrack%02d" % index
		)
		_stamp_floor(
			"wear",
			center + Vector3(-0.35 + float(index % 2) * 0.55, 0.006, 0.18),
			Vector2(1.75, 1.10),
			float(index) * 0.38,
			0.74,
			"CausewayWear%02d" % index
		)
		surface_story_counts["causeway"] = int(surface_story_counts["causeway"]) + 2
		if index in [1, 3, 5]:
			_stamp_floor(
				"moss",
				center + Vector3(-1.45, 0.010, -0.25),
				Vector2(1.05, 0.72),
				float(index) * 0.91,
				0.70,
				"CausewayJointMoss%02d" % index
			)
			surface_story_counts["causeway"] = int(surface_story_counts["causeway"]) + 1


func _dress_water_geography() -> void:
	var upper_wet: Array[Vector3] = [
		Vector3(4.85, 2.29, -7.8),
		Vector3(6.00, 2.29, -8.0),
		Vector3(6.85, 2.29, -8.9),
		Vector3(6.65, 2.29, -10.0),
		Vector3(5.55, 2.29, -10.5),
		Vector3(4.75, 2.29, -9.4),
	]
	for index: int in range(upper_wet.size()):
		_stamp_floor(
			"wet",
			upper_wet[index],
			Vector2(1.35, 1.15),
			float(index) * 0.61,
			0.94,
			"UpperStreamWet%02d" % index
		)
		surface_story_counts["waterfall"] = int(surface_story_counts["waterfall"]) + 1

	var lower_bank: Array[Vector3] = [
		Vector3(0.75, -5.03, -8.4),
		Vector3(1.15, -5.03, -10.2),
		Vector3(2.4, -5.03, -12.0),
		Vector3(5.2, -5.03, -12.0),
		Vector3(7.25, -5.03, -10.8),
		Vector3(7.45, -5.03, -8.2),
	]
	for index: int in range(lower_bank.size()):
		_stamp_floor(
			"wet",
			lower_bank[index],
			Vector2(1.6, 1.15),
			float(index) * 0.77,
			0.76,
			"LowerBasinWet%02d" % index
		)
		surface_story_counts["waterfall"] = int(surface_story_counts["waterfall"]) + 1

	for index: int in range(4):
		_stamp_wall(
			"wet",
			Vector3(5.15 + float(index) * 0.48, -0.8 - float(index % 2) * 0.25, -11.32),
			Vector3(0.0, 0.0, 1.0),
			Vector2(0.72, 2.8 + float(index % 2) * 0.5),
			0.04 * float(index),
			0.88,
			"WaterfallRunoff%02d" % index
		)
		surface_story_counts["waterfall"] = int(surface_story_counts["waterfall"]) + 1


func _dress_shrine_history() -> void:
	# Central ceremonial path is worn, while moss and grime prefer the margins.
	for index: int in range(7):
		_stamp_floor(
			"wear",
			Vector3(
				-0.35 + sin(float(index) * 1.2) * 0.32,
				2.335,
				-11.7 - float(index) * 0.86
			),
			Vector2(1.45, 1.02),
			float(index) * 0.42,
			0.82,
			"ShrinePathWear%02d" % index
		)
		surface_story_counts["shrine"] = int(surface_story_counts["shrine"]) + 1

	for index: int in range(8):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		_stamp_floor(
			"moss" if index % 3 != 0 else "grime",
			Vector3(
				side * (4.0 + float(index % 3) * 0.52),
				2.34,
				-12.0 - float(index % 4) * 1.55
			),
			Vector2(1.35 + float(index % 2) * 0.28, 0.92),
			float(index) * 0.58,
			0.74,
			"ShrineEdgeAge%02d" % index
		)
		surface_story_counts["shrine"] = int(surface_story_counts["shrine"]) + 1

	# Protected rear-wall motifs survive better than the exposed paving.
	for index: int in range(5):
		var x_value: float = -3.8 + float(index) * 1.9
		_stamp_wall(
			"carving",
			Vector3(x_value, 4.35 + float(index % 2) * 0.26, -17.50),
			Vector3(0.0, 0.0, 1.0),
			Vector2(1.10, 1.18),
			float(index) * 0.27,
			0.82,
			"ShrineCarving%02d" % index
		)
		_stamp_wall(
			"grime",
			Vector3(x_value + 0.25, 3.10, -17.49),
			Vector3(0.0, 0.0, 1.0),
			Vector2(1.45, 1.05),
			float(index) * 0.49,
			0.62,
			"ShrineWallGrime%02d" % index
		)
		surface_story_counts["shrine"] = int(surface_story_counts["shrine"]) + 2

	for index: int in range(5):
		_stamp_floor(
			"wear",
			Vector3(0.0, 1.22 + float(index) * 0.30, -9.0 - float(index) * 0.72),
			Vector2(2.2 - float(index) * 0.12, 0.55),
			0.0,
			0.70,
			"ShrineStepWear%02d" % index
		)
		surface_story_counts["shrine"] = int(surface_story_counts["shrine"]) + 1


func _dress_secondary_ruins() -> void:
	# The leaning monolith carries the clearest surviving non-shrine marks.
	for index: int in range(3):
		_stamp_wall(
			"carving",
			Vector3(-6.92, 1.6 + float(index) * 1.35, 7.0),
			Vector3(0.0, 0.0, -1.0),
			Vector2(0.72, 0.82),
			float(index) * 0.31,
			0.76,
			"MonolithCarving%02d" % index
		)
		surface_story_counts["ruins"] = int(surface_story_counts["ruins"]) + 1

	for index: int in range(5):
		_stamp_floor(
			"moss",
			Vector3(-7.7 + float(index) * 0.70, 1.58, -5.7 + float(index % 2) * 1.1),
			Vector2(1.0, 0.72),
			float(index) * 0.73,
			0.72,
			"LeftTerraceMoss%02d" % index
		)
		surface_story_counts["ruins"] = int(surface_story_counts["ruins"]) + 1


func _stamp_floor(
	kind: String,
	position_value: Vector3,
	footprint: Vector2,
	rotation_radians: float,
	intensity: float,
	label: String
) -> void:
	surface_story_director.create_stamp(
		kind,
		position_value,
		Vector3.UP,
		footprint,
		rotation_radians,
		intensity,
		-1.0,
		label
	)


func _stamp_wall(
	kind: String,
	position_value: Vector3,
	normal: Vector3,
	footprint: Vector2,
	rotation_radians: float,
	intensity: float,
	label: String
) -> void:
	surface_story_director.create_stamp(
		kind,
		position_value,
		normal,
		footprint,
		rotation_radians,
		intensity,
		-1.0,
		label
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_surface_story"] = true
	data["surface_story_authority"] = "SurfaceStoryDirector"
	data["surface_story_counts"] = surface_story_counts.duplicate(true)
	data["story_logic"] = "traffic + stress + water + shade + age + human history"
	return data
