extends "res://scripts/presentation/presentation_audio.gd"
class_name SpellPresentationAudio


func _get_cue_profile(cue_id: String) -> Dictionary:
	match cue_id:
		"spell_prepare":
			return _profile(0.16, [220.0, 330.0, 495.0], 0.08, 0.012, 5.8, 0.3)
		"spell_release":
			return _profile(0.13, [175.0, 350.0, 700.0], 0.14, 0.002, 12.0, 0.52)
		"spell_travel":
			return _profile(0.11, [285.0, 570.0], 0.12, 0.004, 11.0, 0.24)
		"spell_manifest":
			return _profile(0.24, [132.0, 264.0, 528.0], 0.18, 0.004, 6.2, 0.56)
		"spell_latch":
			return _profile(0.17, [118.0, 236.0, 410.0], 0.24, 0.003, 9.0, 0.48)
		"spell_sustain":
			return _profile(0.22, [156.0, 312.0], 0.06, 0.012, 4.8, 0.22)
		"spell_resolve":
			return _profile(0.18, [96.0, 192.0, 384.0], 0.2, 0.002, 8.4, 0.54)
		"spell_handoff":
			return _profile(0.26, [84.0, 168.0, 336.0, 672.0], 0.12, 0.004, 5.2, 0.6)
		"spell_cancel":
			return _profile(0.12, [205.0, 154.0], 0.16, 0.003, 15.0, 0.2)

		"element_earth":
			return _profile(0.2, [74.0, 111.0, 166.0], 0.34, 0.004, 6.4, 0.32)
		"element_air":
			return _profile(0.18, [410.0, 615.0], 0.44, 0.01, 6.0, 0.25)
		"element_metal":
			return _profile(0.21, [520.0, 1040.0, 1560.0], 0.04, 0.002, 5.5, 0.32)
		"element_poison":
			return _profile(0.24, [106.0, 159.0, 238.0], 0.36, 0.008, 4.4, 0.28)
		"element_body":
			return _profile(0.18, [64.0, 128.0, 196.0], 0.3, 0.002, 9.0, 0.34)
		"element_soul":
			return _profile(0.25, [196.0, 392.0, 784.0], 0.06, 0.012, 4.4, 0.3)
		"element_dreams":
			return _profile(0.28, [247.0, 370.5, 494.0], 0.03, 0.018, 3.9, 0.26)
		"element_time":
			return _profile(0.22, [125.0, 250.0, 1000.0], 0.08, 0.001, 5.0, 0.28)
		_:
			return super._get_cue_profile(cue_id)
