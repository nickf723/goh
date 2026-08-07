extends Node

const BoulderAbility: AbilityDefinition = preload(
	"res://data/abilities/boulder_ability.tres"
)
const GraceLoadout: AbilityLoadout = preload(
	"res://data/loadouts/grace_starting_loadout.tres"
)
const IconFactory = preload(
	"res://scripts/ui/spell_icon_factory.gd"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var descriptor: Dictionary = IconFactory.get_debug_descriptor(
		BoulderAbility
	)
	_expect(
		str(descriptor.get("spell_id", "")) == "boulder",
		"Boulder icon descriptor keeps the stable spell ID"
	)
	_expect(
		str(descriptor.get("element", "")) == "earth",
		"Boulder icon descriptor remains on the Earth page"
	)
	_expect(
		str(descriptor.get("glyph", "")) == "●",
		"Boulder renders the distinct solid-stone Focus glyph"
	)
	_expect(
		_has_spell(GraceLoadout.get_learned_abilities(), "boulder"),
		"Boulder appears in Grace's learned Focus library"
	)
	_expect(
		_has_spell(GraceLoadout.equipped_abilities, "boulder"),
		"Boulder retains a runtime casting reference"
	)

	if failures.is_empty():
		print("BOULDER_FOCUS_ICON_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("BOULDER_FOCUS_ICON_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func _has_spell(
	abilities: Array[AbilityDefinition],
	spell_id: String
) -> bool:
	for ability: AbilityDefinition in abilities:
		if ability != null and ability.get_spell_id() == spell_id:
			return true
	return false


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("BOULDER_FOCUS_ICON_SMOKE_TEST: " + label)
