extends Area3D
class_name StatLabStation

@export var stat_id: String = "stamina"
@export_enum(
	"baseline",
	"boost",
	"overcharge",
	"infinite",
	"set",
	"minimum",
	"full",
	"damage",
	"select_previous",
	"select_next",
	"selected_baseline",
	"selected_boost",
	"selected_overcharge",
	"reset_all",
	"exit"
)
var action: String = "overcharge"
@export var action_value: int = 0
@export var display_name: String = "STAT STATION"
@export var action_context: String = ""
@export var prompt_text: String = "Activate Station"
@export var accent_color: Color = Color(0.58, 0.34, 1.0, 1.0)

@onready var title_label: Label3D = get_node_or_null("TitleLabel") as Label3D
@onready var detail_label: Label3D = get_node_or_null("DetailLabel") as Label3D
@onready var trim_mesh: MeshInstance3D = get_node_or_null("Trim") as MeshInstance3D
@onready var core_mesh: MeshInstance3D = get_node_or_null("Core") as MeshInstance3D


func _ready() -> void:
	add_to_group("stat_lab_station")
	add_to_group("debuggable")
	apply_accent_materials()
	refresh_station()


func interact() -> Dictionary:
	var director: Node = get_tree().get_first_node_in_group("runtime_stat_lab_director")
	if director == null or not director.has_method("activate_station"):
		return {
			"message": "The station has no active laboratory director.",
			"objective": "Run the Runtime Stat Laboratory scene.",
		}

	return director.call("activate_station", self)


func get_station_request() -> Dictionary:
	return {
		"stat_id": stat_id,
		"action": action,
		"value": action_value,
		"context": action_context,
		"display_name": display_name,
	}


func refresh_from_session(session: RuntimeStatLabSession) -> void:
	if session == null:
		refresh_station()
		return

	var status: String = "SYSTEM"
	var value_text: String = ""

	if action != "reset_all" and action != "exit":
		status = session.get_implementation_status(stat_id)
		value_text = session.get_stat_value_text(stat_id)

	if title_label != null:
		title_label.text = display_name.to_upper()
		title_label.modulate = accent_color

	if detail_label != null:
		var infinite_suffix: String = ""
		if session.is_infinite(stat_id):
			infinite_suffix = " • INFINITE"

		detail_label.text = (
			get_action_display_name()
			+ "\n"
			+ status
			+ infinite_suffix
			+ (" • " + value_text if value_text != "" else "")
		)


func refresh_station() -> void:
	if title_label != null:
		title_label.text = display_name.to_upper()
		title_label.modulate = accent_color

	if detail_label != null:
		detail_label.text = get_action_display_name()


func get_action_display_name() -> String:
	match action:
		"baseline":
			return "RESTORE BASELINE"
		"boost":
			return "SET TO 10"
		"overcharge":
			return "SET TO 1000"
		"infinite":
			return "TOGGLE INFINITE"
		"set":
			return "SET TO " + str(action_value)
		"minimum":
			return "SET CURRENT TO " + str(max(action_value, 1))
		"full":
			return "RESTORE TO FULL"
		"damage":
			return (action_context.to_upper() + " " if action_context != "" else "") + "-" + str(max(action_value, 1))
		"select_previous":
			return "PREVIOUS SELECTED STAT"
		"select_next":
			return "NEXT SELECTED STAT"
		"selected_baseline":
			return "SELECTED → BASELINE"
		"selected_boost":
			return "SELECTED → 10"
		"selected_overcharge":
			return "SELECTED → 1000"
		"reset_all":
			return "RESTORE ENTRY SNAPSHOT"
		"exit":
			return "RESTORE AND LEAVE"
		_:
			return action.to_upper()


func apply_accent_materials() -> void:
	if trim_mesh != null:
		trim_mesh.material_override = make_material(accent_color, true)

	if core_mesh != null:
		var core_color: Color = accent_color.lightened(0.22)
		core_mesh.material_override = make_material(core_color, true)


func make_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.55
	material.roughness = 0.32

	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b, 1.0)
		material.emission_energy_multiplier = 0.8

	return material


func get_debug_data() -> Dictionary:
	return get_station_request()
