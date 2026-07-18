extends Node
class_name EnemyThreatSensor

@export var actor_path: NodePath = NodePath("..")
@export var awareness_radius: float = 7.0
@export var base_reaction_delay: float = 0.09
@export var reaction_delay_multiplier: float = 1.0
@export var geometry_padding: float = 0.18
@export var maximum_tracked_threats: int = 8

var actor: Node3D
var tracked_threats: Array[Dictionary] = []
var last_received_summary: String = "none"
var last_actionable_summary: String = "none"


func _ready() -> void:
	actor = get_node_or_null(actor_path) as Node3D
	add_to_group("combat_threat_sensors")
	add_to_group("debuggable")


func receive_combat_threat(threat: CombatThreat) -> void:
	if threat == null or threat.is_expired():
		return

	if actor == null:
		actor = get_node_or_null(actor_path) as Node3D
	if actor == null:
		return

	var source: Node3D = threat.get_source()
	if source == actor:
		return

	var sensor_distance: float = actor.global_position.distance_to(threat.get_origin())
	if sensor_distance > max(awareness_radius, 0.0) + threat.range:
		return

	remove_threat(threat)
	var reaction_delay: float = max(base_reaction_delay * reaction_delay_multiplier, 0.0)
	tracked_threats.append({
		"threat": threat,
		"ready_at_msec": Time.get_ticks_msec() + roundi(reaction_delay * 1000.0),
	})

	while tracked_threats.size() > max(maximum_tracked_threats, 1):
		tracked_threats.pop_front()

	last_received_summary = threat.get_debug_summary()


func get_best_actionable_threat(point: Vector3) -> CombatThreat:
	cleanup_threats()

	var now_msec: int = Time.get_ticks_msec()
	var best_threat: CombatThreat
	var best_score: float = -INF

	for entry: Dictionary in tracked_threats:
		var threat: CombatThreat = entry.get("threat") as CombatThreat
		if threat == null or threat.is_expired():
			continue
		if now_msec < int(entry.get("ready_at_msec", 0)):
			continue
		if not threat.contains_point(point, geometry_padding):
			continue

		var time_until_impact: float = threat.get_time_until_impact()
		var urgency: float = 1.0 / max(abs(time_until_impact) + 0.05, 0.05)
		var score: float = threat.severity + urgency
		if score <= best_score:
			continue

		best_threat = threat
		best_score = score

	last_actionable_summary = best_threat.get_debug_summary() if best_threat != null else "none"
	return best_threat


func acknowledge_threat(threat: CombatThreat) -> void:
	remove_threat(threat)
	last_actionable_summary = "acknowledged: " + threat.display_name if threat != null else "none"


func remove_threat(threat: CombatThreat) -> void:
	if threat == null:
		return

	for index: int in range(tracked_threats.size() - 1, -1, -1):
		var tracked: CombatThreat = tracked_threats[index].get("threat") as CombatThreat
		if tracked == threat:
			tracked_threats.remove_at(index)


func cleanup_threats() -> void:
	for index: int in range(tracked_threats.size() - 1, -1, -1):
		var threat: CombatThreat = tracked_threats[index].get("threat") as CombatThreat
		if threat == null or threat.is_expired():
			tracked_threats.remove_at(index)


func get_reaction_time_remaining(threat: CombatThreat) -> float:
	if threat == null:
		return 0.0

	for entry: Dictionary in tracked_threats:
		if entry.get("threat") != threat:
			continue
		return max(float(int(entry.get("ready_at_msec", 0)) - Time.get_ticks_msec()) / 1000.0, 0.0)

	return 0.0


func get_debug_data() -> Dictionary:
	cleanup_threats()
	return {
		"threats": tracked_threats.size(),
		"threat_received": last_received_summary,
		"threat_actionable": last_actionable_summary,
		"reaction_delay": snapped(base_reaction_delay * reaction_delay_multiplier, 0.01),
	}
