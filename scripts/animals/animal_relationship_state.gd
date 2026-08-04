extends RefCounted
class_name AnimalRelationshipState

var species_id: String = ""
var trust: float = 0.0
var familiarity: float = 0.0
var fear_association: float = 0.0
var peaceful_exposure: float = 0.0
var last_interaction: String = "none"
var interaction_count: int = 0
var traits: Dictionary = {}


static func create_for_species(
	new_species_id: String,
	personality_traits: Dictionary = {}
) -> AnimalRelationshipState:
	var state := AnimalRelationshipState.new()
	state.configure(new_species_id, personality_traits)
	return state


func configure(
	new_species_id: String,
	personality_traits: Dictionary = {}
) -> void:
	species_id = new_species_id.to_lower().strip_edges()
	traits = personality_traits.duplicate(true)
	var courage: float = get_trait("courage", 0.5)
	var curiosity: float = get_trait("curiosity", 0.5)
	match species_id:
		"sheep":
			trust = -0.12 + courage * 0.08
		"capybara":
			trust = -0.02 + curiosity * 0.08
		"wolf":
			trust = -0.2 + courage * 0.08
		_:
			trust = -0.05
	familiarity = 0.0
	fear_association = 0.0
	peaceful_exposure = 0.0
	last_interaction = "none"
	interaction_count = 0


func tick(
	delta: float,
	perception: Dictionary,
	distance_to_grace: float,
	grace_threatening: bool,
	grace_speed: float,
	current_fear: float
) -> void:
	var can_see: bool = bool(perception.get("can_see_target", false))
	var can_hear: bool = bool(perception.get("can_hear_target", false))
	var aware: bool = can_see or can_hear
	var curiosity: float = get_trait("curiosity", 0.5)
	var courage: float = get_trait("courage", 0.5)
	var patience: float = get_trait("patience", 0.5)
	if can_see:
		familiarity = clampf(familiarity + delta * 0.012, 0.0, 1.0)
		if grace_threatening:
			trust = clampf(trust - delta * (0.025 + (1.0 - courage) * 0.025), -1.0, 1.0)
			fear_association = clampf(fear_association + delta * 0.055, 0.0, 1.0)
			peaceful_exposure = maxf(peaceful_exposure - delta * 0.2, 0.0)
		else:
			var comfort_distance: float = get_comfort_distance()
			var calm_movement: bool = grace_speed <= 1.1
			if distance_to_grace >= comfort_distance and calm_movement:
				peaceful_exposure += delta
				trust = clampf(
					trust + delta * (0.004 + curiosity * 0.005 + patience * 0.002),
					-1.0,
					1.0
				)
				fear_association = clampf(fear_association - delta * 0.012, 0.0, 1.0)
			elif distance_to_grace < get_personal_space() and trust < 0.55:
				trust = clampf(trust - delta * (0.006 + (1.0 - courage) * 0.012), -1.0, 1.0)
				fear_association = clampf(fear_association + delta * 0.018, 0.0, 1.0)
	elif can_hear:
		familiarity = clampf(familiarity + delta * 0.003, 0.0, 1.0)
		if grace_threatening:
			fear_association = clampf(fear_association + delta * 0.025, 0.0, 1.0)
	else:
		fear_association = move_toward(
			fear_association,
			0.0,
			delta * (0.006 + courage * 0.008)
		)
	if not aware and current_fear < 0.2:
		peaceful_exposure = maxf(peaceful_exposure - delta * 0.04, 0.0)


func apply_interaction(interaction_id: String) -> Dictionary:
	var normalized_id: String = interaction_id.to_lower().strip_edges()
	var trust_before: float = trust
	var familiarity_before: float = familiarity
	var fear_before: float = fear_association
	match normalized_id:
		"feed":
			trust = clampf(trust + 0.24, -1.0, 1.0)
			familiarity = clampf(familiarity + 0.18, 0.0, 1.0)
			fear_association = clampf(fear_association - 0.18, 0.0, 1.0)
		"soothe":
			trust = clampf(trust + 0.14, -1.0, 1.0)
			familiarity = clampf(familiarity + 0.1, 0.0, 1.0)
			fear_association = clampf(fear_association - 0.28, 0.0, 1.0)
		"startle":
			trust = clampf(trust - 0.2, -1.0, 1.0)
			fear_association = clampf(fear_association + 0.38, 0.0, 1.0)
		"attack":
			trust = clampf(trust - 0.55, -1.0, 1.0)
			fear_association = clampf(fear_association + 0.65, 0.0, 1.0)
		"help":
			trust = clampf(trust + 0.32, -1.0, 1.0)
			familiarity = clampf(familiarity + 0.12, 0.0, 1.0)
			fear_association = clampf(fear_association - 0.2, 0.0, 1.0)
		_:
			return {"ok": false, "error": "unknown interaction"}
	last_interaction = normalized_id
	interaction_count += 1
	return {
		"ok": true,
		"interaction": normalized_id,
		"trust_delta": trust - trust_before,
		"familiarity_delta": familiarity - familiarity_before,
		"fear_association_delta": fear_association - fear_before,
		"state": to_dictionary(),
	}


func get_relationship_label(current_fear: float = 0.0) -> String:
	var aggression: float = get_trait("aggression", 0.5)
	var curiosity: float = get_trait("curiosity", 0.5)
	var combined_fear: float = clampf(current_fear * 0.72 + fear_association * 0.48, 0.0, 1.0)
	if aggression >= 0.58 and trust <= -0.34 and combined_fear < 0.72:
		return "hostile"
	if combined_fear >= 0.68:
		return "afraid"
	if combined_fear >= 0.32 or trust <= -0.16:
		return "wary"
	if trust >= 0.64:
		return "trusting"
	if trust >= 0.17 or (familiarity >= 0.2 and curiosity >= 0.58):
		return "curious"
	return "neutral"


func get_comfort_distance() -> float:
	var base_distance: float = 3.4
	match species_id:
		"sheep":
			base_distance = 4.6
		"capybara":
			base_distance = 3.5
		"wolf":
			base_distance = 4.2
	var courage: float = get_trait("courage", 0.5)
	return clampf(base_distance - trust * 1.25 - courage * 0.45, 1.4, 6.5)


func get_personal_space() -> float:
	return maxf(get_comfort_distance() * 0.48, 1.0)


func get_trait(trait_id: String, fallback: float = 0.5) -> float:
	return clampf(float(traits.get(trait_id.to_lower().strip_edges(), fallback)), 0.0, 1.0)


func to_dictionary() -> Dictionary:
	return {
		"species_id": species_id,
		"trust": trust,
		"familiarity": familiarity,
		"fear_association": fear_association,
		"peaceful_exposure": peaceful_exposure,
		"last_interaction": last_interaction,
		"interaction_count": interaction_count,
		"relationship_label": get_relationship_label(),
		"comfort_distance": get_comfort_distance(),
	}
