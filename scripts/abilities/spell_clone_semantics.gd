extends RefCounted
class_name SpellCloneSemantics

const REPEAT_TRAJECTORY: String = "timeline_trajectory"
const REPEAT_RECAST: String = "timeline_recast"
const REPEAT_SOURCE_STATE: String = "timeline_source_state"
const REPEAT_CHANNEL: String = "timeline_channel"
const REPEAT_WORLD_STATE: String = "world_state_noop"
const REPEAT_SUPPRESS: String = "suppress"

const DUPLICATE_LIVE: String = "live_recast"
const DUPLICATE_SOURCE_STATE: String = "live_source_state"
const DUPLICATE_WORLD_STATE: String = "world_state_noop"
const DUPLICATE_SUPPRESS: String = "suppress"

# Repeat is a recording. Soul duplication is another actor doing the action now.
# Never collapse these into one "clone-safe" boolean again.

const TRAJECTORY_REPEAT_IDS: Array[String] = [
	"arcane_spark",
	"firebolt",
	"ice_lance",
	"metal_needle",
	"life_thorn",
	"death_hex",
	"soul_thread",
	"dream_snare",
	"time_snare",
	"boulder",
	"curling_puck",
]

const CHANNEL_REPEAT_IDS: Array[String] = [
	"flamethrower",
	"water_jet",
	"firewall",
]

const SOURCE_STATE_REPEAT_IDS: Array[String] = [
	"space_blink",
	"flash",
	"surf",
	"flight",
	"grow",
	"shrink",
	"bubble",
	"asteroid_belt",
]

const WORLD_STATE_NOOP_IDS: Array[String] = [
	"rain_weather",
	"snow_weather",
	"thunderstorm_weather",
]

const SUPPRESSED_OWNERSHIP_IDS: Array[String] = [
	"repeat",
	"soul_grip",
	"metal_tether",
	"spectral_familiar",
	"recorded_object_summon",
	"artificer_assembly",
	"deploy_contraption",
]

const EXPLICIT_RECAST_IDS: Array[String] = [
	"lightning_spark",
	"sound_pulse",
	"poison_cloud",
	"fire_field",
	"wind_gust",
	"earth_spike",
	"body_burst",
	"wave",
	"lightning_bolt",
	"wind_well",
	"contagion_cloud",
	"echolocation",
	"resonant_pulse",
	"gust",
]


static func get_repeat_mode(ability: AbilityDefinition) -> String:
	if ability == null:
		return REPEAT_SUPPRESS
	var spell_id: String = ability.get_spell_id()
	if spell_id in SUPPRESSED_OWNERSHIP_IDS:
		return REPEAT_SUPPRESS
	if spell_id in WORLD_STATE_NOOP_IDS:
		return REPEAT_WORLD_STATE
	if spell_id in SOURCE_STATE_REPEAT_IDS:
		return REPEAT_SOURCE_STATE
	if spell_id in CHANNEL_REPEAT_IDS:
		return REPEAT_CHANNEL
	if spell_id in TRAJECTORY_REPEAT_IDS:
		return REPEAT_TRAJECTORY
	if spell_id in EXPLICIT_RECAST_IDS:
		return REPEAT_RECAST
	if ability.category in [
		AbilityDefinition.AbilityCategory.PROJECTILE,
		AbilityDefinition.AbilityCategory.INSTANT,
	]:
		return REPEAT_RECAST
	return REPEAT_SUPPRESS


static func get_duplicate_mode(ability: AbilityDefinition) -> String:
	if ability == null:
		return DUPLICATE_SUPPRESS
	var spell_id: String = ability.get_spell_id()
	if spell_id in SUPPRESSED_OWNERSHIP_IDS:
		return DUPLICATE_SUPPRESS
	if spell_id in WORLD_STATE_NOOP_IDS:
		return DUPLICATE_WORLD_STATE
	# Body/transformation/traversal/defense effects belong to the duplicate actor
	# and therefore should happen live on that actor rather than being suppressed.
	if spell_id in SOURCE_STATE_REPEAT_IDS:
		return DUPLICATE_SOURCE_STATE
	return DUPLICATE_LIVE


static func describe(ability: AbilityDefinition) -> Dictionary:
	return {
		"spell_id": ability.get_spell_id() if ability != null else "",
		"repeat_mode": get_repeat_mode(ability),
		"duplicate_mode": get_duplicate_mode(ability),
		"repeat_copies_world_result": false,
		"repeat_copies_motion_timeline": true,
		"duplicate_runs_live_simulation": true,
	}
