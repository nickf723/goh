extends "res://scripts/ui/quick_item_belt_ui.gd"
class_name QuickItemBeltUIDeferred

# The base HUD requested its persistent familiar roster during _ready(), while
# the scene-tree root was still constructing the player hierarchy. Delay only
# that persistent-service installation; all existing display and process logic
# remains inherited.


func _ready() -> void:
	_resolve_bindings()
	if not _suppress_for_unified_hud():
		refresh_display()
	call_deferred("_ensure_bonded_familiar_roster")
