extends Node
class_name DrownedBellEnvironmentPass

const BuilderScript = preload("res://scripts/environment/authored_environment_builder.gd")
const ChapelPalette = preload("res://data/environment_palettes/drowned_chapel_palette.tres")

var mission: Node3D
var world: Node3D
var authored_root: Node3D
var flooded_state: Node3D
var quiet_state: Node3D
var water_volume: Area3D
var builder
var installed: bool = false
var build_stats: Dictionary = {}


func _ready() -> void:
	add_to_group("authored_environment_pass")
	call_deferred("_install")


func _install() -> void:
	if installed:
		return
	mission = get_parent() as Node3D
	if mission == null:
		return
	world = mission.get_node_or_null("World") as Node3D
	if world == null:
		return
	_reset_legacy_world()
	authored_root = Node3D.new()
	authored_root.name = "AuthoredEnvironmentV2"
	authored_root.add_to_group("authored_environment_root")
	authored_root.set_meta("environment_pass", "drowned_chapel_v2_2")
	world.add_child(authored_root)
	builder = BuilderScript.new(authored_root, ChapelPalette)
	_build_shore_and_causeway()
	_build_chapel_shell()
	_build_architecture()
	_build_props_and_overgrowth()
	_build_water_states()
	_restyle_story_props()
	_configure_lighting()
	build_stats = builder.get_build_stats()
	installed = true


func _reset_legacy_world() -> void:
	flooded_state = world.get_node_or_null("FloodedState") as Node3D
	quiet_state = world.get_node_or_null("QuietState") as Node3D
	for child: Node in world.get_children():
		if child == flooded_state or child == quiet_state:
			_clear_children(child)
		else:
			world.remove_child(child)
			child.free()
	if flooded_state == null:
		flooded_state = Node3D.new()
		flooded_state.name = "FloodedState"
		world.add_child(flooded_state)
	if quiet_state == null:
		quiet_state = Node3D.new()
		quiet_state.name = "QuietState"
		quiet_state.visible = false
		world.add_child(quiet_state)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.free()


func _build_shore_and_causeway() -> void:
	var shore: Node3D = builder.add_root(authored_root, "ShoreAndCauseway")
	builder.add_static_box(shore, "ShoreGround", Vector3(34.0, 0.9, 18.0), Vector3(0.0, -0.45, -5.0), "soil")
	builder.add_static_box(shore, "RoadApproach", Vector3(8.0, 0.18, 15.0), Vector3(0.0, 0.08, -5.0), "mud")
	builder.add_static_box(shore, "WestBank", Vector3(11.0, 1.2, 9.0), Vector3(-11.0, 0.1, -2.0), "soil", Vector3(0.0, 0.08, -0.035))
	builder.add_static_box(shore, "EastBank", Vector3(11.0, 1.0, 10.0), Vector3(11.0, 0.0, -1.5), "soil", Vector3(0.0, -0.07, 0.03))
	builder.add_static_box(shore, "CausewayCore", Vector3(5.0, 0.55, 28.5), Vector3(0.0, -0.14, 10.5), "stone_wet")
	for index: int in range(9):
		var offset_x: float = sin(float(index) * 1.7) * 0.12
		var yaw: float = sin(float(index) * 0.83) * 0.018
		var slab_color: String = "stone_secondary" if index % 3 == 0 else "stone_primary"
		builder.add_visual_box(shore, "CausewaySlab%02d" % index, Vector3(4.65, 0.16, 3.16), Vector3(offset_x, 0.18 + float(index % 2) * 0.025, -2.15 + float(index) * 3.15), slab_color, Vector3(0.0, yaw, 0.0))
	for side: float in [-1.0, 1.0]:
		for index: int in range(6):
			var post_height: float = 0.62 if index in [2, 5] else 1.2
			builder.add_visual_box(shore, "CausewayPost_%s_%02d" % ["L" if side < 0.0 else "R", index], Vector3(0.42, post_height, 0.42), Vector3(side * 2.7, post_height * 0.5, -0.5 + float(index) * 4.8), "stone_secondary", Vector3(0.0, side * 0.08, side * 0.025))
	_build_reed_cluster(shore, "ReedsWest", Vector3(-7.5, 0.0, 0.8), 9)
	_build_reed_cluster(shore, "ReedsEast", Vector3(7.7, 0.0, 2.5), 8)
	_build_reed_cluster(shore, "ReedsCauseway", Vector3(-3.7, 0.0, 11.0), 6)
	_build_lantern(shore, "OrinLantern", Vector3(-3.8, 0.0, -3.3))


func _build_chapel_shell() -> void:
	var shell: Node3D = builder.add_root(authored_root, "ChapelShell")
	builder.add_static_box(shell, "NaveFloor", Vector3(9.4, 0.65, 13.8), Vector3(-2.15, -0.33, 29.45), "stone_wet")
	builder.add_static_box(shell, "EastVestibuleFloor", Vector3(4.7, 0.65, 3.2), Vector3(4.35, -0.33, 24.3), "stone_wet")
	builder.add_static_box(shell, "EastRearFloor", Vector3(4.7, 0.65, 3.1), Vector3(4.35, -0.33, 34.45), "stone_wet")
	builder.add_static_box(shell, "PoolOuterWalkway", Vector3(0.72, 0.65, 7.2), Vector3(6.75, -0.33, 29.55), "stone_wet")
	builder.add_static_box(shell, "PoolWestRim", Vector3(0.78, 0.65, 7.2), Vector3(1.95, -0.33, 29.55), "stone_wet", Vector3.ZERO, true)
	builder.add_static_box(shell, "PoolBasinFloor", Vector3(5.05, 0.5, 5.7), Vector3(4.35, -3.22, 29.55), "stone_dark")
	builder.add_static_box(shell, "PoolEastRetainingWall", Vector3(0.42, 3.2, 5.7), Vector3(6.86, -1.55, 29.55), "stone_dark", Vector3.ZERO, true)
	builder.add_static_box(shell, "PoolFrontRetainingWall", Vector3(5.05, 3.2, 0.38), Vector3(4.35, -1.55, 26.72), "stone_dark", Vector3.ZERO, true)
	builder.add_stair_run(shell, "MainPoolStairs", Vector3(6.42, -3.02, 28.15), Vector3.LEFT, 7, 2.0, 0.62, 3.02, "stone_wet", true)
	builder.add_static_box(shell, "PoolExitStepLip", Vector3(0.82, 0.55, 2.2), Vector3(1.66, -0.27, 28.15), "stone_secondary", Vector3.ZERO, true)
	builder.add_stair_run(shell, "RearPoolStairs", Vector3(4.75, -3.02, 30.45), Vector3.BACK, 4, 1.75, 0.67, 2.95, "stone_wet", true)
	builder.add_static_box(shell, "PoolBackClimbLedge", Vector3(2.3, 0.55, 0.9), Vector3(4.72, 0.02, 33.12), "stone_secondary", Vector3.ZERO, true)
	builder.add_static_box(shell, "DryRecoveryLedge", Vector3(4.65, 0.48, 1.45), Vector3(4.35, 0.12, 33.65), "stone_secondary", Vector3.ZERO, true)
	builder.add_static_box(shell, "WestWall", Vector3(0.72, 6.8, 14.8), Vector3(-7.05, 3.4, 29.5), "stone_primary")
	builder.add_static_box(shell, "EastWall", Vector3(0.72, 6.8, 14.8), Vector3(7.05, 3.4, 29.5), "stone_primary")
	builder.add_static_box(shell, "BackWall", Vector3(14.8, 6.8, 0.72), Vector3(0.0, 3.4, 36.55), "stone_primary")
	builder.add_static_box(shell, "FrontWallWest", Vector3(4.9, 6.0, 0.72), Vector3(-4.95, 3.0, 22.55), "stone_primary")
	builder.add_static_box(shell, "FrontWallEast", Vector3(4.9, 6.0, 0.72), Vector3(4.95, 3.0, 22.55), "stone_primary")
	builder.add_archway(shell, "EntranceArch", Vector3(0.0, 0.0, 22.55), 3.8, 4.65, 0.95, 0.72, "stone_primary")
	for course: int in range(4):
		var y_value: float = 0.9 + float(course) * 1.38
		builder.add_visual_box(shell, "WestMortar%02d" % course, Vector3(0.04, 0.055, 14.1), Vector3(-6.68, y_value, 29.5), "mortar")
		builder.add_visual_box(shell, "EastMortar%02d" % course, Vector3(0.04, 0.055, 14.1), Vector3(6.68, y_value, 29.5), "mortar")


func _build_architecture() -> void:
	var architecture: Node3D = builder.add_root(authored_root, "Architecture")
	for z_value: float in [25.6, 30.0, 34.2]:
		builder.add_pillar(architecture, "WestPillar_%s" % str(z_value).replace(".", "_"), Vector3(-3.95, 0.0, z_value), 5.4, 0.34, "stone_primary")
	for z_value: float in [25.6, 34.15]:
		builder.add_pillar(architecture, "EastPillar_%s" % str(z_value).replace(".", "_"), Vector3(1.15, 0.0, z_value), 5.4, 0.34, "stone_primary")
	for z_value: float in [25.6, 30.0, 34.15]:
		builder.add_visual_box(architecture, "NaveCrossbeam_%s" % str(z_value).replace(".", "_"), Vector3(5.0, 0.34, 0.48), Vector3(-1.4, 5.15, z_value), "stone_secondary")
	for index: int in range(5):
		var z_value: float = 23.8 + float(index) * 3.0
		var tilt: float = -0.08 + float(index % 3) * 0.07
		builder.add_visual_box(architecture, "RafterLeft%02d" % index, Vector3(7.0, 0.22, 0.34), Vector3(-3.25, 6.15 + float(index % 2) * 0.18, z_value), "wood_dark", Vector3(0.0, 0.0, -0.2 + tilt))
		builder.add_visual_box(architecture, "RafterRight%02d" % index, Vector3(7.0, 0.22, 0.34), Vector3(3.25, 6.05, z_value), "wood_dark", Vector3(0.0, 0.0, 0.2 - tilt))
	_build_memorial_arcade(architecture)
	_build_bell_frame(architecture)
	_build_altar_and_crypt(architecture)
	_build_rose_window(architecture)


func _build_memorial_arcade(parent: Node3D) -> void:
	var arcade: Node3D = builder.add_root(parent, "MemorialArcade")
	for index: int in range(4):
		var z_value: float = 25.1 + float(index) * 2.55
		builder.add_visual_box(arcade, "Niche%02d" % index, Vector3(0.09, 1.25, 1.55), Vector3(-6.63, 1.45, z_value), "stone_dark")
		builder.add_visual_torus(arcade, "NicheHalo%02d" % index, 0.5, 0.57, Vector3(-6.54, 1.55, z_value), "stone_secondary", Vector3(0.0, 0.0, PI / 2.0))
		builder.add_visual_box(arcade, "MemorialShelf%02d" % index, Vector3(0.55, 0.12, 1.6), Vector3(-6.35, 0.7, z_value), "stone_secondary")
		if index != 1:
			_build_small_candle(arcade, Vector3(-6.05, 0.82, z_value + 0.35), index)


func _build_bell_frame(parent: Node3D) -> void:
	var frame: Node3D = builder.add_root(parent, "BellFrame", Vector3(-1.35, 0.0, 30.65))
	for side: float in [-1.0, 1.0]:
		var suffix: String = "L" if side < 0.0 else "R"
		builder.add_visual_box(frame, "Post%s" % suffix, Vector3(0.38, 5.4, 0.46), Vector3(side * 1.25, 2.7, 0.0), "wood_dark", Vector3(0.0, 0.0, side * 0.035))
		builder.add_visual_box(frame, "Brace%s" % suffix, Vector3(0.22, 3.2, 0.28), Vector3(side * 0.72, 2.0, 0.0), "wood_primary", Vector3(0.0, 0.0, -side * 0.42))
	builder.add_visual_box(frame, "Crossbeam", Vector3(3.4, 0.42, 0.58), Vector3(0.0, 5.05, 0.0), "wood_dark")
	builder.add_visual_cylinder(frame, "Bell", 0.38, 0.88, 1.45, Vector3(0.0, 3.75, 0.0), "metal_primary", Vector3.ZERO, 1.0, 0.08)
	builder.add_visual_sphere(frame, "Clapper", 0.18, Vector3(0.0, 2.95, 0.0), "metal_dark")
	builder.add_visual_cylinder(frame, "BellYoke", 0.12, 0.12, 2.2, Vector3(0.0, 4.65, 0.0), "metal_dark", Vector3(0.0, 0.0, PI / 2.0))


func _build_altar_and_crypt(parent: Node3D) -> void:
	var altar_root: Node3D = builder.add_root(parent, "AltarAndCrypt")
	builder.add_static_box(altar_root, "AltarDais", Vector3(5.6, 0.58, 3.9), Vector3(-1.8, 0.29, 33.75), "stone_secondary")
	builder.add_stair_run(altar_root, "AltarSteps", Vector3(-1.8, 0.0, 31.55), Vector3.BACK, 3, 3.8, 0.5, 0.58, "stone_secondary", false)
	builder.add_static_box(altar_root, "AltarTable", Vector3(2.7, 1.05, 1.05), Vector3(-1.8, 1.1, 34.1), "stone_primary")
	builder.add_visual_box(altar_root, "AltarCloth", Vector3(2.35, 0.08, 0.82), Vector3(-1.8, 1.66, 34.0), "accent_mystic", Vector3.ZERO, 0.58, 0.35)
	builder.add_archway(altar_root, "CryptFrame", Vector3(-1.8, 0.0, 36.16), 3.5, 3.35, 0.65, 0.62, "stone_secondary")
	builder.add_visual_box(altar_root, "CryptShadow", Vector3(3.35, 3.2, 0.12), Vector3(-1.8, 1.62, 35.78), "stone_dark")


func _build_rose_window(parent: Node3D) -> void:
	var rose: Node3D = builder.add_root(parent, "RoseWindow", Vector3(2.65, 4.45, 36.1), Vector3(PI / 2.0, 0.0, 0.0))
	builder.add_visual_torus(rose, "OuterRing", 1.05, 1.18, Vector3.ZERO, "stone_secondary")
	builder.add_visual_torus(rose, "GlassRing", 0.62, 0.98, Vector3.ZERO, "accent_cool", Vector3.ZERO, 0.38, 0.45)
	builder.add_visual_sphere(rose, "CenterGlass", 0.34, Vector3.ZERO, "accent_mystic", Vector3(1.0, 0.28, 1.0), 0.42, 0.55)
	for index: int in range(8):
		builder.add_visual_box(rose, "Spoke%02d" % index, Vector3(0.08, 0.06, 1.7), Vector3.ZERO, "stone_secondary", Vector3(0.0, float(index) * PI / 4.0, 0.0))


func _build_props_and_overgrowth() -> void:
	var props: Node3D = builder.add_root(authored_root, "PropsAndOvergrowth")
	var pews: Node3D = builder.add_root(props, "BrokenPews")
	var pew_positions: Array[Vector3] = [Vector3(-2.25, 0.0, 25.8), Vector3(-2.2, 0.0, 28.0), Vector3(-2.15, 0.0, 30.2), Vector3(0.05, 0.0, 25.8), Vector3(0.05, 0.0, 28.0)]
	for index: int in range(pew_positions.size()):
		builder.add_bench(pews, "Pew%02d" % index, pew_positions[index], 1.55 if index == 2 else 2.0, 0.04 if index >= 3 else 0.0, -0.45 + float(index) * 0.2)
	builder.add_visual_box(props, "FallenPew", Vector3(2.2, 0.18, 0.62), Vector3(4.2, 0.48, 25.7), "wood_primary", Vector3(0.08, 0.4, 0.22))
	builder.add_visual_box(props, "BrokenBeam", Vector3(5.2, 0.34, 0.42), Vector3(3.8, 1.2, 34.4), "wood_dark", Vector3(0.08, 0.24, -0.18))
	builder.add_visual_cylinder(props, "FallenColumn", 0.34, 0.42, 4.3, Vector3(5.6, 0.55, 26.1), "stone_secondary", Vector3(0.0, 0.0, PI / 2.0))
	for index: int in range(6):
		var x_value: float = -6.55 + float(index % 2) * 13.1
		var z_value: float = 24.0 + float(index) * 2.15
		builder.add_visual_cylinder(props, "Root%02d" % index, 0.07, 0.11, 2.4 + float(index % 3) * 0.4, Vector3(x_value, 4.6, z_value), "wood_dark", Vector3(0.18 + float(index % 2) * 0.2, 0.0, -0.18 + float(index % 3) * 0.16))
	_build_reed_cluster(props, "InteriorReeds", Vector3(6.2, 0.0, 32.8), 7)
	_build_reed_cluster(props, "PoolReeds", Vector3(5.9, -2.8, 27.5), 5)


func _build_water_states() -> void:
	var flooded_visuals: Node3D = builder.add_root(flooded_state, "FloodPresentation")
	builder.add_visual_box(flooded_visuals, "MarshWaterWest", Vector3(13.5, 0.12, 35.0), Vector3(-9.25, -0.03, 11.5), "water_surface", Vector3.ZERO, 1.0, 0.08, "water")
	builder.add_visual_box(flooded_visuals, "MarshWaterEast", Vector3(13.5, 0.12, 35.0), Vector3(9.25, -0.03, 11.5), "water_surface", Vector3.ZERO, 1.0, 0.08, "water")
	builder.add_visual_box(flooded_visuals, "ChapelFloodSheen", Vector3(13.2, 0.06, 12.4), Vector3(0.0, 0.05, 29.2), "water_surface", Vector3.ZERO, 0.35, 0.08, "water_stain")
	for index: int in range(7):
		builder.add_visual_box(flooded_visuals, "CausewayRipple%02d" % index, Vector3(5.4, 0.025, 0.12), Vector3(0.0, 0.08, 1.0 + float(index) * 3.5), "water_highlight", Vector3.ZERO, 0.38, 0.18, "water_ripple")
	var quiet_visuals: Node3D = builder.add_root(quiet_state, "QuietPresentation")
	builder.add_visual_box(quiet_visuals, "LowWaterWest", Vector3(12.8, 0.09, 27.0), Vector3(-9.0, -0.24, 10.0), "water_deep", Vector3.ZERO, 0.72, 0.0, "water")
	builder.add_visual_box(quiet_visuals, "LowWaterEast", Vector3(12.8, 0.09, 27.0), Vector3(9.0, -0.24, 10.0), "water_deep", Vector3.ZERO, 0.72, 0.0, "water")
	builder.add_visual_box(quiet_visuals, "ExposedMudWest", Vector3(4.0, 0.08, 18.0), Vector3(-3.8, -0.08, 11.0), "mud")
	builder.add_visual_box(quiet_visuals, "ExposedMudEast", Vector3(4.0, 0.08, 18.0), Vector3(3.8, -0.08, 11.0), "mud")
	water_volume = mission.get_node_or_null("NaveSwimPocket") as Area3D
	if water_volume == null:
		return
	water_volume.position = Vector3(4.35, -2.55, 29.55)
	water_volume.set("surface_height_offset", 3.1)
	water_volume.set("current_velocity", Vector3(-0.22, 0.0, 0.06))
	water_volume.set("water_label", "Flooded Side Chapel")
	var collision: CollisionShape3D = water_volume.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is BoxShape3D:
		(collision.shape as BoxShape3D).size = Vector3(5.15, 5.7, 5.75)
	for child: Node in water_volume.get_children():
		if child != collision:
			water_volume.remove_child(child)
			child.free()
	builder.add_visual_box(water_volume, "DeepWater", Vector3(5.15, 0.16, 5.75), Vector3(0.0, 3.08, 0.0), "water_surface", Vector3.ZERO, 1.0, 0.16, "water")
	builder.add_visual_box(water_volume, "DeepColor", Vector3(5.05, 0.08, 5.65), Vector3(0.0, 0.38, 0.0), "water_deep", Vector3.ZERO, 0.75, 0.0, "water_depth")
	for index: int in range(4):
		builder.add_visual_box(water_volume, "CurrentRibbon%02d" % index, Vector3(0.85, 0.025, 0.09), Vector3(1.45 - float(index) * 0.82, 3.18, 0.9), "water_highlight", Vector3(0.0, -0.25, 0.0), 0.55, 0.24, "current_marker")


func _restyle_story_props() -> void:
	var entrance: Node3D = mission.get_node_or_null("ChapelEntrance") as Node3D
	if entrance != null:
		_hide_child(entrance, "DoorwayGlow")
		builder.add_visual_torus(entrance, "ThresholdResonance", 1.15, 1.24, Vector3(0.0, 1.55, 0.02), "accent_cool", Vector3(PI / 2.0, 0.0, 0.0), 0.38, 0.42, "quest_accent")
	var plaque: Node3D = mission.get_node_or_null("MemorialPlaque") as Node3D
	if plaque != null:
		_hide_child(plaque, "Plaque")
		builder.add_visual_box(plaque, "StoneTablet", Vector3(0.2, 1.5, 2.25), Vector3(0.0, 0.78, 0.0), "stone_secondary")
		builder.add_visual_box(plaque, "TabletInset", Vector3(0.08, 1.18, 1.85), Vector3(-0.13, 0.78, 0.0), "stone_dark")
		for index: int in range(4):
			builder.add_visual_box(plaque, "Inscription%02d" % index, Vector3(0.035, 0.055, 1.2 - float(index) * 0.08), Vector3(-0.18, 1.08 - float(index) * 0.22, 0.0), "accent_cool", Vector3.ZERO, 0.55, 0.28, "inscription")
	var rope: Node3D = mission.get_node_or_null("SeveredBellRope") as Node3D
	if rope != null:
		_hide_child(rope, "Rope")
		builder.add_visual_cylinder(rope, "RopeUpper", 0.075, 0.095, 1.55, Vector3(0.0, 1.42, 0.0), "wood_primary", Vector3(0.0, 0.0, 0.05))
		builder.add_visual_cylinder(rope, "RopeLower", 0.06, 0.09, 0.72, Vector3(0.08, 0.42, 0.0), "wood_primary", Vector3(0.0, 0.0, -0.22))
		for index: int in range(4):
			builder.add_visual_cylinder(rope, "Fray%02d" % index, 0.015, 0.022, 0.34, Vector3(-0.09 + float(index) * 0.06, 0.05, 0.0), "wood_primary", Vector3(0.0, 0.0, -0.25 + float(index) * 0.17))
	var mechanism: Node3D = mission.get_node_or_null("BurialMechanism") as Node3D
	if mechanism != null:
		_hide_child(mechanism, "MechanismWheel")
		builder.add_visual_box(mechanism, "MechanismHousing", Vector3(2.0, 1.15, 0.8), Vector3.ZERO, "metal_dark", Vector3(0.0, 0.16, 0.0))
		builder.add_visual_cylinder(mechanism, "ResonatorWheel", 0.72, 0.82, 0.28, Vector3(0.0, 0.05, -0.48), "metal_primary", Vector3(PI / 2.0, 0.0, 0.0), 1.0, 0.18)
		builder.add_visual_torus(mechanism, "FalseNoteRing", 0.9, 0.97, Vector3(0.0, 0.05, -0.62), "accent_mystic", Vector3(PI / 2.0, 0.0, 0.0), 0.62, 0.65, "quest_accent")
	var plate: Node3D = mission.get_node_or_null("CorrodedTuningPlate") as Node3D
	if plate != null:
		_hide_child(plate, "Plate")
		builder.add_visual_box(plate, "BrassPlate", Vector3(1.15, 0.14, 0.78), Vector3(0.0, 0.18, 0.0), "metal_primary", Vector3(0.0, 0.12, 0.0), 1.0, 0.18)
		for index: int in range(2):
			builder.add_visual_box(plate, "ToneGroove%02d" % index, Vector3(0.8, 0.025, 0.08), Vector3(0.0, 0.27, -0.16 + float(index) * 0.32), "accent_warm", Vector3.ZERO, 0.8, 0.55, "inscription")
	var crypt: Node3D = mission.get_node_or_null("SubmergedCryptSeal") as Node3D
	if crypt != null:
		_hide_child(crypt, "SealDoor")
		_hide_child(crypt, "PlateSocket")
		builder.add_visual_box(crypt, "CryptDoor", Vector3(3.25, 2.65, 0.28), Vector3(0.0, 1.35, 0.0), "stone_dark")
		builder.add_visual_torus(crypt, "PlateSocket", 0.42, 0.53, Vector3(0.0, 1.32, -0.2), "metal_primary", Vector3(PI / 2.0, 0.0, 0.0), 1.0, 0.18)
		builder.add_visual_torus(crypt, "SealResonance", 0.76, 0.82, Vector3(0.0, 1.32, -0.25), "accent_mystic", Vector3(PI / 2.0, 0.0, 0.0), 0.34, 0.36, "quest_accent")


func _configure_lighting() -> void:
	var directional: DirectionalLight3D = mission.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if directional != null:
		directional.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
		directional.light_color = _palette_color("moon_light")
		directional.light_energy = 0.58
		directional.shadow_enabled = true
	var world_environment: WorldEnvironment = mission.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null:
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color(0.025, 0.055, 0.075)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = _palette_color("moon_light")
		environment.ambient_light_energy = 0.48
		environment.fog_enabled = true
		environment.fog_light_color = _palette_color("fog")
		environment.fog_light_energy = 0.7
		environment.fog_density = 0.012
		world_environment.environment = environment
	var lighting: Node3D = builder.add_root(authored_root, "Lighting")
	builder.add_point_light(lighting, "OrinLanternLight", Vector3(-3.8, 2.15, -3.3), "lantern_light", 2.6, 8.5, true)
	builder.add_point_light(lighting, "MoonThroughDoor", Vector3(0.0, 3.2, 23.8), "moon_light", 1.35, 11.0, false)
	builder.add_point_light(lighting, "NaveResonanceLight", Vector3(-1.2, 3.0, 30.2), "accent_cool", 0.95, 9.0, false)
	builder.add_point_light(lighting, "PoolGlow", Vector3(4.35, -0.4, 29.55), "accent_cool", 1.8, 7.0, false)
	builder.add_point_light(lighting, "AltarGlow", Vector3(-1.8, 2.2, 33.8), "accent_warm", 1.45, 7.5, false)


func _build_reed_cluster(parent: Node3D, node_name: String, position_value: Vector3, count: int) -> void:
	var cluster: Node3D = builder.add_root(parent, node_name, position_value)
	for index: int in range(maxi(count, 1)):
		var angle: float = float(index) * 2.399
		var radius: float = 0.25 + float(index % 4) * 0.16
		var height: float = 0.75 + float(index % 3) * 0.25
		var offset := Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius)
		builder.add_visual_cylinder(cluster, "Reed%02d" % index, 0.022, 0.035, height, offset, "vegetation", Vector3(0.08 * sin(angle), 0.0, 0.08 * cos(angle)))


func _build_lantern(parent: Node3D, node_name: String, position_value: Vector3) -> void:
	var lantern: Node3D = builder.add_root(parent, node_name, position_value)
	builder.add_visual_box(lantern, "Post", Vector3(0.16, 2.6, 0.16), Vector3(0.0, 1.3, 0.0), "wood_dark")
	builder.add_visual_box(lantern, "Hook", Vector3(0.75, 0.12, 0.12), Vector3(0.28, 2.48, 0.0), "metal_dark")
	builder.add_visual_box(lantern, "Cage", Vector3(0.42, 0.65, 0.42), Vector3(0.58, 2.08, 0.0), "metal_dark")
	builder.add_visual_sphere(lantern, "Flame", 0.16, Vector3(0.58, 2.08, 0.0), "lantern_light", Vector3(0.7, 1.25, 0.7), 0.82, 1.8, "light_source")


func _build_small_candle(parent: Node3D, position_value: Vector3, index: int) -> void:
	builder.add_visual_cylinder(parent, "Candle%02d" % index, 0.045, 0.055, 0.24, position_value, Color(0.72, 0.66, 0.48))
	builder.add_visual_sphere(parent, "CandleFlame%02d" % index, 0.05, position_value + Vector3.UP * 0.17, "lantern_light", Vector3(0.65, 1.2, 0.65), 0.8, 1.3, "light_source")


func _hide_child(parent: Node, child_name: String) -> void:
	var child: Node3D = parent.get_node_or_null(child_name) as Node3D
	if child != null:
		child.visible = false


func _palette_color(key: String) -> Color:
	return ChapelPalette.call("color", key, Color.WHITE) as Color


func get_debug_data() -> Dictionary:
	return {
		"installed": installed,
		"authored_root": authored_root != null,
		"water_volume": water_volume != null,
		"build_stats": build_stats.duplicate(true),
		"environment_pass": "drowned_chapel_v2_2",
	}
