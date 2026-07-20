extends Resource
class_name IcePresentationProfile

@export var front_branch_count: int = 8
@export var front_segment_count: int = 8
@export var front_jitter: float = 0.22
@export var frost_branch_count: int = 12
@export var crack_branch_count: int = 7
@export var crack_segment_count: int = 6
@export var crack_jitter: float = 0.18
@export var crystal_count: int = 14
@export var crystal_height: float = 1.25
@export var crystal_radius: float = 0.08
@export var crystal_spread: float = 1.0
@export var shard_count: int = 24
@export var line_emission: float = 2.4
@export var surface_opacity: float = 0.62
@export var effect_lifetime: float = 1.8
@export var maximum_active_effects: int = 72
@export var ice_color: Color = Color(0.52, 0.86, 1.0, 1.0)
@export var frost_color: Color = Color(0.84, 0.98, 1.0, 1.0)
@export var crack_color: Color = Color(0.18, 0.48, 0.72, 1.0)
@export var melt_color: Color = Color(0.4, 0.78, 1.0, 0.72)


static func make_freeze_front() -> IcePresentationProfile:
	var profile := IcePresentationProfile.new()
	profile.front_branch_count = 10
	profile.front_segment_count = 9
	profile.front_jitter = 0.28
	profile.surface_opacity = 0.68
	profile.effect_lifetime = 2.2
	return profile


static func make_crystal_garden() -> IcePresentationProfile:
	var profile := IcePresentationProfile.new()
	profile.crystal_count = 22
	profile.crystal_height = 1.8
	profile.crystal_radius = 0.105
	profile.crystal_spread = 1.6
	profile.effect_lifetime = 3.4
	return profile


static func make_frost_wall() -> IcePresentationProfile:
	var profile := IcePresentationProfile.new()
	profile.frost_branch_count = 18
	profile.front_segment_count = 10
	profile.front_jitter = 0.34
	profile.line_emission = 1.7
	profile.effect_lifetime = 3.0
	return profile


static func make_crack() -> IcePresentationProfile:
	var profile := IcePresentationProfile.new()
	profile.crack_branch_count = 9
	profile.crack_segment_count = 8
	profile.crack_jitter = 0.24
	profile.line_emission = 3.0
	profile.effect_lifetime = 2.4
	return profile


static func make_projectile() -> IcePresentationProfile:
	var profile := IcePresentationProfile.new()
	profile.crystal_count = 7
	profile.crystal_height = 0.75
	profile.crystal_radius = 0.055
	profile.crystal_spread = 0.18
	profile.shard_count = 14
	profile.effect_lifetime = 0.65
	return profile
