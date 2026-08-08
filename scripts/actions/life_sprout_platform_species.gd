extends "res://scripts/actions/life_sprout_platform.gd"
class_name LifeSproutPlatformSpecies

@export var plant_definition: PlantSummonDefinition


func _ready() -> void:
	_apply_plant_definition()
	super._ready()


func set_plant_definition(definition: PlantSummonDefinition) -> void:
	plant_definition = definition
	_apply_plant_definition()


func _apply_plant_definition() -> void:
	if plant_definition == null:
		return
	platform_height = plant_definition.growth_height
	platform_radius = plant_definition.canopy_radius
	platform_thickness = plant_definition.body_thickness
	lifetime = plant_definition.lifetime
	maximum_active_per_caster = plant_definition.maximum_active_per_caster
	character_lift_speed = plant_definition.character_growth_lift_speed
	rigid_lift_speed = plant_definition.rigid_growth_lift_speed
	lift_radius = maxf(
		plant_definition.canopy_radius * 1.1,
		0.65
	)


# Ground-targeted plant summoning adds the actor at the confirmed world point,
# then calls this hook. The original execute() path remains available for old
# labs/tests, but normal gameplay now gets a movable placement reticle first.
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
	data["catalog_driven"] = plant_definition != null
	data["ground_target_hook"] = true
	return data
