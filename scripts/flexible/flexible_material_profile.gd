extends Resource
class_name FlexibleMaterialProfile

enum VisualStyle {
	ROPE,
	CHAIN,
	FILAMENT,
}

@export var material_id: String = "rope"
@export var display_name: String = "Rope"
@export var visual_style: VisualStyle = VisualStyle.ROPE
@export_range(0.01, 20.0, 0.01) var linear_density: float = 0.45
@export_range(1.0, 10000.0, 1.0) var stiffness: float = 850.0
@export_range(0.0, 500.0, 0.1) var tension_damping: float = 28.0
@export_range(1.0, 100000.0, 1.0) var break_strength: float = 900.0
@export_range(0.01, 0.5, 0.005) var radius: float = 0.055
@export var base_color: Color = Color(0.48, 0.28, 0.11, 1.0)
@export_range(0.0, 1.0, 0.01) var metallic: float = 0.0
@export_range(0.0, 1.0, 0.01) var roughness: float = 0.88

@export_category("Elemental Response")
@export var burnable: bool = true
@export_range(0.0, 1.0, 0.01) var ignition_threshold: float = 0.55
@export_range(0.0, 2.0, 0.01) var burn_rate: float = 0.34
@export var conductive: bool = false
@export_range(1.0, 4.0, 0.05) var frozen_stiffness_multiplier: float = 1.75
@export_range(0.05, 1.0, 0.05) var frozen_break_strength_multiplier: float = 0.42
@export var frozen_color: Color = Color(0.62, 0.88, 1.0, 1.0)


func effective_stiffness(cold_amount: float) -> float:
	return stiffness * lerpf(1.0, frozen_stiffness_multiplier, clampf(cold_amount, 0.0, 1.0))


func effective_break_strength(heat_amount: float, cold_amount: float, burn_progress: float) -> float:
	var cold_multiplier := lerpf(1.0, frozen_break_strength_multiplier, clampf(cold_amount, 0.0, 1.0))
	var heat_weakening := clampf(max(heat_amount - ignition_threshold, 0.0) + burn_progress, 0.0, 0.92)
	return maxf(1.0, break_strength * cold_multiplier * (1.0 - heat_weakening))


func is_ignited(heat_amount: float) -> bool:
	return burnable and heat_amount >= ignition_threshold

