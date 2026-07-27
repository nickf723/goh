extends "res://scripts/expedition/expedition_segment_3d.gd"
class_name FamiliarityExpeditionSegment3D

const AuthoredCypressScene: PackedScene = preload("res://scenes/levels/expedition_segments/authored_cypress_basin_v1.tscn")
const AuthoredWetWoodlandScene: PackedScene = preload("res://scenes/levels/expedition_segments/authored_wet_woodland_v1.tscn")

var familiarity_modifiers: Dictionary = {}
var authored_layout: AuthoredWildsSegmentLayout


func configure_familiarity(
	segment_definition: ExpeditionSegmentDefinition,
	seed_value: int,
	modifiers: Dictionary,
	optional_branch: bool = false
) -> void:
	familiarity_modifiers = modifiers.duplicate(true)
	configure(segment_definition, seed_value, optional_branch)


func build_segment() -> void:
	if built or definition == null:
		return
	var authored_scene: PackedScene = get_authored_scene_for_definition()
	if authored_scene == null:
		super.build_segment()
		return
	built = true
	build_sockets()
	authored_layout = authored_scene.instantiate() as AuthoredWildsSegmentLayout
	if authored_layout != null:
		authored_layout.name = "AuthoredLayout"
		add_child(authored_layout)
		authored_layout.configure_layout(definition, segment_seed)
	build_role_content()
	build_segment_label()
	add_to_group("expedition_segment")
	add_to_group("authored_expedition_segment")
	add_to_group("debuggable")


func get_authored_scene_for_definition() -> PackedScene:
	if is_optional_branch or definition == null:
		return null
	match definition.segment_id:
		"cypress_basin":
			return AuthoredCypressScene
		"wet_woodland":
			return AuthoredWetWoodlandScene
	return null


func uses_authored_layout() -> bool:
	return authored_layout != null and is_instance_valid(authored_layout)


func build_role_content() -> void:
	match definition.role:
		"traversal":
			build_traversal_obstacle()
		"combat":
			build_enemy_camp()
		"resource":
			build_resource_grove()
		"discovery":
			build_ruin_fragments()
		"rest":
			build_campsite()
		"transition":
			build_transition_markers()
		_:
			build_scattered_obstacles()
	build_familiarity_overlay()


func build_scattered_obstacles() -> void:
	var multiplier: float = maxf(float(familiarity_modifiers.get("obstacle_multiplier", 1.0)), 0.1)
	var count: int = clampi(roundi(definition.obstacle_density * 8.0 * multiplier), 1, 9)
	for index: int in range(count):
		var side_sign: float = -1.0 if index % 2 == 0 else 1.0
		var x_position: float = side_sign * rng.randf_range(
			definition.path_width * 0.28,
			definition.path_width * 0.43
		)
		var z_position: float = rng.randf_range(4.0, maxf(definition.length - 4.0, 4.5))
		add_rock(
			Vector3(x_position, elevation_at(z_position) + 0.35, z_position),
			rng.randf_range(0.55, 1.0)
		)


func build_enemy_camp() -> void:
	var camp_z: float = definition.length * 0.58
	add_visual_box(
		"CampPlatform",
		Vector3(definition.path_width * 0.92, 0.14, 5.5),
		Vector3(0.0, elevation_at(camp_z) + 0.08, camp_z),
		Vector3.ZERO,
		Color(0.24, 0.17, 0.12, 1.0)
	)
	add_campfire(Vector3(0.0, elevation_at(camp_z) + 0.25, camp_z))

	var threat_multiplier: float = maxf(
		float(familiarity_modifiers.get("threat_multiplier", 1.0)),
		0.0
	)
	if threat_multiplier > 0.72:
		spawn_enemy(
			GoblinScene,
			Vector3(-1.6, elevation_at(camp_z - 1.2) + 0.65, camp_z - 1.2),
			"WildsGoblin"
		)
		spawn_enemy(
			GremlinScene,
			Vector3(1.7, elevation_at(camp_z + 1.1) + 0.55, camp_z + 1.1),
			"WildsGremlin"
		)
	elif threat_multiplier > 0.35:
		spawn_enemy(
			GoblinScene,
			Vector3(0.0, elevation_at(camp_z) + 0.65, camp_z),
			"WildsRouteGuard"
		)
	else:
		add_visual_box(
			"AbandonedCrate",
			Vector3(1.2, 0.8, 1.0),
			Vector3(-1.5, elevation_at(camp_z) + 0.42, camp_z + 0.4),
			Vector3(0.0, 0.28, 0.0),
			Color(0.31, 0.22, 0.13, 1.0)
		)
		add_route_label(
			"CLEARED CAMP",
			Vector3(0.0, elevation_at(camp_z) + 2.4, camp_z),
			Color(0.72, 1.0, 0.7, 1.0)
		)


func build_resource_grove() -> void:
	super.build_resource_grove()
	var resource_multiplier: float = maxf(
		float(familiarity_modifiers.get("resource_multiplier", 1.0)),
		0.1
	)
	var bonus_count: int = clampi(roundi((resource_multiplier - 1.0) * 8.0), 0, 4)
	var grove_z: float = definition.length * 0.52
	for index: int in range(bonus_count):
		var angle: float = TAU * float(index + 1) / float(bonus_count + 1)
		add_glowing_orb(
			Vector3(
				cos(angle) * 2.8,
				elevation_at(grove_z) + 0.34,
				grove_z + sin(angle) * 2.8
			),
			definition.accent_color.lightened(0.16),
			0.25
		)


func build_familiarity_overlay() -> void:
	if bool(familiarity_modifiers.get("add_rest_cache", false)) and definition.role != "rest":
		var cache_z: float = definition.length * 0.34
		add_campfire(Vector3(2.2, elevation_at(cache_z) + 0.2, cache_z))
		add_visual_box(
			"KnownRestCache",
			Vector3(1.4, 0.7, 0.9),
			Vector3(3.0, elevation_at(cache_z) + 0.38, cache_z + 0.5),
			Vector3.ZERO,
			Color(0.38, 0.24, 0.12, 1.0)
		)
		add_route_label(
			"KNOWN SHELTER",
			Vector3(2.4, elevation_at(cache_z) + 2.0, cache_z),
			Color(0.75, 0.94, 1.0, 1.0)
		)

	if bool(familiarity_modifiers.get("show_route_markers", false)):
		for fraction: float in [0.22, 0.52, 0.82]:
			var marker_z: float = definition.length * fraction
			add_glowing_orb(
				Vector3(
					-definition.path_width * 0.42,
					elevation_at(marker_z) + 0.52,
					marker_z
				),
				Color(0.42, 0.82, 1.0, 1.0),
				0.16
			)

	if bool(familiarity_modifiers.get("stabilized_shortcut", false)):
		add_route_label(
			"STABILIZED ROUTE",
			Vector3(0.0, elevation_at(definition.length * 0.16) + 2.25, definition.length * 0.16),
			Color(1.0, 0.84, 0.34, 1.0)
		)


func add_route_label(text_value: String, local_position: Vector3, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.position = local_position
	label.font_size = 24
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 5
	add_child(label)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["authored"] = uses_authored_layout()
	data["authored_layout"] = authored_layout.layout_id if uses_authored_layout() else "procedural"
	return data
