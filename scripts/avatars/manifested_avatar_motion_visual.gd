extends "res://scripts/visuals/grace_elemental_authority_motion_visual.gd"
class_name ManifestedAvatarMotionVisual


func _ready() -> void:
	super._ready()
	add_to_group("manifested_avatar_motion_visual")


func resolve_presentation_state() -> String:
	var resolved: String = super.resolve_presentation_state()
	if resolved != "exhausted":
		return resolved
	# The shared visual normally reads Grace's global stamina for her exhausted pose.
	# An autonomous manifestation owns no part of Grace's resource pool, so it falls
	# back to ordinary local locomotion instead.
	return "locomotion" if movement_weight > 0.04 else "idle"
