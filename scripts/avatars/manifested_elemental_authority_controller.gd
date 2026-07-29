extends "res://scripts/player/player_elemental_authority_controller.gd"
class_name ManifestedElementalAuthorityController

const ManifestedFireFieldScene: PackedScene = preload(
	"res://scenes/actions/manifested_fire_field.tscn"
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
