extends Node
class_name DrownedBellPlayabilityPass

const PlayableSpaceScript = preload("res://scripts/quality/playable_space_3d.gd")
const RecoveryVolumeScript = preload("res://scripts/quality/playable_recovery_volume_3d.gd")
const SwimmingExitAnchorScript = preload("res://scripts/quality/swimming_exit_anchor_3d.gd")
const GuidanceTargetScript = preload("res://scripts/quality/quest_guidance_target_3d.gd")

const FLAG_ACCEPTED := "drowned_bell_accepted"
const FLAG_HEARD_PATTERN := "drowned_bell_heard_pattern"
const FLAG_CHAPEL_ENTERED := "drowned_bell_chapel_entered"
const FLAG_PLAQUE := "drowned_bell_plaque_read"
const FLAG_ROPE := "drowned_bell_rope_found"
const FLAG_MECHANISM := "drowned_bell_mechanism_found"
const FLAG_CLUES_COMPLETE := "drowned_bell_clues_complete"
const FLAG_TUNING_PLATE := "drowned_bell_tuning_plate_recovered"
const FLAG_COMPLETE := "drowned_bell_complete"

var mission: Node3D
var world: Node3D
var playable_space: Node3D
var water_volume: Area3D
var exit_anchors: Array[Node3D] = []
var installed: bool = false


func _ready() -> void:
	add_to_group("playability_integration")
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
	installed = true
	_build_playable_space()
	_rebuild_pool_escape_routes()
	_build_guidance_targets()
	if not GameState.flag_changed.is_connected(_on_flag_changed):
		GameState.flag_changed.connect(_on_flag_changed)
	_refresh_recovery_anchor()


func _build_playable_space() -> void:
	playable_space = Node3D.new()
	playable_space.name = "PlayableSpace"
	playable_space.set_script(PlayableSpaceScript)
	playable_space.set("use_bounds", true)
	playable_space.set("bounds_center", Vector3(0.0, 1.5, 15.0))
	playable_space.set("bounds_size", Vector3(32.0, 20.0, 58.0))
	playable_space.set("minimum_recovery_y", -4.4)
	playable_space.set("generate_boundary_collision", true)
	playable_space.set("boundary_thickness", 1.2)
	playable_space.set("boundary_height", 18.0)

	var default_anchor := Marker3D.new()
	default_anchor.name = "DefaultRecoveryAnchor"
	default_anchor.position = Vector3(0.0, 1.0, -10.0)
	playable_space.add_child(default_anchor)
	playable_space.set("default_recovery_path", NodePath("DefaultRecoveryAnchor"))
	mission.add_child(playable_space)

	var recovery_volume := Area3D.new()
	recovery_volume.name = "VoidRecoveryVolume"
	recovery_volume.position = Vector3(0.0, -7.0, 15.0)
	recovery_volume.set_script(RecoveryVolumeScript)
	recovery_volume.set("recovery_reason", "fell beneath the authored level")
	var recovery_shape := CollisionShape3D.new()
	var recovery_box := BoxShape3D.new()
	recovery_box.size = Vector3(40.0, 4.0, 70.0)
	recovery_shape.shape = recovery_box
	recovery_volume.add_child(recovery_shape)
	playable_space.add_child(recovery_volume)

	_add_collision_box(
		world,
		"DeepSafetyCatch",
		Vector3(38.0, 0.5, 68.0),
		Vector3(0.0, -8.8, 15.0),
		Color(0.04, 0.05, 0.06),
		false
	)


func _rebuild_pool_escape_routes() -> void:
	water_volume = mission.get_node_or_null("NaveSwimPocket") as Area3D
	if water_volume == null:
		return
	water_volume.position = Vector3(4.2, -2.5, 29.5)
	water_volume.set("current_velocity", Vector3(-0.28, 0.0, 0.08))
	var water_shape: CollisionShape3D = water_volume.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if water_shape != null and water_shape.shape is BoxShape3D:
		(water_shape.shape as BoxShape3D).size = Vector3(5.0, 5.5, 5.0)

	_add_collision_box(world, "PoolWestRim", Vector3(1.0, 0.8, 5.4), Vector3(1.2, -0.4, 29.5), Color(0.29, 0.3, 0.28))
	_add_collision_box(world, "PoolExitStepDeep", Vector3(1.1, 0.5, 2.4), Vector3(4.0, -2.55, 28.5), Color(0.22, 0.24, 0.23), true)
	_add_collision_box(world, "PoolExitStepMid", Vector3(1.0, 0.65, 2.4), Vector3(3.15, -1.95, 28.5), Color(0.25, 0.27, 0.25), true)
	_add_collision_box(world, "PoolExitStepHigh", Vector3(1.0, 0.75, 2.4), Vector3(2.35, -1.2, 28.5), Color(0.28, 0.29, 0.27), true)
	_add_collision_box(world, "PoolExitStepLip", Vector3(0.8, 0.8, 2.4), Vector3(1.72, -0.42, 28.5), Color(0.31, 0.31, 0.28), true)
	_add_collision_box(world, "PoolBackClimbLedge", Vector3(2.2, 0.55, 0.9), Vector3(3.0, 0.25, 32.15), Color(0.34, 0.34, 0.3), true)

	var existing_ledge: Node = world.get_node_or_null("DryRecoveryLedge")
	if existing_ledge != null:
		existing_ledge.add_to_group("climbable")
		existing_ledge.set_meta("climb_surface", "wet")

	_make_exit_anchor("PoolWestExit", Vector3(0.5, 1.05, 28.5), "SHALLOW EXIT")
	_make_exit_anchor("PoolBackExit", Vector3(3.0, 1.05, 33.0), "LEDGE EXIT")

	for index: int in range(3):
		var arrow := MeshInstance3D.new()
		arrow.name = "CurrentArrow%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.48, 0.04, 0.12)
		arrow.mesh = mesh
		arrow.position = Vector3(5.5 - float(index) * 0.85, 0.68, 30.5)
		arrow.rotation.y = -0.28
		arrow.material_override = _material(Color(0.25, 0.72, 0.9, 0.58))
		world.add_child(arrow)


func _make_exit_anchor(node_name: String, position_value: Vector3, label: String) -> void:
	var anchor := Node3D.new()
	anchor.name = node_name
	anchor.position = position_value
	anchor.set_script(SwimmingExitAnchorScript)
	anchor.set("marker_text", label)
	anchor.set("activation_radius", 3.4)
	anchor.set("maximum_vertical_distance", 2.8)
	anchor.set("require_facing", false)
	anchor.set("show_marker", true)
	mission.add_child(anchor)
	anchor.call("set_water_volume", water_volume)
	exit_anchors.append(anchor)


func _build_guidance_targets() -> void:
	_add_guidance("FerrymanOrin", "TALK", "", FLAG_ACCEPTED, false)
	_add_guidance("BellListeningPoint", "LISTEN", FLAG_ACCEPTED, FLAG_HEARD_PATTERN, false)
	_add_guidance("ChapelEntrance", "ENTER", FLAG_HEARD_PATTERN, FLAG_CHAPEL_ENTERED, false)
	_add_guidance("MemorialPlaque", "PLAQUE", FLAG_CHAPEL_ENTERED, FLAG_PLAQUE, true)
	_add_guidance("SeveredBellRope", "ROPE", FLAG_CHAPEL_ENTERED, FLAG_ROPE, true)
	_add_guidance("BurialMechanism", "SUBMERGED CLUE", FLAG_CHAPEL_ENTERED, FLAG_MECHANISM, true)
	_add_guidance("CorrodedTuningPlate", "TUNING PLATE", FLAG_CLUES_COMPLETE, FLAG_TUNING_PLATE, false)
	_add_guidance("SubmergedCryptSeal", "CRYPT SEAL", FLAG_TUNING_PLATE, FLAG_COMPLETE, false)


func _add_guidance(
	target_path: String,
	label: String,
	required: String,
	blocked: String,
	optional: bool
) -> void:
	var target: Node3D = mission.get_node_or_null(target_path) as Node3D
	if target == null or target.get_node_or_null("QuestGuidance") != null:
		return
	var guidance := Node3D.new()
	guidance.name = "QuestGuidance"
	guidance.set_script(GuidanceTargetScript)
	guidance.set("marker_text", label)
	guidance.set("required_flag", required)
	guidance.set("blocked_flag", blocked)
	guidance.set("optional_target", optional)
	guidance.set("show_distance", true)
	guidance.set("marker_height", 2.7 if optional else 3.0)
	target.add_child(guidance)
	target.set_meta("quality_requires_guidance", true)


func _on_flag_changed(flag_name: String, _value: bool) -> void:
	if flag_name in [FLAG_ACCEPTED, FLAG_HEARD_PATTERN, FLAG_CHAPEL_ENTERED, FLAG_TUNING_PLATE, FLAG_COMPLETE]:
		_refresh_recovery_anchor()


func _refresh_recovery_anchor() -> void:
	if playable_space == null:
		return
	var position_value := Vector3(0.0, 1.0, -10.0)
	var anchor_id := "shore"
	if GameState.get_flag(FLAG_CHAPEL_ENTERED):
		position_value = Vector3(0.0, 1.0, 24.2)
		anchor_id = "chapel_entrance"
	elif GameState.get_flag(FLAG_HEARD_PATTERN):
		position_value = Vector3(0.0, 1.0, 12.0)
		anchor_id = "causeway"
	elif GameState.get_flag(FLAG_ACCEPTED):
		position_value = Vector3(-2.2, 1.0, -2.0)
		anchor_id = "orin_camp"
	playable_space.call(
		"set_active_recovery_transform",
		Transform3D(Basis.IDENTITY, position_value),
		anchor_id
	)


func _add_collision_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	color: Color,
	climbable: bool = false
) -> StaticBody3D:
	var existing: StaticBody3D = parent.get_node_or_null(node_name) as StaticBody3D
	if existing != null:
		return existing
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	if climbable:
		body.add_to_group("climbable")
		body.set_meta("climb_surface", "wet")
	parent.add_child(body)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _material(color: Color) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = 0.88
	if color.a < 1.0:
		value.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		value.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		value.emission_enabled = true
		value.emission = Color(color.r, color.g, color.b)
		value.emission_energy_multiplier = 0.45
	return value


func get_debug_data() -> Dictionary:
	return {
		"installed": installed,
		"playable_space": playable_space != null,
		"water_volume": water_volume != null,
		"exit_anchors": exit_anchors.size(),
		"guidance_targets": get_tree().get_nodes_in_group("quest_guidance_target").size() if get_tree() != null else 0,
	}
