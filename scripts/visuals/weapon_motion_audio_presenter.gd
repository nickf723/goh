extends Node
class_name WeaponMotionAudioPresenter

const PresentationServiceScript = preload(
	"res://scripts/presentation/presentation_service.gd"
)

@export_range(0.1, 0.95, 0.05) var swing_timing_ratio: float = 0.62
@export_range(0.01, 0.3, 0.01) var minimum_swing_delay: float = 0.025
@export_range(0.05, 0.5, 0.01) var maximum_swing_delay: float = 0.30
@export_range(0.0, 1.0, 0.05) var volume_strength: float = 1.0

var actor: CharacterBody3D
var weapon_controller: WeaponController
var attack_serial: int = 0
var last_attack_id: String = "none"
var last_weapon_class: String = "none"
var last_scheduled_delay: float = 0.0
var emitted_cues: int = 0


func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	if actor != null:
		weapon_controller = actor.get_node_or_null(
			"WeaponController"
		) as WeaponController
	if weapon_controller == null:
		push_warning("WeaponMotionAudioPresenter could not resolve WeaponController.")
		return
	if not weapon_controller.attack_started.is_connected(_on_attack_started):
		weapon_controller.attack_started.connect(_on_attack_started)
	add_to_group("weapon_motion_audio_presenter")
	add_to_group("debuggable")


func _exit_tree() -> void:
	if (
		weapon_controller != null
		and is_instance_valid(weapon_controller)
		and weapon_controller.attack_started.is_connected(_on_attack_started)
	):
		weapon_controller.attack_started.disconnect(_on_attack_started)


func _on_attack_started(attack: WeaponAttackDefinition) -> void:
	if attack == null or weapon_controller == null:
		return
	attack_serial += 1
	var serial: int = attack_serial
	last_attack_id = attack.attack_id
	last_weapon_class = (
		weapon_controller.equipped_weapon.weapon_class
		if weapon_controller.equipped_weapon != null
		else "sword"
	)
	var attack_speed: float = maxf(weapon_controller.get_attack_speed(), 0.05)
	var startup: float = maxf(attack.get_startup_duration(attack_speed), 0.01)
	var delay: float = clampf(
		startup * swing_timing_ratio,
		minimum_swing_delay,
		maximum_swing_delay
	)
	# Very fast throws/releases need their transient close to launch, while heavy
	# weapons benefit from hearing the accelerating head just before contact.
	if last_weapon_class in ["bow", "shuriken", "boomerang"]:
		delay = minf(delay, 0.11)
	elif attack.input_kind == "heavy":
		delay = minf(delay + 0.018, maximum_swing_delay)
	last_scheduled_delay = delay
	get_tree().create_timer(delay, true, false, false).timeout.connect(
		func() -> void:
			_emit_swing_if_current(serial, attack)
	)


func _emit_swing_if_current(
	serial: int,
	attack: WeaponAttackDefinition
) -> void:
	if serial != attack_serial or attack == null:
		return
	if weapon_controller == null or not is_instance_valid(weapon_controller):
		return
	# An attack may have been cancelled into a dodge, spell, guard, or another
	# technique before its whoosh point. Do not play a phantom swing afterward.
	if weapon_controller.current_attack == null:
		return
	if weapon_controller.current_attack.attack_id != attack.attack_id:
		return
	var director: GamePresentationDirector = PresentationServiceScript.get_or_create(
		get_tree()
	)
	if director == null:
		return
	var weapon_class: String = (
		weapon_controller.equipped_weapon.weapon_class
		if weapon_controller.equipped_weapon != null
		else "sword"
	)
	var position: Vector3 = actor.global_position + Vector3.UP * 0.9 if actor != null else Vector3.ZERO
	var hand_anchor: Node3D = weapon_controller.get_node_or_null(
		"HandAnchor"
	) as Node3D
	if hand_anchor != null:
		position = hand_anchor.global_position
	var intensity: float = _attack_intensity(attack, weapon_class)
	director.present("weapon_motion", {
		"actor": actor,
		"position": position,
		"weapon_class": weapon_class,
		"input_kind": attack.input_kind,
		"attack_id": attack.attack_id,
		"tags": attack.extra_tags.duplicate(),
		"intensity": intensity * clampf(volume_strength, 0.0, 1.0),
	})
	emitted_cues += 1
	last_weapon_class = weapon_class


func _attack_intensity(
	attack: WeaponAttackDefinition,
	weapon_class: String
) -> float:
	var intensity: float = 0.44 if attack.input_kind == "light" else 0.68
	intensity += clampf((attack.damage_multiplier - 1.0) * 0.16, -0.08, 0.18)
	intensity += clampf((attack.stance_multiplier - 1.0) * 0.12, -0.05, 0.16)
	if weapon_class in ["axe", "hammer", "mace", "halberd", "scythe"]:
		intensity += 0.10
	elif weapon_class in ["daggers", "shuriken", "gauntlets"]:
		intensity -= 0.06
	if attack.extra_tags.has("charged") or attack.extra_tags.has("charge_release"):
		intensity += 0.12
	if attack.extra_tags.has("aerial_heavy") or attack.extra_tags.has("plunge"):
		intensity += 0.10
	return clampf(intensity, 0.18, 1.0)


func get_debug_data() -> Dictionary:
	return {
		"weapon_motion_audio_presenter": true,
		"controller_ready": weapon_controller != null,
		"attack_serial": attack_serial,
		"last_attack": last_attack_id,
		"last_weapon_class": last_weapon_class,
		"last_delay": snappedf(last_scheduled_delay, 0.001),
		"emitted_cues": emitted_cues,
		"presentation_directed": true,
		"gameplay_authority": false,
	}
