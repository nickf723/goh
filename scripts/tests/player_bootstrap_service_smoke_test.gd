extends Node

const PresentationServiceScript = preload(
	"res://scripts/presentation/presentation_service.gd"
)
const GraceWireVisualScene: PackedScene = preload(
	"res://scenes/actors/player/grace_wire_visual_v1.tscn"
)
const QuickItemBeltScene: PackedScene = preload(
	"res://scenes/ui/quick_item_belt_ui.tscn"
)
const CombatPlayerScene: PackedScene = preload(
	"res://scenes/actors/player/player_combat_v2.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	_validate_scene_wiring()
	await _validate_deferred_presentation_service()
	_finish()


func _validate_scene_wiring() -> void:
	var wire_visual: Node = GraceWireVisualScene.instantiate()
	var renderer: Node = wire_visual.get_node_or_null("WireSkeletonRenderer")
	_expect(
		renderer is AvatarWireSkeletonRenderer,
		"Grace wire scene uses the avatar-aware renderer subclass"
	)
	wire_visual.free()

	var quick_ui: Node = QuickItemBeltScene.instantiate()
	_expect(
		quick_ui is QuickItemBeltUIDeferred,
		"quick-item HUD defers persistent familiar roster creation"
	)
	quick_ui.free()

	var player: Node = CombatPlayerScene.instantiate()
	var avatar_manager: Node = player.get_node_or_null("AvatarManager")
	_expect(
		avatar_manager is PlayerAvatarManagerProductionBridge,
		"combat player uses the production-safe avatar manager"
	)
	player.free()


func _validate_deferred_presentation_service() -> void:
	var first: GamePresentationDirector = PresentationServiceScript.get_or_create(
		get_tree()
	)
	var second: GamePresentationDirector = PresentationServiceScript.get_or_create(
		get_tree()
	)
	_expect(first != null, "presentation service creates a director")
	_expect(first == second, "pending presentation requests share one director")
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(
		first != null and is_instance_valid(first) and first.get_parent() == get_tree().root,
		"presentation director attaches to the root after setup completes"
	)
	_expect(
		get_tree().root.get_node_or_null("PresentationDirector") == first,
		"deferred presentation director retains the canonical root name"
	)
	if first != null and is_instance_valid(first):
		first.queue_free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("PLAYER_BOOTSTRAP_SERVICE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("PLAYER_BOOTSTRAP_SERVICE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
