extends "res://scripts/player/player_elemental_authority_controller.gd"
class_name ManifestedElementalAuthorityController

const ManifestedFireFieldScene: PackedScene = preload(
	"res://scenes/actions/manifested_fire_field.tscn"
)
const ManifestedProjectileScene: PackedScene = preload(
	"res://scenes/actions/manifested_generic_projectile.tscn"
)


func _ready() -> void:
	super._ready()
	add_to_group("manifested_avatar_elemental_authority")


func get_modified_mana_cost(_ability: AbilityDefinition) -> int:
	return 0


func _pay_authority_cost(
	_ability: AbilityDefinition,
	_required_mana: int
) -> bool:
	return true


func _refund_authority_cost(_mana_cost: int) -> void:
	pass


func _cast_authority_projectile(
	ability: AbilityDefinition,
	cast_origin: Vector3,
	cast_direction: Vector3
) -> bool:
	if ability == null:
		return false
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return false
	var ability_instance: Node = ManifestedProjectileScene.instantiate()
	var base_payload: Resource = ability.get_action_payload()
	if base_payload is DamagePayload:
		var authority_payload: DamagePayload = modify_spell_payload(
			ability,
			base_payload as DamagePayload
		)
		if ability_instance.has_method("set_payload"):
			ability_instance.call("set_payload", authority_payload)
	if ability_instance.has_method("set_source_actor"):
		ability_instance.call("set_source_actor", actor)
	scene_root.add_child(ability_instance)
	if ability_instance is Node3D:
		(ability_instance as Node3D).global_position = cast_origin
	if "speed" in ability_instance:
		ability_instance.set(
			"speed",
			float(ability_instance.get("speed"))
			* profile.projectile_speed_multiplier
		)
	if ability_instance.has_method("launch"):
		ability_instance.call("launch", cast_direction)
	last_cast_instance = ability_instance
	return true


func _spawn_fire_field_at(
	world_position: Vector3,
	field_payload: DamagePayload,
	field_kind: String,
	apply_authority_bonuses: bool,
	radius_override: float,
	lifetime_override: float
) -> Node3D:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return null
	var field_instance: Node = ManifestedFireFieldScene.instantiate()
	if not (field_instance is Node3D):
		field_instance.queue_free()
		return null
	if radius_override > 0.0:
		field_instance.set("radius", radius_override)
	if lifetime_override > 0.0:
		field_instance.set("lifetime", lifetime_override)
	if field_payload != null and field_instance.has_method("set_payload"):
		field_instance.call("set_payload", field_payload)
	if field_instance.has_method("set_source_actor"):
		field_instance.call("set_source_actor", actor)
	scene_root.add_child(field_instance)
	var field_node: Node3D = field_instance as Node3D
	field_node.global_position = world_position
	if field_instance.has_method("set_authority_context"):
		field_instance.call(
			"set_authority_context",
			actor,
			profile,
			apply_authority_bonuses,
			field_kind
		)
	if field_instance.has_method("ignite_at"):
		field_instance.call("ignite_at", world_position)
	else:
		if field_instance.has_method("configure_area"):
			field_instance.call("configure_area")
		if field_instance.has_method("configure_visual"):
			field_instance.call("configure_visual")
	register_owned_field(field_node, field_kind)
	return field_node


func _show_message(_text: String) -> void:
	pass
