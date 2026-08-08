extends Node
class_name VineGrappleTargetPreview

const VineTargeting = preload(
	"res://scripts/player/vine_grapple_targeting.gd"
)

@export_range(2.0, 40.0, 0.5) var maximum_target_range: float = 22.0
@export_range(1.0, 1000.0, 1.0) var maximum_rigidbody_mass: float = 180.0
@export_range(1.0, 60.0, 1.0) var soft_aim_angle_degrees: float = 20.0
@export var require_line_of_sight: bool = true
@export_range(0.02, 0.4, 0.01) var refresh_interval: float = 0.06

var player: Node3D
var selection: Dictionary = {}
var selected_target: Node3D
var refresh_remaining: float = 0.0
var target_change_pulse: float = 0.0

var marker_root: Node3D
var inner_ring: MeshInstance3D
var outer_ring: MeshInstance3D
var center_dot: MeshInstance3D
var target_label: Label3D
var guide_instance: MeshInstance3D
var guide_mesh: ImmediateMesh
var marker_material: StandardMaterial3D
var guide_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("vine_grapple_target_previews")
	add_to_group("debuggable")
	_create_visuals()
	set_process(true)


func _process(delta: float) -> void:
	if not _resolve_player() or not _should_show_preview():
		selection = {}
		selected_target = null
		_hide_visuals()
		return

	refresh_remaining -= maxf(delta, 0.0)
	if refresh_remaining <= 0.0:
		refresh_remaining = maxf(refresh_interval, 0.02)
		_refresh_selection()
	_update_visuals(delta)


func _resolve_player() -> bool:
	if player != null and is_instance_valid(player) and player.is_inside_tree():
		return true
	player = null
	if get_tree() == null:
		return false
	var grouped: Node = get_tree().get_first_node_in_group("player")
	if grouped is Node3D:
		player = grouped as Node3D
		return true
	var scene: Node = get_tree().current_scene
	if scene != null:
		var fallback: Node = scene.find_child("Player", true, false)
		if fallback is Node3D:
			player = fallback as Node3D
	return player != null


func _should_show_preview() -> bool:
	if player == null:
		return false
	if bool(player.get("is_defeated")):
		return false
	if (
		player.has_method("is_focus_spell_menu_open")
		and bool(player.call("is_focus_spell_menu_open"))
	):
		return false
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster == null or not caster.has_method("get_current_ability"):
		return false
	var ability_value: Variant = caster.call("get_current_ability")
	if not ability_value is AbilityDefinition:
		return false
	return (ability_value as AbilityDefinition).get_spell_id() == "vine_grapple"


func _refresh_selection() -> void:
	var next_selection: Dictionary = VineTargeting.resolve_target(
		player,
		maximum_target_range,
		maximum_rigidbody_mass,
		soft_aim_angle_degrees,
		require_line_of_sight
	)
	var next_target: Node3D = next_selection.get("target") as Node3D
	if next_target != selected_target:
		selected_target = next_target
		target_change_pulse = 1.0
	selection = next_selection


func _create_visuals() -> void:
	marker_root = Node3D.new()
	marker_root.name = "VineTargetMarker"
	marker_root.visible = false
	add_child(marker_root)

	marker_material = StandardMaterial3D.new()
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.emission_enabled = true
	marker_material.emission_energy_multiplier = 2.5

	inner_ring = _make_ring("InnerRing", 0.24, 0.31)
	inner_ring.rotation_degrees.x = 90.0
	marker_root.add_child(inner_ring)

	outer_ring = _make_ring("OuterRing", 0.39, 0.45)
	outer_ring.rotation_degrees.x = 90.0
	marker_root.add_child(outer_ring)

	center_dot = MeshInstance3D.new()
	center_dot.name = "TargetCore"
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	sphere.radial_segments = 10
	sphere.rings = 5
	center_dot.mesh = sphere
	center_dot.material_override = marker_material
	center_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker_root.add_child(center_dot)

	target_label = Label3D.new()
	target_label.name = "TargetLabel"
	target_label.position = Vector3(0.0, 0.58, 0.0)
	target_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	target_label.font_size = 20
	target_label.pixel_size = 0.0045
	target_label.outline_size = 7
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker_root.add_child(target_label)

	guide_instance = MeshInstance3D.new()
	guide_instance.name = "VineAimGuide"
	guide_instance.visible = false
	guide_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	guide_mesh = ImmediateMesh.new()
	guide_instance.mesh = guide_mesh
	add_child(guide_instance)

	guide_material = StandardMaterial3D.new()
	guide_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guide_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide_material.emission_enabled = true
	guide_material.emission_energy_multiplier = 1.8


func _make_ring(node_name: String, inner_radius: float, outer_radius: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	var torus := TorusMesh.new()
	torus.inner_radius = inner_radius
	torus.outer_radius = outer_radius
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = marker_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


func _update_visuals(delta: float) -> void:
	if marker_root == null or selected_target == null or not is_instance_valid(selected_target):
		_hide_visuals()
		return
	var point_value: Variant = selection.get("point")
	if not point_value is Vector3:
		_hide_visuals()
		return

	var point: Vector3 = point_value as Vector3
	var valid: bool = bool(selection.get("valid", false))
	var source_kind: String = str(selection.get("source", "none"))
	var reason: String = str(selection.get("reason", ""))
	var color: Color = (
		Color(0.24, 1.0, 0.32, 0.94)
		if valid
		else Color(1.0, 0.2, 0.12, 0.96)
	)
	_set_visual_color(color)

	marker_root.visible = true
	marker_root.global_position = point
	var camera: Camera3D = player.get_viewport().get_camera_3d()
	if camera != null:
		marker_root.look_at(camera.global_position, Vector3.UP)

	target_change_pulse = maxf(target_change_pulse - maxf(delta, 0.0) * 3.6, 0.0)
	var age: float = float(Time.get_ticks_msec()) * 0.001
	var pulse: float = (
		1.0
		+ sin(age * 7.0) * 0.055
		+ target_change_pulse * 0.22
	)
	marker_root.scale = Vector3.ONE * pulse
	outer_ring.rotation.z = age * 0.55
	inner_ring.rotation.z = -age * 0.75

	var name_text: String = VineTargeting.get_target_display_name(selected_target)
	var distance: float = float(selection.get("distance", 0.0))
	var prefix: String = "LOCK" if source_kind == VineTargeting.SOURCE_HARD_LOCK else "VINE"
	if valid:
		target_label.text = prefix + "  •  " + name_text + "  •  " + str(snapped(distance, 0.1)) + " m"
	else:
		target_label.text = prefix + "  •  " + VineTargeting.get_reason_label(reason)
	target_label.modulate = color
	_update_guide(point, color, valid)


func _update_guide(point: Vector3, color: Color, valid: bool) -> void:
	if guide_instance == null or guide_mesh == null or player == null:
		return
	guide_instance.visible = true
	guide_mesh.clear_surfaces()
	var line_color: Color = color
	line_color.a = 0.52 if valid else 0.42
	guide_material.albedo_color = line_color
	guide_material.emission = Color(color.r, color.g, color.b, 1.0)
	guide_mesh.surface_begin(Mesh.PRIMITIVE_LINES, guide_material)
	var source: Vector3 = VineTargeting.get_source_anchor_position(player)
	var offset: Vector3 = point - source
	var segment_count: int = 9
	for index: int in range(segment_count):
		if index % 2 == 1:
			continue
		var start_t: float = float(index) / float(segment_count)
		var end_t: float = minf(float(index + 1) / float(segment_count), 1.0)
		var start_point: Vector3 = source.lerp(point, start_t)
		var end_point: Vector3 = source.lerp(point, end_t)
		var sag_scale: float = sin(start_t * PI) * minf(offset.length() * 0.018, 0.24)
		start_point.y -= sag_scale
		end_point.y -= sin(end_t * PI) * minf(offset.length() * 0.018, 0.24)
		guide_mesh.surface_add_vertex(start_point)
		guide_mesh.surface_add_vertex(end_point)
	guide_mesh.surface_end()


func _set_visual_color(color: Color) -> void:
	if marker_material != null:
		marker_material.albedo_color = color
		marker_material.emission = Color(color.r, color.g, color.b, 1.0)


func _hide_visuals() -> void:
	if marker_root != null:
		marker_root.visible = false
	if guide_instance != null:
		guide_instance.visible = false
		if guide_mesh != null:
			guide_mesh.clear_surfaces()


func get_debug_data() -> Dictionary:
	return {
		"vine_target_preview": true,
		"active": marker_root != null and marker_root.visible,
		"target": VineTargeting.get_target_display_name(selected_target) if selected_target != null else "none",
		"valid": bool(selection.get("valid", false)),
		"source": str(selection.get("source", "none")),
		"reason": str(selection.get("reason", "")),
		"distance": snapped(float(selection.get("distance", 0.0)), 0.01),
	}
