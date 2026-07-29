extends "res://scripts/levels/prototype_animation_showcase_fire_specialist.gd"
class_name PrototypeAnimationShowcaseDivineSpecials

const DivineSpecialDummyScene: PackedScene = preload(
	"res://scenes/actors/enemies/combat_feel_dummy.tscn"
)
const DivineSpecialStatusReceiverScript = preload(
	"res://scripts/combat/status_receiver.gd"
)

var divine_special_controller: PlayerDivineSpecialController


func _ready() -> void:
	super._ready()
	if player != null:
		divine_special_controller = player.get_node_or_null(
			"DivineSpecialController"
		) as PlayerDivineSpecialController
	_build_divine_special_range()
	GameState.set_objective(
		"F11 activates the selected Divine Special. Shift+F11 cycles Caldera Drop, Wildfire Procession, and Hearth of the First Flame. F6 refills Divine Charge. F9 incarnates Ruvia; F10 manifests her."
	)


func _update_hud() -> void:
	super._update_hud()
	if status_label == null:
		return
	var special: Dictionary = (
		divine_special_controller.get_debug_data()
		if divine_special_controller != null
		else {}
	)
	var last_effect: Dictionary = {}
	var last_effect_value: Variant = special.get("last_effect", {})
	if last_effect_value is Dictionary:
		last_effect = last_effect_value as Dictionary
	status_label.text += (
		"\nDIVINE SPECIAL  •  "
		+ str(special.get("selected_name", "NONE")).to_upper()
		+ "     CHARGE "
		+ str(roundi(float(special.get("charge", 0.0))))
		+ "%     "
		+ ("READY" if bool(special.get("ready", false)) else "RECHARGING")
		+ "     F11 ACTIVATE     SHIFT+F11 CYCLE     F6 FULL"
		+ "\nSPECIAL STATE  •  "
		+ ("ACTIVE" if bool(special.get("active", false)) else "IDLE")
		+ "     RESULT "
		+ str(special.get("last_result", "none")).to_upper()
		+ "     TARGETS "
		+ str(last_effect.get("targets_hit", 0))
		+ "     PROJECTILES "
		+ str(last_effect.get("projectiles_cleared", 0))
		+ "     FIELDS "
		+ str(last_effect.get("persistent_nodes_spawned", 0))
	)


func _build_divine_special_range() -> void:
	var range_center: Vector3 = Vector3(7.4, 0.035, -7.2)
	# The base motion floor ends before the complete Procession lane. This dedicated
	# platform keeps all eight eruption markers, clustered targets, and the Hearth
	# radius on one continuous physical surface rather than hanging over the void.
	_add_box_body(
		"DivineSpecialRangeFloor",
		Vector3(10.8, 0.25, 18.0),
		Vector3(7.4, -0.125, -12.0),
		Color(0.075, 0.045, 0.04)
	)
	_add_box_body(
		"CalderaDropMarker",
		Vector3(4.6, 0.045, 4.6),
		range_center,
		Color(0.72, 0.08, 0.025),
		false
	)
	_add_box_body(
		"HearthDomainMarker",
		Vector3(8.6, 0.035, 8.6),
		range_center + Vector3(0.0, -0.006, 0.0),
		Color(0.28, 0.055, 0.025),
		false
	)
	for marker_index: int in range(8):
		_add_box_body(
			"WildfireProcessionMarker" + str(marker_index + 1),
			Vector3(0.9, 0.055, 0.22),
			range_center
			+ Vector3(
				0.0,
				0.018,
				-3.0 - float(marker_index) * 1.25
			),
			Color(1.0, 0.32 + float(marker_index) * 0.055, 0.04),
			false
		)

	var title: Label3D = Label3D.new()
	title.text = "DIVINE SPECIALS\nBREAK GLASS TO ALTER BATTLEFIELD"
	title.position = range_center + Vector3(0.0, 2.25, 1.8)
	title.font_size = 20
	title.pixel_size = 0.007
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.outline_size = 7
	title.modulate = Color(1.0, 0.62, 0.14)
	add_child(title)

	var instructions: Label3D = Label3D.new()
	instructions.text = (
		"F11 • ACTIVATE\n"
		+ "SHIFT+F11 • CYCLE\n"
		+ "F6 • FULL CHARGE\n"
		+ "CALDERA • BURST\n"
		+ "PROCESSION • TRAVELING FIRE\n"
		+ "HEARTH • PROTECTIVE DOMAIN"
	)
	instructions.position = range_center + Vector3(0.0, 1.3, 2.8)
	instructions.font_size = 15
	instructions.pixel_size = 0.006
	instructions.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	instructions.outline_size = 5
	instructions.modulate = Color(1.0, 0.82, 0.42)
	add_child(instructions)
	_build_divine_special_targets(range_center)


func _build_divine_special_targets(range_center: Vector3) -> void:
	var target_positions: Array[Vector3] = [
		range_center + Vector3(0.0, -0.035, -0.4),
		range_center + Vector3(-1.75, -0.035, -1.5),
		range_center + Vector3(1.75, -0.035, -1.5),
		range_center + Vector3(-2.5, -0.035, -4.2),
		range_center + Vector3(0.0, -0.035, -4.65),
		range_center + Vector3(2.5, -0.035, -4.2),
	]
	for target_index: int in range(target_positions.size()):
		var instance: Node = DivineSpecialDummyScene.instantiate()
		if not (instance is Node3D):
			if instance != null:
				instance.queue_free()
			continue
		var target: Node3D = instance as Node3D
		target.name = "DivineSpecialTarget" + str(target_index + 1)
		target.position = target_positions[target_index]
		if target.get_node_or_null("StatusReceiver") == null:
			var status_receiver: Node = DivineSpecialStatusReceiverScript.new()
			status_receiver.name = "StatusReceiver"
			target.add_child(status_receiver)
		add_child(target)
