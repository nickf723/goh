extends "res://scripts/soul/soul_duplicate_actor.gd"
class_name SoulDuplicateActorReady

const BubbleControllerScript = preload(
	"res://scripts/player/player_bubble_shield_controller.gd"
)
const AbilityProxyScript = preload(
	"res://scripts/soul/soul_duplicate_ability_proxy.gd"
)

@export_range(5.0, 20.0, 0.1) var surf_speed: float = 12.5
@export_range(10.0, 180.0, 1.0) var surf_turn_rate_degrees: float = 72.0

var surf_active: bool = false
var surf_direction: Vector3 = Vector3.FORWARD
var bubble_controller: PlayerBubbleShieldController = null
var ability_proxy: SoulDuplicateAbilityProxy = null


func _ready() -> void:
	super._ready()
	bubble_controller = BubbleControllerScript.new() as PlayerBubbleShieldController
	bubble_controller.name = "BubbleShieldController"
	add_child(bubble_controller)


func _build_support_controllers() -> void:
	action_state = PlayerActionStateScript.new() as PlayerActionState
	action_state.name = "PlayerActionState"
	add_child(action_state)
	ability_proxy = AbilityProxyScript.new() as SoulDuplicateAbilityProxy
	ability_proxy.name = "AbilityCaster"
	add_child(ability_proxy)
	flamethrower_controller = FlamethrowerControllerScript.new() as PlayerFlamethrowerController
	flamethrower_controller.name = "FlamethrowerController"
	add_child(flamethrower_controller)


func set_mirrored_ability(
	ability: AbilityDefinition,
	direction: Vector3
) -> void:
	if ability_proxy != null:
		ability_proxy.set_mirrored_ability(ability, direction)


func _physics_process(delta: float) -> void:
	if not surf_active:
		super._physics_process(delta)
		return
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return
	var input_vector: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	if input_vector.length() <= 0.08:
		surf_active = false
		super._physics_process(delta)
		return
	var desired: Vector3 = _camera_relative_direction(input_vector)
	if desired.length_squared() > 0.001:
		if surf_direction.length_squared() <= 0.001:
			surf_direction = desired
		else:
			var angle: float = surf_direction.angle_to(desired)
			if angle > 0.001:
				var ratio: float = minf(deg_to_rad(surf_turn_rate_degrees) * delta / angle, 1.0)
				surf_direction = surf_direction.slerp(desired, ratio).normalized()
	velocity.x = surf_direction.x * surf_speed
	velocity.z = surf_direction.z * surf_speed
	_apply_gravity(delta)
	move_and_slide()


func apply_source_state_spell(spell_id: String, cast_direction: Vector3) -> void:
	match spell_id:
		"surf":
			surf_active = not surf_active
			var planar: Vector3 = cast_direction
			planar.y = 0.0
			surf_direction = planar.normalized() if planar.length_squared() > 0.001 else -global_transform.basis.z
		"bubble":
			if bubble_controller != null:
				bubble_controller.activate_bubble()
		"space_blink":
			var direction: Vector3 = cast_direction
			direction.y = 0.0
			if direction.length_squared() <= 0.001:
				direction = -global_transform.basis.z
			global_position += direction.normalized() * 5.0
		_:
			super.apply_source_state_spell(spell_id, cast_direction)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["surf_active"] = surf_active
	data["bubble_active"] = (
		bubble_controller != null and bubble_controller.is_bubble_active()
	)
	data["ability_proxy_ready"] = ability_proxy != null
	data["ready_source_states"] = true
	return data
