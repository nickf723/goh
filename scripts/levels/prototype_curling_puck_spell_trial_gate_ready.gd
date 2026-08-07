extends "res://scripts/levels/prototype_curling_puck_spell_trial_reliable.gd"
class_name PrototypeCurlingPuckSpellTrialGateReady

# Runtime puck trails contain many samples. Focused progression fixtures may use
# the three authored marks directly. Both still have to satisfy the right-curl,
# total-span, and mark-or-bend contracts inherited from the reliable trial.


func _ready() -> void:
	reliable_minimum_curl_segments = 3
	super._ready()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["exact_authored_curl_fixture_supported"] = true
	return data
