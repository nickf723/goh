extends "res://scripts/visuals/grace_0_5_blockout_model_v8.gd"
class_name Grace05BlockoutModelV9

# V9 uses the modular proxy's split robe as intended: rigid panels get small
# context-specific corrections after bone following/secondary motion so extreme
# poses do not force them directly through the thighs.

@export_group("Context Clothing")
@export_range(0.0, 28.0, 0.5) var crouch_panel_lift_degrees: float = 11.0
@export_range(0.0, 28.0, 0.5) var climb_panel_trail_degrees: float = 10.0
@export_range(0.0, 36.0, 0.5) var swim_panel_trail_degrees: float = 18.0
@export_range(0.0, 36.0, 0.5) var riding_panel_spread_degrees: float = 15.0

var clothing_stealth: PlayerStealthController
var clothing_climb: PlayerClimbingController
var clothing_swim: PlayerSwimmingController
var clothing_ride: PlayerRidingController
var last_clothing_context: String = "ordinary"


func _process(delta: float) -> void:
	super._process(delta)
	_resolve_clothing_controllers()
	_apply_context_clothing()


func _resolve_clothing_controllers() -> void:
	if secondary_actor == null:
		return
	if clothing_stealth == null:
		clothing_stealth = secondary_actor.get_node_or_null(
			"StealthController"
		) as PlayerStealthController
	if clothing_climb == null:
		clothing_climb = secondary_actor.get_node_or_null(
			"ClimbingController"
		) as PlayerClimbingController
	if clothing_swim == null:
		clothing_swim = secondary_actor.get_node_or_null(
			"SwimmingController"
		) as PlayerSwimmingController
	if clothing_ride == null:
		clothing_ride = secondary_actor.get_node_or_null(
			"RidingController"
		) as PlayerRidingController


func _apply_context_clothing() -> void:
	last_clothing_context = "ordinary"
	if clothing_ride != null and clothing_ride.is_riding():
		last_clothing_context = "riding"
		_apply_riding_clothing()
		return
	if clothing_climb != null and clothing_climb.should_handle_locomotion():
		last_clothing_context = "mantle" if clothing_climb.mantling else "climbing"
		_apply_climb_clothing(clothing_climb.mantling)
		return
	if clothing_swim != null and clothing_swim.should_handle_locomotion():
		last_clothing_context = "swim_underwater" if clothing_swim.underwater else "swim_surface"
		_apply_swim_clothing(clothing_swim.underwater)
		return
	if clothing_stealth != null and clothing_stealth.is_crouched():
		last_clothing_context = "crouched"
		_apply_crouch_clothing()


func _apply_crouch_clothing() -> void:
	# Lift the front hem slightly and split it around the raised knees.
	_add_part_rotation("FrontPanelLeft", Vector3(
		deg_to_rad(crouch_panel_lift_degrees),
		deg_to_rad(-3.0),
		deg_to_rad(-4.0)
	))
	_add_part_rotation("FrontPanelRight", Vector3(
		deg_to_rad(crouch_panel_lift_degrees),
		deg_to_rad(3.0),
		deg_to_rad(4.0)
	))
	_add_part_rotation("SidePanelLeft", Vector3(
		deg_to_rad(crouch_panel_lift_degrees * 0.55),
		0.0,
		deg_to_rad(-5.0)
	))
	_add_part_rotation("SidePanelRight", Vector3(
		deg_to_rad(crouch_panel_lift_degrees * 0.55),
		0.0,
		deg_to_rad(5.0)
	))
	_add_part_rotation("BackRobePanel", Vector3(
		deg_to_rad(-crouch_panel_lift_degrees * 0.45),
		0.0,
		0.0
	))


func _apply_climb_clothing(mantling: bool) -> void:
	var strength: float = 1.35 if mantling else 1.0
	var trail: float = climb_panel_trail_degrees * strength
	for part_name: String in ["FrontPanelLeft", "FrontPanelRight"]:
		_add_part_rotation(part_name, Vector3(deg_to_rad(-trail), 0.0, 0.0))
	_add_part_rotation("SidePanelLeft", Vector3(deg_to_rad(-trail * 0.75), 0.0, deg_to_rad(-3.5 * strength)))
	_add_part_rotation("SidePanelRight", Vector3(deg_to_rad(-trail * 0.75), 0.0, deg_to_rad(3.5 * strength)))
	_add_part_rotation("BackRobePanel", Vector3(deg_to_rad(trail * 0.62), 0.0, 0.0))
	_add_part_rotation("SashTailLeft", Vector3(deg_to_rad(trail * 0.8), 0.0, deg_to_rad(-3.0)))
	_add_part_rotation("SashTailRight", Vector3(deg_to_rad(trail * 0.72), 0.0, deg_to_rad(3.0)))


func _apply_swim_clothing(underwater: bool) -> void:
	var strength: float = 1.0 if underwater else 0.7
	var trail: float = swim_panel_trail_degrees * strength
	# Water motion trails loose cloth toward Grace's feet/back rather than letting
	# the panels retain their terrestrial vertical hang.
	_add_part_rotation("FrontPanelLeft", Vector3(deg_to_rad(-trail), 0.0, deg_to_rad(-2.5 * strength)))
	_add_part_rotation("FrontPanelRight", Vector3(deg_to_rad(-trail), 0.0, deg_to_rad(2.5 * strength)))
	_add_part_rotation("SidePanelLeft", Vector3(deg_to_rad(-trail * 0.8), 0.0, deg_to_rad(-4.0 * strength)))
	_add_part_rotation("SidePanelRight", Vector3(deg_to_rad(-trail * 0.8), 0.0, deg_to_rad(4.0 * strength)))
	_add_part_rotation("BackRobePanel", Vector3(deg_to_rad(-trail * 0.55), 0.0, 0.0))
	_add_part_rotation("SashTailLeft", Vector3(deg_to_rad(-trail * 1.25), deg_to_rad(-4.0 * strength), deg_to_rad(-4.0 * strength)))
	_add_part_rotation("SashTailRight", Vector3(deg_to_rad(-trail * 1.15), deg_to_rad(4.0 * strength), deg_to_rad(4.0 * strength)))


func _apply_riding_clothing() -> void:
	var spread: float = riding_panel_spread_degrees
	_add_part_rotation("FrontPanelLeft", Vector3(deg_to_rad(5.0), 0.0, deg_to_rad(-spread)))
	_add_part_rotation("FrontPanelRight", Vector3(deg_to_rad(5.0), 0.0, deg_to_rad(spread)))
	_add_part_rotation("SidePanelLeft", Vector3(deg_to_rad(3.0), 0.0, deg_to_rad(-spread * 0.8)))
	_add_part_rotation("SidePanelRight", Vector3(deg_to_rad(3.0), 0.0, deg_to_rad(spread * 0.8)))
	_add_part_rotation("BackRobePanel", Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	_add_part_rotation("SashTailLeft", Vector3(deg_to_rad(-12.0), 0.0, deg_to_rad(-6.0)))
	_add_part_rotation("SashTailRight", Vector3(deg_to_rad(-11.0), 0.0, deg_to_rad(6.0)))


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["grace_0_5_context_clothing_v9"] = true
	data["clothing_context"] = last_clothing_context
	return data
