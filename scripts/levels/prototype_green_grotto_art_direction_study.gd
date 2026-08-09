extends "res://scripts/levels/prototype_green_grotto_hero_surface_finish.gd"
class_name PrototypeGreenGrottoArtDirectionStudy

# This pass deliberately stops asking procedural detail systems to invent the
# composition. All previous geometry remains in the tree for collision and
# systems testing, but its visuals are hidden while a small hand-authored set
# establishes the art direction in large, readable shapes.

var direction_root: Node3D = null
var direction_counts: Dictionary = {
	"hidden_visual_roots": 0,
	"causeway_slabs": 0,
	"cliff_masses": 0,
	"gate_modules": 0,
	"shrine_modules": 0,
	"ecology_accents": 0,
}


func _ready() -> void:
	super._ready()
	_hide_procedural_visual_set()
	_build_direction_root()
	_build_structured_arrival()
	_build_structured_causeway()
	_build_paifang_gate()
	_build_structured_shrine()
	_build_restrained_ecology()
	_tune_direction_study_environment()
	set_meta("art_direction_study", "green_grotto_structured_v1")
	set_meta("art_direction_rule", "large_forms_before_detail")
	set_meta("direction_counts", direction_counts.duplicate(true))


func _hide_procedural_visual_set() -> void:
	for root: Node3D in [
		terrain_root,
		architecture_root,
		foliage_root,
		canopy_root,
		water_root,
		fauna_root,
		hero_root,
	]:
		if root == null:
			continue
		root.visible = false
		direction_counts["hidden_visual_roots"] = int(
			direction_counts["hidden_visual_roots"]
		) + 1


func _build_direction_root() -> void:
	direction_root = _new_root(environment_root, "ArtDirectionStudyV1")
	direction_root.set_meta("visual_only", true)
	direction_root.set_meta("collision_source", "hidden_prototype_scaffolds")


func _build_structured_arrival() -> void:
	var paving: Material = hero_materials.get_material("hero_paving")
	var rock: Material = hero_materials.get_material("hero_rock")
	var masonry: Material = hero_materials.get_material("hero_masonry")

	# One unmistakable starting terrace replaces the paving confetti.
	_add_visual_box(
		direction_root,
		"StudyArrivalDeck",
		Vector3(9.4, 0.18, 8.6),
		Vector3(0.0, 0.02, 13.0),
		paving
	)
	_add_visual_box(
		direction_root,
		"StudyArrivalThreshold",
		Vector3(6.8, 0.42, 1.0),
		Vector3(0.0, 0.18, 8.85),
		masonry
	)

	# Four large faceted cliff masses frame the route. They are intentionally
	# rectilinear and sparse, avoiding the previous wall of overlapping spheres.
	var cliff_specs: Array[Dictionary] = [
		{"name": "LeftNear", "size": Vector3(5.8, 10.0, 13.0), "pos": Vector3(-9.0, 3.1, 10.0), "rot": Vector3(0.04, -0.08, 0.09)},
		{"name": "RightNear", "size": Vector3(5.8, 10.5, 13.0), "pos": Vector3(9.2, 3.0, 9.3), "rot": Vector3(-0.03, 0.07, -0.08)},
		{"name": "LeftDeep", "size": Vector3(6.8, 12.0, 14.5), "pos": Vector3(-10.0, 3.0, -6.2), "rot": Vector3(0.03, 0.09, 0.06)},
		{"name": "RightDeep", "size": Vector3(6.8, 12.0, 14.5), "pos": Vector3(10.2, 3.0, -7.0), "rot": Vector3(-0.02, -0.08, -0.06)},
	]
	for spec: Dictionary in cliff_specs:
		_add_visual_box(
			direction_root,
			"StudyCliff" + str(spec["name"]),
			spec["size"] as Vector3,
			spec["pos"] as Vector3,
			rock,
			spec["rot"] as Vector3
		)
		direction_counts["cliff_masses"] = int(
			direction_counts["cliff_masses"]
		) + 1


func _build_structured_causeway() -> void:
	var paving: Material = hero_materials.get_material("hero_paving")
	var wet_paving: Material = hero_materials.get_material("hero_paving_wet")
	var masonry: Material = hero_materials.get_material("hero_masonry")
	var slabs: Array[Dictionary] = [
		{"pos": Vector3(0.0, 0.29, 8.7), "size": Vector3(5.35, 0.20, 3.75), "rot": Vector3(0.0, 0.02, 0.0)},
		{"pos": Vector3(-0.20, 0.41, 5.0), "size": Vector3(5.05, 0.20, 2.85), "rot": Vector3(0.008, -0.025, -0.012)},
		{"pos": Vector3(0.18, 0.62, 2.05), "size": Vector3(4.75, 0.20, 2.35), "rot": Vector3(-0.015, 0.04, 0.018)},
		{"pos": Vector3(-0.28, 0.87, -0.55), "size": Vector3(4.35, 0.20, 2.10), "rot": Vector3(0.02, -0.055, -0.03)},
		{"pos": Vector3(0.25, 1.06, -2.95), "size": Vector3(4.05, 0.20, 1.88), "rot": Vector3(-0.01, 0.075, 0.025)},
		{"pos": Vector3(0.04, 1.21, -5.15), "size": Vector3(3.78, 0.20, 1.78), "rot": Vector3(0.018, -0.035, -0.018)},
		{"pos": Vector3(-0.12, 1.35, -7.20), "size": Vector3(4.02, 0.20, 1.92), "rot": Vector3(-0.012, 0.025, 0.012)},
	]
	for index: int in range(slabs.size()):
		var spec: Dictionary = slabs[index]
		var material: Material = wet_paving if index >= 5 else paving
		_add_visual_box(
			direction_root,
			"StudyCauseway%02d" % index,
			spec["size"] as Vector3,
			spec["pos"] as Vector3,
			material,
			spec["rot"] as Vector3
		)
		direction_counts["causeway_slabs"] = int(
			direction_counts["causeway_slabs"]
		) + 1

	# Two masonry piers are enough to explain that the route is constructed.
	for z_value: float in [2.0, -4.95]:
		for side: float in [-1.0, 1.0]:
			_add_visual_box(
				direction_root,
				"StudyCausewayPier",
				Vector3(0.72, 2.7, 0.78),
				Vector3(side * 1.55, -0.70, z_value),
				masonry
			)


func _build_paifang_gate() -> void:
	var masonry: Material = hero_materials.get_material("hero_masonry")
	var trim: Material = hero_materials.get_material("hero_trim")
	var wood: Material = hero_materials.get_material("hero_wood")
	var roof: Material = hero_materials.get_material("hero_roof")
	var z_value: float = -8.05

	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			direction_root,
			"StudyGatePillar",
			Vector3(0.68, 4.8, 0.76),
			Vector3(side * 3.25, 3.72, z_value),
			masonry
		)
		_add_visual_box(
			direction_root,
			"StudyGateFoot",
			Vector3(1.15, 0.34, 1.15),
			Vector3(side * 3.25, 1.42, z_value),
			trim
		)
	_add_visual_box(
		direction_root,
		"StudyGateMainBeam",
		Vector3(8.0, 0.42, 0.78),
		Vector3(0.0, 5.75, z_value),
		wood
	)
	_add_visual_box(
		direction_root,
		"StudyGateUpperBeam",
		Vector3(6.4, 0.30, 0.58),
		Vector3(0.0, 6.45, z_value),
		trim
	)
	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			direction_root,
			"StudyGateRoof",
			Vector3(4.8, 0.28, 1.55),
			Vector3(side * 1.95, 6.88, z_value),
			roof,
			Vector3(0.0, 0.0, side * 0.08)
		)
	direction_counts["gate_modules"] = 9


func _build_structured_shrine() -> void:
	var masonry: Material = hero_materials.get_material("hero_masonry")
	var trim: Material = hero_materials.get_material("hero_trim")
	var wood: Material = hero_materials.get_material("hero_wood")
	var roof: Material = hero_materials.get_material("hero_roof")
	var paving: Material = hero_materials.get_material("hero_paving")

	# One broad terrace and a clear stair establish the final destination.
	_add_visual_box(
		direction_root,
		"StudyShrineTerrace",
		Vector3(12.0, 1.30, 8.8),
		Vector3(0.0, 1.52, -14.8),
		masonry
	)
	_add_visual_box(
		direction_root,
		"StudyShrineDeck",
		Vector3(11.5, 0.14, 8.2),
		Vector3(0.0, 2.23, -14.8),
		paving
	)
	for index: int in range(5):
		var height: float = 0.24 + float(index) * 0.24
		_add_visual_box(
			direction_root,
			"StudyShrineStep%02d" % index,
			Vector3(6.1 - float(index) * 0.15, height, 0.70),
			Vector3(0.0, 1.25 + height * 0.5, -9.05 - float(index) * 0.68),
			masonry
		)

	# Four columns, one back wall, and three beams make the building legible from
	# the gameplay camera before decorative language is considered.
	for x_value: float in [-3.4, 3.4]:
		for z_value: float in [-12.2, -17.0]:
			_add_visual_box(
				direction_root,
				"StudyShrineColumn",
				Vector3(0.72, 4.0, 0.72),
				Vector3(x_value, 4.3, z_value),
				masonry
			)
	_add_visual_box(
		direction_root,
		"StudyShrineBackWall",
		Vector3(7.5, 3.5, 0.40),
		Vector3(0.0, 4.0, -17.15),
		wood
	)
	for z_value: float in [-12.2, -17.0]:
		_add_visual_box(
			direction_root,
			"StudyShrineCrossBeam",
			Vector3(8.2, 0.38, 0.52),
			Vector3(0.0, 6.12, z_value),
			wood
		)
	_add_visual_box(
		direction_root,
		"StudyShrineRidgeBeam",
		Vector3(7.4, 0.28, 5.4),
		Vector3(0.0, 6.32, -14.6),
		trim
	)

	# Two oversized roof planes are the main stylistic silhouette. No roof tile
	# micro-detail until this shape itself feels right.
	for side: float in [-1.0, 1.0]:
		_add_visual_box(
			direction_root,
			"StudyShrineRoof",
			Vector3(10.2, 0.34, 3.6),
			Vector3(0.0, 7.02, -14.6 + side * 1.55),
			roof,
			Vector3(side * -0.20, 0.0, 0.0)
		)
	_add_visual_box(
		direction_root,
		"StudyShrineRoofRidge",
		Vector3(10.0, 0.48, 0.50),
		Vector3(0.0, 7.45, -14.6),
		roof
	)
	direction_counts["shrine_modules"] = 18

	var focus_light := OmniLight3D.new()
	focus_light.name = "StudyShrineFocusLight"
	focus_light.position = Vector3(0.0, 5.0, -14.0)
	focus_light.light_color = Color(1.0, 0.55, 0.24, 1.0)
	focus_light.light_energy = 1.65
	focus_light.omni_range = 13.0
	focus_light.shadow_enabled = false
	direction_root.add_child(focus_light)


func _build_restrained_ecology() -> void:
	var moss: Material = hero_materials.get_material("hero_moss")
	var accent_specs: Array[Dictionary] = [
		{"pos": Vector3(-4.8, 0.12, 10.0), "scale": Vector3(1.8, 0.08, 1.1)},
		{"pos": Vector3(4.8, 0.12, 7.0), "scale": Vector3(1.5, 0.07, 1.0)},
		{"pos": Vector3(-5.0, 2.30, -12.3), "scale": Vector3(1.6, 0.06, 0.9)},
		{"pos": Vector3(5.0, 2.30, -16.2), "scale": Vector3(1.6, 0.06, 0.9)},
	]
	for index: int in range(accent_specs.size()):
		var spec: Dictionary = accent_specs[index]
		var patch := _add_visual_sphere(
			direction_root,
			"StudyMossAccent%02d" % index,
			spec["pos"] as Vector3,
			0.72,
			moss,
			spec["scale"] as Vector3
		)
		patch.rotation.y = float(index) * 0.72
		direction_counts["ecology_accents"] = int(
			direction_counts["ecology_accents"]
		) + 1


func _tune_direction_study_environment() -> void:
	var world_environment: WorldEnvironment = get_node_or_null(
		"GreenGrottoArt/Lighting/GreenGrottoEnvironment"
	) as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		var environment: Environment = world_environment.environment
		environment.tonemap_exposure = 0.88
		environment.fog_density = 0.0028
		environment.fog_light_color = Color(0.18, 0.24, 0.20, 1.0)
		environment.fog_light_energy = 0.30
		environment.volumetric_fog_density = 0.009
		environment.volumetric_fog_albedo = Color(0.28, 0.36, 0.30, 1.0)
		environment.glow_intensity = 0.10
		environment.glow_bloom = 0.015

	var sun: DirectionalLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/CanopySunset"
	) as DirectionalLight3D
	if sun != null:
		sun.light_energy = 1.25
		sun.light_color = Color(1.0, 0.68, 0.42, 1.0)
		sun.light_volumetric_fog_energy = 0.65

	var fill: DirectionalLight3D = get_node_or_null(
		"GreenGrottoArt/Lighting/GrottoGreenFill"
	) as DirectionalLight3D
	if fill != null:
		fill.light_color = Color(0.16, 0.31, 0.26, 1.0)
		fill.light_energy = 0.46


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_art_direction_study"] = true
	data["art_direction_study"] = "structured_v1"
	data["direction_counts"] = direction_counts.duplicate(true)
	data["visual_strategy"] = "hide procedural set, preserve collision, author large forms by hand"
	return data
