extends "res://scripts/levels/prototype_green_grotto_lighting_pass.gd"
class_name PrototypeGreenGrottoMotionPass

var environmental_motion_director: EnvironmentalMotionDirector3D = null
var motion_registration_counts: Dictionary = {
	"foliage": 0,
	"canopy": 0,
	"vine": 0,
	"water": 0,
	"waterfall": 0,
}


func _ready() -> void:
	super._ready()
	environmental_motion_director = get_node_or_null(
		"EnvironmentalMotionDirector"
	) as EnvironmentalMotionDirector3D
	_register_environment_motion_targets()
	set_meta("environmental_motion_pass", "environmental_motion_director_v1")
	set_meta("environmental_motion_authority", "EnvironmentalMotionDirector")
	set_meta("motion_registration_counts", motion_registration_counts.duplicate(true))


func _register_environment_motion_targets() -> void:
	if environmental_motion_director == null:
		return
	_register_prehistoric_foliage()
	_register_canopy_motion()
	_register_water_motion()


func _register_prehistoric_foliage() -> void:
	if foliage_root == null:
		return
	for child: Node in foliage_root.get_children():
		if not child is Node3D:
			continue
		var target: Node3D = child as Node3D
		var target_name: String = str(target.name)
		var strength: float = 0.0
		var frequency: float = 1.0
		if target_name.begins_with("Fern"):
			strength = 1.0
			frequency = 1.06
		elif target_name.begins_with("Cycad"):
			strength = 0.82
			frequency = 0.82
		elif target_name.begins_with("GroundLeaf"):
			strength = 0.58
			frequency = 1.24
		else:
			continue
		if environmental_motion_director.register_target(
			target,
			"foliage",
			strength,
			_phase_for_node(target),
			0.92,
			frequency
		):
			motion_registration_counts["foliage"] = int(motion_registration_counts["foliage"]) + 1


func _register_canopy_motion() -> void:
	if canopy_root == null:
		return
	for child: Node in canopy_root.get_children():
		if not child is Node3D:
			continue
		var target: Node3D = child as Node3D
		var target_name: String = str(target.name)
		if target_name.begins_with("CanopyCrown") or target_name.begins_with("CanopyInner"):
			if environmental_motion_director.register_target(
				target,
				"canopy",
				0.72,
				_phase_for_node(target),
				0.38,
				0.46
			):
				motion_registration_counts["canopy"] = int(motion_registration_counts["canopy"]) + 1
		elif target_name.begins_with("HangingVine"):
			if environmental_motion_director.register_target(
				target,
				"vine",
				0.74,
				_phase_for_node(target),
				1.15,
				0.72
			):
				motion_registration_counts["vine"] = int(motion_registration_counts["vine"]) + 1


func _register_water_motion() -> void:
	if hero_water_root == null:
		return
	for child: Node in hero_water_root.get_children():
		if not child is Node3D:
			continue
		var target: Node3D = child as Node3D
		var target_name: String = str(target.name)
		if target_name == "V3UpperStream" or target_name == "V3LowerBasin":
			if environmental_motion_director.register_target(
				target,
				"water",
				0.72 if target_name == "V3UpperStream" else 0.48,
				_phase_for_node(target),
				0.18,
				0.42
			):
				motion_registration_counts["water"] = int(motion_registration_counts["water"]) + 1
		elif target_name.begins_with("V3WaterfallSheet"):
			if environmental_motion_director.register_target(
				target,
				"waterfall",
				0.78,
				_phase_for_node(target),
				0.42,
				0.88
			):
				motion_registration_counts["waterfall"] = int(motion_registration_counts["waterfall"]) + 1


func _phase_for_node(node: Node) -> float:
	if node == null:
		return 0.0
	var node_id: int = node.get_instance_id()
	return fmod(float(abs(node_id % 1009)) / 1009.0 * TAU, TAU)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_environmental_motion"] = true
	data["environmental_motion_authority"] = "EnvironmentalMotionDirector"
	data["motion_registration_counts"] = motion_registration_counts.duplicate(true)
	data["visual_ambient_wind_only"] = true
	data["wind_well_can_drive_environment_motion"] = true
	return data
