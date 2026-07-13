extends Node
class_name RuntimeStatLabSession

signal session_changed(debug_data: Dictionary)
signal mutation_applied(message: String)

const StatCatalogScript = preload("res://scripts/systems/stat_catalog.gd")
const RESOURCE_IDS: Array[String] = ["health", "stamina", "mana", "stance"]
const LIVE_STAT_IDS: Array[String] = ["health", "stamina", "mana", "stance", "focus"]
const PARTIAL_STAT_IDS: Array[String] = [
	"power",
	"dexterity",
	"arcana",
	"intelligence",
	"water",
	"earth",
	"fire",
	"air",
	"ice",
	"metal",
	"lightning",
	"poison",
	"life",
	"death",
	"body",
	"soul",
	"dreams",
	"sound",
	"space",
	"time",
	"light",
	"darkness",
	"dark",
	"void",
]

var entry_snapshot: Dictionary = {}
var infinite_resources: Dictionary = {}
var last_mutation: String = "Session has not started."
var mutation_count: int = 0
var session_active: bool = false
var is_restoring: bool = false


func _ready() -> void:
	add_to_group("runtime_stat_lab_session")
	add_to_group("debuggable")


func _process(_delta: float) -> void:
	if not session_active or is_restoring:
		return

	refill_infinite_resources()


func begin_session(snapshot_override: Dictionary = {}) -> void:
	if session_active:
		return

	if snapshot_override.is_empty():
		entry_snapshot = GameState.get_stat_snapshot()
	else:
		entry_snapshot = snapshot_override.duplicate(true)

	infinite_resources.clear()
	mutation_count = 0
	last_mutation = "Entry snapshot captured. Laboratory changes are temporary."
	session_active = true
	Engine.time_scale = 1.0
	emit_state()


func apply_station_action(
	stat_id: String,
	action: String,
	value: int = 0,
	context: String = ""
) -> Dictionary:
	if not session_active:
		begin_session()

	var message: String = ""

	match action:
		"baseline":
			message = restore_stat_to_entry(stat_id)
		"boost":
			message = set_stat_preset(stat_id, 10, "BOOST")
		"overcharge":
			message = set_stat_preset(stat_id, 1000, "OVERCHARGE")
		"infinite":
			message = toggle_infinite_resource(stat_id)
		"set":
			message = set_stat_value(stat_id, value, context)
		"minimum":
			message = set_resource_current(stat_id, max(value, 1), "MINIMUM")
		"full":
			message = refill_resource(stat_id)
		"damage":
			message = apply_safe_damage(stat_id, max(value, 1), context)
		"reset_all":
			restore_entry_snapshot(true)
			message = "All stats restored to the entry snapshot. Infinite modes disabled."
		_:
			message = "Unknown stat-lab action: " + action

	if action != "reset_all":
		mutation_count += 1
		last_mutation = message
		emit_state()

	mutation_applied.emit(message)
	return {
		"message": message,
		"objective": "Use the laboratory stations to compare live, partial, and dormant stat hooks.",
	}


func set_stat_preset(stat_id: String, value: int, preset_name: String) -> String:
	if RESOURCE_IDS.has(stat_id):
		set_resource_pair(stat_id, value)
		return stat_id.capitalize() + " " + preset_name + ": " + str(value) + " / " + str(value) + "."

	GameState.set_stat(stat_id, value)
	return stat_id.capitalize() + " " + preset_name + ": " + str(value) + "."


func set_stat_value(stat_id: String, value: int, context: String = "") -> String:
	if RESOURCE_IDS.has(stat_id):
		set_resource_pair(stat_id, value)
	else:
		GameState.set_stat(stat_id, value)

	var label: String = context if context != "" else "SET"
	return stat_id.capitalize() + " " + label + ": " + get_stat_value_text(stat_id) + "."


func set_resource_pair(resource_id: String, value: int) -> void:
	if not RESOURCE_IDS.has(resource_id):
		return

	var resolved_value: int = max(value, 0)
	GameState.set_stat("max_" + resource_id, resolved_value)
	GameState.set_stat(resource_id, resolved_value)


func set_resource_current(resource_id: String, value: int, label: String = "SET") -> String:
	if not RESOURCE_IDS.has(resource_id):
		GameState.set_stat(resource_id, value)
		return resource_id.capitalize() + " " + label + ": " + str(value) + "."

	var maximum: int = GameState.get_stat("max_" + resource_id)
	GameState.set_stat(resource_id, clamp(value, 0, maximum))
	return resource_id.capitalize() + " " + label + ": " + get_stat_value_text(resource_id) + "."


func refill_resource(resource_id: String) -> String:
	if not RESOURCE_IDS.has(resource_id):
		return resource_id.capitalize() + " is not a refillable action resource."

	GameState.set_stat(resource_id, GameState.get_stat("max_" + resource_id))
	return resource_id.capitalize() + " restored: " + get_stat_value_text(resource_id) + "."


func apply_safe_damage(resource_id: String, amount: int, context: String = "") -> String:
	if resource_id != "health" and resource_id != "stance":
		return resource_id.capitalize() + " does not accept the safe damage demonstration."

	var current_value: int = GameState.get_stat(resource_id)
	var minimum_value: int = 1 if resource_id == "health" else 0
	var new_value: int = max(current_value - amount, minimum_value)
	GameState.set_stat(resource_id, new_value)

	var damage_label: String = context if context != "" else "controlled"
	return damage_label.capitalize() + " pressure: -" + str(current_value - new_value) + " " + resource_id + "."


func restore_stat_to_entry(stat_id: String) -> String:
	if entry_snapshot.is_empty():
		return "No entry snapshot exists."

	if RESOURCE_IDS.has(stat_id):
		var max_key: String = "max_" + stat_id
		GameState.set_stat(max_key, int(entry_snapshot.get(max_key, GameState.get_stat(max_key))))
		GameState.set_stat(stat_id, int(entry_snapshot.get(stat_id, GameState.get_stat(stat_id))))
		infinite_resources.erase(stat_id)
	else:
		GameState.set_stat(stat_id, int(entry_snapshot.get(stat_id, GameState.get_stat(stat_id))))

	return stat_id.capitalize() + " restored to entry baseline: " + get_stat_value_text(stat_id) + "."


func toggle_infinite_resource(resource_id: String) -> String:
	if not RESOURCE_IDS.has(resource_id):
		return resource_id.capitalize() + " cannot use infinite-resource mode."

	var enabled: bool = not bool(infinite_resources.get(resource_id, false))
	infinite_resources[resource_id] = enabled

	if enabled:
		set_resource_pair(resource_id, max(GameState.get_stat("max_" + resource_id), 1000))
		refill_infinite_resources()
		return "INFINITE " + resource_id.to_upper() + " enabled."

	return "INFINITE " + resource_id.to_upper() + " disabled. Current overcharge remains until reset."


func refill_infinite_resources() -> void:
	for resource_variant: Variant in infinite_resources.keys():
		var resource_id: String = str(resource_variant)
		if not bool(infinite_resources.get(resource_id, false)):
			continue

		var max_key: String = "max_" + resource_id
		var target_value: int = max(GameState.get_stat(max_key), 1000)

		if GameState.get_stat(max_key) != target_value:
			GameState.set_stat(max_key, target_value)
		if GameState.get_stat(resource_id) != target_value:
			GameState.set_stat(resource_id, target_value)


func restore_entry_snapshot(keep_session_active: bool = true) -> void:
	if entry_snapshot.is_empty() or is_restoring:
		return

	is_restoring = true
	infinite_resources.clear()
	Engine.time_scale = 1.0

	GameState.stats = entry_snapshot.duplicate(true)
	for stat_variant: Variant in GameState.stats.keys():
		var stat_id: String = str(stat_variant)
		GameState.stat_changed.emit(stat_id, int(GameState.stats[stat_variant]))

	clear_player_runtime_flags()
	last_mutation = "Entry snapshot restored."
	mutation_count = 0
	session_active = keep_session_active
	is_restoring = false
	emit_state()


func prepare_exit() -> void:
	restore_entry_snapshot(false)


func clear_player_runtime_flags() -> void:
	GameState.player_invulnerable = false
	GameState.player_invulnerability_timer = 0.0

	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var action_state: Node = player.get_node_or_null("PlayerActionState")
	if action_state != null and action_state.has_method("reset_for_respawn"):
		action_state.call("reset_for_respawn")

	if player.has_method("cancel_combat_motion"):
		player.call("cancel_combat_motion")
	if player.has_method("clear_lock_on"):
		player.call("clear_lock_on")


func get_implementation_status(stat_id: String) -> String:
	if LIVE_STAT_IDS.has(stat_id):
		return "LIVE"
	if PARTIAL_STAT_IDS.has(stat_id):
		return "PARTIAL"
	return "DORMANT"


func get_status_explanation(stat_id: String) -> String:
	match get_implementation_status(stat_id):
		"LIVE":
			if stat_id == "focus":
				return "Actively controls focus-menu time slowdown."
			return "Actively read and spent by current gameplay systems."
		"PARTIAL":
			return "Referenced by loadout/scaling metadata; production formulas are not active yet."
		_:
			return "Defined in the stat catalog, but no production gameplay formula reads it yet."


func get_stat_value_text(stat_id: String) -> String:
	return StatCatalogScript.get_stat_value_text(stat_id, GameState.get_stat_snapshot())


func is_infinite(resource_id: String) -> bool:
	return bool(infinite_resources.get(resource_id, false))


func get_entry_snapshot() -> Dictionary:
	return entry_snapshot.duplicate(true)


func emit_state() -> void:
	session_changed.emit(get_debug_data())


func get_debug_data() -> Dictionary:
	return {
		"active": session_active,
		"snapshot_size": entry_snapshot.size(),
		"mutations": mutation_count,
		"last_mutation": last_mutation,
		"infinite": infinite_resources.duplicate(true),
		"resources": {
			"health": get_stat_value_text("health"),
			"stamina": get_stat_value_text("stamina"),
			"mana": get_stat_value_text("mana"),
			"stance": get_stat_value_text("stance"),
		},
		"focus": GameState.get_stat("focus"),
		"time_scale": snapped(Engine.time_scale, 0.01),
	}


func _exit_tree() -> void:
	if session_active and not is_restoring:
		restore_entry_snapshot(false)
