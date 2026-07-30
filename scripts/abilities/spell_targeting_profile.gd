extends Resource
class_name SpellTargetingProfile


enum PreviewShape {
	NONE,
	POINT,
	CIRCLE,
	CONE,
	LINE,
	TRAJECTORY,
	SELF_BURST,
	TARGET_LOCK,
}

enum PlacementMode {
	FREE_GROUND,
	FORWARD,
	SELF,
	TARGET,
	BALLISTIC,
}

@export var profile_id: String = "targeting_profile"
@export_enum(
	"None",
	"Point",
	"Circle",
	"Cone",
	"Line",
	"Trajectory",
	"Self Burst",
	"Target Lock"
) var preview_shape: int = PreviewShape.POINT
@export_enum(
	"Free Ground",
	"Forward",
	"Self",
	"Target",
	"Ballistic"
) var placement_mode: int = PlacementMode.FORWARD

@export_group("Dimensions")
@export_range(0.0, 60.0, 0.1) var maximum_range: float = 12.0
@export_range(0.0, 20.0, 0.1) var minimum_range: float = 0.0
@export_range(0.05, 20.0, 0.05) var radius: float = 1.0
@export_range(0.05, 30.0, 0.05) var length: float = 6.0
@export_range(0.05, 20.0, 0.05) var width: float = 1.0
@export_range(1.0, 179.0, 1.0) var angle_degrees: float = 60.0
@export_range(0.0, 30.0, 0.1) var initial_distance: float = 6.0

@export_group("Placement")
@export_range(0.1, 30.0, 0.1) var cursor_speed: float = 8.0
@export_range(0.0, 0.95, 0.01) var input_deadzone: float = 0.18
@export_range(-1.0, 2.0, 0.01) var ground_y_offset: float = 0.05
@export var clamp_to_range: bool = true
@export var require_ground: bool = false
@export var require_line_of_sight: bool = false
@export var allow_through_obstacles: bool = true

@export_group("Preview")
@export var valid_color: Color = Color(0.3, 0.72, 1.0, 1.0)
@export var invalid_color: Color = Color(1.0, 0.24, 0.18, 1.0)
@export var neutral_color: Color = Color(0.62, 0.7, 0.82, 1.0)
@export_range(0.0, 1.0, 0.01) var fill_alpha: float = 0.24
@export_range(0.0, 1.0, 0.01) var outline_alpha: float = 0.92
@export_range(0.0, 4.0, 0.05) var emission_energy: float = 0.7
@export_range(0.0, 20.0, 0.1) var pulse_speed: float = 5.0
@export_range(0.0, 0.25, 0.005) var pulse_size: float = 0.04
@export var show_range_ring: bool = true
@export var show_direction_line: bool = true
@export var show_center_marker: bool = true
@export var preview_label: String = ""


func validate_profile() -> Array[String]:
	var errors: Array[String] = []
	if profile_id.strip_edges() == "":
		errors.append("Targeting profile requires a profile_id.")
	if maximum_range < 0.0:
		errors.append("Maximum range cannot be negative.")
	if minimum_range < 0.0:
		errors.append("Minimum range cannot be negative.")
	if minimum_range > maximum_range and maximum_range > 0.0:
		errors.append("Minimum range cannot exceed maximum range.")
	if radius <= 0.0:
		errors.append("Radius must be greater than zero.")
	if length <= 0.0:
		errors.append("Length must be greater than zero.")
	if width <= 0.0:
		errors.append("Width must be greater than zero.")
	if angle_degrees <= 0.0 or angle_degrees >= 180.0:
		errors.append("Cone angle must stay between 0 and 180 degrees.")
	if cursor_speed <= 0.0:
		errors.append("Cursor speed must be greater than zero.")
	return errors


func get_shape_name() -> String:
	match preview_shape:
		PreviewShape.NONE:
			return "none"
		PreviewShape.POINT:
			return "point"
		PreviewShape.CIRCLE:
			return "circle"
		PreviewShape.CONE:
			return "cone"
		PreviewShape.LINE:
			return "line"
		PreviewShape.TRAJECTORY:
			return "trajectory"
		PreviewShape.SELF_BURST:
			return "self_burst"
		PreviewShape.TARGET_LOCK:
			return "target_lock"
		_:
			return "point"


func get_placement_name() -> String:
	match placement_mode:
		PlacementMode.FREE_GROUND:
			return "free_ground"
		PlacementMode.FORWARD:
			return "forward"
		PlacementMode.SELF:
			return "self"
		PlacementMode.TARGET:
			return "target"
		PlacementMode.BALLISTIC:
			return "ballistic"
		_:
			return "forward"


func get_summary() -> String:
	var parts: Array[String] = [profile_id, get_shape_name(), get_placement_name()]
	if maximum_range > 0.0:
		parts.append("range=" + str(snappedf(maximum_range, 0.1)))
	match preview_shape:
		PreviewShape.CIRCLE, PreviewShape.SELF_BURST:
			parts.append("radius=" + str(snappedf(radius, 0.1)))
		PreviewShape.CONE:
			parts.append("length=" + str(snappedf(length, 0.1)))
			parts.append("angle=" + str(roundi(angle_degrees)))
		PreviewShape.LINE:
			parts.append("length=" + str(snappedf(length, 0.1)))
			parts.append("width=" + str(snappedf(width, 0.1)))
		_:
			pass
	return " | ".join(parts)


func to_config() -> Dictionary:
	return {
		"profile_id": profile_id,
		"shape": get_shape_name(),
		"placement": get_placement_name(),
		"range": maximum_range,
		"minimum_range": minimum_range,
		"radius": radius,
		"length": length,
		"width": width,
		"angle_degrees": angle_degrees,
		"initial_distance": initial_distance,
		"speed": cursor_speed,
		"deadzone": input_deadzone,
		"ground_y_offset": ground_y_offset,
		"clamp_to_range": clamp_to_range,
		"require_ground": require_ground,
		"require_line_of_sight": require_line_of_sight,
		"allow_through_obstacles": allow_through_obstacles,
		"valid_color": valid_color,
		"invalid_color": invalid_color,
		"neutral_color": neutral_color,
		"fill_alpha": fill_alpha,
		"outline_alpha": outline_alpha,
		"emission_energy": emission_energy,
		"pulse_speed": pulse_speed,
		"pulse_size": pulse_size,
		"show_range_ring": show_range_ring,
		"show_direction_line": show_direction_line,
		"show_center_marker": show_center_marker,
		"preview_label": preview_label,
	}


func apply_config(config: Dictionary) -> void:
	if config.has("profile_id"):
		profile_id = str(config["profile_id"])
	preview_shape = _parse_shape(config.get("shape", config.get("preview_shape", preview_shape)))
	placement_mode = _parse_placement(config.get("placement", config.get("placement_mode", placement_mode)))
	maximum_range = _read_float(config, "range", maximum_range)
	minimum_range = _read_float(config, "minimum_range", minimum_range)
	radius = _read_float(config, "radius", radius)
	length = _read_float(config, "length", length)
	width = _read_float(config, "width", width)
	angle_degrees = _read_float(config, "angle_degrees", angle_degrees)
	initial_distance = _read_float(config, "initial_distance", initial_distance)
	cursor_speed = _read_float(config, "speed", cursor_speed)
	input_deadzone = _read_float(config, "deadzone", input_deadzone)
	ground_y_offset = _read_float(config, "ground_y_offset", ground_y_offset)
	clamp_to_range = bool(config.get("clamp_to_range", clamp_to_range))
	require_ground = bool(config.get("require_ground", require_ground))
	require_line_of_sight = bool(config.get("require_line_of_sight", require_line_of_sight))
	allow_through_obstacles = bool(config.get("allow_through_obstacles", allow_through_obstacles))
	valid_color = _read_color(config, "valid_color", config.get("disc_color", valid_color) as Color if config.get("disc_color", null) is Color else valid_color)
	invalid_color = _read_color(config, "invalid_color", invalid_color)
	neutral_color = _read_color(config, "neutral_color", neutral_color)
	fill_alpha = _read_float(config, "fill_alpha", _read_float(config, "disc_alpha", fill_alpha))
	outline_alpha = _read_float(config, "outline_alpha", outline_alpha)
	emission_energy = _read_float(config, "emission_energy", emission_energy)
	pulse_speed = _read_float(config, "pulse_speed", pulse_speed)
	pulse_size = _read_float(config, "pulse_size", pulse_size)
	show_range_ring = bool(config.get("show_range_ring", show_range_ring))
	show_direction_line = bool(config.get("show_direction_line", show_direction_line))
	show_center_marker = bool(config.get("show_center_marker", show_center_marker))
	preview_label = str(config.get("preview_label", preview_label))


static func from_config(config: Dictionary, fallback_id: String = "runtime_targeting") -> SpellTargetingProfile:
	var profile := SpellTargetingProfile.new()
	profile.profile_id = fallback_id
	profile.apply_config(config)
	return profile


func _parse_shape(value: Variant) -> int:
	if value is int:
		return clampi(int(value), PreviewShape.NONE, PreviewShape.TARGET_LOCK)
	match str(value).to_lower():
		"none":
			return PreviewShape.NONE
		"circle", "ground_circle", "aoe":
			return PreviewShape.CIRCLE
		"cone":
			return PreviewShape.CONE
		"line", "beam":
			return PreviewShape.LINE
		"trajectory", "ballistic", "lob":
			return PreviewShape.TRAJECTORY
		"self", "self_burst", "burst":
			return PreviewShape.SELF_BURST
		"target", "target_lock", "lock":
			return PreviewShape.TARGET_LOCK
		_:
			return PreviewShape.POINT


func _parse_placement(value: Variant) -> int:
	if value is int:
		return clampi(int(value), PlacementMode.FREE_GROUND, PlacementMode.BALLISTIC)
	match str(value).to_lower():
		"free_ground", "ground":
			return PlacementMode.FREE_GROUND
		"self":
			return PlacementMode.SELF
		"target", "lock":
			return PlacementMode.TARGET
		"ballistic", "trajectory", "lob":
			return PlacementMode.BALLISTIC
		_:
			return PlacementMode.FORWARD


func _read_float(config: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = config.get(key, fallback)
	return fallback if value == null else float(value)


func _read_color(config: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = config.get(key, fallback)
	return value as Color if value is Color else fallback
