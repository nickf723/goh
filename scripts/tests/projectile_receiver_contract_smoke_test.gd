extends Node3D

const ProjectileScene: PackedScene = preload(
	"res://scenes/actions/generic_projectile.tscn"
)
const Catalog = preload(
	"res://scripts/objects/recorded_object_catalog.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	HitStop.force_release()
	Engine.time_scale = 1.0

	var barrel := RecordedObjectInstanceSafe.new()
	barrel.name = "VoidReturningBlastBarrel"
	add_child(barrel)
	barrel.configure(Catalog.get_definition("blast_barrel"))
	barrel.global_position = Vector3(0.0, 1.0, 0.0)

	var projectile_node: Node = ProjectileScene.instantiate()
	assert_true(
		projectile_node is GenericProjectileSafe,
		"live projectile scene uses the normalized dispatcher"
	)
	if not projectile_node is GenericProjectileSafe:
		_finish()
		return
	var projectile := projectile_node as GenericProjectileSafe
	projectile.name = "VoidReceiverContractProjectile"
	add_child(projectile)
	projectile.global_position = barrel.global_position

	var fire := DamagePayload.new()
	fire.element = "fire"
	fire.amount = 4
	fire.stance_damage = 4
	fire.status_strength = 1.0
	fire.source_name = "Charged Firebolt"
	fire.hit_type = "projectile"
	fire.tags = [
		"magic",
		"projectile",
		"fire",
		"firebolt",
		"charged",
		"heavy_impact",
		"ignite",
	]
	projectile.set_payload(fire)
	projectile.try_hit(barrel)

	var result: Dictionary = projectile.last_payload_result
	assert_true(
		not result.is_empty(),
		"projectile stores a normalized receiver result"
	)
	assert_true(
		bool(result.get("handled", false)),
		"void-returning environmental receiver is treated as handled"
	)
	assert_equal(
		str(result.get("receiver_return_type", "")),
		"Nil",
		"void receiver return is normalized instead of returned as Dictionary"
	)
	assert_equal(
		str(result.get("message", "unexpected")),
		"",
		"void receiver does not create false combat text"
	)

	var process_frames: int = 0
	for _index: int in range(18):
		await get_tree().process_frame
		process_frames += 1
		await get_tree().physics_frame
	assert_equal(
		process_frames,
		18,
		"frames continue after the live void-receiver projectile hit"
	)
	assert_true(
		not bool(HitStop.get_debug_data().get("active", true)),
		"charged impact HitStop releases"
	)
	assert_true(
		is_equal_approx(Engine.time_scale, 1.0),
		"global time returns to normal"
	)
	assert_true(
		barrel == null
		or not is_instance_valid(barrel)
		or barrel.is_queued_for_deletion(),
		"barrel detonation still completes"
	)

	HitStop.force_release()
	Engine.time_scale = 1.0
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PROJECTILE_RECEIVER_CONTRACT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PROJECTILE_RECEIVER_CONTRACT_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_true(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		failures.append(
			label
			+ " (expected "
			+ str(expected)
			+ ", got "
			+ str(actual)
			+ ")"
		)
