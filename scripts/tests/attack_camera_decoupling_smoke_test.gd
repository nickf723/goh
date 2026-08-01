extends Node3D

const PlayerScene = preload("res://scenes/actors/player/player.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var weapon: SafeWeaponController = (
		player.get_node_or_null("WeaponController") as SafeWeaponController
	)
	var visual: Node3D = player.get_node_or_null("GraceVisualV1") as Node3D
	var camera: Camera3D = player.get_node_or_null(
		"CameraPivot/SpringArm3D/Camera3D"
	) as Camera3D
	assert_true(weapon != null, "player installs SafeWeaponController")
	assert_true(visual != null, "player installs Grace visual")
	assert_true(camera != null, "player installs camera")
	if weapon == null or visual == null or camera == null:
		_finish()
		return

	player.rotation.y = 0.0
	visual.rotation.y = 0.0
	weapon.rotation.y = 0.0
	var actor_yaw_before: float = player.rotation.y
	var camera_forward_before: Vector3 = -camera.global_transform.basis.z

	weapon.apply_attack_facing(Vector3.RIGHT)
	var camera_forward_after: Vector3 = -camera.global_transform.basis.z
	assert_near(player.rotation.y, actor_yaw_before, 0.0001, "attack facing does not rotate CharacterBody")
	assert_true(
		camera_forward_before.normalized().dot(camera_forward_after.normalized()) > 0.9999,
		"attack facing leaves camera world yaw unchanged"
	)
	assert_true(absf(visual.rotation.y) > 0.05, "Grace presentation turns toward attack")
	assert_true(absf(weapon.rotation.y) > 0.05, "weapon presentation turns with Grace")
	assert_near(visual.rotation.y, weapon.rotation.y, 0.001, "body and weapon share visual attack yaw")

	weapon.reset_attack_facing_visual(true)
	assert_near(visual.rotation.y, 0.0, 0.0001, "Grace visual returns to neutral")
	assert_near(weapon.rotation.y, 0.0, 0.0001, "weapon visual returns to neutral")
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("ATTACK_CAMERA_DECOUPLING_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ATTACK_CAMERA_DECOUPLING_SMOKE_TEST: " + failure)
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
