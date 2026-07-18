extends Area3D
class_name EnvironmentalEmitterConsole

var emitter: ElementEmitter
var trigger_count: int = 0


func _ready() -> void:
	add_to_group("debuggable")
	add_to_group("lab_resettable")


func configure_emitter(target_emitter: ElementEmitter) -> void:
	emitter = target_emitter


func interact() -> Dictionary:
	if emitter == null:
		return {
			"message": "Environmental source console has no emitter connected.",
			"objective": "Connect an environmental element emitter.",
		}
	trigger_count += 1
	var results: Array[Dictionary] = emitter.emit_pulse()
	return {
		"message": "Environmental " + emitter.element.capitalize() + " pulse released toward " + str(results.size()) + " compatible target" + ("s." if results.size() != 1 else "."),
		"objective": "Compare environmental electricity with Grace's Lightning spell.",
	}


func reset_target() -> void:
	trigger_count = 0


func get_debug_data() -> Dictionary:
	return {
		"environmental_emitter_console": emitter.emitter_id if emitter != null else "missing",
		"element": emitter.element if emitter != null else "none",
		"triggers": trigger_count,
	}
