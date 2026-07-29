extends Resource
class_name DivineSpecialDefinition


@export_group("Identity")
@export var special_id: String = "divine_special"
@export var patron_id: String = ""
@export var display_name: String = "Divine Special"
@export_multiline var description: String = ""
@export var tags: Array[String] = []

@export_group("Availability")
@export var required_unlock_id: String = ""
@export var debug_available: bool = false

@export_group("Execution")
@export_enum(
	"owner",
	"locked_or_aim_ground",
	"locked_or_cluster",
	"aim_line"
) var targeting_mode: String = "locked_or_aim_ground"
@export_enum(
	"projection_or_active_avatar",
	"projection_only",
	"active_avatar_only"
) var performer_mode: String = "projection_or_active_avatar"
@export var effect_scene: PackedScene
@export var patron_avatar_definition: PlayableAvatarDefinition
@export_range(1.0, 60.0, 0.5) var maximum_target_range: float = 18.0
@export_range(0.0, 30.0, 0.1) var area_radius: float = 4.0
@export_range(0.01, 30.0, 0.05) var action_timeout: float = 8.0
@export_range(0.0, 30.0, 0.05) var active_duration: float = 0.0
@export_range(0.0, 3.0, 0.01) var activation_lock_seconds: float = 0.18
@export_range(0.0, 3.0, 0.01) var invulnerability_seconds: float = 0.0

@export_group("Shared Divine Charge")
@export_range(1.0, 100.0, 1.0) var required_charge: float = 100.0
@export_range(5.0, 300.0, 1.0) var recharge_seconds: float = 75.0


func validate_definition() -> Array[String]:
	var failures: Array[String] = []
	if special_id.strip_edges() == "":
		failures.append("special_id must not be empty")
	if patron_id.strip_edges() == "":
		failures.append(special_id + ": patron_id must not be empty")
	if display_name.strip_edges() == "":
		failures.append(special_id + ": display_name must not be empty")
	if targeting_mode not in [
		"owner",
		"locked_or_aim_ground",
		"locked_or_cluster",
		"aim_line",
	]:
		failures.append(special_id + ": targeting_mode is invalid")
	if performer_mode not in [
		"projection_or_active_avatar",
		"projection_only",
		"active_avatar_only",
	]:
		failures.append(special_id + ": performer_mode is invalid")
	if effect_scene == null:
		failures.append(special_id + ": effect_scene is required")
	if patron_avatar_definition == null:
		failures.append(special_id + ": patron_avatar_definition is required")
	elif patron_avatar_definition.avatar_id != patron_id:
		failures.append(
			special_id
			+ ": patron_id must match the patron avatar definition"
		)
	if maximum_target_range <= 0.0:
		failures.append(special_id + ": maximum_target_range must be positive")
	if action_timeout <= 0.0:
		failures.append(special_id + ": action_timeout must be positive")
	if required_charge <= 0.0 or required_charge > 100.0:
		failures.append(special_id + ": required_charge must be within 1..100")
	if recharge_seconds <= 0.0:
		failures.append(special_id + ": recharge_seconds must be positive")
	return failures


func is_unlocked(force_debug: bool = false) -> bool:
	if required_unlock_id == "":
		return true
	if GameState.has_method("has_unlock") and bool(
		GameState.call("has_unlock", required_unlock_id)
	):
		return true
	# Runtime debug input only passes true from an OS debug build. Regressions can
	# also force deterministic catalog access without depending on engine flavor.
	return force_debug and debug_available


func get_debug_summary() -> Dictionary:
	return {
		"special_id": special_id,
		"patron_id": patron_id,
		"display_name": display_name,
		"required_unlock": required_unlock_id,
		"debug_available": debug_available,
		"unlocked": is_unlocked(false),
		"targeting_mode": targeting_mode,
		"performer_mode": performer_mode,
		"maximum_target_range": maximum_target_range,
		"area_radius": area_radius,
		"action_timeout": action_timeout,
		"active_duration": active_duration,
		"required_charge": required_charge,
		"recharge_seconds": recharge_seconds,
		"tags": tags.duplicate(),
	}
