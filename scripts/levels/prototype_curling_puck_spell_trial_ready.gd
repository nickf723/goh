extends "res://scripts/levels/prototype_curling_puck_spell_trial.gd"
class_name PrototypeCurlingPuckSpellTrialReady

# The two marks share one centerline. Grace writes the ice route from the first
# mark, steps forward, switches to Boulder, and sends the heavy spell down the
# exact path rather than accidentally creating two parallel lanes.


func _ready() -> void:
	super._ready()
	var ice_mark: Node3D = get_node_or_null(
		"RimeRinkEnvironment/MomentumIceMark"
	) as Node3D
	var boulder_mark: Node3D = get_node_or_null(
		"RimeRinkEnvironment/MomentumBoulderMark"
	) as Node3D
	if ice_mark != null:
		ice_mark.position = Vector3(0.0, 0.06, 38.6)
	if boulder_mark != null:
		boulder_mark.position = Vector3(0.0, 0.06, 40.4)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["momentum_marks_share_centerline"] = true
	return data
