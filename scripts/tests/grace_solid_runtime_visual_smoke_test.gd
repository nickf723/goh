extends Node

const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	add_child(player)
	for _index: int in range(3):
		await get_tree().process_frame

	var visual: GraceElementalAuthorityMotionVisual = player.get_node_or_null(
		"GraceVisualV1"
	) as GraceElementalAuthorityMotionVisual
	var wire: GraceWireSkeletonRenderer = player.get_node_or_null(
		"GraceVisualV1/WireSkeletonRenderer"
	) as GraceWireSkeletonRenderer
	var torso: MeshInstance3D = player.get_node_or_null(
		"GraceVisualV1/VisualRoot/BodyRoot/Torso"
	) as MeshInstance3D
	var head: MeshInstance3D = player.get_node_or_null(
		"GraceVisualV1/VisualRoot/HeadRoot/Head"
	) as MeshInstance3D
	var hair: MeshInstance3D = player.get_node_or_null(
		"GraceVisualV1/VisualRoot/HeadRoot/HairBack"
	) as MeshInstance3D
	var weapon_animator: PlayerWeaponControlAnimator = player.get_node_or_null(
		"PlayerWeaponControlAnimator"
	) as PlayerWeaponControlAnimator

	_expect(visual != null, "Player resolves full Grace elemental-authority motion visual")
	_expect(visual is GraceWireMotionVisual, "solid Grace preserves wire-motion compatibility type")
	_expect(torso != null and torso.visible, "solid Grace torso is visible")
	_expect(head != null and head.visible, "solid Grace head is visible")
	_expect(hair != null and hair.visible, "solid Grace hair is visible")
	_expect(wire != null, "hidden wire skeleton remains available to motion systems")
	if wire != null:
		_expect(not wire.visible, "wire skeleton is hidden from player-facing presentation")
		_expect(not wire.hide_source_meshes, "wire skeleton never hides the solid source meshes")
		wire.sample_now(1.0)
		_expect(wire.get_joint_count() == 19, "hidden wire skeleton still computes all joints")
		_expect(wire.get_segment_count() == 18, "hidden wire skeleton still computes all segments")
		_expect(wire.has_finite_pose(), "hidden wire skeleton retains a finite motion pose")
	_expect(weapon_animator != null and weapon_animator.visual != null, "weapon control animator still resolves Grace through the wire-motion API")

	player.queue_free()
	await get_tree().process_frame
	_finish()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_SOLID_RUNTIME_VISUAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_SOLID_RUNTIME_VISUAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
