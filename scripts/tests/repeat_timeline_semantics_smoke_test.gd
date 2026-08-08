extends Node3D

const Semantics = preload(
	"res://scripts/abilities/spell_clone_semantics.gd"
)
const TrajectoryEchoScript = preload(
	"res://scripts/time/repeat_trajectory_echo.gd"
)
const BoulderAbility: AbilityDefinition = preload(
	"res://data/abilities/boulder_ability.tres"
)
const FireboltAbility: AbilityDefinition = preload(
	"res://data/abilities/firebolt_ability.tres"
)
const RainAbility: AbilityDefinition = preload(
	"res://data/abilities/rain_weather_ability.tres"
)
const BubbleAbility: AbilityDefinition = preload(
	"res://data/abilities/bubble_ability.tres"
)
const AsteroidAbility: AbilityDefinition = preload(
	"res://data/abilities/asteroid_belt_ability.tres"
)
const WaterJetAbility: AbilityDefinition = preload(
	"res://data/abilities/water_jet_ability.tres"
)
const FirewallAbility: AbilityDefinition = preload(
	"res://data/abilities/firewall_ability.tres"
)
const GrowAbility: AbilityDefinition = preload(
	"res://data/abilities/grow_ability.tres"
)
const SurfAbility: AbilityDefinition = preload(
	"res://data/abilities/surf_ability.tres"
)
const FamiliarAbility: AbilityDefinition = preload(
	"res://data/abilities/spectral_familiar_ability.tres"
)

var failures: Array[String] = []

class TimelineTarget:
	extends StaticBody3D
	var received_hits: int = 0
	var last_payload: DamagePayload = null

	func receive_damage_payload(payload: DamagePayload) -> Dictionary:
		received_hits += 1
		last_payload = payload.duplicate(true) as DamagePayload
		return {"received": true, "damage": payload.amount}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_test_semantic_table()
	await _test_recorded_trajectory_interaction()
	_finish()


func _test_semantic_table() -> void:
	_expect(
		Semantics.get_repeat_mode(BoulderAbility) == Semantics.REPEAT_TRAJECTORY,
		"Repeat treats Boulder as a prerecorded trajectory"
	)
	_expect(
		Semantics.get_repeat_mode(FireboltAbility) == Semantics.REPEAT_TRAJECTORY,
		"Repeat treats ordinary projectiles as prerecorded trajectories"
	)
	_expect(
		Semantics.get_repeat_mode(WaterJetAbility) == Semantics.REPEAT_CHANNEL,
		"Repeat records Water Jet aim and duration"
	)
	_expect(
		Semantics.get_repeat_mode(FirewallAbility) == Semantics.REPEAT_CHANNEL,
		"Repeat records Firewall's drawn path and eruption timeline"
	)
	_expect(
		Semantics.get_repeat_mode(BubbleAbility) == Semantics.REPEAT_SOURCE_STATE,
		"Repeat handles Bubble as delayed source state with timed pop events"
	)
	_expect(
		Semantics.get_repeat_mode(AsteroidAbility) == Semantics.REPEAT_RECAST,
		"Repeat reenacts Asteroid Belt around the delayed Grace echo"
	)
	_expect(
		Semantics.get_repeat_mode(GrowAbility) == Semantics.REPEAT_SOURCE_STATE
		and Semantics.get_repeat_mode(SurfAbility) == Semantics.REPEAT_SOURCE_STATE,
		"transformations and traversal inherit the recorded Grace timeline"
	)
	_expect(
		Semantics.get_repeat_mode(RainAbility) == Semantics.REPEAT_WORLD_STATE,
		"weather intentionally performs no second world-state cast"
	)
	_expect(
		Semantics.get_repeat_mode(FamiliarAbility) == Semantics.REPEAT_SUPPRESS,
		"summon ownership remains suppressed"
	)
	_expect(
		Semantics.get_duplicate_mode(BoulderAbility) == Semantics.DUPLICATE_LIVE,
		"Soul Duplicate would launch a second live Boulder simulation"
	)
	_expect(
		Semantics.get_duplicate_mode(GrowAbility) == Semantics.DUPLICATE_SOURCE_STATE,
		"Soul Duplicate owns its own live Grow state"
	)
	_expect(
		Semantics.get_duplicate_mode(RainAbility) == Semantics.DUPLICATE_WORLD_STATE,
		"Soul Duplicate also no-ops global weather"
	)
	_expect(
		Semantics.get_duplicate_mode(FamiliarAbility) == Semantics.DUPLICATE_SUPPRESS,
		"Soul Duplicate does not duplicate summon ownership"
	)


func _test_recorded_trajectory_interaction() -> void:
	var proxy := Node3D.new()
	proxy.name = "TimelineProxy"
	add_child(proxy)

	var target := TimelineTarget.new()
	target.name = "NewTargetInRememberedPath"
	target.position = Vector3(2.0, 0.0, 1.0)
	target.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.42
	collision.shape = shape
	target.add_child(collision)
	add_child(target)

	var echo := TrajectoryEchoScript.new() as RepeatTrajectoryEcho
	add_child(echo)
	echo.configure(
		BoulderAbility,
		proxy,
		BoulderAbility.get_action_payload()
	)
	# The first real Boulder could have hit an enemy at (2,0,0), been deflected,
	# and then continued north. Repeat must preserve that bend even though the
	# original enemy is absent. A new target standing on the remembered north leg
	# may be hit, but cannot straighten or redirect the memory.
	echo.advance_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)), 0.1)
	echo.advance_to(Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, 0.0)), 0.1)
	echo.advance_to(Transform3D(Basis.IDENTITY, Vector3(2.0, 0.0, 2.0)), 0.1)
	await get_tree().physics_frame

	_expect(
		target.received_hits >= 1,
		"a new body intersecting the remembered Boulder path can be hit"
	)
	_expect(
		echo.global_position.is_equal_approx(Vector3(2.0, 0.0, 2.0)),
		"new collisions never redirect the prerecorded Boulder endpoint"
	)
	_expect(
		bool(echo.get_debug_data().get("collisions_cannot_redirect_replay", false)),
		"trajectory echo reports timeline authority over collision response"
	)
	if target.last_payload != null:
		_expect(
			target.last_payload.tags.has("timeline_replay")
		and target.last_payload.tags.has("repeat"),
			"new interactions are marked as delayed Repeat effects"
		)
	else:
		_expect(false, "new trajectory target received a Repeat payload")

	echo.finish_replay()
	target.queue_free()
	proxy.queue_free()
	await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("REPEAT_TIMELINE_SEMANTICS_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("REPEAT_TIMELINE_SEMANTICS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("REPEAT_TIMELINE_SEMANTICS_SMOKE_TEST: " + failure)
	get_tree().quit(1)
