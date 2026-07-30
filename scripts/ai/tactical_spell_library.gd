extends RefCounted
class_name TacticalSpellLibrary

const Manifest = preload(
	"res://scripts/abilities/spell_capability_manifest.gd"
)

static var records_by_id: Dictionary = {}
static var build_count: int = 0


static func get_record(spell_id: String) -> Dictionary:
	_ensure_records()
	var normalized: String = spell_id.strip_edges().to_lower()
	var value: Variant = records_by_id.get(normalized, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func get_records(spell_ids: Array[String]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for spell_id: String in spell_ids:
		var record: Dictionary = get_record(spell_id)
		if not record.is_empty():
			records.append(record)
	return records


static func rebuild() -> void:
	records_by_id.clear()
	var bundle: Dictionary = Manifest.build_bundle()
	var spells_value: Variant = bundle.get("spells", [])
	if spells_value is Array:
		for raw: Variant in spells_value as Array:
			if not raw is Dictionary:
				continue
			var record: Dictionary = raw as Dictionary
			var spell_id: String = str(record.get("spell_id", "")).to_lower()
			if spell_id != "":
				records_by_id[spell_id] = record.duplicate(true)
	build_count += 1


static func get_debug_data() -> Dictionary:
	_ensure_records()
	return {
		"spell_count": records_by_id.size(),
		"build_count": build_count,
	}


static func _ensure_records() -> void:
	if records_by_id.is_empty():
		rebuild()
