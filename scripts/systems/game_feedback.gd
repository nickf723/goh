extends Node
class_name GameFeedback

const HAPTICS_ENABLED: bool = true
const DEBUG_PRINTS_ENABLED: bool = false

const PRESETS: Dictionary = {
	"light_tick": {
		"label": "Light Tick",
		"haptic": {
			"weak": 0.10,
			"strong": 0.00,
			"duration": 0.055,
			"device": 0,
		},
		"tags": ["ui", "light"],
	},
	"full_charge": {
		"label": "Full Charge",
		"haptic": {
			"weak": 0.20,
			"strong": 0.65,
			"duration": 0.16,
			"device": 0,
		},
		"tags": ["ability", "charge", "firebolt"],
	},
	"guard_block": {
		"label": "Guard Block",
		"haptic": {
			"weak": 0.45,
			"strong": 0.85,
			"duration": 0.13,
			"device": 0,
		},
		"tags": ["defense", "guard", "impact"],
	},
	"heavy_impact": {
		"label": "Heavy Impact",
		"haptic": {
			"weak": 0.35,
			"strong": 1.00,
			"duration": 0.20,
			"device": 0,
		},
		"tags": ["combat", "impact"],
	},
	"low_health_warning": {
		"label": "Low Health Warning",
		"haptic": {
			"weak": 0.22,
			"strong": 0.30,
			"duration": 0.10,
			"device": 0,
		},
		"tags": ["health", "warning"],
	},
}


static func play(feedback_id: String, overrides: Dictionary = {}) -> Dictionary:
	var data: Dictionary = get_feedback_data(feedback_id, overrides)

	if DEBUG_PRINTS_ENABLED:
		print("Feedback: ", feedback_id, " -> ", data)

	play_haptics(data)
	return data


static func get_feedback_data(feedback_id: String, overrides: Dictionary = {}) -> Dictionary:
	var data: Dictionary = get_preset(feedback_id)

	for key in overrides.keys():
		data[str(key)] = overrides[key]

	data["id"] = feedback_id
	return data


static func get_preset(feedback_id: String) -> Dictionary:
	if PRESETS.has(feedback_id):
		return (PRESETS[feedback_id] as Dictionary).duplicate(true)

	return {
		"label": feedback_id.capitalize(),
		"haptic": {},
		"tags": ["unknown"],
	}


static func play_haptics(feedback_data: Dictionary) -> void:
	if not HAPTICS_ENABLED:
		return

	if not feedback_data.has("haptic"):
		return

	if not (feedback_data["haptic"] is Dictionary):
		return

	var haptic: Dictionary = feedback_data["haptic"] as Dictionary

	if haptic.is_empty():
		return

	var weak: float = clamp(float(haptic.get("weak", 0.0)), 0.0, 1.0)
	var strong: float = clamp(float(haptic.get("strong", 0.0)), 0.0, 1.0)
	var duration: float = max(float(haptic.get("duration", 0.0)), 0.0)
	var device: int = int(haptic.get("device", 0))

	if duration <= 0.0:
		return

	if device < 0:
		play_haptics_on_all_devices(weak, strong, duration)
		return

	Input.start_joy_vibration(device, weak, strong, duration)


static func play_haptics_on_all_devices(weak: float, strong: float, duration: float) -> void:
	var devices: Array = Input.get_connected_joypads()

	if devices.size() <= 0:
		Input.start_joy_vibration(0, weak, strong, duration)
		return

	for device_variant in devices:
		Input.start_joy_vibration(int(device_variant), weak, strong, duration)


static func stop_haptics(device: int = -1) -> void:
	if device >= 0:
		Input.stop_joy_vibration(device)
		return

	for device_variant in Input.get_connected_joypads():
		Input.stop_joy_vibration(int(device_variant))

	Input.stop_joy_vibration(0)


static func get_preset_ids() -> Array[String]:
	var ids: Array[String] = []

	for preset_id in PRESETS.keys():
		ids.append(str(preset_id))

	ids.sort()
	return ids
