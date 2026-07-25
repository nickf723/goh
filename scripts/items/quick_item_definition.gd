extends Resource
class_name QuickItemDefinition

const GameplayEffectAccessScript = preload("res://scripts/effects/gameplay_effect_access.gd")

@export var item_id: String = "quick_item"
@export var display_name: String = "Quick Item"
@export var short_label: String = "ITEM"
@export_multiline var description: String = "A reusable quick-slot item."
@export var icon_symbol: String = "◇"
@export var use_visual_color: Color = Color(0.45, 0.82, 1.0, 1.0)

@export_group("Inventory")
@export_range(1, 99, 1) var max_stack: int = 1
@export_range(0, 99, 1) var max_charges: int = 1
@export var refill_on_rest: bool = true

@export_group("Use Commitment")
@export_range(0.05, 5.0, 0.05) var use_duration: float = 0.8
@export_range(0.0, 1.0, 0.05) var movement_multiplier: float = 0.35
@export var requires_grounded: bool = true
@export var can_use_at_maximum: bool = false

@export_group("Effect")
@export_enum("restore_resource", "delivery_scene", "gameplay_effect", "cleanse_effects") var effect_type: String = "restore_resource"
@export_enum("health", "mana", "stamina", "stance") var restore_resource_id: String = "health"
@export_range(0, 99, 1) var restore_amount: int = 1
@export var gameplay_effect_ids: Array[String] = []
@export_range(0.1, 600.0, 0.1) var gameplay_effect_duration: float = 30.0
@export var gameplay_effect_tags: Array[String] = ["consumable_buff"]
@export var cleanse_effect_tags: Array[String] = []
@export var delivery_scene: PackedScene
@export var impact_scene: PackedScene
@export_range(1.0, 30.0, 0.5) var throw_speed: float = 12.0
@export_range(0.0, 12.0, 0.25) var throw_vertical_boost: float = 3.0
@export_range(0.0, 30.0, 0.5) var throw_gravity: float = 12.0
@export_range(0.2, 6.0, 0.1) var delivery_lifetime: float = 2.0
@export_range(0.0, 60.0, 0.5) var impact_lifetime: float = 12.0
@export_range(0.1, 3.0, 0.05) var impact_scale: float = 1.0

@export_group("Identity")
@export var element: String = "neutral"
@export var tags: Array[String] = ["consumable", "quick_item"]


func get_max_stack() -> int:
	return maxi(max_stack, 1)


func get_max_charges() -> int:
	return mini(maxi(max_charges, 0), get_max_stack())


func get_use_duration() -> float:
	return maxf(use_duration, 0.05)


func get_movement_multiplier() -> float:
	return clampf(movement_multiplier, 0.0, 1.0)


func is_delivery_item() -> bool:
	return effect_type == "delivery_scene"


func is_gameplay_effect_item() -> bool:
	return effect_type == "gameplay_effect"


func is_cleanse_item() -> bool:
	return effect_type == "cleanse_effects"


func get_current_resource() -> int:
	return GameState.get_stat(restore_resource_id)


func get_maximum_resource() -> int:
	return GameState.get_stat("max_" + restore_resource_id)


func can_apply() -> bool:
	if is_delivery_item():
		return delivery_scene != null and impact_scene != null
	if is_gameplay_effect_item():
		return not gameplay_effect_ids.is_empty() and gameplay_effect_duration > 0.0
	if is_cleanse_item():
		for effect_tag: String in cleanse_effect_tags:
			if GameplayEffectAccessScript.has_effect_with_tag(effect_tag):
				return true
		return false
	if restore_amount <= 0:
		return false
	if can_use_at_maximum:
		return true
	return get_current_resource() < get_maximum_resource()


func apply_resource_effect() -> int:
	if is_delivery_item():
		return 0
	var before: int = get_current_resource()
	var effective_amount: int = maxi(GameplayEffectAccessScript.modify_int(restore_resource_id + "_restore", restore_amount), 0)
	match restore_resource_id:
		"health":
			GameState.heal(effective_amount)
		"mana":
			GameState.restore_mana(effective_amount)
		"stamina":
			GameState.restore_stamina(effective_amount)
		"stance":
			GameState.restore_stance(effective_amount)
		_:
			return 0
	return GameState.get_stat(restore_resource_id) - before


func apply_gameplay_effect() -> bool:
	if not is_gameplay_effect_item() or gameplay_effect_ids.is_empty():
		return false
	GameplayEffectAccessScript.set_effect_source(
		"quick_item:" + item_id,
		gameplay_effect_ids,
		gameplay_effect_duration,
		gameplay_effect_tags
	)
	return true


func apply_cleanse_effect() -> int:
	if not is_cleanse_item():
		return 0
	var removed_count: int = 0
	for effect_tag: String in cleanse_effect_tags:
		removed_count += GameplayEffectAccessScript.remove_effects_with_tag(effect_tag)
	if removed_count > 0 and restore_amount > 0:
		apply_resource_effect()
	return removed_count


func apply_effect() -> int:
	if is_gameplay_effect_item():
		return 1 if apply_gameplay_effect() else 0
	if is_cleanse_item():
		return apply_cleanse_effect()
	return apply_resource_effect()


func get_debug_data() -> Dictionary:
	return {
		"id": item_id,
		"name": display_name,
		"effect": effect_type,
		"stack": get_max_stack(),
		"charges": get_max_charges(),
		"duration": get_use_duration(),
		"movement": get_movement_multiplier(),
		"restore_resource": restore_resource_id,
		"restore_amount": restore_amount,
		"gameplay_effect_ids": gameplay_effect_ids.duplicate(),
		"gameplay_effect_duration": gameplay_effect_duration,
		"cleanse_effect_tags": cleanse_effect_tags.duplicate(),
		"refill_on_rest": refill_on_rest,
		"delivery_scene": delivery_scene.resource_path if delivery_scene != null else "",
		"impact_scene": impact_scene.resource_path if impact_scene != null else "",
	}
