extends Node3D

const AbilityCasterScript = preload(
	"res://scripts/abilities/ability_caster_player_channels.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var player: CharacterBody3D = CharacterBody3D.new()
	player.name = "TestPlayer"
	add_child(player)

	var player_shape: CollisionShape3D = CollisionShape3D.new()
	var player_capsule: CapsuleShape3D = CapsuleShape3D.new()
	player_capsule.radius = 0.45
	player_capsule.height = 1.9
	player_shape.shape = player_capsule
	player.add_child(player_shape)

	# Reproduce Grace's large child InteractionArea. Without recursive RID
	# exclusion, the camera ray enters this sphere behind the cast origin and the
	# projectile launches upward/backward toward Grace herself.
	var interaction_area: Area3D = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 1
	interaction_area.collision_mask = 1
	player.add_child(interaction_area)
	var interaction_shape: CollisionShape3D = CollisionShape3D.new()
	var interaction_sphere: SphereShape3D = SphereShape3D.new()
	interaction_sphere.radius = 2.0
	interaction_shape.shape = interaction_sphere
	interaction_area.add_child(interaction_shape)

	var caster: Node3D = AbilityCasterScript.new()
	caster.name = "AbilityCaster"
	player.add_child(caster)

	var target: StaticBody3D = StaticBody3D.new()
	target.name = "ForwardTarget"
	target.position = Vector3(0.0, 1.2, -8.0)
	target.collision_layer = 1
	add_child(target)
	var target_shape: CollisionShape3D = CollisionShape3D.new()
	var target_box: BoxShape3D = BoxShape3D.new()
	target_box.size = Vector3(2.0, 2.0, 1.0)
	target_shape.shape = target_box
	target.add_child(target_shape)

	var camera: Camera3D = Camera3D.new()
	camera.name = "TestCamera"
	camera.position = Vector3(0.0, 1.2, 5.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.2, -10.0), Vector3.UP)
	camera.current = true

	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var cast_origin := Vector3(0.0, 1.2, 0.0)
	var direction_value: Variant = caster.call(
		"_get_camera_converged_cast_direction",
		player,
		cast_origin
	)
	var direction: Vector3 = (
		direction_value as Vector3
		if direction_value is Vector3
		else Vector3.ZERO
	)
	assert_true(direction.z < -0.8, "camera convergence points forward, not behind Grace")
	assert_true(absf(direction.x) < 0.08, "camera convergence stays centered horizontally")
	assert_true(absf(direction.y) < 0.12, "level camera target does not launch skyward")
	assert_near(direction.length(), 1.0, 0.001, "caster direction is normalized")

	var exclusions_value: Variant = caster.call(
		"_get_player_collision_exclusions",
		player
	)
	var exclusions: Array = exclusions_value as Array if exclusions_value is Array else []
	assert_true(exclusions.has(player.get_rid()), "player body RID is excluded")
	assert_true(exclusions.has(interaction_area.get_rid()), "child InteractionArea RID is excluded")

	if failures.is_empty():
		print("ABILITY_CASTER_SELF_EXCLUSION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ABILITY_CASTER_SELF_EXCLUSION_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_near(
	actual: float,
	expected: float,
	tolerance: float,
	label: String
) -> void:
	if absf(actual - expected) > tolerance:
		failures.append(
			label + " (expected " + str(expected) + ", got " + str(actual) + ")"
		)
