extends "res://scripts/abilities/ability_caster_plant_summons.gd"
class_name AbilityCasterSpellPresentation

const SpellPresentation = preload(
	"res://scripts/presentation/spell_presentation_bridge.gd"
)

var charged_presentation_prepared: bool = false
var charge_presentation_bucket: int = 0
var channel_presentation_prepared: bool = false
var presentation_confirming_ground_target: bool = false


func cast_from_player(
	player: Node3D,
	cast_lock_duration: float = 0.18,
	allow_charge: bool = true
) -> bool:
	var ability: AbilityDefinition = get_current_ability()
	if (
		ability != null
		and not is_ground_targeting()
		and _is_channeled_delivery(ability.get_delivery_type())
	):
		channel_presentation_prepared = true
		_present_ability_phase("prepare", ability, player)
		var channel_result: bool = super.cast_from_player(player, cast_lock_duration, allow_charge)
		if not channel_result:
			_present_ability_phase("cancel", ability, player)
		channel_presentation_prepared = false
		return channel_result
	return super.cast_from_player(player, cast_lock_duration, allow_charge)


func execute_ability_from_player(
	player: Node3D,
	ability: AbilityDefinition,
	cast_lock_duration: float = 0.18,
	action_payload_override: Resource = null,
	power_ratio: float = 0.0,
	extra_mana_cost: int = 0
) -> bool:
	var is_channel: bool = ability != null and _is_channeled_delivery(ability.get_delivery_type())
	var charge_prepare_owned: bool = (
		charged_presentation_prepared
		and ability != null
		and ability.get_spell_id() == FIREBOLT_SPELL_ID
	)
	var prepare_owned_elsewhere: bool = charge_prepare_owned or (
		is_channel and channel_presentation_prepared
	)
	if not prepare_owned_elsewhere:
		_present_ability_phase("prepare", ability, player, _null_position(), power_ratio, {
			"subtle": true,
			"suppress_haptics": true,
			"detail": "instant_prepare",
		})

	var did_cast: bool = super.execute_ability_from_player(
		player,
		ability,
		cast_lock_duration,
		action_payload_override,
		power_ratio,
		extra_mana_cost
	)
	if did_cast:
		# Channeled/tether actions own their release/latch/sustain language because
		# those phases are coupled to whether the tether actually finds a target.
		if not is_channel:
			var origin: Vector3 = get_player_cast_origin(player)
			_present_ability_phase("release", ability, player, origin, power_ratio)
			if ability != null and _is_projectile_delivery(ability.get_delivery_type()):
				_present_ability_phase("travel", ability, player, origin, power_ratio, {
					"subtle": true,
				})
	else:
		_present_ability_phase("cancel", ability, player)

	if charge_prepare_owned:
		charged_presentation_prepared = false
		charge_presentation_bucket = 0
	return did_cast


func begin_charged_firebolt(
	player: Node3D,
	ability: AbilityDefinition
) -> bool:
	var was_charging: bool = is_charging_firebolt
	var started: bool = super.begin_charged_firebolt(player, ability)
	if started and not was_charging:
		charged_presentation_prepared = true
		charge_presentation_bucket = 0
		_present_ability_phase("prepare", ability, player, _null_position(), 0.2, {
			"charging": true,
		})
	return started


func update_charged_firebolt(delta: float) -> void:
	super.update_charged_firebolt(delta)
	if not is_charging_firebolt or not charged_presentation_prepared:
		return
	var ratio: float = get_charged_firebolt_ratio()
	var next_bucket: int = clampi(floori(ratio * 4.0), 0, 4)
	if next_bucket <= charge_presentation_bucket or next_bucket <= 0:
		return
	charge_presentation_bucket = next_bucket
	_present_ability_phase("sustain", charge_ability, charge_player, _null_position(), ratio, {
		"charging": true,
		"detail": "charge_step_" + str(next_bucket),
		"intensity": clampf(0.26 + ratio * 0.42, 0.26, 0.68),
	})


func cancel_charged_firebolt(should_emit: bool = true) -> void:
	if is_charging_firebolt and charged_presentation_prepared:
		_present_ability_phase("cancel", charge_ability, charge_player, _null_position(), 0.0, {
			"charging": true,
		})
	charged_presentation_prepared = false
	charge_presentation_bucket = 0
	super.cancel_charged_firebolt(should_emit)


func begin_ground_targeting(
	player: Node3D,
	ability: AbilityDefinition,
	ground_spell: Dictionary
) -> bool:
	var started: bool = super.begin_ground_targeting(player, ability, ground_spell)
	if started:
		_present_ability_phase("prepare", ability, player, _null_position(), 0.0, {
			"ground_targeting": true,
			"spell_key": str(ground_spell.get("spell_key", ability.get_spell_id() if ability != null else "")),
		})
	return started


func confirm_ground_targeting() -> bool:
	if not is_ground_targeting():
		return false
	var controller: RefCounted = get_ground_targeting_controller()
	var ability: AbilityDefinition = controller.get_ability() as AbilityDefinition
	var player: Node3D = controller.get_source_player()
	var target_position: Vector3 = controller.get_target_position()
	var spell_key: String = controller.get_spell_key()

	presentation_confirming_ground_target = true
	var did_handle: bool = super.confirm_ground_targeting()
	presentation_confirming_ground_target = false

	if did_handle and not is_ground_targeting() and ability != null and player != null:
		_present_ability_phase("release", ability, player)
		_present_ability_phase("manifest", ability, player, target_position, 0.0, {
			"spell_key": spell_key,
			"ground_targeting": true,
		})
	return did_handle


func cancel_ground_targeting(
	should_show_feedback: bool = true
) -> void:
	if not is_ground_targeting():
		super.cancel_ground_targeting(should_show_feedback)
		return
	var controller: RefCounted = get_ground_targeting_controller()
	var ability: AbilityDefinition = controller.get_ability() as AbilityDefinition
	var player: Node3D = controller.get_source_player()
	var should_present_cancel: bool = not presentation_confirming_ground_target
	super.cancel_ground_targeting(should_show_feedback)
	if should_present_cancel:
		_present_ability_phase("cancel", ability, player, _null_position(), 0.0, {
			"ground_targeting": true,
		})


func _present_ability_phase(
	phase: String,
	ability: AbilityDefinition,
	player: Node3D,
	position_value: Variant = null,
	power_ratio: float = 0.0,
	extra: Dictionary = {}
) -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {}
	var position: Variant = position_value
	if not position is Vector3:
		position = get_player_cast_origin(player)
	var context: Dictionary = SpellPresentation.make_ability_context(
		ability,
		player,
		position,
		power_ratio
	)
	for key: Variant in extra.keys():
		context[key] = extra[key]
	return SpellPresentation.present(self, phase, context)


func _is_projectile_delivery(delivery_type: String) -> bool:
	var normalized: String = delivery_type.strip_edges().to_lower()
	return "projectile" in normalized or normalized in ["homing", "target_lock"]


func _is_channeled_delivery(delivery_type: String) -> bool:
	var normalized: String = delivery_type.strip_edges().to_lower()
	return "channel" in normalized or "tether" in normalized


func _null_position() -> Variant:
	return null


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["spell_presentation_lifecycle"] = true
	data["spell_presentation_phases"] = [
		"prepare", "release", "travel", "manifest", "latch", "sustain", "resolve", "cancel", "handoff",
	]
	data["charged_prepare_owned"] = charged_presentation_prepared
	data["charge_presentation_bucket"] = charge_presentation_bucket
	data["channel_prepare_owned"] = channel_presentation_prepared
	data["ground_confirming"] = presentation_confirming_ground_target
	return data
