extends Area3D
class_name MagneticPolaritySwitch

@export var field_path: NodePath
@export var positive_text: String = "POLARITY: N →"
@export var negative_text: String = "POLARITY: ← N"

@onready var label: Label3D = get_node_or_null("Label3D") as Label3D

var initial_polarity: float = 1.0


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	var field: MagneticDipoleField = get_field()
	if field != null:
		initial_polarity = field.polarity
	update_label()


func interact() -> Dictionary:
	var field: MagneticDipoleField = get_field()
	if field == null:
		return {
			"message": "The polarity switch cannot find its magnetic field.",
			"objective": "",
		}
	field.reverse_polarity()
	update_label()
	return {
		"message": "Current direction reverses. The magnetic poles swap.",
		"objective": "Observe force and torque after the field reverses.",
	}


func get_field() -> MagneticDipoleField:
	return get_node_or_null(field_path) as MagneticDipoleField


func update_label() -> void:
	if label == null:
		return
	var field: MagneticDipoleField = get_field()
	if field == null:
		label.text = "POLARITY: FIELD MISSING"
		return
	label.text = positive_text if field.polarity >= 0.0 else negative_text


func reset_target() -> void:
	var field: MagneticDipoleField = get_field()
	if field != null:
		field.polarity = initial_polarity
	update_label()


func get_debug_data() -> Dictionary:
	var field: MagneticDipoleField = get_field()
	return {
		"polarity_switch": true,
		"field": field.field_id if field != null else "missing",
		"polarity": field.polarity if field != null else 0.0,
	}
