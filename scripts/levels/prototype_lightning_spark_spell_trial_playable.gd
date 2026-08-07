extends "res://scripts/levels/prototype_lightning_spark_spell_trial.gd"
class_name PrototypeLightningSparkSpellTrialPlayable

var spark_listener_connected: bool = false
var incomplete_fan_reset_count: int = 0


func _ready() -> void:
	super._ready()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var callback := Callable(self, "_on_tree_node_added")
	if not tree.node_added.is_connected(callback):
		tree.node_added.connect(callback)
	spark_listener_connected = true


func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var callback := Callable(self, "_on_tree_node_added")
	if tree.node_added.is_connected(callback):
		tree.node_added.disconnect(callback)
	spark_listener_connected = false


func _on_tree_node_added(node: Node) -> void:
	# SceneTree.node_added fires before the new node's _ready method, so inspect
	# the attached script class rather than waiting for its runtime groups.
	if not node is LightningSparkBurst:
		return
	var callback := Callable(self, "_on_lightning_spark_fired")
	if not node.is_connected("spark_fired", callback):
		node.connect("spark_fired", callback, Object.CONNECT_ONE_SHOT)


func _on_lightning_spark_fired(_hit_count: int) -> void:
	if stage != TrialStage.FORKED_FAN:
		return
	if completed_fan_target_ids.size() >= fan_targets.size():
		return
	if completed_fan_target_ids.is_empty():
		return
	call_deferred("_reset_incomplete_fan_attempt")


func _reset_incomplete_fan_attempt() -> void:
	if stage != TrialStage.FORKED_FAN:
		return
	incomplete_fan_reset_count += 1
	completed_fan_target_ids.clear()
	for target: CombatTrainingTarget in fan_targets:
		if target != null and is_instance_valid(target):
			target.reset_target()
	_show_message(
		"The fork collapses. All three conductors must answer the same Lightning Spark."
	)


func _spawn_target(
	node_name: String,
	label: String,
	position_value: Vector3,
	health: int
) -> CombatTrainingTarget:
	var target: CombatTrainingTarget = super._spawn_target(
		node_name,
		label,
		position_value,
		health
	)
	# These are puzzle conductors, not combat enemies. The cone can still find
	# them through physics, while an already-unlocked Chain Lightning cannot use
	# them as secondary jumps and counterfeit the authored fan solution.
	if target.is_in_group("enemy"):
		target.remove_from_group("enemy")
	target.add_to_group("lightning_spark_trial_conductors")
	target.set_physics_process(false)
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null:
		hit_receiver.set("hit_mode", 2)
		hit_receiver.set("max_health", maxi(health, 1))
		hit_receiver.set("current_health", maxi(health, 1))
		hit_receiver.set("max_stance", 1)
		hit_receiver.set("current_stance", 1)
		hit_receiver.set("regenerates_stance", false)
		hit_receiver.set("disappears_when_defeated", false)
	return target


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["one_cast_fan_required"] = true
	data["incomplete_fan_resets"] = incomplete_fan_reset_count
	data["spark_listener"] = spark_listener_connected
	data["conductors_are_chain_targets"] = false
	return data
