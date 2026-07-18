extends Node3D
class_name PhysicalInteractionLab

@export var readout_refresh_interval: float = 0.1

@onready var magnetic_field: MagneticDipoleField = get_node_or_null("MagneticCore") as MagneticDipoleField
@onready var permanent_magnet: FieldResponsiveBody = get_node_or_null("PermanentMagnetBar") as FieldResponsiveBody
@onready var iron_slug: FieldResponsiveBody = get_node_or_null("IronSlug") as FieldResponsiveBody
@onready var copper_block: FieldResponsiveBody = get_node_or_null("CopperBlock") as FieldResponsiveBody
@onready var readout: Label3D = get_node_or_null("FieldReadout") as Label3D
@onready var player: Node3D = get_node_or_null("Player") as Node3D

var refresh_timer: float = 0.0
var initial_player_transform: Transform3D


func _ready() -> void:
	add_to_group("debuggable")
	if player != null:
		initial_player_transform = player.transform
	GameState.set_objective("Compare polarity alignment, iron attraction, and nonmagnetic copper.")
	update_readout()


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = max(readout_refresh_interval, 0.04)
	update_readout()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			reset_lab()


func reset_lab() -> void:
	for resettable: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if resettable == null or not is_ancestor_of(resettable):
			continue
		if resettable.has_method("reset_target"):
			resettable.reset_target()
	if player != null:
		player.transform = initial_player_transform
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	refresh_timer = 0.0
	call_deferred("update_readout")
	show_message("Physical interaction laboratory reset.")


func update_readout() -> void:
	if readout == null:
		return
	var polarity: String = "N →" if magnetic_field != null and magnetic_field.polarity >= 0.0 else "← N"
	var magnet_data: Dictionary = get_body_response(permanent_magnet)
	var iron_data: Dictionary = get_body_response(iron_slug)
	var copper_data: Dictionary = get_body_response(copper_block)
	readout.text = (
		"FIELD POLARITY: " + polarity
		+ "\nMAGNET  torque " + format_vector_magnitude(magnet_data.get("torque", Vector3.ZERO))
		+ "  force " + format_vector_magnitude(magnet_data.get("force", Vector3.ZERO))
		+ "\nIRON      magnetization " + format_vector_magnitude(magnet_data.get("induced", Vector3.ZERO) if false else iron_data.get("induced", Vector3.ZERO))
		+ "  force " + format_vector_magnitude(iron_data.get("force", Vector3.ZERO))
		+ "\nCOPPER  conductivity 1.00  magnetic force " + format_vector_magnitude(copper_data.get("force", Vector3.ZERO))
	)


func get_body_response(body: FieldResponsiveBody) -> Dictionary:
	if body == null:
		return {}
	var field_receiver: PhysicalFieldReceiver = body.get_node_or_null("PhysicalFieldReceiver") as PhysicalFieldReceiver
	if field_receiver == null:
		return {}
	return {
		"field": field_receiver.last_total_field,
		"force": field_receiver.last_total_force,
		"torque": field_receiver.last_total_torque,
		"induced": field_receiver.induced_magnetization,
	}


func format_vector_magnitude(raw_value: Variant) -> String:
	if not raw_value is Vector3:
		return "0.00"
	return str(snapped((raw_value as Vector3).length(), 0.01))


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"physical_interaction_lab": true,
		"field": magnetic_field.get_debug_data() if magnetic_field != null else {},
		"permanent_magnet": permanent_magnet.get_debug_data() if permanent_magnet != null else {},
		"iron": iron_slug.get_debug_data() if iron_slug != null else {},
		"copper": copper_block.get_debug_data() if copper_block != null else {},
	}
