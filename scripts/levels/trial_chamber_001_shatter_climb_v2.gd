extends "res://scripts/levels/trial_chamber_001_shatter_climb.gd"
class_name TrialChamber001ShatterClimbV2


# Trial 001's puzzle logic is already accepted. Keep the base implementation
# intact and correct only the final authored presentation/layout pass: the
# cascade must rise toward the crown seal rather than slope back toward Grace.
func _build_synthesis_ascent() -> void:
	_create_static_box("AscentLowerFloor", Vector3(0.0, -0.5, -13.0), Vector3(18.0, 1.0, 6.0), floor_material)
	_create_visual_box("AscentVoid", Vector3(0.0, -6.5, -19.0), Vector3(18.0, 1.0, 12.0), void_material)
	ascent_bridge = _create_water_ice_surface(
		"FrozenAscent",
		"trial_001_frozen_ascent",
		ASCENT_FLAG,
		Vector3(0.0, 3.0, -19.0),
		Vector3(8.0, 0.5, 12.0),
		Vector3(30.0, 0.0, 0.0),
		"The flooded chute freezes into a steep crystalline ramp."
	)
	ascent_bridge.connect("bridge_frozen", _on_ascent_frozen)

	_create_static_box("UpperLanding", Vector3(0.0, 5.75, -25.5), Vector3(18.0, 1.0, 5.0), platform_material)
	_create_static_box("CrownWingLeft", Vector3(-7.0, 9.0, -28.0), Vector3(4.0, 7.0, 1.0), wall_material)
	_create_static_box("CrownWingRight", Vector3(7.0, 9.0, -28.0), Vector3(4.0, 7.0, 1.0), wall_material)
	crown_gate = _create_shatter_gate(
		"CrownMasonrySeal",
		"trial_001_crown_masonry",
		CROWN_FLAG,
		Vector3(0.0, 6.0, -28.0),
		Vector3(10.0, 7.0, 1.0),
		"Ice turns the crown seal brittle.",
		"The Heavy Hammer strike opens the final passage."
	)
	crown_gate.connect("gate_opened", _on_crown_gate_opened)
	_create_static_box("GoalFloor", Vector3(0.0, 5.75, -32.5), Vector3(18.0, 1.0, 8.0), platform_material)
