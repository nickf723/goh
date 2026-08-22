extends RefCounted
class_name MobMoveExecutionState

const PHASE_STARTUP := "startup"
const PHASE_ACTIVE := "active"
const PHASE_RECOVERY := "recovery"
const PHASE_COMPLETE := "complete"
const PHASE_INTERRUPTED := "interrupted"

var move_id: String = ""
var move_data: Dictionary = {}
var context: Dictionary = {}
var timing: Dictionary = {}
var phase: String = PHASE_STARTUP
var elapsed: float = 0.0
var total_duration: float = 0.0
var completed: bool = false
var interrupted: bool = false
var effect_request_claimed: bool = false
var result: Dictionary = {}


static func create(
	new_move_data: Dictionary,
	execution_context: Dictionary = {}
) -> MobMoveExecutionState:
	var state := MobMoveExecutionState.new()
	state.move_data = new_move_data.duplicate(true)
	state.move_id = str(new_move_data.get("id", new_move_data.get("move_id", "")))
	state.context = execution_context.duplicate(true)
	state.timing = normalize_timing(new_move_data)
	if execution_context.has("duration_override"):
		var duration_override: float = maxf(
			float(execution_context.get("duration_override", 0.0)),
			0.0
		)
		state.timing["startup"] = 0.0
		state.timing["active"] = duration_override
		state.timing["recovery"] = 0.0
	state.total_duration = (
		float(state.timing.get("startup", 0.0))
		+ float(state.timing.get("active", 0.0))
		+ float(state.timing.get("recovery", 0.0))
	)
	state.phase = state._phase_for_elapsed(0.0)
	return state


static func normalize_timing(move: Dictionary) -> Dictionary:
	var authored: Dictionary = (
		(move.get("timing", {}) as Dictionary).duplicate(true)
		if move.get("timing", {}) is Dictionary
		else {}
	)
	var effect: Dictionary = (
		move.get("effect", {}) as Dictionary
		if move.get("effect", {}) is Dictionary
		else {}
	)
	var action_kind: String = str(move.get("action_kind", "utility")).to_lower()
	var effect_duration: float = maxf(float(effect.get("duration", 0.0)), 0.0)
	var defaults: Dictionary
	match action_kind:
		"attack":
			defaults = {"startup": 0.18, "active": 0.18, "recovery": 0.32}
		"movement":
			defaults = {
				"startup": 0.05,
				"active": effect_duration if effect_duration > 0.0 else 0.8,
				"recovery": 0.1,
			}
		"support":
			defaults = {"startup": 0.2, "active": 0.3, "recovery": 0.35}
		_:
			defaults = {
				"startup": 0.05,
				"active": effect_duration if effect_duration > 0.0 else 0.65,
				"recovery": 0.1,
			}
	for key: String in ["startup", "active", "recovery"]:
		authored[key] = maxf(float(authored.get(key, defaults[key])), 0.0)
	if not authored.has("interruptible_phases"):
		authored["interruptible_phases"] = [
			PHASE_STARTUP,
			PHASE_ACTIVE,
			PHASE_RECOVERY,
		]
	if not authored.has("effect_trigger"):
		authored["effect_trigger"] = "active_start"
	return authored


func advance(delta: float) -> Dictionary:
	var previous_phase: String = phase
	if not is_active():
		return _transition(previous_phase)
	elapsed = minf(elapsed + maxf(delta, 0.0), total_duration)
	phase = _phase_for_elapsed(elapsed)
	if elapsed >= total_duration:
		completed = true
		phase = PHASE_COMPLETE
		if result.is_empty():
			result = {"ok": true, "outcome": "completed"}
	return _transition(previous_phase)


func finish(outcome: Dictionary = {}) -> Dictionary:
	var previous_phase: String = phase
	if not is_active():
		return _transition(previous_phase)
	elapsed = total_duration
	completed = true
	phase = PHASE_COMPLETE
	result = outcome.duplicate(true)
	if not result.has("ok"):
		result["ok"] = true
	if not result.has("outcome"):
		result["outcome"] = "completed"
	return _transition(previous_phase)


func interrupt(reason: String, force: bool = false, outcome: Dictionary = {}) -> Dictionary:
	var previous_phase: String = phase
	if not is_active():
		return _transition(previous_phase)
	if not force and not can_interrupt():
		return {
			"ok": false,
			"error": "phase is not interruptible",
			"move_id": move_id,
			"phase": phase,
		}
	interrupted = true
	phase = PHASE_INTERRUPTED
	result = outcome.duplicate(true)
	result["ok"] = false
	result["outcome"] = "interrupted"
	result["reason"] = reason
	return _transition(previous_phase)


func can_interrupt() -> bool:
	if not is_active():
		return false
	var raw_phases: Variant = timing.get("interruptible_phases", [])
	if not raw_phases is Array:
		return true
	for raw_phase: Variant in raw_phases as Array:
		if str(raw_phase).to_lower().strip_edges() == phase:
			return true
	return false


func is_active() -> bool:
	return not completed and not interrupted


func is_impact_window() -> bool:
	return is_active() and phase == PHASE_ACTIVE


func is_effect_request_ready() -> bool:
	if effect_request_claimed or interrupted:
		return false
	if str(timing.get("effect_trigger", "active_start")) != "active_start":
		return false
	if float(timing.get("active", 0.0)) <= 0.0:
		return false
	return elapsed >= float(timing.get("startup", 0.0))


func claim_active_effect() -> bool:
	if not is_effect_request_ready():
		return false
	effect_request_claimed = true
	return true


func get_remaining() -> float:
	return maxf(total_duration - elapsed, 0.0)


func to_dictionary() -> Dictionary:
	return {
		"move_id": move_id,
		"move": move_data.duplicate(true),
		"context": context.duplicate(true),
		"timing": timing.duplicate(true),
		"phase": phase,
		"elapsed": elapsed,
		"remaining": get_remaining(),
		"total_duration": total_duration,
		"active": is_active(),
		"impact_window": is_impact_window(),
		"effect_request_ready": is_effect_request_ready(),
		"effect_request_claimed": effect_request_claimed,
		"completed": completed,
		"interrupted": interrupted,
		"result": result.duplicate(true),
	}


func _phase_for_elapsed(value: float) -> String:
	var startup_end: float = float(timing.get("startup", 0.0))
	var active_end: float = startup_end + float(timing.get("active", 0.0))
	if value < startup_end:
		return PHASE_STARTUP
	if value < active_end:
		return PHASE_ACTIVE
	if value < total_duration:
		return PHASE_RECOVERY
	return PHASE_COMPLETE


func _transition(previous_phase: String) -> Dictionary:
	var snapshot: Dictionary = to_dictionary()
	snapshot["previous_phase"] = previous_phase
	snapshot["phase_changed"] = previous_phase != phase
	return snapshot
