extends Area3D
class_name ResourcePickup

const CombatFeedback = preload("res://scripts/combat/combat_feedback.gd")

signal collected(definition: PickupDefinition, applied_amount: int)

@export var definition: PickupDefinition
@export var visual_anchor_path: NodePath = NodePath("VisualAnchor")
@export var core_mesh_path: NodePath = NodePath("VisualAnchor/Core")
@export var ring_mesh_path: NodePath = NodePath("VisualAnchor/Ring")
@export var light_path: NodePath = NodePath("VisualAnchor/GlowLight")
@export var scatter_gravity: float = 12.0
@export var scatter_settle_seconds: float = 0.65

var visual_anchor: Node3D = null
var core_mesh: MeshInstance3D = null
var ring_mesh: MeshInstance3D = null
var glow_light: OmniLight3D = null
var target_player: Node3D = null
var launch_velocity: Vector3 = Vector3.ZERO
var attraction_velocity: float = 0.0
var spawn_floor_y: float = 0.0
var age_seconds: float = 0.0
var hover_phase: float = 0.0
var collected_already: bool = false


func _ready() -> void:
	resolve_components()
	apply_definition_presentation()
	hover_phase = randf_range(0.0, TAU)
	spawn_floor_y = global_position.y
	add_to_group("pickups")
	add_to_group("debuggable")


func configure(
	next_definition: PickupDefinition,
	spawn_position: Vector3,
	initial_velocity: Vector3 = Vector3.ZERO
) -> void:
	definition = next_definition
	global_position = spawn_position
	spawn_floor_y = spawn_position.y
	launch_velocity = initial_velocity
	age_seconds = 0.0
	attraction_velocity = 0.0
	collected_already = false
	apply_definition_presentation()


func _process(delta: float) -> void:
	if definition == null or collected_already:
		return

	age_seconds += delta
	if definition.lifetime_seconds > 0.0 and age_seconds >= definition.lifetime_seconds:
		queue_free()
		return

	update_scatter(delta)
	update_visual_motion(delta)
	update_collection(delta)


func resolve_components() -> void:
	visual_anchor = get_node_or_null(visual_anchor_path) as Node3D
	core_mesh = get_node_or_null(core_mesh_path) as MeshInstance3D
	ring_mesh = get_node_or_null(ring_mesh_path) as MeshInstance3D
	glow_light = get_node_or_null(light_path) as OmniLight3D


func apply_definition_presentation() -> void:
	if definition == null:
		return

	if visual_anchor == null:
		resolve_components()

	if visual_anchor != null:
		visual_anchor.scale = Vector3.ONE * max(definition.visual_scale, 0.05)

	if core_mesh != null:
		core_mesh.material_override = make_glow_material(definition.primary_color, 1.8)

	if ring_mesh != null:
		ring_mesh.material_override = make_glow_material(definition.secondary_color, 1.15)

	if glow_light != null:
		glow_light.light_color = definition.primary_color
		glow_light.light_energy = 1.4
		glow_light.omni_range = 2.4 * max(definition.visual_scale, 0.05)


func make_glow_material(color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	material.roughness = 0.22
	return material


func update_scatter(delta: float) -> void:
	if age_seconds >= scatter_settle_seconds:
		if global_position.y < spawn_floor_y:
			global_position.y = spawn_floor_y
		return

	launch_velocity.y -= scatter_gravity * delta
	global_position += launch_velocity * delta
	launch_velocity.x = move_toward(launch_velocity.x, 0.0, delta * 3.2)
	launch_velocity.z = move_toward(launch_velocity.z, 0.0, delta * 3.2)

	if global_position.y <= spawn_floor_y and launch_velocity.y < 0.0:
		global_position.y = spawn_floor_y
		launch_velocity.y *= -0.24


func update_visual_motion(delta: float) -> void:
	if visual_anchor == null:
		return

	var hover_offset: float = definition.hover_height + sin(
		hover_phase + age_seconds * definition.hover_speed
	) * definition.hover_amplitude
	visual_anchor.position.y = hover_offset
	visual_anchor.rotate_y(deg_to_rad(definition.spin_speed_degrees) * delta)

	if ring_mesh != null:
		ring_mesh.rotate_x(deg_to_rad(definition.spin_speed_degrees * 0.55) * delta)


func update_collection(delta: float) -> void:
	if target_player == null or not is_instance_valid(target_player):
		target_player = find_player()

	if target_player == null or not definition.can_apply():
		attraction_velocity = 0.0
		return

	var target_position: Vector3 = target_player.global_position + Vector3.UP * 0.45
	var offset: Vector3 = target_position - global_position
	var distance: float = offset.length()

	if distance > definition.attraction_radius:
		attraction_velocity = 0.0
		return

	if distance <= definition.collection_radius:
		collect_pickup()
		return

	attraction_velocity = move_toward(
		attraction_velocity,
		definition.attraction_speed,
		definition.attraction_acceleration * delta
	)
	global_position += offset.normalized() * attraction_velocity * delta


func find_player() -> Node3D:
	var grouped_player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if grouped_player != null:
		return grouped_player

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	return scene_root.find_child("Player", true, false) as Node3D


func collect_pickup() -> void:
	if collected_already or definition == null:
		return

	var applied_amount: int = definition.apply_to_game_state()
	if applied_amount <= 0 and not definition.collect_when_full:
		return

	collected_already = true
	CombatFeedback.show_reaction_feedback(
		self,
		"pickup_collect",
		{
			"reaction_name": definition.get_collection_label(applied_amount),
			"visual_style": "pickup",
			"visual_color": definition.primary_color,
			"visual_radius": 0.9 * max(definition.visual_scale, 0.2),
			"visual_duration": 0.32,
		}
	)
	GameFeedback.play("pickup_collect", {"source": definition.pickup_id})
	collected.emit(definition, applied_amount)
	queue_free()


func get_debug_data() -> Dictionary:
	return {
		"resource_pickup": true,
		"definition": definition.pickup_id if definition != null else "none",
		"age": snapped(age_seconds, 0.01),
		"attraction_velocity": snapped(attraction_velocity, 0.01),
		"player_found": target_player != null,
	}
