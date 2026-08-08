extends Node

const VineGrappleAbility: AbilityDefinition = preload(
	"res://data/abilities/life_vine_grapple_ability.tres"
)
const VineMaterial: FlexibleMaterialProfile = preload(
	"res://data/flexible_materials/life_vine_grapple.tres"
)
const StartingLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_starting_loadout.tres"
)
const VineScene: PackedScene = preload(
	"res://scenes/actions/life_vine_grapple.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	run_tests()
	if failures.is_empty():
		print("LIFE_VINE_GRAPPLE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LIFE_VINE_GRAPPLE_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func run_tests() -> void:
	validate_ability_contract()
	validate_material_contract()
	validate_enemy_pull_contract()
	validate_rigid_body_mass_contract()


func validate_ability_contract() -> void:
	if VineGrappleAbility == null:
		failures.append("Vine Grapple ability resource is missing")
		return
	if VineGrappleAbility.get_spell_id() != "vine_grapple":
		failures.append("Vine Grapple spell id mismatch")
	if VineGrappleAbility.element != "life":
		failures.append("Vine Grapple must be a Life spell")
	if VineGrappleAbility.get_delivery_type() != "channeled_tether":
		failures.append("Vine Grapple must use channeled tether delivery")
	for required_role: String in ["control", "force", "grapple", "pull"]:
		if not VineGrappleAbility.roles.has(required_role):
			failures.append("Vine Grapple missing role " + required_role)
	if not StartingLoadout.knows_ability(VineGrappleAbility):
		failures.append("Grace must learn Vine Grapple in the starting loadout")


func validate_material_contract() -> void:
	if VineMaterial == null:
		failures.append("living vine material is missing")
		return
	if VineMaterial.visual_style != FlexibleMaterialProfile.VisualStyle.ROPE:
		failures.append("living vine must use the flexible rope presentation")
	if not VineMaterial.burnable:
		failures.append("living vine should remain vulnerable to Fire")
	if VineMaterial.conductive:
		failures.append("living vine should not inherit Metal Tether conductivity")
	if VineMaterial.break_strength >= 5200.0:
		failures.append("living vine should be more breakable than the metal filament")


func validate_enemy_pull_contract() -> void:
	var source := CharacterBody3D.new()
	source.name = "GraceTestBody"
	source.position = Vector3.ZERO
	add_child(source)

	var target := CharacterBody3D.new()
	target.name = "GrappleEnemy"
	target.position = Vector3(0.0, 0.0, -6.0)
	target.add_to_group("enemy")
	var receiver := ForceReceiver.new()
	receiver.name = "ForceReceiver"
	target.add_child(receiver)
	add_child(target)

	var action: LifeVineGrapple = VineScene.instantiate() as LifeVineGrapple
	add_child(action)
	action.set_source_actor(source)
	if not action.target_meets_contract(target):
		failures.append("enemy CharacterBody with ForceReceiver is not grappleable")
	elif not action.attach_to_target(target, target.global_position + Vector3.UP * 0.5):
		failures.append("Vine Grapple could not attach to a valid enemy")
	else:
		action.apply_pull(0.1)
		if receiver.external_velocity.length() <= 0.01:
			failures.append("Vine Grapple did not feed pull velocity into ForceReceiver")
		elif receiver.external_velocity.z <= 0.0:
			failures.append("Vine Grapple pulled the enemy away from Grace instead of toward her")
		if action.tether_visual == null:
			failures.append("Vine Grapple did not create the shared flexible tether visual")

	action.release_grapple("smoke test", false)
	target.queue_free()
	source.queue_free()


func validate_rigid_body_mass_contract() -> void:
	var source := Node3D.new()
	source.name = "GraceMassTest"
	add_child(source)

	var action: LifeVineGrapple = VineScene.instantiate() as LifeVineGrapple
	add_child(action)
	action.set_source_actor(source)

	var light_body := RigidBody3D.new()
	light_body.mass = minf(20.0, action.maximum_rigidbody_mass)
	add_child(light_body)
	if not action.target_meets_contract(light_body):
		failures.append("movable light RigidBody should be grappleable")

	var heavy_body := RigidBody3D.new()
	heavy_body.mass = action.maximum_rigidbody_mass + 1.0
	add_child(heavy_body)
	if action.target_meets_contract(heavy_body):
		failures.append("RigidBody above the Vine Grapple mass ceiling should resist")

	heavy_body.queue_free()
	light_body.queue_free()
	action.queue_free()
	source.queue_free()
