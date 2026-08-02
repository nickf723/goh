extends "res://scripts/levels/ruined_village_outdoor_remaster_pass_legacy.gd"
class_name RuinedVillageOutdoorRemasterPass

# Child _ready() runs before the procedural village root has created its
# GeneratedGeometry and GeneratedDetails children. The legacy pass retried with
# call_deferred(), which could exhaust every attempt in one idle cycle on a cold
# import. Retry once per process frame instead so the parent has time to build.


func _ready() -> void:
	add_to_group("ruined_village_outdoor_remaster_pass")
	set_process(true)


func _process(_delta: float) -> void:
	if installed:
		set_process(false)
		return
	_install()
	if installed:
		set_process(false)
