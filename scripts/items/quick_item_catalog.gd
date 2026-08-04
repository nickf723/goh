extends RefCounted
class_name QuickItemCatalog

const HealingFlask: QuickItemDefinition = preload("res://data/items/healing_flask.tres")
const OilFlask: QuickItemDefinition = preload("res://data/items/oil_flask.tres")
const NoiseMaker: QuickItemDefinition = preload("res://data/items/noise_maker.tres")
const HealingPotion: QuickItemDefinition = preload("res://data/items/healing_potion.tres")
const ResonanceTonic: QuickItemDefinition = preload("res://data/items/resonance_tonic.tres")
const FrostVigorDraught: QuickItemDefinition = preload("res://data/items/frost_vigor_draught.tres")
const Antidote: QuickItemDefinition = preload("res://data/items/antidote.tres")
const ConductiveElixir: QuickItemDefinition = preload("res://data/items/conductive_elixir.tres")
const SwiftTonic: QuickItemDefinition = preload("res://data/items/swift_tonic.tres")
const ArcaneDraught: QuickItemDefinition = preload("res://data/items/arcane_draught.tres")
const IronbarkBrew: QuickItemDefinition = preload("res://data/items/ironbark_brew.tres")
const FieldTreat: QuickItemDefinition = preload("res://data/items/field_treat.tres")
const RecordedCrateBlueprint: QuickItemDefinition = preload(
	"res://data/items/recorded_crate_blueprint.tres"
)
const RecordedPlatformBlueprint: QuickItemDefinition = preload(
	"res://data/items/recorded_platform_blueprint.tres"
)
const RecordedSpringBlueprint: QuickItemDefinition = preload(
	"res://data/items/recorded_spring_blueprint.tres"
)
const RecordedBlastBarrelBlueprint: QuickItemDefinition = preload(
	"res://data/items/recorded_blast_barrel_blueprint.tres"
)
const BridgeFrameBlueprint: QuickItemDefinition = preload(
	"res://data/items/bridge_frame_blueprint.tres"
)
const LaunchTowerBlueprint: QuickItemDefinition = preload(
	"res://data/items/launch_tower_blueprint.tres"
)
const BlastCartBlueprint: QuickItemDefinition = preload(
	"res://data/items/blast_cart_blueprint.tres"
)
const ConductiveRaftBlueprint: QuickItemDefinition = preload(
	"res://data/items/conductive_raft_blueprint.tres"
)

const ITEM_IDS: Array[String] = [
	"healing_flask",
	"oil_flask",
	"noise_maker",
	"healing_potion",
	"resonance_tonic",
	"frost_vigor_draught",
	"antidote",
	"conductive_elixir",
	"swift_tonic",
	"arcane_draught",
	"ironbark_brew",
	"field_treat",
	"recorded_crate_blueprint",
	"recorded_platform_blueprint",
	"recorded_spring_blueprint",
	"recorded_blast_barrel_blueprint",
	"bridge_frame_blueprint",
	"launch_tower_blueprint",
	"blast_cart_blueprint",
	"conductive_raft_blueprint",
]


static func get_item(item_id: String) -> QuickItemDefinition:
	match item_id:
		"healing_flask":
			return HealingFlask
		"oil_flask":
			return OilFlask
		"noise_maker":
			return NoiseMaker
		"healing_potion":
			return HealingPotion
		"resonance_tonic":
			return ResonanceTonic
		"frost_vigor_draught":
			return FrostVigorDraught
		"antidote":
			return Antidote
		"conductive_elixir":
			return ConductiveElixir
		"swift_tonic":
			return SwiftTonic
		"arcane_draught":
			return ArcaneDraught
		"ironbark_brew":
			return IronbarkBrew
		"field_treat":
			return FieldTreat
		"recorded_crate_blueprint":
			return RecordedCrateBlueprint
		"recorded_platform_blueprint":
			return RecordedPlatformBlueprint
		"recorded_spring_blueprint":
			return RecordedSpringBlueprint
		"recorded_blast_barrel_blueprint":
			return RecordedBlastBarrelBlueprint
		"bridge_frame_blueprint":
			return BridgeFrameBlueprint
		"launch_tower_blueprint":
			return LaunchTowerBlueprint
		"blast_cart_blueprint":
			return BlastCartBlueprint
		"conductive_raft_blueprint":
			return ConductiveRaftBlueprint
		_:
			return null


static func get_all_items() -> Array[QuickItemDefinition]:
	return [
		HealingFlask,
		OilFlask,
		NoiseMaker,
		HealingPotion,
		ResonanceTonic,
		FrostVigorDraught,
		Antidote,
		ConductiveElixir,
		SwiftTonic,
		ArcaneDraught,
		IronbarkBrew,
		FieldTreat,
		RecordedCrateBlueprint,
		RecordedPlatformBlueprint,
		RecordedSpringBlueprint,
		RecordedBlastBarrelBlueprint,
		BridgeFrameBlueprint,
		LaunchTowerBlueprint,
		BlastCartBlueprint,
		ConductiveRaftBlueprint,
	]


static func get_inventory_rows(inventory: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item_id: String in ITEM_IDS:
		var item := get_item(item_id)
		if item == null:
			continue
		var count: int = int(inventory.get(item_id, 0))
		if count <= 0 and not inventory.has(item_id):
			continue
		rows.append({
			"id": item.item_id,
			"name": item.display_name,
			"short_label": item.short_label,
			"description": item.description,
			"icon": item.icon_symbol,
			"count": count,
			"maximum": item.get_max_stack(),
			"refill_on_rest": item.refill_on_rest,
			"effect": item.effect_type,
			"element": item.element,
			"tags": item.tags.duplicate(),
		})
	return rows
