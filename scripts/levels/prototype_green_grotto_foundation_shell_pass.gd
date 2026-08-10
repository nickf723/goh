extends "res://scripts/levels/prototype_green_grotto_calibration_kit_pass.gd"
class_name PrototypeGreenGrottoFoundationShellPass

# The calibration kit answers repeated-asset questions. This shell answers the
# larger spatial question the kit cannot: what continuous place do those assets
# belong to? The shell stays deliberately broad and visual-only while the proven
# Green Grotto blockout remains authoritative for traversal and collision.

var foundation_shell_root: Node3D = null
var foundation_shell_counts: Dictionary = {
	"basin_surfaces": 0,
	"water_surfaces": 0,
	"land_masses": 0,
	"canyon_underfills": 0,
	"background_closures": 0,
}


func _ready() -> void:
	super._ready()
	_build_foundation_shell_root()
	_build_basin_substrate()
	_build_continuous_water_body()
	_build_arrival_landmass()
	_build_canyon_underfill()
	_build_shrine_island()
	_build_background_closure()
	set_meta("foundation_shell", "green_earth_foundation_v0_1")
	set_meta("foundation_shell_collision", "visual_only_existing_blockout_authoritative")
	set_meta("foundation_shell_counts", foundation_shell_counts.duplicate(true))
	set_meta("foundation_shell_rule", "continuous_world_before_environment_dressing")


func _build_foundation_shell_root() -> void:
	foundation_shell_root = _new_root(environment_root, "GreenEarthFoundationShellV01")
	foundation_shell_root.add_to_group("green_earth_foundation_shell")
	foundation_shell_root.set_meta("visual_only", true)
	foundation_shell_root.set_meta("collision_source", "hidden_green_grotto_blockout")
	foundation_shell_root.set_meta("authoring_role", "unique_world_shell_not_reusable_asset_kit")


func _build_basin_substrate() -> void:
	var rock: Material = hero_materials.get_material("hero_rock")
	var wet_rock: Material = hero_materials.get_material("hero_rock_wet")

	# A broad floor gives the water a bottom and prevents the route from reading as
	# suspended over a void. It deliberately extends beyond the camera's likely
	# view so gaps between kit pieces still belong to one physical canyon.
	_add_visual_box(
		foundation_shell_root,
		"BasinFloor",
		Vector3(21.0, 1.30, 34.0),
		Vector3(0.0, -3.65, -1.5),
		rock,
		Vector3(0.015, 0.015, -0.01)
	)
	foundation_shell_counts["basin_surfaces"] = 1

	# A slightly raised wet shelf beneath the central water channel keeps the deep
	# basin from becoming a single featureless dark rectangle through transparent
	# water, while remaining far below traversal height.
	_add_visual_box(
		foundation_shell_root,
		"BasinChannelShelf",
		Vector3(14.5, 0.55, 25.0),
		Vector3(0.0, -2.75, -2.0),
		wet_rock,
		Vector3(-0.01, 0.0, 0.008)
	)
	foundation_shell_counts["basin_surfaces"] = 2


func _build_continuous_water_body() -> void:
	var deep_water: Material = hero_materials.get_material("hero_water_deep")
	var water := _add_visual_box(
		foundation_shell_root,
		"CanyonWaterBody",
		Vector3(16.8, 0.075, 28.5),
		Vector3(0.0, -0.38, -1.3),
		deep_water
	)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("foundation_water", true)
	water.set_meta("waterline_y", -0.3425)
	foundation_shell_counts["water_surfaces"] = 1


func _build_arrival_landmass() -> void:
	var rock: Material = hero_materials.get_material("hero_rock")
	var wet_rock: Material = hero_materials.get_material("hero_rock_wet")

	# The starting shelf is now visibly attached to the canyon rather than ending
	# at the first path module. Its top stays at the authored blockout's y=0 plane.
	_add_visual_box(
		foundation_shell_root,
		"ArrivalBank",
		Vector3(11.2, 2.35, 8.7),
		Vector3(0.0, -1.175, 13.0),
		rock,
		Vector3(0.015, 0.0, 0.0)
	)
	foundation_shell_counts["land_masses"] = int(
		foundation_shell_counts["land_masses"]
	) + 1

	# Two low wet shoulders soften the abrupt transition from arrival shelf to the
	# main water corridor without placing decorative rubble everywhere.
	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			foundation_shell_root,
			"ArrivalWetShoulder",
			Vector3(2.6, 1.1, 6.0),
			Vector3(side * 5.05, -0.88, 10.9),
			wet_rock,
			Vector3(0.0, side * 0.07, side * 0.025)
		)
		foundation_shell_counts["land_masses"] = int(
			foundation_shell_counts["land_masses"]
		) + 1


func _build_canyon_underfill() -> void:
	var rock: Material = hero_materials.get_material("hero_rock")
	var wet_rock: Material = hero_materials.get_material("hero_rock_wet")

	# These are not hero cliff assets. They are broad lower canyon masses that make
	# the four calibration cliff modules visibly emerge from one geological body.
	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			foundation_shell_root,
			"CanyonFootNear",
			Vector3(4.9, 3.25, 17.0),
			Vector3(side * 8.25, -1.95, 7.0),
			wet_rock,
			Vector3(0.0, side * -0.035, side * 0.035)
		)
		_add_visual_box(
			foundation_shell_root,
			"CanyonFootDeep",
			Vector3(5.4, 4.0, 18.0),
			Vector3(side * 8.85, -2.15, -9.0),
			rock,
			Vector3(0.015, side * 0.045, side * 0.025)
		)
		foundation_shell_counts["canyon_underfills"] = int(
			foundation_shell_counts["canyon_underfills"]
		) + 2


func _build_shrine_island() -> void:
	var masonry: Material = hero_materials.get_material("hero_masonry")
	var wet_rock: Material = hero_materials.get_material("hero_rock_wet")

	# The shrine kit sits on a broad geological island. The top reaches y=1.05,
	# exactly where the calibration shrine platform begins, so architecture reads as
	# built *on* the world rather than floating above water.
	_add_visual_box(
		foundation_shell_root,
		"ShrineIslandCore",
		Vector3(13.2, 3.15, 10.8),
		Vector3(0.0, -0.525, -15.0),
		wet_rock,
		Vector3(-0.01, 0.0, 0.0)
	)
	foundation_shell_counts["land_masses"] = int(
		foundation_shell_counts["land_masses"]
	) + 1

	# A quieter masonry apron bridges the final route into the stair without
	# competing with the reusable shrine platform itself.
	_add_visual_box(
		foundation_shell_root,
		"ShrineApproachApron",
		Vector3(8.4, 1.25, 3.0),
		Vector3(0.0, 0.325, -9.65),
		masonry,
		Vector3(0.0, 0.0, -0.015)
	)
	foundation_shell_counts["land_masses"] = int(
		foundation_shell_counts["land_masses"]
	) + 1


func _build_background_closure() -> void:
	var rock: Material = hero_materials.get_material("hero_rock")

	# The rear canyon wall closes the finite study set. Two angled returns keep the
	# camera from finding bright void slivers when it rotates around Grace.
	_add_visual_box(
		foundation_shell_root,
		"RearCanyonClosure",
		Vector3(22.0, 14.0, 6.0),
		Vector3(0.0, 2.2, -25.0),
		rock,
		Vector3(-0.045, 0.0, 0.0)
	)
	foundation_shell_counts["background_closures"] = 1

	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			foundation_shell_root,
			"RearCanyonReturn",
			Vector3(6.5, 12.0, 10.0),
			Vector3(side * 9.2, 1.1, -20.0),
			rock,
			Vector3(0.0, side * 0.22, side * -0.03)
		)
		foundation_shell_counts["background_closures"] = int(
			foundation_shell_counts["background_closures"]
		) + 1


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_foundation_shell_pass"] = true
	data["foundation_shell"] = "green_earth_foundation_v0_1"
	data["foundation_shell_counts"] = foundation_shell_counts.duplicate(true)
	data["foundation_shell_visual_only"] = true
	data["foundation_shell_waterline_y"] = -0.3425
	data["foundation_shell_world_continuity"] = "basin + water + arrival land + canyon feet + shrine island + rear closure"
	data["foundation_shell_collision_authority"] = "hidden_green_grotto_blockout"
	return data
