extends Node

const DeathHexAbility: AbilityDefinition = preload(
	"res://data/abilities/death_hex_ability.tres"
)
const DeathHexPayload: DamagePayload = preload(
	"res://data/damage_payloads/death_hex_payload.tres"
)
const StartingLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_starting_loadout.tres"
)
const ProjectileScene: PackedScene = preload(
	"res://scenes/actions/death_hex_projectile.tscn"
)
const HitReceiverScript: Script = preload(
	"res://scripts/combat/hit_receiver.gd"
)
const StatusReceiverScript: Script = preload(
	"res://scripts/combat/status_receiver.gd"
)
const StatePolicy = preload(
	"res://scripts/systems/reaction_state_policy.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	validate_ability_contract()
	await validate_curse_delivery_and_decay()
	await validate_recast_refresh_contract()
	_finish()


func validate_ability_contract() -> void:
	_expect(DeathHexAbility != null, "Death Hex ability exists")
	if DeathHexAbility == null:
		return
	_expect(DeathHexAbility.element == "death", "Death Hex belongs to Death")
	_expect(DeathHexAbility.get_spell_id() == "death_hex", "Death Hex keeps its stable spell id")
	_expect(DeathHexAbility.mana_cost == 1, "Death Hex remains a cheap curse")
	_expect(DeathHexAbility.get_delivery_type() == "projectile", "Death Hex remains aimed projectile delivery")
	_expect(DeathHexAbility.status_tags.has("hexed"), "Death Hex exposes the reusable hexed state")
	_expect(not DeathHexAbility.status_tags.has("poisoned"), "Death Hex no longer masquerades as Poison")
	_expect(StartingLoadout.knows_ability(DeathHexAbility), "Grace still knows Death Hex")
	_expect(StatePolicy.get_state_element("hexed") == "death", "hexed is registered as a Death state")
	_expect(DeathHexPayload.status_effect == "", "Death Hex payload no longer applies generic poison")
	_expect(DeathHexPayload.tags.has("health_decay"), "Death Hex payload declares health decay")


func validate_curse_delivery_and_decay() -> void:
	var source := Node3D.new()
	source.name = "DeathHexSource"
	add_child(source)
	var target := _make_target("DeathHexTarget", 24, 5)
	add_child(target)
	await get_tree().process_frame

	var hit_receiver: Node = target.get_node("HitReceiver")
	var status_receiver: Node = target.get_node("StatusReceiver")
	var health_before: int = int(hit_receiver.get("current_health"))
	var stance_before: int = int(hit_receiver.get("current_stance"))

	var projectile: DeathHexProjectile = ProjectileScene.instantiate() as DeathHexProjectile
	add_child(projectile)
	projectile.set_source_actor(source)
	projectile.set_payload(DeathHexPayload)
	projectile.launch(Vector3.FORWARD)
	projectile.try_hit(target)
	await get_tree().process_frame

	_expect(int(hit_receiver.get("current_health")) == health_before, "delivery projectile deals no direct damage")
	var curse: Node = target.get_node_or_null("DeathHexCurse")
	_expect(curse != null, "projectile attaches one Death Hex curse controller")
	_expect(bool(status_receiver.call("has_status", "hexed")), "target exposes the hexed combat state")
	if curse != null:
		_expect(curse.get("visual_root") != null, "Death Hex creates a visible target-bound sigil")
		_expect(curse.call("get_damage_for_pulse", 0) == 1, "first pulse is weak")
		_expect(curse.call("get_damage_for_pulse", 2) == 2, "middle decay pulse strengthens")
		_expect(curse.call("get_damage_for_pulse", 4) == 3, "late decay pulse is strongest")

		curse.call("_apply_decay_pulse")
		_expect(int(hit_receiver.get("current_health")) == health_before - 1, "first pulse drains health")
		_expect(int(hit_receiver.get("current_stance")) == stance_before, "Death Hex bypasses stance instead of damaging it")
		curse.call("_apply_decay_pulse")
		curse.call("_apply_decay_pulse")
		_expect(int(hit_receiver.get("current_health")) == health_before - 4, "damage escalates across the first three pulses")
		_expect(int(curse.get("pulse_index")) == 3, "curse tracks decay progression")

	if curse != null and curse.has_method("release_hex"):
		curse.call("release_hex", false)
	await get_tree().process_frame
	_expect(not bool(status_receiver.call("has_status", "hexed")), "ending the curse removes hexed state")
	target.queue_free()
	source.queue_free()
	await get_tree().process_frame


func validate_recast_refresh_contract() -> void:
	var source := Node3D.new()
	add_child(source)
	var target := _make_target("RefreshHexTarget", 30, 4)
	add_child(target)
	await get_tree().process_frame

	var first: DeathHexProjectile = ProjectileScene.instantiate() as DeathHexProjectile
	add_child(first)
	first.set_source_actor(source)
	first.set_payload(DeathHexPayload)
	first.try_hit(target)
	await get_tree().process_frame
	var curse: Node = target.get_node_or_null("DeathHexCurse")
	_expect(curse != null, "first cast creates a curse")
	if curse == null:
		target.queue_free()
		source.queue_free()
		return

	curse.call("_apply_decay_pulse")
	curse.call("_apply_decay_pulse")
	var stage_before: int = int(curse.get("pulse_index"))
	curse.set("remaining", 0.8)

	var second: DeathHexProjectile = ProjectileScene.instantiate() as DeathHexProjectile
	add_child(second)
	second.set_source_actor(source)
	second.set_payload(DeathHexPayload)
	second.try_hit(target)
	await get_tree().process_frame

	var curse_count: int = 0
	for child: Node in target.get_children():
		if child.name == "DeathHexCurse":
			curse_count += 1
	_expect(curse_count == 1, "recasting refreshes one curse instead of stacking duplicates")
	_expect(int(curse.get("pulse_index")) == stage_before, "recasting preserves the curse's current decay stage")
	_expect(float(curse.get("remaining")) > 6.0, "recasting restores the curse duration")

	curse.call("release_hex", false)
	target.queue_free()
	source.queue_free()
	await get_tree().process_frame


func _make_target(target_name: String, health: int, stance: int) -> CharacterBody3D:
	var target := CharacterBody3D.new()
	target.name = target_name
	target.add_to_group("enemy")

	var hit_receiver: Node = HitReceiverScript.new()
	hit_receiver.name = "HitReceiver"
	hit_receiver.set("hit_mode", 3)
	hit_receiver.set("max_health", health)
	hit_receiver.set("current_health", health)
	hit_receiver.set("max_stance", stance)
	hit_receiver.set("current_stance", stance)
	hit_receiver.set("regenerates_stance", false)
	target.add_child(hit_receiver)

	var status_receiver: Node = StatusReceiverScript.new()
	status_receiver.name = "StatusReceiver"
	target.add_child(status_receiver)
	return target


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("DEATH_HEX_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("DEATH_HEX_SMOKE_TEST: " + failure)
	get_tree().quit(1)
