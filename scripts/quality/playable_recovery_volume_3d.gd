extends "res://scripts/quality/playable_forbidden_volume_3d.gd"
class_name PlayableRecoveryVolume3D

@export var recovery_reason: String = "left the playable space"
@export var detect_collision_mask: int = 1


func _ready() -> void:
	super._ready()
	collision_mask = detect_collision_mask
	monitoring = active
	monitorable = true
	add_to_group("playable_recovery_volume")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func set_active(value: bool) -> void:
	super.set_active(value)
	monitoring = active


func _on_body_entered(body: Node3D) -> void:
	if not active or body == null:
		return
	var recovery: Node = body.get_node_or_null("RecoveryController")
	if recovery == null or not recovery.has_method("request_recovery"):
		return
	recovery.call_deferred("request_recovery", recovery_reason)
