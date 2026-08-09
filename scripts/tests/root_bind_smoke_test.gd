extends Node

const RootBindAbility: AbilityDefinition = preload(
	"res://data/abilities/root_bind_ability.tres"
)
const StartingLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_starting_loadout.tres"
)
const RootCastScene: PackedScene = preload(
	"res://scenes/actions/life_root_cast.tscn"
)
const StatusReceiverScript = preload(
	"res://scripts/combat/status_receiver.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	validate_ability_contract()
	await validate_enemy_binding()
	await validate_rigid_body_binding()
	await validate_aim_contract()
	validate_mass_contract()
	_finish()


func validate_ability_contract() -> void:
	_expect(RootBindAbility != null, "Root Bind ability exists")
	if RootBindAbility == null:
		return
	_expect(RootBindAbility.element == "life", "Root Bind belongs to Life")
	_expect(RootBindAbility.get_spell_id() == "root_bind", "Root Bind spell id is stable")
	_expect(RootBindAbility.mana_cost == 2, "Root Bind has its utility-control cost")
	_expect(RootBindAbility.targeting_style == "aimed_target", "Root Bind declares aimed target delivery")
	for role: String in ["control", "root", "anchor", "utility"]:
		_expect(RootBindAbility.roles.has(role), "Root Bind declares " + role)
	_expect(StartingLoadout.knows_ability(RootBindAbility), "Grace learns Root Bind")


func validate_enemy_binding() -> void:
	var source := Node3D.new()
	source.name = "RootSource"
	add_child(source)
	var enemy := CharacterBody3D.new()
	enemy.name = "RootEnemy"
	enemy.add_to_group("enemy")
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	enemy.add_child(collision)
	var receiver: Node = StatusReceiverScript.new()
	receiver.name = "StatusReceiver"
	enemy.add_child(receiver)
	add_child(enemy)
	await get_tree().process_frame

	var cast: LifeRootCast = RootCastScene.instantiate() as LifeRootCast
	add_child(cast)
	cast.set_source_actor(source)
	_expect(cast.can_root_target(enemy), "enemy CharacterBody is rootable")
	_expect(cast.bind_target(enemy, 3.25), "Root Bind attaches to an enemy")
	_expect(bool(receiver.call("has_status", "rooted")), "enemy receives rooted status")
	_expect(absf(float(receiver.call("get_movement_multiplier"))) < 0.001, "rooted enemy cannot translate")
	_expect(not bool(receiver.call("blocks_actions")), "rooted enemy can still act")
	var binding: Node = enemy.get_node_or_null("LifeRootBinding")
	_expect(binding != null, "enemy owns one visible root binding")
	if binding != null and binding.has_method("get_debug_data"):
		var debug: Dictionary = binding.call("get_debug_data") as Dictionary
		_expect(bool(debug.get("bounds_driven_visual", false)), "enemy roots use measured target bounds")
	if binding != null and binding.has_method("release_binding"):
		binding.call("release_binding")
	_expect(not bool(receiver.call("has_status", "rooted")), "releasing roots restores enemy movement state")

	cast.queue_free()
	enemy.queue_free()
	source.queue_free()


func validate_rigid_body_binding() -> void:
	var source := Node3D.new()
	source.name = "RootUtilitySource"
	add_child(source)
	var crate := RigidBody3D.new()
	crate.name = "RootCrate"
	crate.mass = 45.0
	crate.linear_velocity = Vector3(5.0, 0.0, -2.0)
	crate.angular_velocity = Vector3(0.0, 3.0, 0.0)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.0, 2.0)
	collision.shape = box
	crate.add_child(collision)
	add_child(crate)
	await get_tree().physics_frame

	var cast: LifeRootCast = RootCastScene.instantiate() as LifeRootCast
	add_child(cast)
	cast.set_source_actor(source)
	_expect(cast.can_root_target(crate), "movable RigidBody is rootable")
	_expect(cast.bind_target(crate, 6.0), "Root Bind attaches to a utility object")
	_expect(crate.freeze, "rooted RigidBody is physically pinned")
	_expect(crate.linear_velocity.length() < 0.001, "rooted object loses translation velocity")
	_expect(crate.angular_velocity.length() < 0.001, "rooted object loses angular velocity")

	var first_binding: Node = crate.get_node_or_null("LifeRootBinding")
	_expect(first_binding != null, "utility object owns a root binding")
	if first_binding != null and first_binding.has_method("get_debug_data"):
		var debug: Dictionary = first_binding.call("get_debug_data") as Dictionary
		# A 2x2 cube has a horizontal corner radius of sqrt(2). The roots must sit
		# beyond that, not disappear inside the cube as the old height guess did.
		_expect(float(debug.get("visual_radius", 0.0)) > 1.45, "crate roots wrap outside the cube corners")
		_expect(float(debug.get("visual_base_y", 0.0)) < -0.9, "crate root crown starts at the measured bottom face")
	var visual_root: Node = first_binding.get_node_or_null("RootVisual") if first_binding != null else null
	_expect(visual_root != null, "crate root visual exists")
	if visual_root != null:
		_expect(visual_root.get_node_or_null("LowerBindingBand") != null, "crate gets a visible lower binding band")
		_expect(visual_root.get_node_or_null("UpperBindingBand") != null, "crate gets a visible upper binding band")

	_expect(cast.bind_target(crate, 8.0), "recasting refreshes an existing root binding")
	var binding_count: int = 0
	for child: Node in crate.get_children():
		if child.name == "LifeRootBinding":
			binding_count += 1
	_expect(binding_count == 1, "recasting does not stack duplicate binding controllers")

	if first_binding != null and first_binding.has_method("release_binding"):
		first_binding.call("release_binding")
	_expect(not crate.freeze, "utility object returns to normal physics after release")
	_expect(crate.linear_velocity.length() < 0.001, "released object resumes from rest instead of storing old momentum")

	cast.queue_free()
	crate.queue_free()
	source.queue_free()
	await get_tree().process_frame


func validate_aim_contract() -> void:
	var source := Node3D.new()
	source.name = "RootAimSource"
	add_child(source)
	var cast: LifeRootCast = RootCastScene.instantiate() as LifeRootCast
	add_child(cast)
	cast.set_source_actor(source)
	cast.require_line_of_sight = false

	var centered := RigidBody3D.new()
	centered.name = "CenteredRootObject"
	centered.mass = 5.0
	centered.position = Vector3(0.0, 0.0, -6.0)
	var centered_collision := CollisionShape3D.new()
	var centered_box := BoxShape3D.new()
	centered_box.size = Vector3.ONE
	centered_collision.shape = centered_box
	centered.add_child(centered_collision)
	add_child(centered)

	var side := RigidBody3D.new()
	side.name = "SideRootObject"
	side.mass = 5.0
	side.position = Vector3(5.0, 0.0, -6.0)
	var side_collision := CollisionShape3D.new()
	var side_box := BoxShape3D.new()
	side_box.size = Vector3.ONE
	side_collision.shape = side_box
	side.add_child(side_collision)
	add_child(side)
	await get_tree().physics_frame

	var aim_direction: Vector3 = (
		cast.get_target_point(centered) - cast.get_cast_origin()
	).normalized()
	_expect(
		bool(cast.call("_candidate_matches_aim", centered, aim_direction)),
		"object close to the crosshair qualifies for Root Bind aim assist"
	)
	_expect(
		not bool(cast.call("_candidate_matches_aim", side, aim_direction)),
		"off-axis nearby object is not selected merely because it is close"
	)

	side.queue_free()
	centered.queue_free()
	cast.queue_free()
	source.queue_free()
	await get_tree().process_frame


func validate_mass_contract() -> void:
	var source := Node3D.new()
	add_child(source)
	var cast: LifeRootCast = RootCastScene.instantiate() as LifeRootCast
	add_child(cast)
	cast.set_source_actor(source)
	var heavy := RigidBody3D.new()
	heavy.mass = cast.maximum_rigidbody_mass + 1.0
	add_child(heavy)
	_expect(not cast.can_root_target(heavy), "objects above the Root Bind mass ceiling resist")
	heavy.queue_free()
	cast.queue_free()
	source.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("ROOT_BIND_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ROOT_BIND_SMOKE_TEST: " + failure)
	get_tree().quit(1)
