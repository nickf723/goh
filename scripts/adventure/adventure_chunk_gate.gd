extends StaticBody3D
class_name AdventureChunkGate

signal gate_locked(required_chunk_id: String)
signal gate_unlocked(required_chunk_id: String)

@export var required_chunk_id: String = ""
@export var gate_name: String = "Adventure Gate"
@export var gate_size: Vector3 = Vector3(6.8, 3.0, 0.7)
@export var hide_when_unlocked: bool = true
@export var locked_color: Color = Color(0.18, 0.28, 0.4, 0.92)
@export var unlocked_color: Color = Color(0.35, 0.95, 0.62, 0.38)

var director: AdventureSequenceDirector
var gate_mesh: MeshInstance3D
var gate_collision: CollisionShape3D
var label: Label3D
var locked: bool = true
var original_collision_layer: int = 1
var original_collision_mask: int = 1


func _ready() -> void:
	add_to_group("adventure_chunk_gates")
	add_to_group("debuggable")
	_build_gate_if_needed()
	original_collision_layer = collision_layer if collision_layer != 0 else 1
	original_collision_mask = collision_mask if collision_mask != 0 else 1
	call_deferred("_resolve_director")


func _exit_tree() -> void:
	_disconnect_director()


func bind_director(director_value: AdventureSequenceDirector) -> void:
	_disconnect_director()
	director = director_value
	if director == null:
		return
	var complete_callback := Callable(self, "_on_chunk_completed")
	var reset_callback := Callable(self, "_on_sequence_reset")
	if not director.chunk_finished.is_connected(complete_callback):
		director.chunk_finished.connect(complete_callback)
	if not director.sequence_reset.is_connected(reset_callback):
		director.sequence_reset.connect(reset_callback)
	sync_from_director()


func sync_from_director() -> void:
	if director == null or not is_instance_valid(director):
		lock_gate()
		return
	var chunk: AdventureChunk = director.get_chunk(required_chunk_id)
	if chunk != null and chunk.is_complete():
		unlock_gate()
	else:
		lock_gate()


func lock_gate() -> void:
	var changed: bool = not locked
	locked = true
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
	visible = true
	_refresh_presentation()
	if changed:
		gate_locked.emit(AdventureChunkDefinition.normalize_id(required_chunk_id))


func unlock_gate() -> void:
	var changed: bool = locked
	locked = false
	collision_layer = 0
	collision_mask = 0
	visible = not hide_when_unlocked
	_refresh_presentation()
	if changed:
		gate_unlocked.emit(AdventureChunkDefinition.normalize_id(required_chunk_id))


func is_locked() -> bool:
	return locked


func _resolve_director() -> void:
	var candidate: Node = get_tree().get_first_node_in_group("adventure_sequence_directors")
	if candidate is AdventureSequenceDirector:
		bind_director(candidate as AdventureSequenceDirector)
	else:
		lock_gate()


func _disconnect_director() -> void:
	if director == null or not is_instance_valid(director):
		director = null
		return
	var complete_callback := Callable(self, "_on_chunk_completed")
	var reset_callback := Callable(self, "_on_sequence_reset")
	if director.chunk_finished.is_connected(complete_callback):
		director.chunk_finished.disconnect(complete_callback)
	if director.sequence_reset.is_connected(reset_callback):
		director.sequence_reset.disconnect(reset_callback)
	director = null


func _on_chunk_completed(chunk_id: String) -> void:
	if AdventureChunkDefinition.normalize_id(chunk_id) == AdventureChunkDefinition.normalize_id(required_chunk_id):
		unlock_gate()


func _on_sequence_reset(_sequence_id: String) -> void:
	sync_from_director()


func _build_gate_if_needed() -> void:
	gate_collision = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if gate_collision == null:
		gate_collision = CollisionShape3D.new()
		gate_collision.name = "CollisionShape3D"
		add_child(gate_collision)
	var shape := BoxShape3D.new()
	shape.size = gate_size
	gate_collision.shape = shape

	gate_mesh = get_node_or_null("GateMesh") as MeshInstance3D
	if gate_mesh == null:
		gate_mesh = MeshInstance3D.new()
		gate_mesh.name = "GateMesh"
		add_child(gate_mesh)
	var mesh := BoxMesh.new()
	mesh.size = gate_size
	gate_mesh.mesh = mesh

	label = get_node_or_null("GateLabel") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "GateLabel"
		label.position = Vector3(0.0, gate_size.y * 0.65, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 24
		label.pixel_size = 0.006
		label.outline_size = 7
		add_child(label)
	_refresh_presentation()


func _refresh_presentation() -> void:
	if gate_mesh != null:
		var material := StandardMaterial3D.new()
		var color: Color = locked_color if locked else unlocked_color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 1.2 if locked else 0.65
		gate_mesh.material_override = material
	if label != null:
		label.text = (
			gate_name.to_upper() + "\nCOMPLETE " + AdventureChunkDefinition.normalize_id(required_chunk_id).replace("_", " ").to_upper()
			if locked
			else gate_name.to_upper() + "\nOPEN"
		)
		label.modulate = locked_color.lightened(0.28) if locked else unlocked_color.lightened(0.32)


func get_debug_data() -> Dictionary:
	return {
		"gate_name": gate_name,
		"required_chunk_id": AdventureChunkDefinition.normalize_id(required_chunk_id),
		"locked": locked,
		"director_found": director != null and is_instance_valid(director),
		"collision_layer": collision_layer,
		"visible": visible,
	}
