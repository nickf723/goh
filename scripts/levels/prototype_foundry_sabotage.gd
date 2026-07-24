extends Node3D
class_name PrototypeFoundrySabotage

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
const GremlinScene: PackedScene = preload(
	"res://scenes/actors/enemies/gremlin_drone.tscn"
)
const PerceptionBrainScript = preload(
	"res://scripts/enemies/enemy_perception_investigation_brain.gd"
)
const PerceptionSensorScript = preload(
	"res://scripts/perception/enemy_perception_sensor.gd"
)
const MovementEmitterScript = preload(
	"res://scripts/perception/perception_movement_emitter.gd"
)
const GasVolumeGridScript = preload("res://scripts/gas/gas_volume_grid.gd")
const GasEmitterScript = preload("res://scripts/gas/gas_emitter_3d.gd")
const SmokeGas: GasDefinition = preload("res://data/gas/smoke_gas.tres")
const WoodProfile: StructuralMaterialProfile = preload(
	"res://data/structural_materials/wood_support.tres"
)
const IronProfile: StructuralMaterialProfile = preload(
	"res://data/structural_materials/iron_support.tres"
)
const MasonryProfile: StructuralMaterialProfile = preload(
	"res://data/structural_materials/masonry_joint.tres"
)
const WoodPhysical: PhysicalMaterialProfile = preload(
	"res://data/materials/wood_physical_profile.tres"
)
const HempRope: FlexibleMaterialProfile = preload(
	"res://data/flexible_materials/hemp_rope.tres"
)
const FoundryLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_foundry_sabotage_loadout.tres"
)
const TrainingHammer: WeaponDefinition = preload(
	"res://data/weapons/training_hammer.tres"
)
const CollapseConsequencesScript = preload(
	"res://scripts/physics/structural_collapse_consequence_3d.gd"
)

@export var enable_editor_f8_reset: bool = true
@export_range(0.05, 0.5, 0.01) var readout_refresh_interval: float = 0.12

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var readout: Label = get_node_or_null(
	"EncounterHUD/Panel/Margin/Readout"
) as Label
@onready var escape_zone: Area3D = get_node_or_null("EscapeZone") as Area3D

var stat_snapshot: Dictionary = {}
var assemblies: Array[StructuralAssembly3D] = []
var routes: Dictionary = {}
var enemies: Array[CharacterBody3D] = []
var core_visual: MeshInstance3D = null
var core_disabled: bool = false
var escape_unlocked: bool = false
var encounter_completed: bool = false
var winning_route: String = "none"
var collapse_count: int = 0
var readout_timer: float = 0.0
var smoke_volume: GasVolumeGrid = null
var collapse_consequences: StructuralCollapseConsequence3D = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("foundry_sabotage_encounter")
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	build_foundry()
	configure_player()
	if escape_zone != null:
		escape_zone.body_entered.connect(_on_escape_zone_body_entered)
	GameState.set_objective(
		"Disable the foundry core by burning the hoist, hammering the masonry, or extracting the metal brace. Then escape."
	)
	show_message(
		"Foundry occupied. Three sabotage routes lead to the same very expensive shutdown."
	)
	refresh_readout()


func _process(delta: float) -> void:
	readout_timer -= maxf(delta, 0.0)
	if readout_timer <= 0.0:
		readout_timer = maxf(readout_refresh_interval, 0.05)
		refresh_readout()


func _exit_tree() -> void:
	for stat_name: Variant in stat_snapshot.keys():
		GameState.set_stat(str(stat_name), int(stat_snapshot[stat_name]))


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if (
		key_event.pressed
		and not key_event.echo
		and key_event.physical_keycode == KEY_F8
		and enable_editor_f8_reset
		and OS.has_feature("editor")
	):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func configure_player() -> void:
	if player == null:
		return
	player.add_to_group("player")
	if player.get_node_or_null("PerceptionMovementEmitter") == null:
		var movement_emitter: Node = MovementEmitterScript.new()
		movement_emitter.name = "PerceptionMovementEmitter"
		player.add_child(movement_emitter)
	var caster: Node = player.get_node_or_null("AbilityCaster")
	if caster != null:
		caster.set("loadout", FoundryLoadout.duplicate(true))
		caster.set("current_ability_index", 0)
		if caster.has_method("align_focus_menu_to_current_ability"):
			caster.call("align_focus_menu_to_current_ability")
		if caster.has_method("emit_current_ability"):
			caster.call("emit_current_ability")
	var weapon_controller: Node = player.get_node_or_null("WeaponController")
	if weapon_controller != null and weapon_controller.has_method("equip_weapon"):
		weapon_controller.call("equip_weapon", TrainingHammer)
	for resource_name: String in ["health", "stamina", "mana", "stance"]:
		var maximum_name: String = "max_" + resource_name
		GameState.set_stat(resource_name, GameState.get_stat(maximum_name))
	GameState.set_stat("fire", maxi(GameState.get_stat("fire"), 5))
	GameState.set_stat("metal", maxi(GameState.get_stat("metal"), 5))
	GameState.set_stat("air", maxi(GameState.get_stat("air"), 5))


func build_foundry() -> void:
	create_architecture()
	create_core()
	create_collapse_consequences()
	create_burn_hoist_route()
	create_masonry_route()
	create_tether_brace_route()
	create_smoke_curtain()
	create_guard(
		"BoldFoundryGuard",
		Vector3(-4.2, 0.9, -9.0),
		"bold"
	)
	create_guard(
		"SkittishFoundryGuard",
		Vector3(4.2, 0.9, -8.0),
		"skittish"
	)
	create_signage()


func create_architecture() -> void:
	create_static_box(
		"FoundryFloor",
		Vector3(0.0, -0.5, -1.0),
		Vector3(28.0, 1.0, 32.0),
		Color(0.045, 0.043, 0.045, 1.0)
	)
	var wall_color: Color = Color(0.07, 0.055, 0.05, 1.0)
	create_static_box(
		"WestWall",
		Vector3(-14.0, 4.0, -1.0),
		Vector3(0.6, 8.0, 32.0),
		wall_color
	)
	create_static_box(
		"EastWall",
		Vector3(14.0, 4.0, -1.0),
		Vector3(0.6, 8.0, 32.0),
		wall_color
	)
	create_static_box(
		"NorthWallLeft",
		Vector3(-8.0, 4.0, -16.0),
		Vector3(12.0, 8.0, 0.6),
		wall_color
	)
	create_static_box(
		"NorthWallRight",
		Vector3(8.0, 4.0, -16.0),
		Vector3(12.0, 8.0, 0.6),
		wall_color
	)
	for x_value: float in [-9.0, 9.0]:
		create_static_box(
			"PipeBank" + str(x_value),
			Vector3(x_value, 1.1, 0.0),
			Vector3(2.2, 2.2, 12.0),
			Color(0.16, 0.09, 0.045, 1.0)
		)


func create_core() -> void:
	var core: StaticBody3D = StaticBody3D.new()
	core.name = "FoundryCore"
	core.position = Vector3(0.0, 1.6, -5.0)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 2.0
	shape.height = 3.2
	collision.shape = shape
	core.add_child(collision)
	core_visual = MeshInstance3D.new()
	core_visual.name = "CoreVisual"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.8
	mesh.bottom_radius = 2.0
	mesh.height = 3.2
	core_visual.mesh = mesh
	core_visual.material_override = ElementVisuals.make_material(
		Color(0.88, 0.12, 0.025, 1.0),
		3.5,
		1.0,
		false
	)
	core.add_child(core_visual)
	add_child(core)
	add_world_label(
		"FOUNDRY CORE",
		Vector3(0.0, 4.0, -5.0),
		Color(1.0, 0.42, 0.12, 1.0),
		25
	)


func create_collapse_consequences() -> void:
	collapse_consequences = CollapseConsequencesScript.new() as StructuralCollapseConsequence3D
	collapse_consequences.name = "StructuralCollapseConsequences"
	collapse_consequences.sound_loudness = 24.0
	collapse_consequences.impact_radius = 5.0
	collapse_consequences.impact_damage = 4
	collapse_consequences.impact_stance_damage = 8
	add_child(collapse_consequences)


func create_burn_hoist_route() -> void:
	var assembly: StructuralAssembly3D = create_assembly("BurnHoistAssembly")
	var load: StructuralMember3D = create_member(
		assembly,
		"MoltenCrucible",
		Vector3(-5.5, 5.0, -4.5),
		Vector3(3.0, 2.0, 3.0),
		120.0,
		Color(0.43, 0.16, 0.035, 1.0)
	)
	var anchor: StaticBody3D = StaticBody3D.new()
	anchor.name = "HoistAnchor"
	anchor.position = Vector3(-5.5, 9.2, -4.5)
	assembly.add_child(anchor)
	var tether: FlexibleTether3D = FlexibleTether3D.new()
	tether.name = "HoistRope"
	tether.endpoint_a_path = NodePath("../HoistAnchor")
	tether.endpoint_b_path = NodePath("../MoltenCrucible")
	tether.material_profile = HempRope
	tether.rest_length = 4.4
	tether.segment_count = 15
	tether.constraint_iterations = 8
	tether.apply_endpoint_forces = false
	assembly.add_child(tether)
	var connection: StructuralConnection3D = create_connection(
		assembly,
		"burn_hoist",
		Vector3(-5.5, 8.75, -4.5),
		Vector3(0.8, 0.8, 0.8),
		WoodProfile,
		load,
		false
	)
	connection.cut_tether_path = NodePath("../HoistRope")
	routes["burn"] = connection


func create_masonry_route() -> void:
	var assembly: StructuralAssembly3D = create_assembly("MasonryCollapseAssembly")
	var slab: StructuralMember3D = create_member(
		assembly,
		"MasonrySlab",
		Vector3(0.0, 6.2, -6.5),
		Vector3(6.5, 1.0, 3.5),
		190.0,
		Color(0.34, 0.32, 0.3, 1.0)
	)
	var connection: StructuralConnection3D = create_connection(
		assembly,
		"masonry_column",
		Vector3(0.0, 2.6, -7.2),
		Vector3(1.3, 5.2, 1.3),
		MasonryProfile,
		slab,
		false
	)
	routes["hammer"] = connection


func create_tether_brace_route() -> void:
	var assembly: StructuralAssembly3D = create_assembly("BraceGantryAssembly")
	var gantry: StructuralMember3D = create_member(
		assembly,
		"OreGantry",
		Vector3(5.8, 5.4, -4.8),
		Vector3(5.0, 0.75, 3.0),
		145.0,
		Color(0.18, 0.24, 0.28, 1.0)
	)
	var connection: StructuralConnection3D = create_connection(
		assembly,
		"metal_brace",
		Vector3(5.8, 7.25, -4.8),
		Vector3(1.0, 2.2, 0.8),
		IronProfile,
		gantry,
		true
	)
	var anchor: MetalTetherAnchor3D = connection.get_node_or_null(
		"MetalTetherAnchor"
	) as MetalTetherAnchor3D
	if anchor != null:
		anchor.anchor_broken.connect(
			_on_tether_anchor_broken.bind(connection)
		)
	routes["tether"] = connection


func create_smoke_curtain() -> void:
	var smoke_definition: GasDefinition = SmokeGas.duplicate(true) as GasDefinition
	smoke_definition.buoyancy_velocity = Vector3(0.0, 0.28, 0.0)
	smoke_definition.diffusion_rate = 0.16
	smoke_definition.decay_rate_per_second = 0.06
	smoke_volume = GasVolumeGridScript.new() as GasVolumeGrid
	smoke_volume.name = "FoundrySmokeGrid"
	smoke_volume.position = Vector3(0.0, 2.4, 2.5)
	smoke_volume.gas_definition = smoke_definition
	smoke_volume.grid_size = Vector3i(8, 5, 7)
	smoke_volume.cell_size = 1.2
	smoke_volume.simulation_interval = 0.22
	smoke_volume.maximum_steps_per_frame = 1
	smoke_volume.visual_stride = 2
	smoke_volume.visual_update_interval = 0.38
	smoke_volume.visual_alpha_multiplier = 0.62
	add_child(smoke_volume)
	var emitter: GasEmitter3D = GasEmitterScript.new() as GasEmitter3D
	emitter.name = "FoundrySmokeEmitter"
	emitter.position = Vector3(0.0, 0.45, 2.5)
	emitter.gas_id = "smoke"
	emitter.emission_rate_per_second = 1.0
	emitter.emission_radius = 1.7
	emitter.pulse_frequency = 0.16
	emitter.pulse_depth = 0.1
	add_child(emitter)


func create_guard(
	guard_name: String,
	position_value: Vector3,
	personality: String
) -> void:
	var enemy: CharacterBody3D = GremlinScene.instantiate() as CharacterBody3D
	if enemy == null:
		return
	var old_brain: Node = enemy.get_node_or_null("EnemyBrain")
	var definition_value: Variant = old_brain.get("enemy_definition") if old_brain != null else null
	var attack_value: Variant = old_brain.get("default_attack") if old_brain != null else null
	var options_value: Variant = old_brain.get("action_options") if old_brain != null else []
	if old_brain != null:
		enemy.remove_child(old_brain)
		old_brain.free()
	var sensor: EnemyPerceptionSensor = PerceptionSensorScript.new() as EnemyPerceptionSensor
	sensor.name = "EnemyPerceptionSensor"
	sensor.vision_range = 14.0
	sensor.field_of_view_degrees = 100.0
	sensor.hearing_sensitivity = 1.2
	sensor.sample_interval = 0.1
	enemy.add_child(sensor)
	var brain: Node = PerceptionBrainScript.new()
	brain.name = "EnemyBrain"
	brain.set("enemy_definition", definition_value)
	brain.set("default_attack", attack_value)
	brain.set("action_options", options_value)
	brain.set("personality_id", personality)
	brain.set("allow_combat", true)
	brain.set("zone_awareness_radius", 5.0)
	enemy.add_child(brain)
	enemy.name = guard_name
	enemy.position = position_value
	enemy.rotation.y = PI
	add_child(enemy)
	enemies.append(enemy)


func create_signage() -> void:
	add_world_label(
		"CHOOSE ONE SABOTAGE ROUTE",
		Vector3(0.0, 7.8, 4.0),
		Color(1.0, 0.72, 0.25, 1.0),
		27
	)
	add_world_label(
		"FIREBOLT\nBurn hoist rope",
		Vector3(-5.5, 9.8, -4.5),
		Color(1.0, 0.35, 0.1, 1.0),
		23
	)
	add_world_label(
		"HEAVY HAMMER\nFracture column",
		Vector3(0.0, 5.5, -8.0),
		Color(0.86, 0.84, 0.8, 1.0),
		23
	)
	add_world_label(
		"METAL TETHER\nExtract gold brace",
		Vector3(5.8, 8.9, -4.8),
		Color(1.0, 0.75, 0.18, 1.0),
		23
	)
	add_world_label(
		"SMOKE CURTAIN\nGust opens sightlines",
		Vector3(0.0, 3.8, 2.5),
		Color(0.72, 0.82, 0.9, 1.0),
		21
	)
	add_world_label(
		"ESCAPE\nCore shutdown required",
		Vector3(0.0, 3.3, -15.4),
		Color(0.35, 0.7, 1.0, 1.0),
		23
	)


func create_assembly(assembly_name: String) -> StructuralAssembly3D:
	var assembly: StructuralAssembly3D = StructuralAssembly3D.new()
	assembly.name = assembly_name
	assembly.connection_failed.connect(_on_connection_failed)
	add_child(assembly)
	assemblies.append(assembly)
	return assembly


func create_member(
	assembly: StructuralAssembly3D,
	member_name: String,
	position_value: Vector3,
	size_value: Vector3,
	mass_value: float,
	color: Color
) -> StructuralMember3D:
	var member: StructuralMember3D = StructuralMember3D.new()
	member.name = member_name
	member.structural_id = member_name.to_snake_case()
	member.position = position_value
	member.mass = mass_value
	member.freeze = true
	member.linear_damp = 0.3
	member.angular_damp = 0.65
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	member.add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = ElementVisuals.make_material(
		color,
		0.16,
		1.0,
		false
	)
	member.add_child(visual)
	assembly.add_child(member)
	return member


func create_connection(
	assembly: StructuralAssembly3D,
	connection_id: String,
	position_value: Vector3,
	size_value: Vector3,
	profile: StructuralMaterialProfile,
	supported_member: StructuralMember3D,
	add_tether_anchor: bool
) -> StructuralConnection3D:
	var connection: StructuralConnection3D = StructuralConnection3D.new()
	connection.name = connection_id.to_pascal_case()
	connection.connection_id = connection_id
	connection.position = position_value
	connection.anchor_a_to_world = true
	connection.member_b_path = NodePath("../" + str(supported_member.name))
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	connection.add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = ElementVisuals.make_material(
		profile.intact_color,
		0.45 if profile.material_id == "iron_support" else 0.08,
		1.0,
		false
	)
	connection.add_child(visual)
	if profile.burnable:
		add_combustion_stack(connection)
	var integrity: StructuralIntegrity = StructuralIntegrity.new()
	integrity.name = "StructuralIntegrity"
	integrity.material_profile = profile
	connection.add_child(integrity)
	var payload_receiver: PayloadReceiver = PayloadReceiver.new()
	payload_receiver.name = "PayloadReceiver"
	connection.add_child(payload_receiver)
	if add_tether_anchor:
		var anchor: MetalTetherAnchor3D = MetalTetherAnchor3D.new()
		anchor.name = "MetalTetherAnchor"
		anchor.anchor_id = connection_id
		anchor.display_name = "FOUNDRY STRUCTURAL BRACE"
		anchor.breakable = true
		anchor.break_strength = 850.0
		connection.add_child(anchor)
		add_anchor_visual(anchor)
	assembly.add_child(connection)
	return connection


func add_combustion_stack(connection: StructuralConnection3D) -> void:
	var thermal: ThermalState = ThermalState.new()
	thermal.name = "ThermalState"
	thermal.material_profile = WoodPhysical
	thermal.mass_kg = 0.12
	thermal.gameplay_heat_capacity_scale = 0.003
	thermal.ignition_enabled = true
	connection.add_child(thermal)
	var combustion: CombustionState = CombustionState.new()
	combustion.name = "CombustionState"
	combustion.material_profile = WoodPhysical
	combustion.thermal_state_path = NodePath("../ThermalState")
	combustion.initial_fuel_kg_override = 0.16
	combustion.burn_rate_kg_per_second_override = 0.085
	connection.add_child(combustion)


func add_anchor_visual(anchor: Node3D) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "AnchorRing"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.58
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.material_override = ElementVisuals.make_material(
		Color(1.0, 0.72, 0.12, 1.0),
		2.0,
		1.0,
		false
	)
	anchor.add_child(ring)


func _on_tether_anchor_broken(
	_anchor: MetalTetherAnchor3D,
	tension: float,
	connection: StructuralConnection3D
) -> void:
	if connection != null:
		connection.break_connection("Metal Tether extraction", tension)


func _on_connection_failed(
	connection_id: String,
	reason: String,
	peak_stress_n: float
) -> void:
	collapse_count += 1
	var route_id: String = get_route_for_connection(connection_id)
	var collapse_origin: Vector3 = get_collapse_origin(route_id)
	var route_label: String = get_route_label(route_id)
	var affected: int = 0
	if collapse_consequences != null:
		affected = collapse_consequences.trigger_collapse(
			collapse_origin,
			route_label + " collapse"
		)
	show_message(
		route_label
		+ " failed by "
		+ reason
		+ " at "
		+ str(int(round(peak_stress_n)))
		+ " N. "
		+ str(affected)
		+ " nearby target(s) caught in the collapse."
	)
	if not core_disabled:
		shutdown_core(route_id)


func shutdown_core(route_id: String) -> void:
	core_disabled = true
	escape_unlocked = true
	winning_route = route_id
	if core_visual != null:
		core_visual.material_override = ElementVisuals.make_material(
			Color(0.06, 0.09, 0.12, 1.0),
			0.05,
			1.0,
			false
		)
	var furnace_light: OmniLight3D = get_node_or_null(
		"FurnaceGlow"
	) as OmniLight3D
	if furnace_light != null:
		furnace_light.light_color = Color(0.12, 0.28, 0.42, 1.0)
		furnace_light.light_energy = 0.75
	GameState.set_objective("The foundry core is disabled. Reach the blue escape door.")
	show_message(
		"CORE OFFLINE through "
		+ get_route_label(route_id)
		+ ". The north escape is unlocked."
	)


func _on_escape_zone_body_entered(body: Node3D) -> void:
	if body == null or not body.is_in_group("player"):
		return
	if not escape_unlocked:
		show_message("The escape remains sealed while the foundry core is active.")
		return
	if encounter_completed:
		return
	encounter_completed = true
	GameState.set_objective("Foundry sabotaged. Encounter complete.")
	show_message(
		"FOUNDRY SABOTAGE COMPLETE — escaped after "
		+ get_route_label(winning_route)
		+ "."
	)


func get_route_for_connection(connection_id: String) -> String:
	for route_id: Variant in routes.keys():
		var connection: StructuralConnection3D = routes[route_id] as StructuralConnection3D
		if connection != null and connection.connection_id == connection_id:
			return str(route_id)
	return "unknown"


func get_route_label(route_id: String) -> String:
	match route_id:
		"burn":
			return "Burned Hoist"
		"hammer":
			return "Masonry Fracture"
		"tether":
			return "Metal Brace Extraction"
	return "Structural Failure"


func get_collapse_origin(route_id: String) -> Vector3:
	match route_id:
		"burn":
			return Vector3(-3.2, 1.0, -4.8)
		"hammer":
			return Vector3(0.0, 1.0, -6.0)
		"tether":
			return Vector3(3.2, 1.0, -4.8)
	return Vector3(0.0, 1.0, -5.0)


func force_route_for_test(route_id: String) -> void:
	var connection: StructuralConnection3D = routes.get(route_id) as StructuralConnection3D
	if connection != null:
		connection.break_connection("automated sabotage", 1200.0)


func refresh_readout() -> void:
	if readout == null:
		return
	var core_text: String = "OFFLINE" if core_disabled else "ACTIVE"
	var route_text: String = get_route_label(winning_route) if core_disabled else "Choose burn / hammer / tether"
	var awareness_parts: Array[String] = []
	for enemy: CharacterBody3D in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var brain: Node = enemy.get_node_or_null("EnemyBrain")
		if brain != null and brain.has_method("get_awareness_state_name"):
			awareness_parts.append(
				enemy.name.replace("FoundryGuard", "")
				+ " "
				+ str(brain.call("get_awareness_state_name"))
			)
	readout.text = (
		"FOUNDRY CORE "
		+ core_text
		+ "  •  "
		+ route_text
		+ "\nGuards "
		+ (", ".join(awareness_parts) if not awareness_parts.is_empty() else "cleared")
		+ "  •  "
		+ ("ESCAPE OPEN" if escape_unlocked else "Escape sealed")
	)


func create_static_box(
	body_name: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = body_name
	body.position = position_value
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = ElementVisuals.make_material(
		color,
		0.08,
		1.0,
		false
	)
	body.add_child(visual)
	add_child(body)
	return body


func add_world_label(
	text_value: String,
	position_value: Vector3,
	color: Color,
	font_size: int
) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	return label


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)


func get_debug_data() -> Dictionary:
	return {
		"foundry_sabotage": true,
		"routes": routes.keys(),
		"core_disabled": core_disabled,
		"escape_unlocked": escape_unlocked,
		"completed": encounter_completed,
		"winning_route": winning_route,
		"collapse_count": collapse_count,
		"guards_alive": get_alive_guard_count(),
	}


func get_alive_guard_count() -> int:
	var count: int = 0
	for enemy: CharacterBody3D in enemies:
		if enemy != null and is_instance_valid(enemy):
			count += 1
	return count
