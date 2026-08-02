extends "res://scripts/levels/prototype_progression_challenge_lab.gd"

# The inherited reaction laboratory keeps readout references to its Steam and
# Sound stations. Park those stations instead of freeing them, and use typed
# visibility access so local Godot caches never see a stale object path.


func _configure_reaction_wing() -> void:
	if reaction_wing == null:
		return
	reaction_wing.set("enable_editor_f8_reset", false)
	var title: Label3D = reaction_wing.get_node_or_null("LabTitle") as Label3D
	if title != null:
		title.text = "PROGRESSION CHALLENGE LABORATORY"
	var subtitle: Label3D = reaction_wing.get_node_or_null("LabSubtitle") as Label3D
	if subtitle != null:
		subtitle.text = "REACTIONS • ALCHEMY • CREATURE STUDY • LIVE REWARDS"
	var instruction: Label3D = reaction_wing.get_node_or_null("EntryInstruction") as Label3D
	if instruction != null:
		instruction.text = "F1-F5 STATIONS • F8 RESET • F9 CLEAR PROGRESS • F10 COMPLETE ALL"
	var old_console: Node3D = reaction_wing.get_node_or_null("LabResetConsole") as Node3D
	if old_console != null:
		old_console.visible = false
		old_console.process_mode = Node.PROCESS_MODE_DISABLED
	for old_station_name: String in ["SteamStation", "SoundStation"]:
		var old_station: Node3D = reaction_wing.get_node_or_null(old_station_name) as Node3D
		if old_station == null:
			continue
		old_station.position.y = -60.0
		old_station.visible = false
		old_station.process_mode = Node.PROCESS_MODE_DISABLED
	var freeze_label: Label3D = reaction_wing.get_node_or_null("FreezeStation/Label") as Label3D
	if freeze_label != null:
		freeze_label.text = "FREEZE PREP\nWater → Ice\nThen strike at Shatterproof"
	_configure_lab_loadout()
