extends "res://scripts/actions/water_jet_cast.gd"
class_name WaterJetCastReady

# The production authority primes the stream transform immediately, preventing
# the reused cylinder meshes from appearing at the scene origin for one visual
# update interval after the channel begins.


func execute(player: Node3D, requested_direction: Vector3) -> void:
	super.execute(player, requested_direction)
	if not active or source_actor == null or not is_instance_valid(source_actor):
		return
	current_origin = _get_cast_origin()
	current_direction = _get_cast_direction(current_origin)
	current_hit = _resolve_stream_hit(current_origin, current_direction)
	current_stream_length = _get_stream_length(current_origin, current_hit)
	last_hit_name = _get_hit_name(current_hit)
	_update_visuals()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["start_transform_primed"] = true
	return data
