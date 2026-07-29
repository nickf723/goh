extends "res://scripts/levels/prototype_animation_showcase_lab.gd"
class_name PrototypeAnimationShowcaseFireSpecialist

const CombatFeelDummyScene: PackedScene = preload(
	"res://scenes/actors/enemies/combat_feel_dummy.tscn"
)

var elemental_authority: PlayerElementalAuthorityController
var showcase_weapon: WeaponController


func _ready() -> void:
	super._ready()
	if player != null:
		elemental_authority = player.get_node_or_null(
			"ElementalAuthorityController"
		) as PlayerElementalAuthorityController
		showcase_weapon = player.get_node_or_null(
			"WeaponController"
		) as WeaponController
	_build_fire_specialist_bay()
	GameState.set_objective(
		"Press F9 for Ruvia. Weave Firebolt from Cinder Sweep, plant Fire Field after Haft Check, pull through it with Reaping Hook, flare it with Ember Wheel, then thrust through it."
	)


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
	status_label.text += (
		"\nAUTHORITY  •  "
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
		+ "     MANA "
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
		"LIGHT 1/2 → FIREBOLT\n"
		+ "LIGHT 3 → FIRE FIELD\n"
		+ "GROUP → SOLAR DESCENT"
	)
	tip_label.position = bay_center + Vector3(0.0, 1.1, 1.8)
	tip_label.font_size = 14
	tip_label.pixel_size = 0.006
	tip_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tip_label.outline_size = 5
	tip_label.modulate = Color(1.0, 0.82, 0.46)
	add_child(tip_label)


func _build_fire_specialist_targets(bay_center: Vector3) -> void:
	var target_positions: Array[Vector3] = [
		bay_center + Vector3(0.0, -0.035, -1.0),
		bay_center + Vector3(-1.45, -0.035, -3.65),
		bay_center + Vector3(0.0, -0.035, -4.15),
		bay_center + Vector3(1.45, -0.035, -3.65),
	]
	for target_index: int in range(target_positions.size()):
		var target: Node = CombatFeelDummyScene.instantiate()
		if not target is Node3D:
			target.queue_free()
			continue
		var target_3d: Node3D = target as Node3D
		target_3d.name = "FireSpecialistTarget" + str(target_index + 1)
		add_child(target_3d)
		target_3d.global_position = target_positions[target_index]
