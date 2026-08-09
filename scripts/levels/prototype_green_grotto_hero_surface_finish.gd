extends "res://scripts/levels/prototype_green_grotto_hero_pass.gd"
class_name PrototypeGreenGrottoHeroSurfaceFinish

var hero_surface_counts: Dictionary = {
	"terrace_tiles": 0,
	"terrace_edge_blocks": 0,
	"shrine_deck_tiles": 0,
	"arrival_edge_rocks": 0,
}


func _ready() -> void:
	super._ready()
	_build_arrival_finish()
	_build_side_terrace_finish()
	_build_shrine_deck_finish()
	set_meta("hero_surface_finish", "v3_complete_visible_surface_replacement")
	set_meta("hero_surface_counts", hero_surface_counts.duplicate(true))


func _build_arrival_finish() -> void:
	var rock: Material = hero_materials.get_material("hero_rock")
	for index: int in range(16):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var along: float = -4.0 + float(index % 8) * 1.15
		var position_value: Vector3
		if index < 8:
			position_value = Vector3(side * 4.55, -0.10 + float(index % 3) * 0.08, 13.0 + along)
		else:
			position_value = Vector3(along, -0.08 + float(index % 3) * 0.08, 8.55 + side * 0.35)
		_add_hero_rock(
			hero_architecture_root,
			"ArrivalHeroEdge%02d" % index,
			position_value,
			0.48 + float(index % 4) * 0.11,
			rock,
			Vector3(1.25, 0.62, 1.0),
			float(index) * 0.43
		)
		hero_surface_counts["arrival_edge_rocks"] = int(hero_surface_counts["arrival_edge_rocks"]) + 1


func _build_side_terrace_finish() -> void:
	var paving: Material = hero_materials.get_material("hero_paving")
	var wet_paving: Material = hero_materials.get_material("hero_paving_wet")
	var masonry: Material = hero_materials.get_material("hero_masonry")

	_build_tiled_deck(
		"LeftHeroTerrace",
		Vector3(-6.2, 1.52, -3.8),
		Vector2(6.20, 6.20),
		4,
		4,
		paving,
		[3, 12]
	)
	_build_tiled_deck(
		"RightHeroTerrace",
		Vector3(6.5, 2.12, -8.0),
		Vector2(5.72, 6.70),
		4,
		5,
		wet_paving,
		[0, 4, 15]
	)
	_build_tiled_deck(
		"RightHeroLedge",
		Vector3(6.1, 2.245, -2.0),
		Vector2(3.45, 3.75),
		3,
		3,
		paving,
		[2, 8]
	)

	# Visible masonry skirts restore depth below the tiled decks without bringing
	# back the hidden monolithic terrace boxes.
	var terrace_specs: Array[Dictionary] = [
		{"name": "Left", "center": Vector3(-6.2, 1.0, -3.8), "size": Vector2(6.5, 6.5), "height": 1.0},
		{"name": "Right", "center": Vector3(6.5, 1.5, -8.0), "size": Vector2(6.0, 7.0), "height": 1.2},
		{"name": "Ledge", "center": Vector3(6.1, 1.95, -2.0), "size": Vector2(3.7, 4.0), "height": 0.55},
	]
	for spec: Dictionary in terrace_specs:
		_build_masonry_skirt(
			str(spec["name"]),
			spec["center"] as Vector3,
			spec["size"] as Vector2,
			float(spec["height"]),
			masonry
		)


func _build_shrine_deck_finish() -> void:
	var paving: Material = hero_materials.get_material("hero_paving")
	var wet_paving: Material = hero_materials.get_material("hero_paving_wet")
	var moss: Material = hero_materials.get_material("hero_moss")
	var columns: int = 6
	var rows: int = 5
	var tile_width: float = 11.8 / float(columns)
	var tile_depth: float = 8.45 / float(rows)
	for row: int in range(rows):
		for column: int in range(columns):
			var index: int = row * columns + column
			if index in [0, 5, 24, 29]:
				continue
			var material: Material = wet_paving if row >= 3 and column >= 4 else paving
			var tile := _add_visual_box(
				hero_architecture_root,
				"HeroShrineDeck%02d" % index,
				Vector3(tile_width - 0.085, 0.035, tile_depth - 0.085),
				Vector3(
					-5.9 + tile_width * (float(column) + 0.5),
					2.275 + float(index % 2) * 0.002,
					-18.925 + tile_depth * (float(row) + 0.5)
				),
				material,
				Vector3(0.0, sin(float(index) * 0.81) * 0.012, 0.0)
			)
			tile.set_meta("hero_surface", "shrine_deck")
			hero_surface_counts["shrine_deck_tiles"] = int(hero_surface_counts["shrine_deck_tiles"]) + 1

	# Moss collects on the outer course, while the central ceremonial path remains clear.
	for index: int in range(10):
		var side: float = -1.0 if index % 2 == 0 else 1.0
		var patch := _add_visual_sphere(
			hero_architecture_root,
			"HeroDeckMoss%02d" % index,
			Vector3(
				side * (4.6 + float(index % 3) * 0.35),
				2.315,
				-11.1 - float(index % 5) * 1.58
			),
			0.48 + float(index % 4) * 0.09,
			moss,
			Vector3(1.55, 0.025, 0.70)
		)
		patch.rotation.y = float(index) * 0.59


func _build_tiled_deck(
	label: String,
	center: Vector3,
	size: Vector2,
	columns: int,
	rows: int,
	material: Material,
	skipped_indices: Array[int]
) -> void:
	var tile_width: float = size.x / float(maxi(columns, 1))
	var tile_depth: float = size.y / float(maxi(rows, 1))
	for row: int in range(rows):
		for column: int in range(columns):
			var index: int = row * columns + column
			if skipped_indices.has(index):
				continue
			var x_value: float = center.x - size.x * 0.5 + tile_width * (float(column) + 0.5)
			var z_value: float = center.z - size.y * 0.5 + tile_depth * (float(row) + 0.5)
			var tile := _add_visual_box(
				hero_architecture_root,
				label + "Tile%02d" % index,
				Vector3(tile_width - 0.07, 0.035, tile_depth - 0.07),
				Vector3(
					x_value + sin(float(index) * 1.27) * 0.025,
					center.y + float(index % 2) * 0.002,
					z_value + cos(float(index) * 1.11) * 0.025
				),
				material,
				Vector3(0.0, sin(float(index) * 0.73) * 0.018, 0.0)
			)
			tile.set_meta("hero_surface", "terrace_tile")
			hero_surface_counts["terrace_tiles"] = int(hero_surface_counts["terrace_tiles"]) + 1


func _build_masonry_skirt(
	label: String,
	center: Vector3,
	size: Vector2,
	height: float,
	material: Material
) -> void:
	var course_count: int = maxi(1, ceili(height / 0.42))
	for course: int in range(course_count):
		var y_value: float = center.y - height * 0.5 + 0.22 + float(course) * 0.40
		var x_blocks: int = maxi(3, roundi(size.x / 0.92))
		var z_blocks: int = maxi(3, roundi(size.y / 0.92))
		for index: int in range(x_blocks):
			var x_value: float = center.x - size.x * 0.5 + size.x * (float(index) + 0.5) / float(x_blocks)
			for z_side: float in [-1.0, 1.0]:
				_add_visual_box(
					hero_architecture_root,
					label + "SkirtZ",
					Vector3(size.x / float(x_blocks) - 0.035, 0.38, 0.32),
					Vector3(x_value, y_value, center.z + z_side * (size.y * 0.5 - 0.12)),
					material,
					Vector3(0.0, sin(float(index + course)) * 0.014, 0.0)
				)
				hero_surface_counts["terrace_edge_blocks"] = int(hero_surface_counts["terrace_edge_blocks"]) + 1
		for index: int in range(z_blocks):
			var z_value: float = center.z - size.y * 0.5 + size.y * (float(index) + 0.5) / float(z_blocks)
			for x_side: float in [-1.0, 1.0]:
				_add_visual_box(
					hero_architecture_root,
					label + "SkirtX",
					Vector3(0.32, 0.38, size.y / float(z_blocks) - 0.035),
					Vector3(center.x + x_side * (size.x * 0.5 - 0.12), y_value, z_value),
					material,
					Vector3(0.0, 0.0, x_side * sin(float(index + course)) * 0.014)
				)
				hero_surface_counts["terrace_edge_blocks"] = int(hero_surface_counts["terrace_edge_blocks"]) + 1


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["green_grotto_hero_surface_finish"] = true
	data["hero_surface_counts"] = hero_surface_counts.duplicate(true)
	data["visible_surface_replacement"] = "all retired terrace/foundation tops receive V3 authored decks or masonry"
	return data
