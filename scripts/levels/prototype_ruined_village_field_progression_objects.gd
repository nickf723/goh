extends "res://scripts/levels/prototype_ruined_village_field_progression.gd"
class_name PrototypeRuinedVillageFieldProgressionObjects

const RecordableWorldObjectScript = preload(
	"res://scripts/interaction/recordable_world_object.gd"
)

var recorded_object_sources_root: Node3D


func _ready() -> void:
	await super._ready()
	_build_recorded_object_sources()


func _build_recorded_object_sources() -> void:
	if get_node_or_null("FieldProgression/RecordedObjectSources") != null:
		return
	recorded_object_sources_root = Node3D.new()
	recorded_object_sources_root.name = "RecordedObjectSources"
	field_root.add_child(recorded_object_sources_root)

	_create_recordable_source(
		"HerbalistSupplyCrate",
		"crate",
		Vector3(-6.2, 3.12, 15.2),
		0.0,
		"Study the herbalist's supply crate",
		"Try reproducing the crate as a step, weight, or movable obstacle."
	)
	_create_recordable_source(
		"RavineScaffoldPlatform",
		"platform",
		Vector3(7.5, 6.12, -41.2),
		90.0,
		"Study the collapsed scaffold panel",
		"A recorded platform can create temporary footing where the old route failed."
	)

	var hint := Label3D.new()
	hint.name = "RecordedObjectFieldHint"
	hint.position = Vector3(-6.2, 6.0, 15.2)
	hint.text = "RECORDED OBJECT\nStudy a useful shape, then reproduce it elsewhere"
	hint.font_size = 24
	hint.pixel_size = 0.0065
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.outline_size = 7
	hint.modulate = Color(0.56, 0.86, 1.0, 1.0)
	recorded_object_sources_root.add_child(hint)


func _create_recordable_source(
	node_name: String,
	blueprint_id: String,
	position_value: Vector3,
	yaw_degrees: float,
	prompt: String,
	objective_after: String
) -> void:
	var source := Area3D.new()
	source.name = node_name
	source.set_script(RecordableWorldObjectScript)
	source.set("blueprint_id", blueprint_id)
	source.set("prompt_text", prompt)
	source.set("objective_after", objective_after)
	source.position = position_value
	source.rotation_degrees.y = yaw_degrees
	recorded_object_sources_root.add_child(source)


func get_field_progression_debug_data() -> Dictionary:
	var data: Dictionary = super.get_field_progression_debug_data()
	data["recorded_object_sources"] = (
		recorded_object_sources_root.get_child_count()
		if recorded_object_sources_root != null
		else 0
	)
	data["crate_source"] = get_node_or_null(
		"FieldProgression/RecordedObjectSources/HerbalistSupplyCrate"
	) != null
	data["platform_source"] = get_node_or_null(
		"FieldProgression/RecordedObjectSources/RavineScaffoldPlatform"
	) != null
	return data
