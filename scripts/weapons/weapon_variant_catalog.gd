extends RefCounted
class_name WeaponVariantCatalog

const WeaponMasteryCatalogScript = preload(
	"res://scripts/weapons/weapon_mastery_catalog.gd"
)

const CLASS_DESCRIPTIONS: Dictionary = {
	"sword": "Balanced blades ranging from nimble fencing weapons to committed two-handed forms.",
	"lance": "Long thrusting weapons built around spacing, advancing pressure, and precise tips.",
	"axe": "Hooking and cleaving weapons that trade recovery for force and broad arcs.",
	"bow": "Ranged launchers distinguished by draw weight, limb shape, and firing rhythm.",
	"hammer": "Blunt impact weapons focused on stance break, armor damage, and committed blows.",
	"mace": "Compact crushing weapons with weighted heads and reliable close-range pressure.",
	"daggers": "Short paired blades built for speed, angle changes, and deep combo strings.",
	"whip": "Flexible line-control weapons that vary through length, material, and striking tip.",
	"chains": "Free-flowing tether weapons using hooks, darts, blades, and weighted ends.",
	"gauntlets": "Hand-mounted weapons ranging from reinforced fists to claws and striking frames.",
	"flail": "Weighted swinging heads whose chain length and head count reshape their orbit.",
	"halberd": "Polearms mixing thrust, chop, hook, and sweep through radically different head geometry.",
	"boomerang": "Returning weapons including bent throwers, bladed returners, and chakrams.",
	"scythe": "Reaping weapons built around crescent arcs, pulls, and execution sweeps.",
	"staff": "Versatile pole weapons that blend defense, leverage, resonance, and spellwork.",
	"shuriken": "Compact thrown arsenals ranging from stars and spikes to heavy windmill blades.",
}

const VARIANTS: Dictionary = {
	"sword": [
		{"id": "arming_sword", "name": "Arming Sword", "item_id": "practice_sword", "description": "A balanced one-handed baseline with adaptable cuts and thrusts."},
		{"id": "rapier", "name": "Rapier", "description": "A narrow fencing blade emphasizing lunges, precision, and counterthrusts."},
		{"id": "saber", "name": "Saber", "description": "A curved cutting sword designed for flowing movement and passing attacks."},
		{"id": "greatsword", "name": "Greatsword", "description": "A long two-handed blade trading speed for reach, guard pressure, and broad control."},
	],
	"lance": [
		{"id": "spear", "name": "Spear", "item_id": "training_spear", "description": "A flexible thrusting polearm with quick recovery and strong spacing."},
		{"id": "pike", "name": "Pike", "description": "Extreme reach and formation control at the cost of close-range flexibility."},
		{"id": "partisan", "name": "Partisan", "description": "A winged spear that adds catches, parries, and short cutting arcs."},
		{"id": "cavalry_lance", "name": "Cavalry Lance", "description": "A committed driving weapon built for charges and devastating linear impact."},
	],
	"axe": [
		{"id": "hand_axe", "name": "Hand Axe", "description": "A compact chopping weapon with quick hooks and throws."},
		{"id": "battleaxe", "name": "Battleaxe", "description": "A broad one-handed axe balancing cleave, hook, and guard pressure."},
		{"id": "dane_axe", "name": "Dane Axe", "description": "A long-hafted cutter with sweeping reach and committed recovery."},
		{"id": "greataxe", "name": "Greataxe", "description": "Maximum cleaving force with slow, terrain-commanding arcs."},
	],
	"bow": [
		{"id": "shortbow", "name": "Shortbow", "description": "Fast shots, mobile aim, and compact handling."},
		{"id": "longbow", "name": "Longbow", "description": "Heavy draw weight and long-range precision."},
		{"id": "recurve", "name": "Recurve Bow", "description": "A responsive bow balancing power with quick handling."},
		{"id": "warbow", "name": "Warbow", "description": "A punishing high-draw bow designed for armor and stance pressure."},
	],
	"hammer": [
		{"id": "maul", "name": "Maul", "item_id": "training_hammer", "description": "A two-handed crushing head for broad stance-breaking blows."},
		{"id": "warhammer", "name": "Warhammer", "description": "A compact hammer balancing blunt impact with a piercing back spike."},
		{"id": "lucerne", "name": "Lucerne Hammer", "description": "A long pole hammer built for reach, armor puncture, and leverage."},
		{"id": "sledge", "name": "Sledge Hammer", "description": "Slow industrial force translated into brutal combat momentum."},
	],
	"mace": [
		{"id": "flanged_mace", "name": "Flanged Mace", "description": "Focused crushing ridges that bite into armor and stance."},
		{"id": "club", "name": "War Club", "description": "A simple weighted body with reliable, readable impact."},
		{"id": "kanabo", "name": "Kanabo", "description": "A heavy studded club with devastating committed swings."},
		{"id": "scepter", "name": "Battle Scepter", "description": "A compact ceremonial mace blending magical focus with blunt force."},
	],
	"daggers": [
		{"id": "twin_daggers", "name": "Twin Daggers", "description": "Matched blades for rapid alternating strings."},
		{"id": "dirks", "name": "Dirks", "description": "Long defensive daggers suited to parries and close thrusts."},
		{"id": "stilettos", "name": "Stilettos", "description": "Needle-like blades built around weak-point precision."},
		{"id": "kukris", "name": "Kukris", "description": "Forward-curved chopping knives with surprising cleaving authority."},
	],
	"whip": [
		{"id": "bullwhip", "name": "Bullwhip", "description": "Long reach, cracking tip speed, and precise line control."},
		{"id": "ribbon_whip", "name": "Ribbon Whip", "description": "A wide flowing weapon that paints persistent sweeping zones."},
		{"id": "thorn_lash", "name": "Thorn Lash", "description": "A barbed flexible strand that rewards catches and dragging hits."},
		{"id": "segmented_whip", "name": "Segmented Whip", "description": "Linked rigid sections combining whip reach with blade-like impact."},
	],
	"chains": [
		{"id": "chain_blades", "name": "Chain Blades", "description": "Paired blades on tethers for orbiting attacks and retrieval."},
		{"id": "rope_dart", "name": "Rope Dart", "description": "A compact piercing head accelerated through flowing body movement."},
		{"id": "meteor_chain", "name": "Meteor Chain", "description": "Weighted ends that build momentum through continuous circles."},
		{"id": "hook_chains", "name": "Hook Chains", "description": "Hooked ends designed to pull enemies, objects, and defenses apart."},
	],
	"gauntlets": [
		{"id": "cestus", "name": "Cestus", "description": "Reinforced fists preserving speed and grappling freedom."},
		{"id": "tonfa", "name": "Tonfa Gauntlets", "description": "Forearm guards that blend blocks, elbows, and rotational strikes."},
		{"id": "claws", "name": "Claw Gauntlets", "description": "Extended talons emphasizing rakes, aerial catches, and bleed pressure."},
		{"id": "impact_frames", "name": "Impact Frames", "description": "Mechanical striking braces built for charged punches and launch force."},
	],
	"flail": [
		{"id": "one_hand_flail", "name": "One-Handed Flail", "description": "A short chain and compact head for shield-breaking close pressure."},
		{"id": "great_flail", "name": "Great Flail", "description": "A long two-handed orbit with huge area denial."},
		{"id": "triple_flail", "name": "Triple Flail", "description": "Three smaller heads creating chaotic multi-hit patterns."},
		{"id": "meteor_hammer", "name": "Meteor Hammer", "description": "A long rope-mounted weight blending flail force with tether mobility."},
	],
	"halberd": [
		{"id": "classic_halberd", "name": "Classic Halberd", "description": "A balanced axe, spear point, and rear hook in one adaptable head."},
		{"id": "glaive", "name": "Glaive", "description": "A long single-edged blade favoring flowing cuts and broad sweeps."},
		{"id": "bardiche", "name": "Bardiche", "description": "An elongated axe blade producing heavy cleaves along a long haft."},
		{"id": "poleaxe", "name": "Poleaxe", "description": "A compact armored-fighting head combining hammer, spike, and axe."},
	],
	"boomerang": [
		{"id": "hunting_boomerang", "name": "Hunting Boomerang", "description": "A heavy curved thrower built for direct impact and reliable return."},
		{"id": "war_boomerang", "name": "War Boomerang", "description": "A larger edged returner with broad cutting passes."},
		{"id": "chakram", "name": "Chakram", "description": "A circular blade that supports ricochets, rolling cuts, and returning arcs."},
		{"id": "split_returner", "name": "Split Returner", "description": "A paired folding thrower that separates outward and rejoins on return."},
	],
	"scythe": [
		{"id": "war_scythe", "name": "War Scythe", "description": "A forward-set blade for direct cuts, thrusts, and formation pressure."},
		{"id": "crescent_scythe", "name": "Crescent Scythe", "description": "A deep curved blade designed for reaping sweeps and pulls."},
		{"id": "kama_pair", "name": "Kama Pair", "description": "Twin hand scythes trading reach for speed and climbing hooks."},
		{"id": "great_reaper", "name": "Great Reaper", "description": "An oversized execution scythe with enormous commitment and payoff."},
	],
	"staff": [
		{"id": "quarterstaff", "name": "Quarterstaff", "description": "A balanced wooden pole with rapid transitions between offense and defense."},
		{"id": "battle_staff", "name": "Battle Staff", "description": "Reinforced ends for heavier impact and stance control."},
		{"id": "scepter_staff", "name": "Scepter Staff", "description": "A magical focus mounted on a combat-capable haft."},
		{"id": "crook_staff", "name": "Crook Staff", "description": "A hooked staff for trips, catches, vaults, and creature handling."},
	],
	"shuriken": [
		{"id": "hira_shuriken", "name": "Hira Shuriken", "description": "Flat throwing stars suited to rapid volleys and marks."},
		{"id": "kunai", "name": "Kunai", "description": "Straight utility blades balancing throws with close combat."},
		{"id": "senbon", "name": "Senbon", "description": "Needle projectiles built for precision, status delivery, and saturation."},
		{"id": "fuuma", "name": "Fuuma Shuriken", "description": "A large windmill blade with slower throws and dramatic returning force."},
	],
}


static func get_class_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for weapon_class: String in WeaponMasteryCatalogScript.WEAPON_CLASSES:
		var definition: Dictionary = WeaponMasteryCatalogScript.get_definition(weapon_class)
		rows.append({
			"id": weapon_class,
			"name": str(definition.get("name", weapon_class.capitalize())),
			"icon": str(definition.get("icon", "◇")),
			"description": str(CLASS_DESCRIPTIONS.get(weapon_class, "A weapon class.")),
			"variant_count": get_variants(weapon_class).size(),
		})
	return rows


static func get_class_definition(weapon_class: String) -> Dictionary:
	for row: Dictionary in get_class_rows():
		if str(row.get("id", "")) == weapon_class:
			return row
	return {}


static func get_variants(weapon_class: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var values: Variant = VARIANTS.get(weapon_class, [])
	if values is Array:
		for value: Variant in values as Array:
			if value is Dictionary:
				rows.append((value as Dictionary).duplicate(true))
	return rows


static func get_variant(weapon_class: String, variant_id: String) -> Dictionary:
	for row: Dictionary in get_variants(weapon_class):
		if str(row.get("id", "")) == variant_id:
			return row
	return {}
