extends Node
class_name WeaponRecoveryPresenter

@export_range(0.04, 0.3, 0.01) var light_settle_seconds: float = 0.1
@export_range(0.04, 0.4, 0.01) var heavy_settle_seconds: float = 0.16

var weapon_controller: WeaponController
var hand_anchor: Node3D
var last_attack: WeaponAttackDefinition
var captured_position: Vector3 = Vector3.ZERO
var captured_rotation_degrees: Vector3 = Vector3.ZERO
var settle_tween: Tween


func _ready() -> void:
	# Run just after the skeletal proxy (205). During the migration the character
	# rig drives HandAnchor globally; normalize its local scale so Grace's smaller
	# presentation does not silently shrink authored weapon proportions.
	process_priority = 210
	weapon_controller = get_parent().get_node_or_null("WeaponController") as WeaponController
	if weapon_controller != null:
		hand_anchor = weapon_controller.get_node_or_null("HandAnchor") as Node3D
		if not weapon_controller.attack_started.is_connected(_on_attack_started):
			weapon_controller.attack_started.connect(_on_attack_started)
		if not weapon_controller.attack_finished.is_connected(_on_attack_finished):
			weapon_controller.attack_finished.connect(_on_attack_finished)
	add_to_group("weapon_recovery_presenter")
	add_to_group("debuggable")


func _process(_delta: float) -> void:
	if hand_anchor != null:
		hand_anchor.scale = Vector3.ONE


func _exit_tree() -> void:
	_kill_settle_tween()
	if weapon_controller == null:
		return
	if weapon_controller.attack_started.is_connected(_on_attack_started):
		weapon_controller.attack_started.disconnect(_on_attack_started)
	if weapon_controller.attack_finished.is_connected(_on_attack_finished):
		weapon_controller.attack_finished.disconnect(_on_attack_finished)


func _on_attack_started(attack: WeaponAttackDefinition) -> void:
	_kill_settle_tween()
	last_attack = attack


func _on_attack_finished(_attack_id: String) -> void:
	if weapon_controller == null or weapon_controller.weapon_visual_pivot == null:
		return
	captured_position = weapon_controller.weapon_visual_pivot.position
	captured_rotation_degrees = weapon_controller.weapon_visual_pivot.rotation_degrees
	call_deferred("_begin_deferred_settle")


func _begin_deferred_settle() -> void:
	if weapon_controller == null or weapon_controller.weapon_visual_pivot == null:
		return
	# Buffered follow-ups start synchronously after attack_finished is emitted.
	# If one exists, the next attack already owns the pivot and must win.
	if weapon_controller.current_attack != null:
		return
	# Runtime flexible/projectile rigs own their own recovery presentation.
	if weapon_controller.runtime_weapon_rig != null:
		return

	var pivot: Node3D = weapon_controller.weapon_visual_pivot
	pivot.position = captured_position
	pivot.rotation_degrees = captured_rotation_degrees
	var duration: float = light_settle_seconds
	if last_attack != null and last_attack.input_kind == "heavy":
		duration = heavy_settle_seconds
	_kill_settle_tween()
	settle_tween = create_tween()
	settle_tween.set_parallel(true)
	settle_tween.set_trans(Tween.TRANS_QUAD)
	settle_tween.set_ease(Tween.EASE_OUT)
	settle_tween.tween_property(
		pivot,
		"position",
		weapon_controller.base_visual_position,
		maxf(duration, 0.04)
	)
	settle_tween.tween_property(
		pivot,
		"rotation_degrees",
		weapon_controller.base_visual_rotation_degrees,
		maxf(duration, 0.04)
	)
	settle_tween.finished.connect(_on_settle_finished)


func _on_settle_finished() -> void:
	settle_tween = null


func _kill_settle_tween() -> void:
	if settle_tween != null and settle_tween.is_valid():
		settle_tween.kill()
	settle_tween = null


func get_debug_data() -> Dictionary:
	return {
		"weapon_recovery_presenter": true,
		"settling": settle_tween != null and settle_tween.is_valid(),
		"attack": last_attack.attack_id if last_attack != null else "none",
		"captured_position": captured_position,
		"captured_rotation": captured_rotation_degrees,
		"hand_anchor_scale": hand_anchor.scale if hand_anchor != null else Vector3.ONE,
	}
