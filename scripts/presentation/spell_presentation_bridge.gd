extends RefCounted
class_name SpellPresentationBridge

const PresentationServiceScript = preload(
	"res://scripts/presentation/presentation_service.gd"
)


static func present(
	owner: Node,
	phase: String,
	context: Dictionary = {}
) -> Dictionary:
	if owner == null or not is_instance_valid(owner) or owner.get_tree() == null:
		return {}
	var director: GamePresentationDirector = PresentationServiceScript.get_or_create(
		owner.get_tree()
	)
	if director == null:
		return {}
	var payload: Dictionary = context.duplicate(true)
	payload["phase"] = phase
	if director.has_method("present_spell"):
		var result: Variant = director.call("present_spell", payload)
		return result as Dictionary if result is Dictionary else {}
	return director.present("spell", payload)


static func make_ability_context(
	ability: AbilityDefinition,
	actor: Node = null,
	position: Variant = null,
	power_ratio: float = 0.0
) -> Dictionary:
	var context: Dictionary = {
		"actor": actor,
		"power_ratio": clampf(power_ratio, 0.0, 1.0),
	}
	if ability != null:
		context["spell_id"] = ability.get_spell_id()
		context["spell_name"] = ability.display_name
		context["element"] = ability.element
		context["delivery_type"] = ability.get_delivery_type()
		context["targeting_style"] = ability.get_targeting_style()
	if position is Vector3:
		context["position"] = position as Vector3
	return context
