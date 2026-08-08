extends RefCounted
class_name SpellCloneReplayPolicy

# Shared by Time echoes today and future Soul duplicates later. The policy
# answers one question only: may a duplicate replay the cast as a fresh action?
# It never copies the original cast's hit results, status applications, or world
# state. Allowed replays get their own trajectory and collide with the world that
# exists when the replay happens.

const MODE_REPLAY: String = "replay"
const MODE_SUPPRESS: String = "suppress"

const EXPLICIT_REPLAY_IDS: Array[String] = [
	"arcane_spark",
	"firebolt",
	"ice_lance",
	"lightning_spark",
	"sound_pulse",
	"poison_cloud",
	"fire_field",
	"wind_gust",
	"earth_spike",
	"metal_needle",
	"life_thorn",
	"death_hex",
	"body_burst",
	"soul_thread",
	"dream_snare",
	"time_snare",
	"wave",
	"lightning_bolt",
	"wind_well",
	"contagion_cloud",
	"boulder",
	"curling_puck",
	"echolocation",
	"resonant_pulse",
	"gust",
]

const EXPLICIT_SUPPRESS_IDS: Dictionary = {
	"repeat": "Repeat cannot recursively repeat itself.",
	"flight_concentration": "Concentration state is owned by the original caster.",
	"rain_weather": "Global weather is world state and does not stack from clones.",
	"snow_weather": "Global weather is world state and does not stack from clones.",
	"thunderstorm_weather": "Global weather is world state and does not stack from clones.",
	"grow": "Body transformations are owned by the original body.",
	"shrink": "Body transformations are owned by the original body.",
	"space_blink": "Self-teleport movement is not replayed by a nonphysical echo.",
	"flash": "Self-teleport movement is not replayed by a nonphysical echo.",
	"surf": "Sustained locomotion is not replayed by a nonphysical echo.",
	"flight": "Sustained locomotion is not replayed by a nonphysical echo.",
	"bubble": "Self-defense state belongs to the original caster.",
	"asteroid_belt": "Self-centered persistent state belongs to the original caster.",
	"flamethrower": "Held channels need duration recording before clone replay is safe.",
	"water_jet": "Held channels need duration recording before clone replay is safe.",
	"firewall": "Drawn paths need full input-history recording before clone replay is safe.",
	"soul_grip": "Grab ownership cannot be duplicated safely.",
	"metal_tether": "Tether ownership cannot be duplicated safely.",
	"spectral_familiar": "Summons are persistent actor ownership, not a replayable cast result.",
	"recorded_object_summon": "World-object summons are not duplicated by echoes.",
	"artificer_assembly": "World-object assembly is not duplicated by echoes.",
	"deploy_contraption": "Persistent deployed objects are not duplicated by echoes.",
}

const BLOCKED_ROLE_WORDS: Array[String] = [
	"concentration",
	"weather",
	"transformation",
	"summon",
	"flight",
]

const BLOCKED_DELIVERY_WORDS: Array[String] = [
	"concentration",
	"movement_state",
	"persistent_body_form",
	"sustained_movement",
]


static func get_policy(ability: AbilityDefinition) -> Dictionary:
	if ability == null:
		return _suppressed("missing ability")
	var spell_id: String = ability.get_spell_id()
	if EXPLICIT_SUPPRESS_IDS.has(spell_id):
		return _suppressed(str(EXPLICIT_SUPPRESS_IDS[spell_id]), spell_id)
	if EXPLICIT_REPLAY_IDS.has(spell_id):
		return _replay(spell_id, "explicit clone-safe spell")

	var roles: Array[String] = ability.get_roles()
	for role: String in roles:
		var normalized_role: String = role.strip_edges().to_lower()
		for blocked_word: String in BLOCKED_ROLE_WORDS:
			if normalized_role.contains(blocked_word):
				return _suppressed(
					"blocked role: " + normalized_role,
					spell_id
				)

	var delivery: String = ability.get_delivery_type().strip_edges().to_lower()
	for blocked_delivery: String in BLOCKED_DELIVERY_WORDS:
		if delivery.contains(blocked_delivery):
			return _suppressed(
				"blocked delivery: " + delivery,
				spell_id
			)

	# New ordinary projectile and instant spells default to replayable. New utility,
	# summon, transformation, and movement spells default to suppressed until their
	# clone semantics are authored deliberately.
	if ability.category in [
		AbilityDefinition.AbilityCategory.PROJECTILE,
		AbilityDefinition.AbilityCategory.INSTANT,
	]:
		return _replay(spell_id, "safe category fallback")
	return _suppressed("unreviewed clone semantics", spell_id)


static func can_replay(ability: AbilityDefinition) -> bool:
	return str(get_policy(ability).get("mode", MODE_SUPPRESS)) == MODE_REPLAY


static func _replay(spell_id: String, reason: String) -> Dictionary:
	return {
		"mode": MODE_REPLAY,
		"spell_id": spell_id,
		"reason": reason,
		"copies_result": false,
		"fresh_world_interaction": true,
	}


static func _suppressed(reason: String, spell_id: String = "") -> Dictionary:
	return {
		"mode": MODE_SUPPRESS,
		"spell_id": spell_id,
		"reason": reason,
		"copies_result": false,
		"fresh_world_interaction": false,
	}
