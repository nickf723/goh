extends RefCounted

# Data table for prototype ground-targeted spells.
# The caster owns input/payment. This registry owns matching, marker config,
# payload shaping, and confirm behavior metadata.

const GROUND_SPELL_DEFS: Dictionary = {
	"earth_spike": {
		"spell_key": "earth_spike",
		"spell_ids": ["earth_spike"],
		"display_names": ["earth spike"],
		"element": "earth",
		"effect_type": "instant_aoe",
		"begin_message": "Place Earth Spike. Right stick moves target. Cast confirms. Cancel backs out.",
		"cancel_message": "Earth Spike canceled.",
		"confirm_message": "Earth Spike erupts.",
		"confirm_hit_message": "Earth Spike erupts and hits {count} target(s).",
		"target": {
			"marker_name": "EarthSpikeTargetMarker",
			"disc_name": "TargetDisc",
			"center_name": "TargetCenter",
			"radius": 2.15,
			"range": 12.0,
			"initial_distance": 6.0,
			"speed": 8.5,
			"deadzone": 0.18,
			"ground_y_offset": 0.05,
			"cast_lock_duration": 0.24,
			"disc_color": Color(0.36, 0.27, 0.14, 0.32),
			"center_color": Color(0.36, 0.27, 0.14, 0.78),
			"disc_alpha": 0.32,
			"center_alpha": 0.78,
			"pulse_speed": 5.5,
			"pulse_size": 0.035,
			"emission_energy": 0.55,
		},
		"payload": {
			"source_name": "Earth Spike",
			"hit_type": "ground_aoe",
			"tags": ["earth_spike", "ground_targeted", "aoe"],
		},
	},
	"poison_bloom": {
		"spell_key": "poison_bloom",
		"spell_ids": ["poison_cloud", "poison_bloom"],
		"display_names": ["poison cloud", "poison bloom"],
		"element": "poison",
		"effect_type": "spawn_field",
		"post_spawn_method": "apply_cloud_tick",
		"begin_message": "Place Poison Bloom. Right stick moves target. Cast confirms. Cancel backs out.",
		"cancel_message": "Poison Bloom canceled.",
		"confirm_message": "Poison Bloom unfurls.",
		"target": {
			"marker_name": "PoisonBloomTargetMarker",
			"disc_name": "PoisonBloomDisc",
			"center_name": "PoisonBloomCenter",
			"radius": 3.0,
			"range": 12.0,
			"initial_distance": 6.0,
			"speed": 8.0,
			"deadzone": 0.18,
			"ground_y_offset": 0.06,
			"cast_lock_duration": 0.22,
			"disc_color": Color(0.22, 0.85, 0.22, 0.34),
			"center_color": Color(0.22, 0.85, 0.22, 0.78),
			"disc_alpha": 0.34,
			"center_alpha": 0.78,
			"pulse_speed": 4.4,
			"pulse_size": 0.055,
			"emission_energy": 0.72,
		},
		"payload": {
			"source_name": "Poison Bloom",
			"hit_type": "ground_field",
			"default_status_effect": "poisoned",
			"default_status_duration": 1.6,
			"default_status_strength": 1.0,
			"tags": ["poison_bloom", "ground_targeted", "field", "aoe"],
		},
	},
	"time_snare": {
		"spell_key": "time_snare",
		"spell_ids": ["time_snare"],
		"display_names": ["time snare"],
		"element": "time",
		"effect_type": "spawn_field",
		"post_spawn_method": "apply_snare_tick",
		"begin_message": "Place Time Snare. Right stick moves target. Cast confirms. Cancel backs out.",
		"cancel_message": "Time Snare canceled.",
		"confirm_message": "Time Snare bends the field.",
		"target": {
			"marker_name": "TimeSnareTargetMarker",
			"disc_name": "TimeSnareDisc",
			"center_name": "TimeSnareCenter",
			"radius": 3.2,
			"range": 12.0,
			"initial_distance": 6.0,
			"speed": 8.0,
			"deadzone": 0.18,
			"ground_y_offset": 0.06,
			"cast_lock_duration": 0.22,
			"disc_color": Color(0.95, 0.78, 0.18, 0.34),
			"center_color": Color(0.95, 0.78, 0.18, 0.82),
			"disc_alpha": 0.34,
			"center_alpha": 0.82,
			"pulse_speed": 5.8,
			"pulse_size": 0.055,
			"emission_energy": 0.9,
		},
		"payload": {
			"source_name": "Time Snare",
			"hit_type": "ground_field",
			"default_status_effect": "chill",
			"default_status_duration": 0.75,
			"default_status_strength": 0.45,
			"tags": ["time_snare", "ground_targeted", "field", "slow", "control"],
		},
	},
	"dream_trap": {
		"spell_key": "dream_trap",
		"spell_ids": ["dream_snare", "dream_trap"],
		"display_names": ["dream snare", "dream trap"],
		"element": "dreams",
		"effect_type": "spawn_field",
		"begin_message": "Place Dream Trap. Right stick moves target. Cast confirms. Cancel backs out.",
		"cancel_message": "Dream Trap canceled.",
		"confirm_message": "Dream Trap waits.",
		"target": {
			"marker_name": "DreamTrapTargetMarker",
			"disc_name": "DreamTrapDisc",
			"center_name": "DreamTrapCenter",
			"radius": 2.75,
			"range": 12.0,
			"initial_distance": 6.0,
			"speed": 8.0,
			"deadzone": 0.18,
			"ground_y_offset": 0.06,
			"cast_lock_duration": 0.22,
			"disc_color": Color(0.62, 0.24, 0.95, 0.34),
			"center_color": Color(0.72, 0.28, 1.0, 0.82),
			"disc_alpha": 0.34,
			"center_alpha": 0.82,
			"pulse_speed": 4.1,
			"pulse_size": 0.06,
			"emission_energy": 0.92,
		},
		"payload": {
			"source_name": "Dream Trap",
			"hit_type": "trap",
			"default_status_effect": "staggered",
			"default_status_duration": 1.2,
			"default_status_strength": 1.0,
			"tags": ["dream_trap", "ground_targeted", "trap", "illusion", "control"],
		},
	},
	"lightning_bolt": {
		"spell_key": "lightning_bolt",
		"spell_ids": ["lightning_bolt"],
		"display_names": ["lightning bolt"],
		"element": "lightning",
		"effect_type": "spawn_field",
		"post_spawn_method": "begin_strike",
		"begin_message": "Place Lightning Bolt. Right stick moves the storm mark. Cast confirms. Cancel backs out.",
		"cancel_message": "Lightning Bolt canceled.",
		"confirm_message": "Lightning answers from above.",
		"target": {
			"marker_name": "LightningBoltTargetMarker",
			"disc_name": "LightningBoltOuterDisc",
			"center_name": "LightningBoltDirectCenter",
			"shape": "circle",
			"placement": "free_ground",
			"radius": 1.8,
			"range": 14.0,
			"minimum_range": 1.0,
			"initial_distance": 6.0,
			"speed": 9.0,
			"deadzone": 0.18,
			"ground_y_offset": 0.06,
			"cast_lock_duration": 0.34,
			"require_ground": true,
			"require_line_of_sight": false,
			"allow_through_obstacles": true,
			"show_direction_line": false,
			"disc_color": Color(0.16, 0.34, 1.0, 0.3),
			"center_color": Color(0.74, 0.92, 1.0, 0.9),
			"disc_alpha": 0.3,
			"center_alpha": 0.9,
			"outline_alpha": 0.96,
			"pulse_speed": 6.4,
			"pulse_size": 0.065,
			"emission_energy": 1.15,
			"preview_label": "LIGHTNING BOLT • CENTER STRIKE",
		},
		"payload": {
			"source_name": "Lightning Bolt",
			"hit_type": "sky_strike",
			"tags": ["lightning_bolt", "ground_targeted", "sky_strike", "direct_strike"],
		},
	},
}


static func get_definition_for_ability(ability: AbilityDefinition) -> Dictionary:
	if ability == null:
		return {}

	for spell_key_variant in GROUND_SPELL_DEFS.keys():
		var spell_key: String = str(spell_key_variant)
		var definition: Dictionary = GROUND_SPELL_DEFS[spell_key]
		if ability_matches_definition(ability, definition):
			return definition.duplicate(true)

	return {}


static func get_definition_for_spell_key(spell_key: String) -> Dictionary:
	if spell_key == "":
		return {}

	if not GROUND_SPELL_DEFS.has(spell_key):
		return {}

	return GROUND_SPELL_DEFS[spell_key].duplicate(true)


static func get_target_config(definition: Dictionary) -> Dictionary:
	if definition.has("target") and definition["target"] is Dictionary:
		var config: Dictionary = definition["target"].duplicate(true)
		config["spell_key"] = get_spell_key(definition)
		return config

	return {}


static func get_spell_key(definition: Dictionary) -> String:
	return str(definition.get("spell_key", ""))


static func get_effect_type(definition: Dictionary) -> String:
	return str(definition.get("effect_type", ""))


static func get_begin_message(definition: Dictionary) -> String:
	return str(definition.get("begin_message", "Place spell. Right stick moves target. Cast confirms. Cancel backs out."))


static func get_cancel_message(definition: Dictionary) -> String:
	return str(definition.get("cancel_message", "Spell canceled."))


static func get_confirm_message(definition: Dictionary, hit_count: int = -1) -> String:
	if hit_count >= 0 and definition.has("confirm_hit_message"):
		var hit_message: String = str(definition["confirm_hit_message"])
		return hit_message.replace("{count}", str(hit_count))

	return str(definition.get("confirm_message", "Spell placed."))


static func get_post_spawn_method(definition: Dictionary) -> String:
	return str(definition.get("post_spawn_method", ""))


static func get_target_radius(definition: Dictionary, fallback: float = 2.0) -> float:
	var target_config: Dictionary = get_target_config(definition)
	var value: Variant = target_config.get("radius", fallback)
	return fallback if value == null else float(value)


static func make_payload_for_ability(ability: AbilityDefinition, definition: Dictionary) -> DamagePayload:
	var base_payload: Resource = get_ability_payload(ability)
	var payload: DamagePayload = DamagePayload.new()

	if base_payload is DamagePayload:
		var duplicate_payload: Resource = base_payload.duplicate(true)
		if duplicate_payload is DamagePayload:
			payload = duplicate_payload as DamagePayload

	if definition.has("payload") and definition["payload"] is Dictionary:
		var payload_def: Dictionary = definition["payload"]
		apply_payload_definition(payload, payload_def)

	return payload


static func ability_matches_definition(ability: AbilityDefinition, definition: Dictionary) -> bool:
	var expected_element: String = str(definition.get("element", "")).to_lower()
	if expected_element != "" and ability.element.to_lower() != expected_element:
		return false

	var spell_id: String = get_ability_spell_id(ability)
	if spell_id != "":
		var spell_ids: Array = definition.get("spell_ids", [])
		return spell_ids.has(spell_id)

	var display_name: String = ability.display_name.to_lower()
	var display_names: Array = definition.get("display_names", [])
	return display_names.has(display_name)


static func get_ability_spell_id(ability: AbilityDefinition) -> String:
	if ability == null:
		return ""

	if ability.has_method("get_spell_id"):
		return str(ability.get_spell_id())

	var spell_id_value: Variant = ability.get("spell_id")
	if spell_id_value != null:
		return str(spell_id_value)

	return ""


static func get_ability_payload(ability: AbilityDefinition) -> Resource:
	if ability == null:
		return null

	if ability.has_method("get_action_payload"):
		var method_payload: Variant = ability.get_action_payload()
		if method_payload is Resource:
			return method_payload as Resource

	if ability.payload != null:
		return ability.payload

	return null


static func apply_payload_definition(payload: DamagePayload, payload_def: Dictionary) -> void:
	if payload == null:
		return

	if payload_def.has("source_name"):
		payload.source_name = str(payload_def["source_name"])

	if payload_def.has("hit_type"):
		payload.hit_type = str(payload_def["hit_type"])

	if payload.status_effect == "" and payload_def.has("default_status_effect"):
		payload.status_effect = str(payload_def["default_status_effect"])

	if payload.status_duration <= 0.0 and payload_def.has("default_status_duration"):
		payload.status_duration = float(payload_def["default_status_duration"])

	if payload.status_strength <= 0.0 and payload_def.has("default_status_strength"):
		payload.status_strength = float(payload_def["default_status_strength"])

	if payload_def.has("tags") and payload_def["tags"] is Array:
		append_payload_tags(payload, payload_def["tags"])


static func append_payload_tags(payload: DamagePayload, tags_to_add: Array) -> void:
	if payload == null:
		return

	var next_tags: Array[String] = []

	for existing_tag: String in payload.tags:
		if existing_tag == "":
			continue
		if next_tags.has(existing_tag):
			continue
		next_tags.append(existing_tag)

	for tag_variant: Variant in tags_to_add:
		var tag: String = str(tag_variant)
		if tag == "":
			continue
		if next_tags.has(tag):
			continue
		next_tags.append(tag)

	payload.tags = next_tags
