extends "res://scripts/actions/life_sprout_platform.gd"
class_name LifeSproutPlatformSpecies

const PlantCatalog = preload("res://scripts/life/plant_summon_catalog.gd")

@export var plant_definition: PlantSummonDefinition

var prepared_parameters: Dictionary = {}


func _ready() -> void:
	_apply_plant_definition()
	super._ready()


func set_plant_definition(definition: PlantSummonDefinition) -> void:
	plant_definition = definition
	_apply_plant_definition()


func set_prepared_parameters(parameters: Dictionary) -> void:
	prepared_parameters = parameters.duplicate(true)
	_apply_plant_definition()


func _apply_plant_definition() -> void:
	if plant_definition == null:
		return
	var preparation: Dictionary = PlantCatalog.sanitize_preparation(
		plant_definition.plant_id,
		prepared_parameters
	)
	prepared_parameters = preparation.duplicate(true)
	var size_multiplier: float = PlantCatalog.get_size_multiplier(preparation)
	var persistence_multiplier: float = PlantCatalog.get_persistence_multiplier(preparation)
	var emergence_multiplier: float = PlantCatalog.get_emergence_multiplier(preparation)

	platform_height = plant_definition.growth_height * size_multiplier
	platform_radius = plant_definition.canopy_radius * size_multiplier
	platform_thickness = plant_definition.body_thickness * maxf(size_multiplier, 0.82)
	lifetime = plant_definition.lifetime * persistence_multiplier
	maximum_active_per_caster = plant_definition.maximum_active_per_caster
	character_lift_speed = (
		plant_definition.character_growth_lift_speed * emergence_multiplier
	)
	rigid_lift_speed = (
		plant_definition.rigid_growth_lift_speed * emergence_multiplier
	)
	lift_radius = maxf(
		plant_definition.canopy_radius * size_multiplier * 1.1,
		0.65
	)


# Ground-targeted plant summoning adds the actor at the confirmed world point,
# then calls this hook. The actor already contains a frozen snapshot of the
# prepared blueprint, so no combat-time configuration is required.
func activate_from_ground_target() -> void:
	_apply_plant_definition()
	activate_at(global_position, Vector3.UP, source_actor)


func get_plant_id() -> String:
	return plant_definition.plant_id if plant_definition != null else ""


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["plant_definition"] = get_plant_id()
	data["plant_archetype"] = (
		plant_definition.growth_archetype
		if plant_definition != null
		else "legacy_sprout"
	)
	data["prepared_parameters"] = prepared_parameters.duplicate(true)
	data["catalog_driven"] = plant_definition != null
	data["ground_target_hook"] = true
	data["combat_configuration_required"] = false
	return data
