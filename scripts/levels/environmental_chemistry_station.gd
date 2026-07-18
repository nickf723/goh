extends Node3D
class_name EnvironmentalChemistryStation

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")

@export var success_message: String = "Environmental chemistry complete: the world supplied both Ice and Fire."
@export var readout_refresh_interval: float = 0.1

@onready var water_patch: Node = get_node_or_null("WaterPatch")
@onready var frost_crystal: Node3D = get_node_or_null("FrostCrystalSource") as Node3D
@onready var brazier: Node3D = get_node_or_null("PushableBrazierSource") as Node3D
@onready var readout: Label3D = get_node_or_null("StateReadout") as Label3D

var refresh_timer: float = 0.0
var success_announced: bool = false


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	update_readout()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return

	refresh_timer = max(readout_refresh_interval, 0.04)
	update_readout()
	check_for_success()


func update_readout() -> void:
	if readout == null or water_patch == null:
		return

	var surface_data: Dictionary = {}
	if water_patch.has_method("get_debug_data"):
		surface_data = water_patch.get_debug_data()

	var state: String = str(surface_data.get("reaction_state", "normal"))
	var last_reaction: String = str(surface_data.get("last_reaction", "none"))
	var frost_data: Dictionary = get_emitter_data(frost_crystal)
	var fire_data: Dictionary = get_emitter_data(brazier)
	var distance_to_water: float = get_horizontal_distance(brazier, water_patch)

	readout.text = (
		"SURFACE: " + state.to_upper()
		+ "\nLAST: " + last_reaction.to_upper()
		+ "\nICE: " + format_source(frost_data)
		+ "\nFIRE: " + format_source(fire_data)
		+ "\nBRAZIER → WATER: " + str(snapped(distance_to_water, 0.05)) + "m"
	)
	readout.modulate = get_state_color(state)


func get_emitter_data(source: Node) -> Dictionary:
	if source == null or not source.has_method("get_emitter"):
		return {}
	var emitter: ElementEmitter = source.get_emitter()
	if emitter == null:
		return {}
	return emitter.get_debug_data()


func format_source(data: Dictionary) -> String:
	if data.is_empty():
		return "missing"
	var active_text: String = "active" if bool(data.get("active", false)) else "inactive"
	return (
		active_text
		+ " • " + str(data.get("mode", "unknown"))
		+ " • pulses " + str(data.get("pulses", 0))
	)


func get_horizontal_distance(a: Node3D, b: Node) -> float:
	if a == null:
		return -1.0
	var b_position: Vector3 = Vector3.ZERO
	if b is Node3D:
		b_position = (b as Node3D).global_position
	elif b.get_parent() is Node3D:
		b_position = (b.get_parent() as Node3D).global_position
	else:
		return -1.0

	var offset: Vector3 = a.global_position - b_position
	offset.y = 0.0
	return offset.length()


func check_for_success() -> void:
	if success_announced or water_patch == null or not water_patch.has_method("get_debug_data"):
		return

	var surface_data: Dictionary = water_patch.get_debug_data()
	if str(surface_data.get("last_reaction", "none")) != "steam_burst":
		return

	success_announced = true
	show_message(success_message)
	GameState.set_objective("Environmental sources can now participate in the elemental reaction system.")


func get_state_color(state: String) -> Color:
	match state:
		"frozen":
			return ElementVisuals.get_element_color("ice")
		"steaming":
			return ElementVisuals.get_element_color("steam")
		_:
			return ElementVisuals.get_element_color("neutral")


func reset_target() -> void:
	success_announced = false
	refresh_timer = 0.0
	call_deferred("update_readout")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var surface_data: Dictionary = {}
	if water_patch != null and water_patch.has_method("get_debug_data"):
		surface_data = water_patch.get_debug_data()
	return {
		"environment_chemistry_station": true,
		"surface": surface_data,
		"frost_source": get_emitter_data(frost_crystal),
		"fire_source": get_emitter_data(brazier),
		"brazier_distance": get_horizontal_distance(brazier, water_patch),
		"success": success_announced,
	}
