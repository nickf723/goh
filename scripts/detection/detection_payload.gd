extends Resource
class_name DetectionPayload

@export var source_name: String = "Sound Pulse"
@export var detection_type: String = "sound"

@export var radius: float = 8.0
@export var reveal_duration: float = 5.0
@export var strength: float = 1.0

@export var tags: Array[String] = ["sound", "detection", "pulse"]
