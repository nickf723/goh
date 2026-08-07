extends Node3D
class_name BodyFormCast

const BodyFormControllerScript = preload(
	"res://scripts/player/player_body_form_controller.gd"
)
const GameplayEffectAccessScript = preload(
	"res://scripts/effects/gameplay_effect_access.gd"
)

@export_enum("grown", "shrunk") var requested_form: String = "grown"
@export_range(0, 20, 1) var authored_mana_cost: int = 0
@export var refund_when_returning_to_normal: bool = true
@export var refund_rejected_transform: bool = true

var source_actor: Node3D = null
var last_result: Dictionary = {}


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var controller: PlayerBodyFormController = source_actor.get_node_or_null(
		"BodyFormController"
	) as PlayerBodyFormController
	if controller == null:
		controller = BodyFormControllerScript.new() as PlayerBodyFormController
		controller.name = "BodyFormController"
		source_actor.add_child(controller)
		await get_tree().process_frame

	if controller == null or not is_instance_valid(controller):
		_refund_paid_mana()
		queue_free()
		return

	last_result = controller.request_form(requested_form)
	var success: bool = bool(last_result.get("success", false))
	var returned_to_normal: bool = bool(
		last_result.get("returned_to_normal", false)
	)
	if (
		(not success and refund_rejected_transform)
		or (success and returned_to_normal and refund_when_returning_to_normal)
	):
		_refund_paid_mana()

	var message: String = str(last_result.get("message", ""))
	if message != "":
		_show_message(message)
	queue_free()


func _refund_paid_mana() -> void:
	var refund: int = GameplayEffectAccessScript.modify_int(
		"mana_cost",
		authored_mana_cost,
		"ceil"
	)
	if refund > 0:
		GameState.restore_mana(refund)


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)


func get_debug_data() -> Dictionary:
	return {
		"body_form_cast": true,
		"requested_form": requested_form,
		"authored_mana_cost": authored_mana_cost,
		"last_result": last_result.duplicate(true),
	}
