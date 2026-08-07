extends "res://scripts/levels/prototype_lightning_spark_spell_trial.gd"
class_name PrototypeLightningSparkSpellTrialPlayable


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
