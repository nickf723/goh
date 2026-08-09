extends Node3D
class_name SurfaceContactPresentationDirector3D

signal contact_presented(event_type: String, style: String, piece_count: int)

const PresentationServiceScript = preload(
	"res://scripts/presentation/presentation_service.gd"
)

@export var profile: SurfaceContactPresentationProfile
@export var enabled: bool = true

var lighting_director: LightingDirector3D = null
var presentation_director: GamePresentationDirector = null
var regions: Array[Dictionary] = []
var live_pieces: Array[MeshInstance3D] = []
var event_counter: int = 0
var contact_counts: Dictionary = {}
var last_contact: Dictionary = {}
var sphere_mesh: SphereMesh = null
var leaf_mesh: BoxMesh = null


func _ready() -> void:
	add_to_group("surface_contact_presentation_director")
	add_to_group("debuggable")
	_resolve_dependencies()
	_build_shared_meshes()
	_connect_presentation()
	set_meta("surface_contact_presentation_initialized", profile != null)


func _process(_delta: float) -> void:
	_cleanup_pieces()
	if lighting_director == null or not is_instance_valid(lighting_director):
		_resolve_dependencies()
	if presentation_director == null or not is_instance_valid(presentation_director):
		_connect_presentation()


func add_region(
	region_id: String,
	world_center: Vector3,
	extents: Vector3,
	style: String,
	priority: int = 0
) -> void:
	regions.append({
		"id": region_id,
		"center": world_center,
		"extents": Vector3(
			maxf(absf(extents.x), 0.05),
			maxf(absf(extents.y), 0.05),
			maxf(absf(extents.z), 0.05)
		),
		"style": style.strip_edges().to_lower(),
		"priority": priority,
	})
	regions.sort_custom(Callable(self, "_sort_regions"))


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_clear_live_pieces()


func present_contact_for_test(
	event_type: String,
	position: Vector3,
	material_id: String,
	strength: float = 0.5
) -> int:
	return _present_contact(event_type, {
		"position": position,
		"material": material_id,
		"strength": strength,
	})


func _resolve_dependencies() -> void:
	lighting_director = null
	if get_tree() == null:
		return
	var lighting_candidate: Node = get_tree().get_first_node_in_group(
		"lighting_director"
	)
	if lighting_candidate is LightingDirector3D:
		lighting_director = lighting_candidate as LightingDirector3D


func _connect_presentation() -> void:
	if get_tree() == null:
		return
	var resolved: GamePresentationDirector = PresentationServiceScript.get_or_create(
		get_tree()
	)
	if resolved == null:
		return
	if presentation_director != null and is_instance_valid(presentation_director):
		if presentation_director.event_presented.is_connected(_on_event_presented):
			presentation_director.event_presented.disconnect(_on_event_presented)
	presentation_director = resolved
	if not presentation_director.event_presented.is_connected(_on_event_presented):
		presentation_director.event_presented.connect(_on_event_presented)


func _on_event_presented(event_type: String, data: Dictionary) -> void:
	if event_type not in ["footstep", "landing"]:
		return
	_present_contact(event_type, data)


func _present_contact(event_type: String, data: Dictionary) -> int:
	if not enabled or profile == null:
		return 0
	var quality: int = _current_quality()
	var piece_count: int = profile.get_piece_count(event_type, quality)
	if piece_count <= 0:
		return 0
	var position: Vector3 = data.get("position", global_position)
	var material_id: String = str(data.get("material", "stone")).to_lower()
	var strength: float = clampf(float(data.get("strength", 0.5)), 0.0, 1.0)
	var style: String = _resolve_style(position, material_id)
	var duration: float = (
		profile.landing_duration
		if event_type == "landing"
		else profile.footstep_duration
	)
	var spawned: int = _spawn_contact_pieces(
		position,
		style,
		piece_count,
		strength,
		duration,
		event_type == "landing"
	)
	event_counter += 1
	contact_counts[style] = int(contact_counts.get(style, 0)) + spawned
	last_contact = {
		"event_type": event_type,
		"style": style,
		"position": position,
		"strength": strength,
		"piece_count": spawned,
		"quality": quality,
	}
	contact_presented.emit(event_type, style, spawned)
	return spawned


func _spawn_contact_pieces(
	position: Vector3,
	style: String,
	piece_count: int,
	strength: float,
	duration: float,
	landing: bool
) -> int:
	var available: int = maxi(
		profile.maximum_live_pieces - live_pieces.size(),
		0
	)
	var count: int = mini(piece_count, available)
	if count <= 0 or get_tree() == null or get_tree().current_scene == null:
		return 0
	var material: StandardMaterial3D = _make_contact_material(style)
	var spread: float = lerpf(0.18, 0.55 if landing else 0.30, strength)
	var lift: float = lerpf(0.07, 0.28 if landing else 0.14, strength)
	for index: int in range(count):
		var piece := MeshInstance3D.new()
		piece.name = "ContactPiece"
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.mesh = leaf_mesh if style == "leaf_litter" else sphere_mesh
		piece.material_override = material
		get_tree().current_scene.add_child(piece)
		var phase: float = float(event_counter * 31 + index * 17) * 0.83
		var radial: float = spread * (0.35 + _hash01(event_counter, index, 1) * 0.65)
		var direction := Vector3(cos(phase), 0.0, sin(phase))
		piece.global_position = position + direction * radial * 0.25 + Vector3.UP * 0.035
		var size: float = _piece_size(style) * lerpf(0.72, 1.22, _hash01(event_counter, index, 2))
		piece.scale = _piece_scale(style, size)
		if style == "leaf_litter":
			piece.rotation = Vector3(
				_hash01(event_counter, index, 3) * 0.55,
				phase,
				_hash01(event_counter, index, 4) * 0.45
			)
		live_pieces.append(piece)
		var outward_target: Vector3 = (
			piece.global_position
			+ direction * radial
			+ Vector3.UP * (lift * lerpf(0.55, 1.25, _hash01(event_counter, index, 5)))
		)
		if style == "damp":
			outward_target += Vector3.UP * lift * 0.45
		var tween := piece.create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(
			piece,
			"global_position",
			outward_target,
			duration
		)
		tween.parallel().tween_property(
			piece,
			"scale",
			piece.scale * (0.62 if style == "dust" else 0.82),
			duration
		)
		if style == "leaf_litter":
			tween.parallel().tween_property(
				piece,
				"rotation:y",
				piece.rotation.y + (1.0 + _hash01(event_counter, index, 6) * 1.8),
				duration
			)
		tween.finished.connect(piece.queue_free)
	# The burst shares one material, so one alpha tween fades every piece together.
	var material_tween := create_tween()
	material_tween.tween_property(
		material,
		"albedo_color:a",
		0.0,
		duration
	)
	return count


func _make_contact_material(style: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var color: Color = _style_color(style)
	color.a *= profile.global_opacity_scale
	material.albedo_color = color
	return material


func _build_shared_meshes() -> void:
	sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	sphere_mesh.radial_segments = 6
	sphere_mesh.rings = 3
	leaf_mesh = BoxMesh.new()
	leaf_mesh.size = Vector3(1.0, 0.08, 0.42)


func _resolve_style(position: Vector3, material_id: String) -> String:
	for record: Dictionary in regions:
		if _region_contains(record, position):
			return str(record.get("style", "dust"))
	match material_id:
		"wood":
			return "leaf_litter"
		"soft":
			return "dust"
		_:
			return "stone"


func _region_contains(record: Dictionary, position: Vector3) -> bool:
	var center: Vector3 = record.get("center", Vector3.ZERO)
	var extents: Vector3 = record.get("extents", Vector3.ONE)
	var local: Vector3 = position - center
	return (
		absf(local.x) <= extents.x
		and absf(local.y) <= extents.y
		and absf(local.z) <= extents.z
	)


func _sort_regions(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("priority", 0)) > int(b.get("priority", 0))


func _style_color(style: String) -> Color:
	match style:
		"damp":
			return Color(0.56, 0.78, 0.72, 0.18)
		"leaf_litter":
			return Color(0.29, 0.22, 0.07, 0.72)
		"stone":
			return Color(0.48, 0.43, 0.30, 0.19)
		_:
			return Color(0.55, 0.45, 0.27, 0.22)


func _piece_size(style: String) -> float:
	match style:
		"damp":
			return 0.08
		"leaf_litter":
			return 0.075
		"stone":
			return 0.05
		_:
			return 0.055


func _piece_scale(style: String, size: float) -> Vector3:
	match style:
		"damp":
			return Vector3(size * 1.4, size * 0.65, size * 1.4)
		"leaf_litter":
			return Vector3(size * 1.5, size, size * 1.1)
		_:
			return Vector3.ONE * size


func _hash01(event_id: int, index: int, salt: int) -> float:
	var value: float = sin(
		float(event_id * 97 + index * 43 + salt * 17) * 12.9898
	) * 43758.5453
	return value - floor(value)


func _current_quality() -> int:
	if lighting_director == null:
		return 2
	return clampi(lighting_director.quality, 0, 2)


func _cleanup_pieces() -> void:
	var valid: Array[MeshInstance3D] = []
	for piece: MeshInstance3D in live_pieces:
		if (
			piece != null
			and is_instance_valid(piece)
			and not piece.is_queued_for_deletion()
		):
			valid.append(piece)
	live_pieces = valid


func _clear_live_pieces() -> void:
	for piece: MeshInstance3D in live_pieces:
		if piece != null and is_instance_valid(piece):
			piece.queue_free()
	live_pieces.clear()


func get_debug_data() -> Dictionary:
	return {
		"surface_contact_presentation_director": true,
		"initialized": profile != null and presentation_director != null,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"quality": _current_quality(),
		"region_count": regions.size(),
		"live_pieces": live_pieces.size(),
		"event_counter": event_counter,
		"contact_counts": contact_counts.duplicate(true),
		"last_contact": last_contact.duplicate(true),
		"uses_existing_presentation_events": true,
		"per_contact_raycast": false,
		"audio_authority": false,
		"gameplay_authority": false,
	}
