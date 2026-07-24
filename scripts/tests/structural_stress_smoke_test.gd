extends Node

const WoodProfile: StructuralMaterialProfile = preload(
	"res://data/structural_materials/wood_support.tres"
)
const IronProfile: StructuralMaterialProfile = preload(
	"res://data/structural_materials/iron_support.tres"
)
const MasonryProfile: StructuralMaterialProfile = preload(
	"res://data/structural_materials/masonry_joint.tres"
)
const LabLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_structural_stress_lab_loadout.tres"
)
const FireboltAbility: AbilityDefinition = preload(
	"res://data/abilities/firebolt_ability.tres"
)
const MetalTetherAbility: AbilityDefinition = preload(
	"res://data/abilities/metal_tether_ability.tres"
)
const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_structural_stress_lab_v1.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	validate_profiles()
	validate_payload_stress()
	validate_fire_weakening()
	await validate_support_release()
	await validate_load_redistribution()
	await validate_laboratory_contract()
	if failures.is_empty():
		print("STRUCTURAL_STRESS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("STRUCTURAL_STRESS_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func validate_profiles() -> void:
	if not WoodProfile.burnable:
		failures.append("wood support profile must be burnable")
	if IronProfile.base_capacity_n <= WoodProfile.base_capacity_n:
		failures.append("iron support must outlast the wood support baseline")
	if MasonryProfile.force_tag_multiplier <= 1.0:
		failures.append("masonry joints must react materially to force payload tags")
	if not LabLoadout.knows_ability(FireboltAbility):
		failures.append("structural lab loadout is missing Firebolt")
	if not LabLoadout.knows_ability(MetalTetherAbility):
		failures.append("structural lab loadout is missing Metal Tether")


func validate_payload_stress() -> void:
	var profile: StructuralMaterialProfile = StructuralMaterialProfile.new()
	profile.base_capacity_n = 300.0
	profile.stress_per_damage_point_n = 120.0
	profile.stress_per_stance_point_n = 100.0
	profile.force_tag_multiplier = 1.5
	profile.overload_grace_seconds = 0.1
	var integrity: StructuralIntegrity = StructuralIntegrity.new()
	integrity.material_profile = profile
	add_child(integrity)
	var payload: DamagePayload = DamagePayload.new()
	payload.amount = 2
	payload.stance_damage = 3
	payload.source_name = "Smoke Hammer"
	payload.tags = ["physical", "force", "heavy"]
	integrity.receive_damage_payload(payload)
	if not integrity.failed or integrity.failure_reason != "impact overload":
		failures.append("force payload above capacity must fracture structural integrity")
	integrity.queue_free()


func validate_fire_weakening() -> void:
	var profile: StructuralMaterialProfile = WoodProfile.duplicate(true)
	profile.base_capacity_n = 500.0
	var integrity: StructuralIntegrity = StructuralIntegrity.new()
	integrity.material_profile = profile
	add_child(integrity)
	integrity.set_sustained_stress(120.0)
	var intact_capacity: float = integrity.get_effective_capacity_n()
	integrity.apply_fire_exposure(1.0, "smoke fire")
	if integrity.get_effective_capacity_n() >= intact_capacity:
		failures.append("burn progression must reduce a burnable support's capacity")
	if not integrity.failed:
		failures.append("burned capacity below a live load must fail the support")
	integrity.queue_free()


func validate_support_release() -> void:
	var assembly: StructuralAssembly3D = StructuralAssembly3D.new()
	assembly.auto_process_loads = false
	var member: StructuralMember3D = create_test_member("ReleaseMember", 20.0)
	var connection: StructuralConnection3D = create_test_connection(
		"ReleaseConnection",
		member,
		IronProfile
	)
	assembly.add_child(member)
	assembly.add_child(connection)
	add_child(assembly)
	await get_tree().process_frame
	assembly.rebuild_structure()
	if not member.supported or not member.freeze:
		failures.append("world-connected member must begin supported")
	connection.break_connection("smoke cut", 1.0)
	assembly.recompute_support_graph()
	if member.supported or member.freeze:
		failures.append("breaking the last support must release and unfreeze its member")
	assembly.queue_free()
	await get_tree().process_frame


func validate_load_redistribution() -> void:
	var profile: StructuralMaterialProfile = WoodProfile.duplicate(true)
	profile.base_capacity_n = 600.0
	profile.overload_grace_seconds = 0.05
	var assembly: StructuralAssembly3D = StructuralAssembly3D.new()
	assembly.auto_process_loads = false
	var member: StructuralMember3D = create_test_member("SharedLoadMember", 100.0)
	var left: StructuralConnection3D = create_test_connection(
		"LeftSupport",
		member,
		profile
	)
	var right: StructuralConnection3D = create_test_connection(
		"RightSupport",
		member,
		profile
	)
	assembly.add_child(member)
	assembly.add_child(left)
	assembly.add_child(right)
	add_child(assembly)
	await get_tree().process_frame
	assembly.rebuild_structure()
	assembly.step_structural_loads(0.05)
	if left.integrity.sustained_stress_n >= profile.base_capacity_n:
		failures.append("two intact supports must share the member load")
	left.break_connection("smoke removal", 1.0)
	assembly.recompute_support_graph()
	assembly.step_structural_loads(0.05)
	right.integrity.step_integrity(0.1)
	assembly.recompute_support_graph()
	if not right.broken:
		failures.append("remaining support must inherit the full load and overload")
	if member.supported:
		failures.append("cascaded support loss must release the loaded member")
	assembly.queue_free()
	await get_tree().process_frame


func validate_laboratory_contract() -> void:
	var lab: Node = LabScene.instantiate()
	if lab == null:
		failures.append("Structural Stress Laboratory failed to instantiate")
		return
	add_child(lab)
	await get_tree().process_frame
	await get_tree().physics_frame
	var assemblies_in_lab: int = 0
	var connections_in_lab: int = 0
	for node: Node in get_tree().get_nodes_in_group("structural_assemblies"):
		if lab.is_ancestor_of(node):
			assemblies_in_lab += 1
	for node: Node in get_tree().get_nodes_in_group("structural_connections"):
		if lab.is_ancestor_of(node):
			connections_in_lab += 1
	if assemblies_in_lab < 4:
		failures.append("laboratory requires four independent structural stations")
	if connections_in_lab < 5:
		failures.append("laboratory requires burn, redundant, impact, and tether supports")
	if lab.get_node_or_null("StructuralHUD/Panel/Margin/Readout") == null:
		failures.append("laboratory is missing its compact structural readout")
	if lab.get_node_or_null("Player/MetalTetherController") == null:
		failures.append("laboratory player is missing Metal Tether integration")
	lab.queue_free()
	await get_tree().process_frame


func create_test_member(member_name: String, mass_kg: float) -> StructuralMember3D:
	var member: StructuralMember3D = StructuralMember3D.new()
	member.name = member_name
	member.mass = mass_kg
	member.freeze = true
	return member


func create_test_connection(
	connection_name: String,
	member: StructuralMember3D,
	profile: StructuralMaterialProfile
) -> StructuralConnection3D:
	var connection: StructuralConnection3D = StructuralConnection3D.new()
	connection.name = connection_name
	connection.anchor_a_to_world = true
	connection.member_b_path = NodePath("../" + str(member.name))
	var integrity: StructuralIntegrity = StructuralIntegrity.new()
	integrity.name = "StructuralIntegrity"
	integrity.material_profile = profile
	connection.add_child(integrity)
	return connection
