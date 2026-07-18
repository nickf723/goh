extends Node
class_name WeaponThreatBroadcaster

@export var enabled: bool = true
@export var origin_height: float = 1.0
@export var close_range_radius: float = 0.85
@export var lifetime_padding: float = 0.18
@export var show_debug_prints: bool = false

var weapon_controller: WeaponController
var current_threat: CombatThreat


func _ready() -> void:
	weapon_controller = get_parent() as WeaponController
	if weapon_controller == null:
		push_warning("WeaponThreatBroadcaster must be a child of WeaponController.")
		return

	if not weapon_controller.attack_started.is_connected(_on_attack_started):
		weapon_controller.attack_started.connect(_on_attack_started)
	if not weapon_controller.attack_finished.is_connected(_on_attack_finished):
		weapon_controller.attack_finished.connect(_on_attack_finished)


func _process(_delta: float) -> void:
	if current_threat == null or current_threat.is_expired():
		current_threat = null
		return

	if weapon_controller == null:
		current_threat.cancelled = true
		current_threat = null
		return

	if weapon_controller.current_attack == null and current_threat.get_time_until_impact() > 0.0:
		current_threat.cancelled = true
		current_threat = null


func _on_attack_started(attack: WeaponAttackDefinition) -> void:
	if not enabled or weapon_controller == null or attack == null:
		return

	if current_threat != null and current_threat.get_time_until_impact() > 0.0:
		current_threat.cancelled = true

	var actor: Node3D = weapon_controller.get_actor()
	if actor == null:
		return

	var weapon: WeaponDefinition = weapon_controller.equipped_weapon
	var attack_speed: float = weapon_controller.get_attack_speed()
	var payload: DamagePayload = attack.build_payload(weapon)
	var threat_tags: Array[String] = []
	append_unique_tag(threat_tags, "weapon")
	append_unique_tag(threat_tags, "melee")
	append_unique_tag(threat_tags, attack.input_kind)

	if weapon != null:
		append_unique_tag(threat_tags, weapon.weapon_class)

	for tag: String in attack.extra_tags:
		append_unique_tag(threat_tags, tag)
	if payload != null:
		for tag: String in payload.tags:
			append_unique_tag(threat_tags, tag)

	var severity: float = max(attack.damage_multiplier, 0.0)
	severity += max(attack.stance_multiplier, 0.0) * 0.5
	if payload != null:
		severity += float(max(payload.amount, 0)) * 0.25

	current_threat = CombatThreat.new().configure(
		attack.attack_id,
		(weapon.display_name + " • " if weapon != null else "") + attack.display_name,
		actor,
		origin_height,
		weapon_controller.get_attack_forward(),
		attack.get_startup_duration(attack_speed),
		attack.get_active_duration(attack_speed),
		attack.attack_range,
		attack.cone_angle_degrees,
		attack.attack_center_forward_offset,
		close_range_radius,
		severity,
		threat_tags
	)
	current_threat.lifetime_padding = lifetime_padding

	get_tree().call_group("combat_threat_sensors", "receive_combat_threat", current_threat)

	if show_debug_prints:
		print("Threat broadcast: ", current_threat.get_debug_summary())


func _on_attack_finished(_attack_id: String) -> void:
	if current_threat == null:
		return
	if current_threat.get_time_until_impact() > 0.0:
		current_threat.cancelled = true
	current_threat = null


func append_unique_tag(target: Array[String], tag: String) -> void:
	var normalized: String = tag.to_lower().strip_edges()
	if normalized == "" or target.has(normalized):
		return
	target.append(normalized)
