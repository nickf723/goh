extends "res://scripts/player/player_avatar_manager_elemental.gd"
class_name PlayerAvatarManagerProductionBridge

const AvatarWireRendererScript = preload(
	"res://scripts/visuals/avatar_wire_skeleton_renderer.gd"
)

var fallback_wire_renderer_created: bool = false


func _resolve_bindings() -> void:
	super._resolve_bindings()
	if wire_renderer != null or actor == null:
		return

	# The production player keeps GraceVisualV1 hidden as a motion/reference rig.
	# PlayerAvatarManager still uses an avatar-aware wire renderer as its compact
	# palette/state adapter. Normal player scenes now ship the correct subclass;
	# this fallback protects older inherited scenes and stale editor instances.
	if not actor.is_node_ready():
		return
	var visual_root: Node3D = actor.get_node_or_null(
		"GraceVisualV1"
	) as Node3D
	if visual_root == null:
		return
	for child: Node in visual_root.get_children():
		if child is AvatarWireSkeletonRenderer:
			wire_renderer = child as AvatarWireSkeletonRenderer
			return

	var fallback: AvatarWireSkeletonRenderer = (
		AvatarWireRendererScript.new() as AvatarWireSkeletonRenderer
	)
	fallback.name = "AvatarPresentationStateAdapter"
	fallback.visible = false
	fallback.hide_source_meshes = false
	visual_root.add_child(fallback)
	wire_renderer = fallback
	fallback_wire_renderer_created = true


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["production_avatar_bridge"] = true
	data["fallback_wire_renderer_created"] = fallback_wire_renderer_created
	data["avatar_presentation_adapter"] = (
		str(wire_renderer.get_path())
		if wire_renderer != null and wire_renderer.is_inside_tree()
		else "none"
	)
	return data
