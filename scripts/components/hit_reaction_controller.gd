extends Node
class_name HitReactionController

signal reaction_resolved(data: Dictionary)

@export var maximum_poise: float = 8.0
@export var mass_scale: float = 1.0
@export_range(0.0, 1.0, 0.05) var armor: float = 0.0
@export var super_armor: bool = false
@export var allows_launch: bool = true
@export var poise_recovery_per_second: float = 3.5
@export var resistance_gain_per_interrupt: float = 0.24
@export var resistance_decay_delay: float = 1.0
@export var resistance_decay_per_second: float = 0.32

var current_poise: float
var reaction_resistance: float = 0.0
var time_since_impact: float = 99.0
var last_reaction: String = "READY"
var consecutive_interrupts: int = 0


func _ready() -> void:
	reset_reactions()


func _process(delta: float) -> void:
	time_since_impact += maxf(delta, 0.0)
	if time_since_impact >= resistance_decay_delay:
		reaction_resistance = maxf(
			reaction_resistance - resistance_decay_per_second * delta,
			0.0
		)
		if reaction_resistance <= 0.01:
			consecutive_interrupts = 0
	current_poise = minf(current_poise + poise_recovery_per_second * delta, maximum_poise)


func configure(profile: Dictionary) -> void:
	maximum_poise = float(profile.get("poise", maximum_poise))
	mass_scale = maxf(float(profile.get("mass", mass_scale)), 0.2)
	armor = clampf(float(profile.get("armor", armor)), 0.0, 0.9)
	super_armor = bool(profile.get("super_armor", super_armor))
	allows_launch = bool(profile.get("allows_launch", allows_launch))
	poise_recovery_per_second = float(profile.get("poise_recovery", poise_recovery_per_second))
	resistance_gain_per_interrupt = float(profile.get("resistance_gain", resistance_gain_per_interrupt))
	reset_reactions()


func resolve_impact(payload: DamagePayload, direction: Vector3, attack: WeaponAttackDefinition = null) -> Dictionary:
	if payload == null:
		return {}
	time_since_impact = 0.0
	var tags: Array[String] = []
	for tag: String in payload.tags:
		tags.append(tag)
	var heavy: bool = tags.has("heavy") or tags.has("finisher")
	if attack != null:
		heavy = heavy or attack.input_kind == "heavy" or attack.damage_multiplier >= 1.5
	var guard_break: bool = tags.has("guard_break")
	var launcher: bool = tags.has("launcher")
	var raw_impact: float = float(payload.stance_damage) + float(payload.amount) * 0.45
	raw_impact += payload.knockback_strength * 0.35
	if heavy:
		raw_impact += 3.0
	if guard_break:
		raw_impact += 5.0
	if launcher:
		raw_impact += 3.5

	var effective_armor: float = 0.0 if guard_break else armor
	var effective_impact: float = raw_impact * (1.0 - effective_armor)
	effective_impact /= maxf(mass_scale, 0.2)
	effective_impact *= 1.0 - reaction_resistance * 0.72
	current_poise = maxf(current_poise - effective_impact, 0.0)

	var reaction: String = "RESIST"
	var duration: float = 0.1
	var displacement: float = 0.0
	var lift: float = 0.0
	var interrupts: bool = false

	if super_armor:
		reaction = "SUPER ARMOR"
	elif reaction_resistance >= 0.86 and not guard_break:
		reaction = "ADAPTED"
	elif guard_break:
		reaction = "GUARD BREAK"
		duration = 0.72
		displacement = 2.4
		interrupts = true
	elif launcher and allows_launch and effective_impact >= 4.0:
		reaction = "LAUNCH"
		duration = 0.72
		displacement = 3.2
		lift = 6.0
		interrupts = true
	elif current_poise <= 0.0 or effective_impact >= 9.0:
		reaction = "STAGGER"
		duration = 0.52
		displacement = 2.0
		interrupts = true
	elif effective_impact >= 2.0:
		reaction = "FLINCH"
		duration = 0.2
		displacement = 0.75
		interrupts = true

	if interrupts:
		consecutive_interrupts += 1
		reaction_resistance = minf(
			reaction_resistance + resistance_gain_per_interrupt,
			1.0
		)
	else:
		consecutive_interrupts = maxi(consecutive_interrupts - 1, 0)

	var horizontal := direction
	horizontal.y = 0.0
	if horizontal.length_squared() <= 0.001:
		horizontal = Vector3.BACK
	var motion: Vector3 = horizontal.normalized() * displacement
	motion.y = lift
	last_reaction = reaction
	var result := {
		"reaction": reaction,
		"duration": duration,
		"velocity": motion,
		"interrupts": interrupts,
		"impact": snappedf(effective_impact, 0.1),
		"poise": snappedf(current_poise, 0.1),
		"resistance": snappedf(reaction_resistance, 0.01),
	}
	reaction_resolved.emit(result)
	return result


func reset_reactions() -> void:
	current_poise = maximum_poise
	reaction_resistance = 0.0
	time_since_impact = 99.0
	last_reaction = "READY"
	consecutive_interrupts = 0


func get_debug_data() -> Dictionary:
	return {
		"reaction": last_reaction,
		"poise": snappedf(current_poise, 0.1),
		"max_poise": snappedf(maximum_poise, 0.1),
		"resistance": snappedf(reaction_resistance, 0.01),
		"interrupts": consecutive_interrupts,
		"armor": snappedf(armor, 0.05),
		"super_armor": super_armor,
	}
