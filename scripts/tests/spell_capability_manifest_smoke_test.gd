extends Node3D


const Manifest = preload(
	"res://scripts/abilities/spell_capability_manifest.gd"
)
const Audit = preload(
	"res://scripts/abilities/spell_capability_audit.gd"
)
const Simulator = preload(
	"res://scripts/abilities/spell_interaction_simulator.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var bundle: Dictionary = Manifest.build_bundle()
	var records: Array[Dictionary] = _dictionary_array(bundle.get("spells", []))
	var coverage: Array[Dictionary] = _dictionary_array(bundle.get("coverage", []))
	var reactions: Array[Dictionary] = _dictionary_array(bundle.get("reactions", []))
	_expect(records.size() >= 20, "Manifest discovers the authored ability library")
	_expect(coverage.size() == 16, "Coverage matrix contains all sixteen core elements")
	_expect(reactions.size() >= 12, "Reaction reachability includes chemistry v2 rules")

	var firebolt: Dictionary = _find_spell(records, "firebolt")
	_expect(not firebolt.is_empty(), "Manifest includes Firebolt")
	_expect(
		_string_array(firebolt.get("capabilities", [])).has("damage"),
		"Firebolt derives Damage capability"
	)
	_expect(
		not _string_array(firebolt.get("triggers_reactions", [])).is_empty(),
		"Firebolt exposes reaction payoff connections"
	)

	var water_jet: Dictionary = _find_spell(records, "water_jet")
	_expect(not water_jet.is_empty(), "Manifest includes Water Jet")
	_expect(
		_string_array(water_jet.get("applies_states", [])).has("wet"),
		"Water Jet exposes Wet setup state"
	)
	_expect(
		_string_array(water_jet.get("capabilities", [])).has("setup"),
		"Water Jet derives Setup capability"
	)

	var echolocation: Dictionary = _find_spell(records, "echolocation")
	_expect(not echolocation.is_empty(), "Manifest includes Echolocation")
	_expect(
		_string_array(echolocation.get("capabilities", [])).has("detection"),
		"Echolocation derives Detection capability"
	)

	var audit: Dictionary = Audit.audit_bundle(bundle)
	_expect(
		bool(audit.get("valid", false)),
		"Spell capability audit has no structural errors: "
		+ str(audit.get("errors", []))
	)
	_expect(
		int(audit.get("spell_count", 0)) == records.size(),
		"Audit and manifest agree on spell count"
	)
	_expect(
		audit.get("coverage_gaps", {}) is Dictionary,
		"Audit reports design gaps without treating them as parser failures"
	)

	var reachable_count: int = 0
	for reaction: Dictionary in reactions:
		if bool(reaction.get("reachable", false)):
			reachable_count += 1
	_expect(
		reachable_count >= 8,
		"At least eight chemistry rules have authored spell triggers"
	)

	var recipe_results: Array[Dictionary] = Simulator.simulate_default_recipes(self)
	_expect(recipe_results.size() == 4, "Simulator exposes four representative recipes")
	for recipe: Dictionary in recipe_results:
		_expect(
			bool(recipe.get("passed", false)),
			"Recipe `" + str(recipe.get("recipe_id", "recipe"))
			+ "` resolves expected reactions; missing="
			+ str(recipe.get("missing_reactions", []))
		)
		var trace: Array[Dictionary] = _dictionary_array(recipe.get("trace", []))
		_expect(not trace.is_empty(), "Recipe preserves a step-by-step transaction trace")
		var has_transaction: bool = false
		for step: Dictionary in trace:
			var transaction: Variant = step.get("transaction", {})
			if (
				transaction is Dictionary
				and str((transaction as Dictionary).get("transaction_id", "")) != ""
			):
				has_transaction = true
		_expect(has_transaction, "Recipe trace includes chemistry transaction IDs")

	if failures.is_empty():
		print("SPELL_CAPABILITY_MANIFEST_SMOKE_TEST: PASS")
		print("SPELL_CAPABILITY_AUDIT: " + Audit.format_summary(audit))
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SPELL_CAPABILITY_MANIFEST_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _find_spell(records: Array[Dictionary], spell_id: String) -> Dictionary:
	for record: Dictionary in records:
		if str(record.get("spell_id", "")) == spell_id:
			return record
	return {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append(raw as Dictionary)
	return result


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
