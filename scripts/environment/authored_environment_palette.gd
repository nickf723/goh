extends Resource
class_name AuthoredEnvironmentPalette

@export_group("Architecture")
@export var stone_primary: Color = Color(0.27, 0.29, 0.29, 1.0)
@export var stone_secondary: Color = Color(0.34, 0.35, 0.33, 1.0)
@export var stone_dark: Color = Color(0.14, 0.17, 0.18, 1.0)
@export var stone_wet: Color = Color(0.18, 0.24, 0.25, 1.0)
@export var mortar: Color = Color(0.20, 0.21, 0.20, 1.0)
@export var wood_primary: Color = Color(0.28, 0.18, 0.10, 1.0)
@export var wood_dark: Color = Color(0.13, 0.09, 0.06, 1.0)
@export var metal_primary: Color = Color(0.43, 0.34, 0.18, 1.0)
@export var metal_dark: Color = Color(0.20, 0.18, 0.14, 1.0)

@export_group("Ground and Water")
@export var soil: Color = Color(0.17, 0.20, 0.14, 1.0)
@export var mud: Color = Color(0.15, 0.13, 0.10, 1.0)
@export var moss: Color = Color(0.15, 0.27, 0.17, 1.0)
@export var vegetation: Color = Color(0.10, 0.24, 0.15, 1.0)
@export var water_surface: Color = Color(0.07, 0.25, 0.34, 0.72)
@export var water_deep: Color = Color(0.035, 0.13, 0.19, 0.82)
@export var water_highlight: Color = Color(0.24, 0.66, 0.82, 0.68)

@export_group("Accents and Light")
@export var accent_cool: Color = Color(0.34, 0.75, 0.94, 1.0)
@export var accent_mystic: Color = Color(0.72, 0.46, 0.96, 1.0)
@export var accent_warm: Color = Color(0.96, 0.66, 0.26, 1.0)
@export var moon_light: Color = Color(0.46, 0.62, 0.78, 1.0)
@export var lantern_light: Color = Color(1.0, 0.56, 0.24, 1.0)
@export var fog_color: Color = Color(0.08, 0.14, 0.17, 1.0)


func color(color_id: String, fallback: Color = Color.WHITE) -> Color:
	match color_id:
		"stone", "stone_primary":
			return stone_primary
		"stone_secondary":
			return stone_secondary
		"stone_dark":
			return stone_dark
		"stone_wet":
			return stone_wet
		"mortar":
			return mortar
		"wood", "wood_primary":
			return wood_primary
		"wood_dark":
			return wood_dark
		"metal", "metal_primary":
			return metal_primary
		"metal_dark":
			return metal_dark
		"soil":
			return soil
		"mud":
			return mud
		"moss":
			return moss
		"vegetation":
			return vegetation
		"water", "water_surface":
			return water_surface
		"water_deep":
			return water_deep
		"water_highlight":
			return water_highlight
		"accent", "accent_cool":
			return accent_cool
		"accent_mystic":
			return accent_mystic
		"accent_warm":
			return accent_warm
		"moon_light":
			return moon_light
		"lantern_light":
			return lantern_light
		"fog":
			return fog_color
		_:
			return fallback
