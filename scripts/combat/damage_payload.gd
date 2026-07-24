extends Resource
class_name DamagePayload

@export var amount: int = 1
@export var stance_damage: int = 1
@export var element: String = "neutral"
@export var source_name: String = "Unknown"
@export var hit_type: String = "magic"

@export var status_effect: String = ""
@export var status_duration: float = 0.0
@export var status_strength: float = 1.0

@export var tags: Array[String] = []

@export var knockback_strength: float = 0.0
@export var knockback_up_strength: float = 0.0

# Weapon attacks copy their equipped weapon's critical identity into the payload.
# Receivers decide whether a valid stance-break window may consume it.
@export_range(1.0, 6.0, 0.05) var critical_multiplier: float = 2.0
