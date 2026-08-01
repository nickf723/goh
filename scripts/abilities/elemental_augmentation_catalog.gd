extends RefCounted
class_name ElementalAugmentationCatalog

const UNLOCK_ID: String = "elemental_augmentation"

const ELEMENT_ORDER: Array[String] = [
	"water", "earth", "fire", "air",
	"ice", "metal", "lightning", "poison",
	"life", "death", "body", "soul",
	"dreams", "sound", "space", "time",
]

# Augmentations are directed recipes. The presence of A → B never implies B → A.
# These rows are data/UI foundations. Runtime payload transformation is a later
# integration layer and should consume this catalog rather than inventing pairs.
const OPTIONS: Dictionary = {
	"water": [
		{"target": "ice", "name": "Cryoflow", "result": "Water spells chill, preserve, and build toward freezing.", "tags": ["chill", "freeze", "preserve"]},
		{"target": "lightning", "name": "Conductive Current", "result": "Water spells prime conductive paths and carry electrical reactions.", "tags": ["wet", "conductive", "chain"]},
	],
	"earth": [
		{"target": "life", "name": "Verdant Stone", "result": "Earth spells sprout roots, moss, and regenerative terrain.", "tags": ["growth", "root", "terrain"]},
		{"target": "metal", "name": "Orebound", "result": "Earth spells gain metallic armor, weight, and structural force.", "tags": ["armor", "ore", "fortify"]},
	],
	"fire": [
		{"target": "air", "name": "Wildfire Draft", "result": "Fire spreads farther, rides currents, and gains directional force.", "tags": ["spread", "lift", "knockback"]},
		{"target": "poison", "name": "Toxic Combustion", "result": "Fire produces venomous smoke and lingering chemical burns.", "tags": ["smoke", "poison", "hazard"]},
	],
	"air": [
		{"target": "poison", "name": "Miasma", "result": "Air spells carry poisonous clouds, spores, and exposure buildup.", "tags": ["cloud", "poison", "exposure"]},
		{"target": "lightning", "name": "Stormwind", "result": "Air currents ionize, shock, and feed storm reactions.", "tags": ["ionized", "shock", "storm"]},
	],
	"ice": [
		{"target": "fire", "name": "Burning Ice", "result": "Cold flame burns while preserving chill and shatter setup.", "tags": ["cold_flame", "burn", "chill"]},
		{"target": "sound", "name": "Singing Crystal", "result": "Ice resonates, reveals through echoes, and fractures at tuned frequencies.", "tags": ["resonance", "reveal", "shatter"]},
	],
	"metal": [
		{"target": "lightning", "name": "Livewire Alloy", "result": "Metal spells conduct, stun, and retain electrical charge.", "tags": ["conductive", "stun", "stored_charge"]},
		{"target": "fire", "name": "Molten Form", "result": "Metal spells heat, melt defenses, and leave incandescent surfaces.", "tags": ["molten", "burn", "melt"]},
	],
	"lightning": [
		{"target": "fire", "name": "Scarlet Arc", "result": "Lightning turns scarlet, ignites targets, and leaves burning discharge.", "tags": ["scarlet", "burn", "ignite"]},
		{"target": "sound", "name": "Thunderwave", "result": "Lightning carries concussive resonance and thunderous stagger.", "tags": ["thunder", "resonance", "stagger"]},
	],
	"poison": [
		{"target": "air", "name": "Aerosol Venom", "result": "Poison disperses into mobile clouds and wider exposure zones.", "tags": ["aerosol", "cloud", "exposure"]},
		{"target": "life", "name": "Parasitic Bloom", "result": "Poison grows invasive flora that feeds on afflicted targets.", "tags": ["parasite", "growth", "drain"]},
	],
	"life": [
		{"target": "earth", "name": "Rooted Growth", "result": "Life magic gains roots, stone anchors, and persistent terrain forms.", "tags": ["root", "terrain", "anchor"]},
		{"target": "water", "name": "Regenerative Flow", "result": "Life spreads through currents, cleansing and restoring along its path.", "tags": ["flow", "cleanse", "regeneration"]},
	],
	"death": [
		{"target": "poison", "name": "Miasmic Decay", "result": "Death produces toxic rot, exposure, and lingering decomposition.", "tags": ["decay", "poison", "rot"]},
		{"target": "soul", "name": "Haunting Decay", "result": "Death spells leave echoes that frighten, mark, or pursue souls.", "tags": ["haunt", "soul_mark", "fear"]},
	],
	"body": [
		{"target": "life", "name": "Regenerative Flesh", "result": "Body alterations heal, regrow, and sustain transformed forms.", "tags": ["regeneration", "heal", "adapt"]},
		{"target": "metal", "name": "Iron Flesh", "result": "Body spells harden skin, reinforce strikes, and increase mass.", "tags": ["armor", "mass", "fortify"]},
	],
	"soul": [
		{"target": "dreams", "name": "Phantasmal Soul", "result": "Soul constructs gain illusion, sleep, and dreamlike misdirection.", "tags": ["illusion", "sleep", "phantasm"]},
		{"target": "death", "name": "Necromantic Echo", "result": "Soul spells bind remains, preserve echoes, and command the dead.", "tags": ["necromancy", "echo", "bind"]},
	],
	"dreams": [
		{"target": "sound", "name": "Lullaby", "result": "Dreams travel through rhythm, emotion, and resonant suggestion.", "tags": ["lullaby", "emotion", "sleep"]},
		{"target": "space", "name": "Impossible Dream", "result": "Dreams distort distance, orientation, and local geometry.", "tags": ["impossible_geometry", "warp", "disorient"]},
	],
	"sound": [
		{"target": "lightning", "name": "Electromagnetic Resonance", "result": "Sound produces electromagnetic waves, charge, and conductive pulses.", "tags": ["electromagnetic", "charge", "pulse"]},
		{"target": "air", "name": "Pressure Chorus", "result": "Sound gains wind pressure, lift, and physical wavefronts.", "tags": ["pressure", "lift", "wavefront"]},
	],
	"space": [
		{"target": "time", "name": "Gravitic Delay", "result": "Space distortions slow motion and stretch the timing of nearby actions.", "tags": ["gravity", "slow", "delay"]},
		{"target": "dreams", "name": "Unreal Space", "result": "Space folds into deceptive paths, false distances, and liminal rooms.", "tags": ["liminal", "illusion", "false_distance"]},
	],
	"time": [
		{"target": "space", "name": "Warped Interval", "result": "Time effects displace positions and bend paths through short warps.", "tags": ["warp", "displace", "interval"]},
		{"target": "death", "name": "Accelerated Decay", "result": "Time rapidly ages, withers, and decomposes affected matter.", "tags": ["age", "wither", "decay"]},
	],
}


static func has_element(element_id: String) -> bool:
	return ELEMENT_ORDER.has(element_id)


static func get_options(source_element: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var raw_value: Variant = OPTIONS.get(source_element, [])
	if not raw_value is Array:
		return rows
	for value: Variant in raw_value as Array:
		if value is Dictionary:
			var row: Dictionary = (value as Dictionary).duplicate(true)
			row["source"] = source_element
			rows.append(row)
	return rows


static func is_valid_pair(source_element: String, target_element: String) -> bool:
	if target_element == "":
		return has_element(source_element)
	for row: Dictionary in get_options(source_element):
		if str(row.get("target", "")) == target_element:
			return true
	return false


static func get_option(source_element: String, target_element: String) -> Dictionary:
	for row: Dictionary in get_options(source_element):
		if str(row.get("target", "")) == target_element:
			return row
	return {}


static func get_pair_label(source_element: String, target_element: String) -> String:
	if target_element == "":
		return source_element.capitalize() + " • Pure"
	var option: Dictionary = get_option(source_element, target_element)
	return str(option.get("name", source_element.capitalize() + " → " + target_element.capitalize()))


static func validate_catalog() -> Array[String]:
	var failures: Array[String] = []
	for source_element: String in ELEMENT_ORDER:
		var rows: Array[Dictionary] = get_options(source_element)
		if rows.is_empty():
			failures.append(source_element + " has no augmentation options")
		var seen_targets: Dictionary = {}
		for row: Dictionary in rows:
			var target: String = str(row.get("target", ""))
			if not has_element(target):
				failures.append(source_element + " targets invalid element " + target)
			if target == source_element:
				failures.append(source_element + " cannot augment itself")
			if seen_targets.has(target):
				failures.append(source_element + " repeats target " + target)
			seen_targets[target] = true
			if str(row.get("name", "")).strip_edges() == "":
				failures.append(source_element + " → " + target + " has no name")
			if str(row.get("result", "")).strip_edges() == "":
				failures.append(source_element + " → " + target + " has no result summary")
	return failures
