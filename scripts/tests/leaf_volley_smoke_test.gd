extends Node

const LeafVolleyAbility: AbilityDefinition = preload(
	"res://data/abilities/leaf_volley_ability.tres"
)
const StartingLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_starting_loadout.tres"
)
const VolleyScene: PackedScene = preload(
	"res://scenes/actions/life_leaf_volley.tscn"
)
const LeafScene: PackedScene = preload(
	"res://scenes/actions/life_leaf_projectile.tscn"
)
const PlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player.tscn"
)
const StatusReceiverScript = preload(
	"res://scripts/combat/status_receiver.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	validate_ability_contract()
	validate_volley_contract()
	await validate_wake_homing()
	await validate_leaf_pelt()
	validate_deterioration_palette()
	await validate_freed_lock_target_safety()
	_finish()


func validate_ability_contract() -> void:
	_expect(LeafVolleyAbility != null, "Leaf Volley ability resource exists")
	if LeafVolleyAbility == null:
		return
	_expect(LeafVolleyAbility.element == "life", "Leaf Volley belongs to Life")
	_expect(LeafVolleyAbility.get_spell_id() == "leaf_volley", "Leaf Volley spell id is stable")
	_expect(LeafVolleyAbility.mana_cost == 1, "Leaf Volley remains a cheap nuisance spell")
	for role: String in ["chip", "harassment", "homing", "slow"]:
		_expect(LeafVolleyAbility.roles.has(role), "Leaf Volley declares " + role)
	_expect(StartingLoadout.knows_ability(LeafVolleyAbility), "Grace learns Leaf Volley in Focus")


func validate_volley_contract() -> void:
	var volley: LifeLeafVolley = VolleyScene.instantiate() as LifeLeafVolley
	add_child(volley)
	_expect(volley != null, "Leaf Volley scene instantiates")
	if volley != null:
		_expect(volley.projectiles_per_cast == 3, "one cast releases exactly three leaves")
		_expect(volley.burst_interval > 0.05 and volley.burst_interval < 0.2, "leaves launch as a quick staggered burst")
	volley.queue_free()


func validate_wake_homing() -> void:
	var source := Node3D.new()
	source.name = "LeafSource"
	add_child(source)
	var target := CharacterBody3D.new()
	target.name = "MovingTarget"
	target.position = Vector3(4.0, 0.0, -8.0)
	target.velocity = Vector3(3.0, 0.0, 0.0)
	add_child(target)
	var leaf: LifeLeafProjectile = LeafScene.instantiate() as LifeLeafProjectile
	add_child(leaf)
	await get_tree().process_frame
	leaf.set_source_actor(source)
	leaf.set_homing_target(target)
	leaf.launch(Vector3(0.0, 0.0, -1.0))
	leaf.update_airflow_motion(0.1)
	_expect(leaf.motion_velocity.x > 0.05, "leaf bends toward a moving off-axis target")
	_expect(leaf.last_target_wake_velocity.is_equal_approx(target.velocity), "leaf samples the target movement wake")
	leaf.queue_free()
	target.queue_free()
	source.queue_free()


func validate_leaf_pelt() -> void:
	var target := CharacterBody3D.new()
	target.name = "PeltTarget"
	var receiver: Node = StatusReceiverScript.new()
	receiver.name = "StatusReceiver"
	target.add_child(receiver)
	add_child(target)
	var leaf: LifeLeafProjectile = LeafScene.instantiate() as LifeLeafProjectile
	add_child(leaf)
	await get_tree().process_frame
	for _hit: int in range(3):
		leaf.apply_leaf_pelt_to_target(target)
	_expect(bool(receiver.call("has_status", "leaf_pelted")), "leaf impacts create Leaf Pelt")
	var movement_multiplier: float = float(receiver.call("get_movement_multiplier"))
	_expect(movement_multiplier < 1.0, "Leaf Pelt barely reduces movement")
	_expect(movement_multiplier >= 0.97, "Leaf Pelt never becomes a true slow")
	_expect(absf(movement_multiplier - leaf.minimum_pelt_multiplier) < 0.002, "three leaves reach the authored nuisance cap")
	leaf.queue_free()
	target.queue_free()


func validate_deterioration_palette() -> void:
	var leaf: LifeLeafProjectile = LeafScene.instantiate() as LifeLeafProjectile
	add_child(leaf)
	var fresh: Color = leaf.get_leaf_age_color(0.1)
	var old: Color = leaf.get_leaf_age_color(0.9)
	_expect(fresh.g > fresh.r, "fresh leaves read green")
	_expect(old.r > old.g, "old leaves turn amber-orange before crumbling")
	leaf.queue_free()


func validate_freed_lock_target_safety() -> void:
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	player.name = "LeafFreedTargetPlayer"
	add_child(player)
	for _frame: int in range(4):
		await get_tree().process_frame

	var target := CharacterBody3D.new()
	target.name = "DisposableLeafTarget"
	target.add_to_group("enemy")
	add_child(target)
	player.set("lock_on_target", target)
	var assist: Node = player.get_node_or_null("CombatTargetingAssist")
	if assist != null and assist.has_method("set_hard_target"):
		assist.call("set_hard_target", target)

	# Free immediately, before Player._process has a chance to clear its stale
	# lock reference. This reproduces the real kill-and-recast crash window.
	target.free()
	var volley: LifeLeafVolley = VolleyScene.instantiate() as LifeLeafVolley
	add_child(volley)
	volley.set_source_actor(player)
	var resolved: Node3D = volley.call("_get_hard_target") as Node3D
	_expect(resolved == null, "freed hard-lock target safely collapses to no target")
	var acquired: Array[Node3D] = volley.acquire_volley_targets()
	_expect(acquired.is_empty(), "Leaf Volley can reacquire after a target dies without touching freed memory")
	volley.queue_free()
	player.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("LEAF_VOLLEY_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LEAF_VOLLEY_SMOKE_TEST: " + failure)
	get_tree().quit(1)
