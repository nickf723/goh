extends Node
class_name RepeatEchoSpellTint

@export_range(0.0, 1.0, 0.01) var transparency_amount: float = 0.18
@export_range(0.0, 8.0, 0.1) var emission_energy: float = 2.0


func _ready() -> void:
	call_deferred("_apply_and_retire")


func _apply_and_retire() -> void:
	var root: Node = get_parent()
	if root != null and is_instance_valid(root):
		_tint_recursive(root)
	queue_free()


func _tint_recursive(node: Node) -> void:
	if node == self:
		return
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		geometry.transparency = maxf(geometry.transparency, transparency_amount)
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var source_material: Material = mesh_instance.material_override
		if source_material is StandardMaterial3D:
			var material := (source_material as StandardMaterial3D).duplicate(true) as StandardMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var original: Color = material.albedo_color
			material.albedo_color = original.lerp(Color(0.34, 0.5, 1.0, original.a), 0.28)
			material.emission_enabled = true
			material.emission = material.albedo_color.lerp(Color(0.56, 0.34, 1.0, 1.0), 0.36)
			material.emission_energy_multiplier = maxf(material.emission_energy_multiplier, emission_energy)
			mesh_instance.material_override = material
	for child: Node in node.get_children():
		_tint_recursive(child)
