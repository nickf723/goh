extends Node3D
class_name PrototypeStructuralStressLab

const ElementVisuals = preload("res://scripts/visuals/element_visuals.gd")
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
const LabLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_structural_stress_lab_loadout.tres"
)
const TrainingHammer: WeaponDefinition = preload(
	"res://data/weapons/training_hammer.tres"
)

@export var enable_editor_f8_reset: bool = true
@export_range(0.03, 0.5, 0.01) var readout_refresh_interval: float = 0.08

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var readout: Label = get_node_or_null(
	"StructuralHUD/Panel/Margin/Readout"
) as Label

var assemblies: Array[StructuralAssembly3D] = []
var burn_connection: StructuralConnection3D = null
var scaffold_assembly: StructuralAssembly3D = null
var scaffold_platform: StructuralMember3D = null
var scaffold_left: StructuralConnection3D = null
var scaffold_right: StructuralConnection3D = null
var impact_connection: StructuralConnection3D = null
var tether_connection: StructuralConnection3D = null
var stat_snapshot: Dictionary = {}
var readout_timer: float = 0.0
var scaffold_load_step: int = 0


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	add_to_group("structural_stress_lab")
	add_to_group("debuggable")
	stat_snapshot = GameState.get_stat_snapshot()
	build_laboratory()
	configure_player()
	GameState.set_objective(
		"Burn the rope coupling, overload the scaffold, hammer the masonry joint, and pull the metal brace."
	)
	show_message(
		"Structural Stress Laboratory online. Every failure now releases its unsupported bodies."
	)
	refresh_readout()


func _process(delta: float) -> void:
	readout_timer -= delta
	if readout_timer <= 0.0:
		readout_timer = maxf(readout_refresh_interval, 0.03)
		refresh_readout()


func _exit_tree() -> void:
	restore_stat_snapshot()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		add_scaffold_load()
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_H:
		get_viewport().set_input_as_handled()
		add_scaffold_load()
	elif (
		key_event.physical_keycode == KEY_F8
		and enable_editor_f8_reset
		and OS.has_feature("editor")
	):
		get_viewport().set_input_as_handled()
		reset_lab()


func configure_player() -> void:
	if player == null:
		return
	var ability_caster: Node = player.get_node_or_null("AbilityCaster")
	if ability_caster != null:
		ability_caster.set("loadout", LabLoadout.duplicate(true))
		ability_caster.set("current_ability_index", 0)
		if ability_caster.has_method("align_focus_menu_to_current_ability"):
			ability_caster.call("align_focus_menu_to_current_ability")
		if ability_caster.has_method("emit_current_ability"):
			ability_caster.call("emit_current_ability")
	var weapon_controller: Node = player.get_node_or_null("WeaponController")
	if weapon_controller != null and weapon_controller.has_method("equip_weapon"):
		weapon_controller.call("equip_weapon", TrainingHammer)
	var aerial: Node = player.get_node_or_null("AerialLocomotion")
	if aerial != null:
		aerial.set("double_jump_unlocked", false)
		aerial.set("hover_unlocked", false)
		aerial.set("flight_unlocked", false)
	for resource_name: String in ["health", "stamina", "mana", "stance"]:
		var maximum_name: String = "max_" + resource_name
		GameState.set_stat(resource_name, GameState.get_stat(maximum_name))
	GameState.set_stat("metal", maxi(GameState.get_stat("metal"), 5))
	GameState.set_stat("fire", maxi(GameState.get_stat("fire"), 5))


func build_laboratory() -> void:
	create_static_box(
		"Floor",
		Vector3(0.0, -0.5, -1.0),
		Vector3(30.0, 1.0, 28.0),
		Color(0.055, 0.06, 0.07, 1.0)
	)
	create_static_box(
		"BackWall",
		Vector3(0.0, 5.0, -12.5),
		Vector3(30.0, 10.0, 0.6),
		Color(0.07, 0.065, 0.06, 1.0)
	)
	create_instruction_board()
	create_burn_release_station()
	create_redundant_scaffold_station()
	create_impact_station()
	create_tether_extraction_station()


func create_instruction_board() -> void:
	add_world_label(
		"STRUCTURAL STRESS LABORATORY\nFIREBOLT burns the rope coupling  •  INTERACT / H adds scaffold load\nHAMMER the cracked masonry column  •  METAL TETHER pulls the gold brace  •  F8 resets",
		Vector3(0.0, 7.5, -11.9),
		Color(1.0, 0.78, 0.3, 1.0),
		26
	)


func create_burn_release_station() -> void:
	var assembly: StructuralAssembly3D = create_assembly("BurnReleaseAssembly")
	var load: StructuralMember3D = create_member(
		assembly,
		"BurnLoad",
		Vector3(-10.0, 3.1, -4.5),
		Vector3(1.8, 1.8, 1.8),
		36.0,
		Color(0.34, 0.19, 0.08, 1.0)
	)
	var anchor: StaticBody3D = StaticBody3D.new()
	anchor.name = "BurnRopeAnchor"
	anchor.position = Vector3(-10.0, 7.0, -4.5)
	assembly.add_child(anchor)

	var tether: FlexibleTether3D = FlexibleTether3D.new()
	tether.name = "BurnRopeVisual"
	tether.endpoint_a_path = NodePath("../BurnRopeAnchor")
	tether.endpoint_b_path = NodePath("../BurnLoad")
	tether.material_profile = HempRope
	tether.rest_length = 3.15
	tether.segment_count = 14
	tether.constraint_iterations = 8
	tether.apply_endpoint_forces = false
	assembly.add_child(tether)

	burn_connection = create_connection(
		assembly,
		"BurnRopeCoupling",
		Vector3(-10.0, 6.55, -4.5),
		Vector3(0.75, 0.75, 0.75),
		WoodProfile,
		load,
		true,
		false
	)
	burn_connection.cut_tether_path = NodePath("../BurnRopeVisual")
	add_world_label(
		"BURN RELEASE\nFirebolt the wooden coupling\nThe 36 kg box MUST fall",
		Vector3(-10.0, 7.8, -4.5),
		Color(1.0, 0.48, 0.18, 1.0),
		22
	)


func create_redundant_scaffold_station() -> void:
	scaffold_assembly = create_assembly("RedundantScaffoldAssembly")
	scaffold_platform = create_member(
		scaffold_assembly,
		"ScaffoldPlatform",
		Vector3(-3.4, 3.05, -4.5),
		Vector3(5.2, 0.55, 3.1),
		80.0,
		Color(0.32, 0.23, 0.12, 1.0)
	)
	scaffold_left = create_connection(
		scaffold_assembly,
		"ScaffoldLeftSupport",
		Vector3(-5.1, 1.45, -4.5),
		Vector3(0.55, 2.9, 0.55),
		WoodProfile,
		scaffold_platform,
		true,
		false
	)
	scaffold_right = create_connection(
		scaffold_assembly,
		"ScaffoldRightSupport",
		Vector3(-1.7, 1.45, -4.5),
		Vector3(0.55, 2.9, 0.55),
		WoodProfile,
		scaffold_platform,
		true,
		false
	)
	add_world_label(
		"REDUNDANT SCAFFOLD\nINTERACT / H adds 30 kg\nOne support fails → load shifts → cascade",
		Vector3(-3.4, 6.1, -4.5),
		Color(0.95, 0.74, 0.34, 1.0),
		22
	)


func create_impact_station() -> void:
	var assembly: StructuralAssembly3D = create_assembly("ImpactAssembly")
	var lintel: StructuralMember3D = create_member(
		assembly,
		"ImpactLintel",
		Vector3(3.3, 4.5, -4.5),
		Vector3(4.2, 1.0, 2.0),
		64.0,
		Color(0.36, 0.34, 0.32, 1.0)
	)
	impact_connection = create_connection(
		assembly,
		"CrackedMasonryJoint",
		Vector3(3.3, 2.0, -4.5),
		Vector3(1.2, 4.0, 1.2),
		MasonryProfile,
		lintel,
		true,
		false
	)
	add_world_label(
		"IMPACT FAILURE\nHeavy Hammer the cracked column\nForce tags become structural stress",
		Vector3(3.3, 6.2, -4.5),
		Color(0.82, 0.8, 0.76, 1.0),
		22
	)


func create_tether_extraction_station() -> void:
	var assembly: StructuralAssembly3D = create_assembly("TetherExtractionAssembly")
	var gate: StructuralMember3D = create_member(
		assembly,
		"TetherGate",
		Vector3(10.0, 3.0, -4.5),
		Vector3(4.4, 4.6, 0.55),
		72.0,
		Color(0.2, 0.27, 0.34, 1.0)
	)
	tether_connection = create_connection(
		assembly,
		"TetherExtractionBrace",
		Vector3(10.0, 6.15, -4.5),
		Vector3(1.0, 1.7, 0.75),
		IronProfile,
		gate,
		true,
		true
	)
	var anchor: MetalTetherAnchor3D = tether_connection.get_node_or_null(
		"MetalTetherAnchor"
	) as MetalTetherAnchor3D
	if anchor != null:
		anchor.anchor_broken.connect(_on_tether_anchor_broken.bind(tether_connection))
	add_world_label(
		"METAL EXTRACTION\nHold Metal Tether and reel/swing\nOverload the GOLD brace to drop the gate",
		Vector3(10.0, 7.7, -4.5),
		Color(1.0, 0.76, 0.2, 1.0),
		22
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
	member.linear_damp = 0.35
	member.angular_damp = 0.8
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	member.add_child(collision)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(
		color,
		0.18,
		1.0,
		false
	)
	member.add_child(mesh_instance)
	assembly.add_child(member)
	return member


func create_connection(
	assembly: StructuralAssembly3D,
	connection_name: String,
	position_value: Vector3,
	size_value: Vector3,
	profile: StructuralMaterialProfile,
	supported_member: StructuralMember3D,
	world_anchor: bool,
	add_tether_anchor: bool
) -> StructuralConnection3D:
	var connection: StructuralConnection3D = StructuralConnection3D.new()
	connection.name = connection_name
	connection.connection_id = connection_name.to_snake_case()
	connection.position = position_value
	connection.anchor_a_to_world = world_anchor
	connection.member_b_path = NodePath("../" + str(supported_member.name))

	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	connection.add_child(collision)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(
		profile.intact_color,
		0.45 if profile.material_id == "iron_support" else 0.08,
		1.0,
		false
	)
	connection.add_child(mesh_instance)

	if profile.burnable:
		var thermal: ThermalState = ThermalState.new()
		thermal.name = "ThermalState"
		thermal.material_profile = WoodPhysical
		thermal.mass_kg = 0.14
		thermal.gameplay_heat_capacity_scale = 0.003
		thermal.ignition_enabled = true
		connection.add_child(thermal)
		var combustion: CombustionState = CombustionState.new()
		combustion.name = "CombustionState"
		combustion.material_profile = WoodPhysical
		combustion.thermal_state_path = NodePath("../ThermalState")
		combustion.initial_fuel_kg_override = 0.18
		combustion.burn_rate_kg_per_second_override = 0.08
		connection.add_child(combustion)

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
		anchor.anchor_id = connection.connection_id
		anchor.display_name = "STRUCTURAL METAL BRACE"
		anchor.breakable = true
		anchor.break_strength = 900.0
		connection.add_child(anchor)
		add_anchor_visual(anchor)

	assembly.add_child(connection)
	return connection


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


func add_scaffold_load() -> void:
	if scaffold_platform == null or not scaffold_platform.supported:
		show_message("The scaffold is already unsupported. Reset before adding more load.")
		return
	scaffold_load_step += 1
	scaffold_platform.mass += 30.0
	var weight_visual: MeshInstance3D = MeshInstance3D.new()
	weight_visual.name = "AddedLoad" + str(scaffold_load_step)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.8, 0.6, 0.8)
	weight_visual.mesh = mesh
	weight_visual.position = Vector3(
		-1.2 + float((scaffold_load_step - 1) % 4) * 0.8,
		0.58,
		0.0
	)
	weight_visual.material_override = ElementVisuals.make_material(
		Color(0.5, 0.2, 0.08, 1.0),
		0.12,
		1.0,
		false
	)
	scaffold_platform.add_child(weight_visual)
	show_message(
		"Scaffold load increased to "
		+ str(int(scaffold_platform.mass))
		+ " kg. The surviving supports automatically inherit the load."
	)


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
	show_message(
		connection_id.replace("_", " ").capitalize()
		+ " failed by "
		+ reason
		+ " at "
		+ str(int(round(peak_stress_n)))
		+ " N."
	)


func refresh_readout() -> void:
	if readout == null:
		return
	var intact_connections: int = 0
	var total_connections: int = 0
	var supported_members: int = 0
	var total_members: int = 0
	for assembly: StructuralAssembly3D in assemblies:
		if assembly == null:
			continue
		intact_connections += assembly.get_intact_connection_count()
		total_connections += assembly.connections.size()
		supported_members += assembly.get_supported_member_count()
		total_members += assembly.members.size()
	readout.text = (
		"STRUCTURE  •  Supports "
		+ str(intact_connections)
		+ "/"
		+ str(total_connections)
		+ "  •  Members "
		+ str(supported_members)
		+ "/"
		+ str(total_members)
		+ "\nBurn "
		+ format_connection(burn_connection)
		+ "  •  Scaffold "
		+ format_connection(scaffold_left)
		+ "  •  Masonry "
		+ format_connection(impact_connection)
		+ "  •  Brace "
		+ format_connection(tether_connection)
	)


func format_connection(connection: StructuralConnection3D) -> String:
	if connection == null or connection.integrity == null:
		return "missing"
	if connection.broken:
		return "BROKEN"
	return (
		str(int(round(connection.integrity.get_total_stress_n())))
		+ "/"
		+ str(int(round(connection.integrity.get_effective_capacity_n())))
		+ "N"
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
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = ElementVisuals.make_material(
		color,
		0.08,
		1.0,
		false
	)
	body.add_child(mesh_instance)
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


func reset_lab() -> void:
	get_tree().reload_current_scene()


func restore_stat_snapshot() -> void:
	for stat_name: Variant in stat_snapshot.keys():
		GameState.set_stat(str(stat_name), int(stat_snapshot[stat_name]))


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"structural_stress_lab": true,
		"assemblies": assemblies.size(),
		"scaffold_load_step": scaffold_load_step,
		"burn_released": burn_connection != null and burn_connection.broken,
		"tether_extracted": tether_connection != null and tether_connection.broken,
	}
