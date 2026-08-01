extends Node3D

const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const TrainingDummyScene: PackedScene = preload(
	"res://scenes/actors/interactables/training_dummy.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	var dummy: Area3D = TrainingDummyScene.instantiate() as Area3D
	add_child(player)
	add_child(dummy)
	player.position = Vector3(0.0, 0.96, 5.0)
	dummy.position = Vector3(0.0, 0.7, -5.0)
	await get_tree().process_frame
	await get_tree().physics_frame

	var caster: Node = player.get_node_or_null("AbilityCaster")
	assert_true(caster != null, "player owns an AbilityCaster")
	if caster == null:
		finish_tests()
		return

	caster.call("select_ability", 2, false)
	player.call("set_lock_on_target", dummy)
	await get_tree().process_frame

	var hand_anchor: Node3D = player.get_node_or_null(
		"GraceVisualV1/RightHandAnchor"
	) as Node3D
	var cast_origin: Vector3 = caster.call("get_player_cast_origin", player)
	assert_true(hand_anchor != null, "Grace exposes a right-hand cast anchor")
	if hand_anchor != null:
		assert_near(
			cast_origin.distance_to(hand_anchor.global_position),
			0.0,
			0.01,
			"targeted projectile origin matches the animated hand"
		)

	var cast_direction: Vector3 = caster.call(
		"get_cast_direction",
		player,
		cast_origin
	)
	assert_true(cast_direction.z < -0.8, "targeted projectile points toward the dummy")
	assert_true(
		cast_direction.y > -0.01,
		"targeted projectile does not begin a downward dive"
	)

	var ability: AbilityDefinition = caster.call("get_current_ability") as AbilityDefinition
	assert_true(ability != null, "Firebolt is selected for the regression")
	if ability != null:
		var cast_succeeded: bool = bool(
			caster.call(
				"execute_ability_from_player",
				player,
				ability,
				0.01
			)
		)
		assert_true(cast_succeeded, "targeted Firebolt casts successfully")
		await get_tree().process_frame
		var projectile: GenericProjectile = _find_projectile()
		assert_true(projectile != null, "targeted cast creates a GenericProjectile")
		if projectile != null:
			assert_true(
				projectile.motion_velocity.z < -1.0,
				"projectile velocity remains forward"
			)
			assert_true(
				projectile.motion_velocity.y > -0.2,
				"projectile velocity does not immediately descend"
			)

	finish_tests()


func _find_projectile() -> GenericProjectile:
	for child: Node in get_children():
		if child is GenericProjectile:
			return child as GenericProjectile
	return null


func finish_tests() -> void:
	if failures.is_empty():
		print("TARGETED_PROJECTILE_HAND_ORIGIN_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("TARGETED_PROJECTILE_HAND_ORIGIN_SMOKE_TEST: " + failure)
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
			label
			+ " (expected "
			+ str(expected)
			+ ", got "
			+ str(actual)
			+ ")"
		)
