extends RefCounted
class_name WorldStateVariant

var variants: Dictionary = {}
var active_id: String = ""


func register_variant(variant_id: String, nodes: Array[Node]) -> void:
	variants[variant_id] = nodes.duplicate()


func apply(variant_id: String) -> void:
	active_id = variant_id
	for id_variant: Variant in variants.keys():
		var id: String = str(id_variant)
		var visible: bool = id == variant_id
		for node_variant: Variant in variants[id]:
			if not is_instance_valid(node_variant):
				continue
			var node: Node = node_variant as Node
			if node is CanvasItem:
				(node as CanvasItem).visible = visible
			elif node is Node3D:
				(node as Node3D).visible = visible
			node.process_mode = Node.PROCESS_MODE_INHERIT if visible else Node.PROCESS_MODE_DISABLED


func get_active_id() -> String:
	return active_id
