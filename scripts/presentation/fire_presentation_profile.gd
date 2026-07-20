extends Resource
class_name FirePresentationProfile

@export var inner_color: Color = Color(1.0, 0.96, 0.58, 1.0)
@export var body_color: Color = Color(1.0, 0.34, 0.04, 0.9)
@export var fringe_color: Color = Color(0.72, 0.05, 0.015, 0.55)
@export var smoke_color: Color = Color(0.12, 0.1, 0.11, 0.52)
@export var ember_color: Color = Color(1.0, 0.46, 0.04, 1.0)
@export var flame_height: float = 1.8
@export var flame_radius: float = 0.55
@export var lick_count: int = 5
@export var flicker_speed: float = 13.0
@export var sway_strength: float = 0.24
@export var smoke_amount: int = 18
@export var ember_amount: int = 14
@export var light_energy: float = 4.2
@export var light_range: float = 5.0
@export var effect_lifetime: float = 1.4
@export var persistent: bool = false


func duplicate_profile() -> FirePresentationProfile:
	var copy := FirePresentationProfile.new()
	copy.inner_color = inner_color
	copy.body_color = body_color
	copy.fringe_color = fringe_color
	copy.smoke_color = smoke_color
	copy.ember_color = ember_color
	copy.flame_height = flame_height
	copy.flame_radius = flame_radius
	copy.lick_count = lick_count
	copy.flicker_speed = flicker_speed
	copy.sway_strength = sway_strength
	copy.smoke_amount = smoke_amount
	copy.ember_amount = ember_amount
	copy.light_energy = light_energy
	copy.light_range = light_range
	copy.effect_lifetime = effect_lifetime
	copy.persistent = persistent
	return copy


func apply_kind(kind: String) -> FirePresentationProfile:
	match kind:
		"torch":
			flame_height = 1.25
			flame_radius = 0.3
			lick_count = 4
			smoke_amount = 10
			ember_amount = 5
			light_energy = 2.8
			light_range = 3.8
		"bonfire":
			flame_height = 3.1
			flame_radius = 1.15
			lick_count = 9
			smoke_amount = 34
			ember_amount = 30
			light_energy = 8.5
			light_range = 9.5
		"smolder":
			flame_height = 0.38
			flame_radius = 0.42
			lick_count = 2
			smoke_amount = 28
			ember_amount = 10
			light_energy = 0.7
			light_range = 2.0
		"firebolt":
			flame_height = 1.65
			flame_radius = 0.42
			lick_count = 6
			smoke_amount = 4
			ember_amount = 24
			light_energy = 4.6
			light_range = 4.5
			effect_lifetime = 0.24
		"extinguish":
			flame_height = 0.55
			flame_radius = 0.7
			lick_count = 1
			smoke_amount = 38
			ember_amount = 4
			light_energy = 0.25
			light_range = 1.5
	return self
