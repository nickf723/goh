extends RefCounted
class_name SpellTargetingCatalog


const TargetingProfileScript = preload(
	"res://scripts/abilities/spell_targeting_profile.gd"
)


static func build_profile(
	ability: AbilityDefinition,
	runtime_config: Dictionary = {}
) -> SpellTargetingProfile:
	var profile: SpellTargetingProfile = _get_authored_profile(ability)
	if profile == null:
		profile = TargetingProfileScript.from_config(
			runtime_config,
			_get_profile_id(ability)
		)
	else:
		profile = profile.duplicate(true) as SpellTargetingProfile
		profile.apply_config(runtime_config)
	if profile.profile_id == "" or profile.profile_id == "targeting_profile":
		profile.profile_id = _get_profile_id(ability)
	_apply_inference(profile, ability, runtime_config)
	_normalize(profile)
	return profile


static func build_profile_from_config(
	config: Dictionary,
	profile_id: String = "runtime_targeting"
) -> SpellTargetingProfile:
	var profile: SpellTargetingProfile = TargetingProfileScript.from_config(
		config,
		profile_id
	)
	_apply_inference(profile, null, config)
	_normalize(profile)
	return profile


static func get_preview_summary(
	ability: AbilityDefinition,
	runtime_config: Dictionary = {}
) -> Dictionary:
	var profile: SpellTargetingProfile = build_profile(ability, runtime_config)
	return {
		"profile_id": profile.profile_id,
		"shape": profile.get_shape_name(),
		"placement": profile.get_placement_name(),
		"range": profile.maximum_range,
		"minimum_range": profile.minimum_range,
		"radius": profile.radius,
		"length": profile.length,
		"width": profile.width,
		"angle_degrees": profile.angle_degrees,
		"requires_ground": profile.require_ground,
		"requires_line_of_sight": profile.require_line_of_sight,
		"summary": profile.get_summary(),
		"errors": profile.validate_profile(),
	}


static func _get_authored_profile(
	ability: AbilityDefinition
) -> SpellTargetingProfile:
	if ability == null:
		return null
	if ability.has_method("get_targeting_profile"):
		var profile_value: Variant = ability.call("get_targeting_profile")
		if profile_value is SpellTargetingProfile:
			return profile_value as SpellTargetingProfile
	var raw_profile: Variant = ability.get("targeting_profile")
	return raw_profile as SpellTargetingProfile if raw_profile is SpellTargetingProfile else null


static func _apply_inference(
	profile: SpellTargetingProfile,
	ability: AbilityDefinition,
	config: Dictionary
) -> void:
	var explicit_shape: bool = config.has("shape") or config.has("preview_shape")
	var explicit_placement: bool = config.has("placement") or config.has("placement_mode")
	var targeting_style: String = ""
	var delivery_type: String = ""
	if ability != null:
		targeting_style = ability.get_targeting_style().to_lower()
		delivery_type = ability.get_delivery_type().to_lower()

	if not explicit_shape and profile.preview_shape == SpellTargetingProfile.PreviewShape.POINT:
		profile.preview_shape = _infer_shape(targeting_style, delivery_type, config)
	if not explicit_placement:
		profile.placement_mode = _infer_placement(
			profile.preview_shape,
			targeting_style,
			delivery_type
		)

	if profile.preview_shape in [
		SpellTargetingProfile.PreviewShape.CIRCLE,
		SpellTargetingProfile.PreviewShape.SELF_BURST,
	]:
		profile.radius = float(config.get("radius", profile.radius))
	if profile.preview_shape == SpellTargetingProfile.PreviewShape.LINE:
		profile.length = float(config.get("length", profile.maximum_range))
	if profile.preview_shape == SpellTargetingProfile.PreviewShape.CONE:
		profile.length = float(config.get("length", profile.maximum_range))

	if profile.placement_mode == SpellTargetingProfile.PlacementMode.FREE_GROUND:
		profile.require_ground = bool(config.get("require_ground", true))
		profile.clamp_to_range = bool(config.get("clamp_to_range", true))

	if ability != null:
		profile.valid_color = _element_color(ability.element, profile.valid_color)
		if profile.preview_label == "":
			profile.preview_label = ability.display_name


static func _infer_shape(
	targeting_style: String,
	delivery_type: String,
	config: Dictionary
) -> int:
	if config.has("radius") and float(config.get("radius", 0.0)) > 0.0:
		return SpellTargetingProfile.PreviewShape.CIRCLE
	match targeting_style:
		"ground", "ground_aoe", "area", "aoe", "field", "trap":
			return SpellTargetingProfile.PreviewShape.CIRCLE
		"cone", "fan":
			return SpellTargetingProfile.PreviewShape.CONE
		"line", "beam", "ray":
			return SpellTargetingProfile.PreviewShape.LINE
		"trajectory", "ballistic", "lob", "arc":
			return SpellTargetingProfile.PreviewShape.TRAJECTORY
		"self", "self_aoe", "burst":
			return SpellTargetingProfile.PreviewShape.SELF_BURST
		"target", "single_target", "lock_on":
			return SpellTargetingProfile.PreviewShape.TARGET_LOCK
	match delivery_type:
		"beam", "line":
			return SpellTargetingProfile.PreviewShape.LINE
		"field", "hazard", "trap":
			return SpellTargetingProfile.PreviewShape.CIRCLE
		"lob", "ballistic":
			return SpellTargetingProfile.PreviewShape.TRAJECTORY
		_:
			return SpellTargetingProfile.PreviewShape.POINT


static func _infer_placement(
	shape: int,
	targeting_style: String,
	delivery_type: String
) -> int:
	match shape:
		SpellTargetingProfile.PreviewShape.CIRCLE:
			return SpellTargetingProfile.PlacementMode.FREE_GROUND
		SpellTargetingProfile.PreviewShape.SELF_BURST:
			return SpellTargetingProfile.PlacementMode.SELF
		SpellTargetingProfile.PreviewShape.TARGET_LOCK:
			return SpellTargetingProfile.PlacementMode.TARGET
		SpellTargetingProfile.PreviewShape.TRAJECTORY:
			return SpellTargetingProfile.PlacementMode.BALLISTIC
		_:
			pass
	if targeting_style in ["ground", "ground_aoe", "field", "trap"]:
		return SpellTargetingProfile.PlacementMode.FREE_GROUND
	if delivery_type in ["lob", "ballistic"]:
		return SpellTargetingProfile.PlacementMode.BALLISTIC
	return SpellTargetingProfile.PlacementMode.FORWARD


static func _normalize(profile: SpellTargetingProfile) -> void:
	profile.maximum_range = maxf(profile.maximum_range, 0.0)
	profile.minimum_range = clampf(
		profile.minimum_range,
		0.0,
		profile.maximum_range if profile.maximum_range > 0.0 else profile.minimum_range
	)
	profile.radius = maxf(profile.radius, 0.05)
	profile.length = maxf(profile.length, 0.05)
	profile.width = maxf(profile.width, 0.05)
	profile.angle_degrees = clampf(profile.angle_degrees, 1.0, 179.0)
	profile.initial_distance = clampf(
		profile.initial_distance,
		profile.minimum_range,
		profile.maximum_range if profile.maximum_range > 0.0 else profile.initial_distance
	)
	profile.cursor_speed = maxf(profile.cursor_speed, 0.1)
	profile.input_deadzone = clampf(profile.input_deadzone, 0.0, 0.95)
	profile.fill_alpha = clampf(profile.fill_alpha, 0.0, 1.0)
	profile.outline_alpha = clampf(profile.outline_alpha, 0.0, 1.0)


static func _get_profile_id(ability: AbilityDefinition) -> String:
	if ability == null:
		return "runtime_targeting"
	return ability.get_spell_id() + "_targeting"


static func _element_color(element: String, fallback: Color) -> Color:
	match element.to_lower():
		"water":
			return Color(0.16, 0.48, 0.95, 1.0)
		"earth":
			return Color(0.52, 0.36, 0.16, 1.0)
		"fire":
			return Color(1.0, 0.28, 0.08, 1.0)
		"air":
			return Color(0.95, 0.48, 0.72, 1.0)
		"ice":
			return Color(0.5, 0.9, 1.0, 1.0)
		"metal":
			return Color(0.96, 0.78, 0.18, 1.0)
		"lightning":
			return Color(0.28, 0.46, 1.0, 1.0)
		"poison":
			return Color(0.48, 0.92, 0.22, 1.0)
		"life":
			return Color(0.1, 0.92, 0.5, 1.0)
		"death":
			return Color(0.82, 0.08, 0.08, 1.0)
		"body":
			return Color(0.92, 0.22, 0.72, 1.0)
		"soul":
			return Color(0.1, 0.86, 0.92, 1.0)
		"dreams":
			return Color(0.58, 0.22, 1.0, 1.0)
		"sound":
			return Color(1.0, 0.52, 0.08, 1.0)
		"space":
			return Color(0.58, 0.22, 1.0, 1.0)
		"time":
			return Color(0.98, 0.66, 0.16, 1.0)
		_:
			return fallback
