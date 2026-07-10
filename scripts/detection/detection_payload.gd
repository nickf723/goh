extends Resource
class_name DetectionPayload

@export var source_name: String = "Sound Pulse"
@export var detection_type: String = "sound"

@export var radius: float = 8.0
@export var reveal_duration: float = 5.0
@export var strength: float = 1.0

# Optional combat rider for detection pulses. This lets Sound Pulse reveal hidden objects
# while also briefly disrupting enemies caught in the echo.
@export var echo_status_effect: String = ""
@export var echo_status_duration: float = 0.0
@export var echo_status_strength: float = 1.0
@export var echo_status_group: String = "enemy"

@export var tags: Array[String] = ["sound", "detection", "pulse"]
