extends RefCounted
class_name FamiliarDefinitionCatalog

const GremlinDefinition: Resource = preload(
	"res://data/summons/gremlin_familiar_definition.tres"
)

const DEFINITIONS: Dictionary = {
	"gremlin": GremlinDefinition,
}


static func get_definition(species_id: String) -> Resource:
	var value: Variant = DEFINITIONS.get(species_id)
	return value as Resource if value is Resource else null


static func has_definition(species_id: String) -> bool:
	return get_definition(species_id) != null


static func get_species_ids() -> Array[String]:
	var ids: Array[String] = []
	for key_value: Variant in DEFINITIONS.keys():
		ids.append(str(key_value))
	ids.sort()
	return ids


static func get_debug_data() -> Dictionary:
	var rows: Array[Dictionary] = []
	for species_id: String in get_species_ids():
		var definition: Resource = get_definition(species_id)
		rows.append({
			"species_id": species_id,
			"available": definition != null,
			"definition": (
				definition.call("get_debug_data")
				if definition != null and definition.has_method("get_debug_data")
				else {}
			),
		})
	return {
		"definition_count": rows.size(),
		"definitions": rows,
	}
