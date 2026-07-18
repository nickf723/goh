extends Resource
class_name EnemyCombatActionDefinition

@export var action_id: String = "enemy_action"
@export_enum("attack", "defense", "utility", "support", "movement")
var action_kind: String = "attack"
@export var display_name: String = "Enemy Action"
@export var role_tags: Array[String] = ["enemy_action"]

@export_group("Timing")
@export var windup_time: float = 0.2
@export var active_time: float = 0.1
@export var recovery_time: float = 0.3
@export var cooldown: float = 1.0

@export_group("Phase Movement")
@export_enum(
	"toward_target",
	"away_from_target",
	"strafe_left",
	"strafe_right",
	"none"
)
var movement_mode: String = "toward_target"
@export var face_target_during_action: bool = true
@export var windup_move_speed_multiplier: float = 0.0
@export var active_move_speed_multiplier: float = 0.0
@export var recovery_move_speed_multiplier: float = 0.0

@export_group("Interrupts")
@export var interruptible_during_windup: bool = true
@export var interruptible_during_active: bool = false
@export var interruptible_during_recovery: bool = false

@export_group("Debug")
@export var debug_notes: String = ""


func get_action_id() -> String:
	var normalized_id: String = action_id.to_lower().strip_edges()
	if normalized_id != "":
		return normalized_id

	return display_name.to_lower().strip_edges().replace(" ", "_")


func get_action_kind() -> String:
	return action_kind.to_lower().strip_edges()


func get_display_name() -> String:
	return display_name


func get_role_tags() -> Array[String]:
	var tags: Array[String] = []
	append_unique_strings(tags, role_tags)

	if not tags.has("enemy_action"):
		tags.append("enemy_action")

	var kind: String = get_action_kind()
	if kind != "" and not tags.has(kind):
		tags.append(kind)

	return tags


func get_windup_time() -> float:
	return max(windup_time, 0.0)


func get_active_time() -> float:
	return max(active_time, 0.0)


func get_recovery_time() -> float:
	return max(recovery_time, 0.0)


func get_cooldown() -> float:
	return max(cooldown, 0.0)


func get_movement_mode() -> String:
	return movement_mode.to_lower().strip_edges()


func should_face_target_during_action() -> bool:
	return face_target_during_action


func get_windup_move_speed_multiplier() -> float:
	return max(windup_move_speed_multiplier, 0.0)


func get_active_move_speed_multiplier() -> float:
	return max(active_move_speed_multiplier, 0.0)


func get_recovery_move_speed_multiplier() -> float:
	return max(recovery_move_speed_multiplier, 0.0)


func get_interruptible_during_windup() -> bool:
	return interruptible_during_windup


func get_interruptible_during_active() -> bool:
	return interruptible_during_active


func get_interruptible_during_recovery() -> bool:
	return interruptible_during_recovery


func get_debug_notes() -> String:
	return debug_notes


func is_attack_action() -> bool:
	return get_action_kind() == "attack"


func is_defensive_action() -> bool:
	return get_action_kind() == "defense"


func append_unique_strings(target: Array[String], source: Array[String]) -> void:
	for value: String in source:
		if value == "" or target.has(value):
			continue

		target.append(value)
