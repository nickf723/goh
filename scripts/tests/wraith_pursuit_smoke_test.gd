extends Node

const WraithAbility: AbilityDefinition = preload(
	"res://data/abilities/wraith_pursuit_ability.tres"
)
const WraithPayload: DamagePayload = preload(
	"res://data/damage_payloads/wraith_pursuit_payload.tres"
)
const StartingLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_starting_loadout.tres"
)
const ProjectileScene: PackedScene = preload(
	"res://scenes/actions/death_wraith_projectile.tscn"
)
const HitReceiverScript: Script = preload(
	"res://scripts/combat/hit_receiver.gd"
)
const VineTargeting = preload(
	"res://scripts/player/vine_grapple_targeting.gd"
)

class StaleLockSource:
	extends Node3D
	var lock_on_target: Node3D = null

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	validate_ability_contract()
	await validate_projectile_and_spirit_contract()
	await validate_freed_target_contract()
	await validate_vine_stale_reference_contract()
	_finish()


func validate_ability_contract() -> void:
	_expect(WraithAbility != null, "Wraith Pursuit ability exists")
	if WraithAbility == null:
		return
	_expect(WraithAbility.element == "death", "Wraith Pursuit belongs to Death")
	_expect(WraithAbility.get_spell_id() == "wraith_pursuit", "Wraith Pursuit id is stable")
	_expect(WraithAbility.mana_cost == 2, "Wraith Pursuit uses its authored mana cost")
	_expect(WraithAbility.get_delivery_type() == "projectile_spirit_pursuit", "Wraith Pursuit declares its two-stage delivery")
	for role: String in ["summon", "pursuit", "persistent_damage"]:
		_expect(WraithAbility.roles.has(role), "Wraith Pursuit declares " + role)
	_expect(StartingLoadout.knows_ability(WraithAbility), "Grace learns Wraith Pursuit")
	_expect(WraithPayload.amount == 1, "each wraith crossing deals light health damage")
	_expect(WraithPayload.stance_damage == 1, "each crossing also pressures stance")


func validate_projectile_and_spirit_contract() -> void:
	var source := Node3D.new()
	source.name = "WraithSource"
	add_child(source)
	var target := _make_health_target("WraithTarget", 20)
	add_child(target)
	await get_tree().process_frame

	var receiver: Node = target.get_node("HitReceiver")
	var projectile: DeathWraithProjectile = ProjectileScene.instantiate() as DeathWraithProjectile
	add_child(projectile)
	projectile.set_source_actor(source)
	projectile.set_payload(WraithPayload)
	projectile.global_position = Vector3(0.0, 0.8, 0.0)
	projectile.launch(Vector3.FORWARD)
	await get_tree().process_frame

	var health_before: int = int(receiver.get("current_health"))
	projectile.try_hit(target)
	_expect(
		int(receiver.get("current_health")) == health_before,
		"delivery projectile deals no direct contact damage"
	)
	await get_tree().process_frame

	var spirit: DeathPursuerSpirit = _get_first_spirit()
	_expect(spirit != null, "projectile contact creates a pursuing spirit")
	if spirit != null and is_instance_valid(spirit):
		var debug: Dictionary = spirit.get_debug_data()
		_expect(bool(debug.get("follows_target", false)), "spirit declares moving-target pursuit")
		_expect(bool(debug.get("damages_only_on_crossing", false)), "spirit damage is crossing-gated")
		_expect(int(debug.get("maximum_passes", 0)) == 4, "spirit makes four authored passes")

		spirit.call("_apply_pass_damage")
		_expect(
			int(receiver.get("current_health")) == health_before - WraithPayload.amount,
			"a spirit crossing delivers its Death payload"
		)
		_expect(
			str(receiver.get("last_payload_summary")).contains("Wraith Pursuit"),
			"receiver records Wraith Pursuit as the pass source"
		)

		var crossing_distance: float = float(
			spirit.call(
				"_segment_point_distance",
				Vector3(-2.0, 0.0, 0.0),
				Vector3(2.0, 0.0, 0.0),
				Vector3.ZERO
			)
		)
		_expect(crossing_distance <= 0.001, "fast dash segments detect passing through the target")

	if is_instance_valid(target):
		target.queue_free()
	if is_instance_valid(source):
		source.queue_free()
	await get_tree().process_frame
	if spirit != null and is_instance_valid(spirit):
		spirit.call("_process", 0.016)
		_expect(bool(spirit.get("dissolving")), "spirit dissolves when its victim disappears")
		spirit.queue_free()
	await get_tree().process_frame


func validate_freed_target_contract() -> void:
	var source := Node3D.new()
	add_child(source)
	var target := _make_health_target("ShortLivedWraithTarget", 3)
	add_child(target)
	var spirit_scene: PackedScene = preload("res://scenes/actions/death_pursuer_spirit.tscn")
	var spirit: DeathPursuerSpirit = spirit_scene.instantiate() as DeathPursuerSpirit
	add_child(spirit)
	await get_tree().process_frame
	_expect(spirit.configure(target, source, WraithPayload, Vector3.FORWARD), "spirit accepts a live target")
	target.queue_free()
	await get_tree().process_frame
	if is_instance_valid(spirit):
		spirit.call("_process", 0.016)
		_expect(bool(spirit.get("dissolving")), "freed targets are treated as lost instead of type-tested")
		spirit.queue_free()
	source.queue_free()
	await get_tree().process_frame


func validate_vine_stale_reference_contract() -> void:
	var source := StaleLockSource.new()
	source.name = "StaleVineSource"
	add_child(source)
	var target := CharacterBody3D.new()
	target.name = "FreedVineTarget"
	target.add_to_group("enemy")
	add_child(target)
	await get_tree().process_frame
	source.lock_on_target = target
	target.queue_free()
	await get_tree().process_frame

	var result: Dictionary = VineTargeting.resolve_target(
		source,
		22.0,
		180.0,
		20.0,
		false
	)
	_expect(
		not bool(result.get("valid", false)),
		"Vine target preview rejects a freed hard-lock reference without crashing"
	)
	source.queue_free()
	await get_tree().process_frame


func _make_health_target(target_name: String, health: int) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = target_name
	target.add_to_group("enemy")
	var receiver: Node = HitReceiverScript.new()
	receiver.name = "HitReceiver"
	receiver.set("hit_mode", 2)
	receiver.set("max_health", health)
	receiver.set("current_health", health)
	receiver.set("max_stance", 4)
	receiver.set("current_stance", 4)
	receiver.set("regenerates_stance", false)
	target.add_child(receiver)
	return target


func _get_first_spirit() -> DeathPursuerSpirit:
	for raw: Node in get_tree().get_nodes_in_group("death_pursuer_spirits"):
		if raw is DeathPursuerSpirit and is_instance_valid(raw):
			return raw as DeathPursuerSpirit
	return null


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("WRAITH_PURSUIT_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WRAITH_PURSUIT_SMOKE_TEST: " + failure)
	get_tree().quit(1)
