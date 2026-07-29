extends "res://scripts/levels/prototype_animation_showcase_lab.gd"
class_name PrototypeAnimationShowcaseFireSpecialist

const CombatFeelDummyScene: PackedScene = preload(
	"res://scenes/actors/enemies/combat_feel_dummy.tscn"
)
const EnemyStatusReceiverScript = preload(
	"res://scripts/combat/status_receiver.gd"
)

@export_group("Showcase Mana Loop")
@export_range(1, 100, 1) var showcase_mana_capacity: int = 24
@export_range(0.0, 2.0, 0.05) var showcase_mana_regeneration_delay: float = 0.35
@export_range(0.25, 10.0, 0.05) var showcase_mana_empty_to_full_seconds: float = 1.4

var elemental_authority: PlayerElementalAuthorityController
var showcase_weapon: WeaponController
var manifestation_manager: PlayerManifestationManager
var showcase_mana_delay_remaining: float = 0.0
var showcase_mana_accumulator: float = 0.0
var observed_showcase_mana: int = 0


func _ready() -> void:
	super._ready()
	if player != null:
		elemental_authority = player.get_node_or_null(
			"ElementalAuthorityController"
		) as PlayerElementalAuthorityController
		showcase_weapon = player.get_node_or_null(
			"WeaponController"
		) as WeaponController
		manifestation_manager = player.get_node_or_null(
			"ManifestationManager"
		) as PlayerManifestationManager
	_configure_showcase_mana()
	_build_fire_specialist_bay()
	GameState.set_objective(
		"F9 incarnates Ruvia. F10 manifests her beside Grace. Test autonomous Firebolt, Haft Check into Fire Field, Hook pulls, field flares, thrust wakes, stairs, recall, and safe incarnation transfer. Mana rapidly recovers; F7 refills it."
	)


func _process(delta: float) -> void:
	_advance_showcase_mana(delta)
	super._process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if (
			key_event.pressed
			and not key_event.echo
			and key_event.physical_keycode == KEY_F7
		):
			_refill_showcase_mana(true)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func _reset_lab() -> void:
	if manifestation_manager != null:
		manifestation_manager.dismiss_manifestation("lab_reset")
	super._reset_lab()
	_refill_showcase_mana(false)


func _configure_showcase_mana() -> void:
	GameState.set_stat("max_mana", maxi(showcase_mana_capacity, 1))
	GameState.set_stat("mana", GameState.get_stat("max_mana"))
	observed_showcase_mana = GameState.get_stat("mana")
	showcase_mana_delay_remaining = 0.0
	showcase_mana_accumulator = 0.0


func _advance_showcase_mana(delta: float) -> void:
	if delta <= 0.0:
		return
	var maximum: int = GameState.get_stat("max_mana")
	var current: int = GameState.get_stat("mana")
	if maximum <= 0:
		return
	if current < observed_showcase_mana:
		showcase_mana_delay_remaining = showcase_mana_regeneration_delay
		showcase_mana_accumulator = 0.0
	observed_showcase_mana = current
	if current >= maximum:
		showcase_mana_delay_remaining = 0.0
		showcase_mana_accumulator = 0.0
		return
	showcase_mana_delay_remaining = maxf(
		showcase_mana_delay_remaining - delta,
		0.0
	)
	if showcase_mana_delay_remaining > 0.0:
		return
	var points_per_second: float = (
		float(maximum) / maxf(showcase_mana_empty_to_full_seconds, 0.01)
	)
	showcase_mana_accumulator += points_per_second * delta
	var whole_points: int = floori(showcase_mana_accumulator)
	if whole_points <= 0:
		return
	var restored: int = mini(whole_points, maximum - current)
	var next_mana: int = current + restored
	GameState.set_stat("mana", next_mana)
	observed_showcase_mana = next_mana
	showcase_mana_accumulator -= float(restored)


func _refill_showcase_mana(show_feedback: bool) -> void:
	var maximum: int = maxi(GameState.get_stat("max_mana"), 1)
	GameState.set_stat("mana", maximum)
	observed_showcase_mana = maximum
	showcase_mana_delay_remaining = 0.0
	showcase_mana_accumulator = 0.0
	if show_feedback:
		_show_message("Showcase mana restored.")


func _update_hud() -> void:
	super._update_hud()
	if status_label == null:
		return
	var authority: Dictionary = (
		elemental_authority.get_debug_data()
		if elemental_authority != null
		else {}
	)
	var rig_data: Dictionary = {}
	if showcase_weapon != null:
		var weapon_debug: Dictionary = showcase_weapon.get_debug_data()
		var runtime_value: Variant = weapon_debug.get("runtime_rig", {})
		if runtime_value is Dictionary:
			rig_data = runtime_value as Dictionary
	var manifestation: Dictionary = (
		manifestation_manager.get_debug_data()
		if manifestation_manager != null
		else {}
	)
	var manifestation_actor: Dictionary = {}
	var actor_value: Variant = manifestation.get("actor", {})
	if actor_value is Dictionary:
		manifestation_actor = actor_value as Dictionary
	var driver: Dictionary = {}
	var driver_value: Variant = manifestation_actor.get("driver", {})
	if driver_value is Dictionary:
		driver = driver_value as Dictionary
	var current_mana: int = GameState.get_stat("mana")
	var maximum_mana: int = GameState.get_stat("max_mana")
	var recharge_state: String = "FULL"
	if current_mana < maximum_mana:
		if showcase_mana_delay_remaining > 0.0:
			recharge_state = (
				"WAIT "
				+ str(snappedf(showcase_mana_delay_remaining, 0.05))
				+ "s"
			)
		else:
			recharge_state = "REGENERATING"
	status_label.text += (
		"\nLAB MANA  •  "
		+ str(current_mana)
		+ "/"
		+ str(maximum_mana)
		+ "     "
		+ recharge_state
		+ "     F7 FULL REFILL"
		+ "\nAUTHORITY  •  "
		+ str(authority.get("authority_id", "none")).to_upper()
		+ "     ELEMENT "
		+ str(authority.get("element", "none")).to_upper()
		+ "     FIELDS "
		+ str(authority.get("owned_fields", 0))
		+ "     WEAVE "
		+ str(authority.get("last_weave", "none")).to_upper()
		+ "     WINDOW "
		+ str(authority.get("weave_window", 0.0))
		+ "\nFIRE SPECIALIST  •  CAST "
		+ str(authority.get("last_cast_ability", "none")).to_upper()
		+ "     COST "
		+ str(authority.get("last_mana_cost", 0))
		+ "     WAKE "
		+ str(authority.get("total_wake_segments", 0))
		+ "     FLARES "
		+ str(authority.get("total_field_flares", 0))
		+ "     PULLS "
		+ str(rig_data.get("total_reaping_pull_count", 0))
		+ "     NEGATED "
		+ str(authority.get("negated_hits", 0))
		+ "     CONDUIT "
		+ (
			"ACTIVE"
			if bool(rig_data.get("authority_cast_active", false))
			else "READY"
		)
		+ "\nMANIFESTATION  •  "
		+ ("ACTIVE" if bool(manifestation.get("active", false)) else "READY")
		+ "     F10 TOGGLE     DRIVER "
		+ str(manifestation.get("driver_id", "none")).to_upper()
		+ "     TARGET "
		+ str(manifestation.get("target", "none")).to_upper()
		+ "     ACTION "
		+ str(manifestation.get("last_action", "none")).to_upper()
		+ "     FIELDS "
		+ str(manifestation.get("owned_fields", 0))
		+ "     RECALLS "
		+ str(manifestation.get("total_recalls", 0))
		+ "\nCOMPANION PLAN  •  "
		+ str(driver.get("decision_reason", "waiting")).to_upper()
		+ "     RANGE "
		+ str(driver.get("target_distance", -1.0))
		+ "     CLUSTER "
		+ str(driver.get("cluster_count", 0))
		+ "     BURNING "
		+ ("YES" if bool(driver.get("target_burning", false)) else "NO")
		+ "     FIELD PLAN "
		+ str(driver.get("pending_spell", "none")).to_upper()
		+ "     STUCK "
		+ str(manifestation.get("stuck_timer", 0.0))
	)


func _build_fire_specialist_bay() -> void:
	var bay_center: Vector3 = Vector3(-6.8, 0.035, -7.2)
	_add_box_body(
		"FireAuthorityFieldMarker",
		Vector3(3.4, 0.045, 3.4),
		bay_center,
		Color(0.72, 0.08, 0.025),
		false
	)
	_add_box_body(
		"FireAuthorityInnerMarker",
		Vector3(2.2, 0.055, 2.2),
		bay_center + Vector3.UP * 0.012,
		Color(1.0, 0.26, 0.035),
		false
	)
	for marker_index: int in range(4):
		_add_box_body(
			"ScorchingThrustWakeMarker" + str(marker_index),
			Vector3(1.0, 0.05, 0.16),
			bay_center
			+ Vector3(
				0.0,
				0.02,
				-2.1 - float(marker_index) * 0.8
			),
			Color(
				1.0,
				0.55 + float(marker_index) * 0.07,
				0.08
			),
			false
		)
	_build_fire_specialist_targets(bay_center)
	var field_label: Label3D = Label3D.new()
	field_label.text = (
		"RUVIA FIRE WEAVING\n"
		+ "HAFT + FIELD • HOOK PULL • WHEEL FLARE • THRUST WAKE"
	)
	field_label.position = bay_center + Vector3(0.0, 2.0, 0.0)
	field_label.font_size = 18
	field_label.pixel_size = 0.007
	field_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	field_label.outline_size = 7
	field_label.modulate = Color(1.0, 0.62, 0.18)
	add_child(field_label)
	var tip_label: Label3D = Label3D.new()
	tip_label.text = (
		"F9 → PLAY RUVIA\n"
		+ "F10 → MANIFEST RUVIA\n"
		+ "LIGHT 1/2 → FIREBOLT\n"
		+ "LIGHT 3 → FIRE FIELD\n"
		+ "GROUP → SOLAR DESCENT\n"
		+ "F7 → REFILL MANA"
	)
	tip_label.position = bay_center + Vector3(0.0, 1.28, 1.8)
	tip_label.font_size = 14
	tip_label.pixel_size = 0.006
	tip_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tip_label.outline_size = 5
	tip_label.modulate = Color(1.0, 0.82, 0.46)
	add_child(tip_label)
	_build_manifestation_marker(bay_center)


func _build_manifestation_marker(bay_center: Vector3) -> void:
	var marker_position: Vector3 = bay_center + Vector3(4.35, 0.02, 1.55)
	_add_box_body(
		"ManifestationControlMarker",
		Vector3(2.4, 0.05, 1.7),
		marker_position,
		Color(1.0, 0.18, 0.055),
		false
	)
	var label: Label3D = Label3D.new()
	label.text = "F10 • RUVIA MANIFESTATION\nAI DRIVER • SAFE RECALL • F9 TRANSFER"
	label.position = marker_position + Vector3.UP * 1.25
	label.font_size = 16
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 6
	label.modulate = Color(1.0, 0.52, 0.12)
	add_child(label)


func _build_fire_specialist_targets(bay_center: Vector3) -> void:
	var target_positions: Array[Vector3] = [
		bay_center + Vector3(0.0, -0.035, -1.0),
		bay_center + Vector3(-1.45, -0.035, -3.65),
		bay_center + Vector3(0.0, -0.035, -4.15),
		bay_center + Vector3(1.45, -0.035, -3.65),
	]
	for target_index: int in range(target_positions.size()):
		var target: Node = CombatFeelDummyScene.instantiate()
		if not (target is Node3D):
			target.queue_free()
			continue
		var target_3d: Node3D = target as Node3D
		target_3d.name = "FireSpecialistTarget" + str(target_index + 1)
		target_3d.position = target_positions[target_index]
		if target_3d.get_node_or_null("StatusReceiver") == null:
			var status_receiver: Node = EnemyStatusReceiverScript.new()
			status_receiver.name = "StatusReceiver"
			target_3d.add_child(status_receiver)
		add_child(target_3d)
