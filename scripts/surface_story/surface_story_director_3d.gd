extends Node3D
class_name SurfaceStoryDirector3D

signal surface_story_enabled_changed(enabled: bool)
signal stamp_created(kind: String, stamp_name: String)

const TextureFactoryScript = preload(
	"res://scripts/surface_story/surface_story_texture_factory.gd"
)

@export var profile: SurfaceStoryProfile
@export var enabled: bool = true
@export var debug_hotkeys_enabled: bool = false

var texture_factory: SurfaceStoryTextureFactory = null
var decals: Array[Decal] = []
var counts_by_kind: Dictionary = {}
var created_count: int = 0


func _ready() -> void:
	add_to_group("surface_story_director")
	add_to_group("debuggable")
	if profile != null:
		texture_factory = TextureFactoryScript.new(
			profile.texture_resolution
		) as SurfaceStoryTextureFactory
	set_meta("surface_story_initialized", texture_factory != null)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_hotkeys_enabled:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_F4:
		return
	set_enabled(not enabled)
	print("Surface Story Director: ", "ON" if enabled else "OFF")
	get_viewport().set_input_as_handled()


func set_enabled(value: bool) -> void:
	enabled = value
	for decal: Decal in decals:
		if decal != null and is_instance_valid(decal):
			decal.visible = enabled
	surface_story_enabled_changed.emit(enabled)


func create_stamp(
	kind: String,
	world_position: Vector3,
	surface_normal: Vector3,
	footprint: Vector2,
	rotation_radians: float = 0.0,
	intensity: float = 1.0,
	projection_depth: float = -1.0,
	stamp_label: String = ""
) -> Decal:
	if texture_factory == null or profile == null:
		return null
	var normalized_kind: String = kind.strip_edges().to_lower()
	var texture_set: Dictionary = texture_factory.get_texture_set(normalized_kind)
	var albedo: Texture2D = texture_set.get("albedo") as Texture2D
	var orm: Texture2D = texture_set.get("orm") as Texture2D
	if albedo == null:
		return null

	var normal: Vector3 = surface_normal
	if normal.length_squared() <= 0.000001:
		normal = Vector3.UP
	normal = normal.normalized()
	var depth: float = projection_depth
	if depth <= 0.0:
		depth = (
			profile.floor_projection_depth
			if absf(normal.y) > 0.72
			else profile.wall_projection_depth
		)

	var decal := Decal.new()
	created_count += 1
	decal.name = (
		stamp_label
		if stamp_label.strip_edges() != ""
		else "%sStamp%03d" % [normalized_kind.capitalize(), created_count]
	)
	decal.size = Vector3(
		maxf(absf(footprint.x), 0.05),
		maxf(depth, 0.02),
		maxf(absf(footprint.y), 0.05)
	)
	decal.texture_albedo = albedo
	decal.texture_orm = orm
	decal.modulate = Color(1.0, 1.0, 1.0, _resolved_intensity(normalized_kind, intensity))
	decal.albedo_mix = _albedo_mix_for_kind(normalized_kind)
	decal.normal_fade = profile.normal_fade
	decal.upper_fade = 0.08
	decal.lower_fade = 0.08
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = profile.distance_fade_begin
	decal.distance_fade_length = profile.distance_fade_length
	decal.visible = enabled
	add_child(decal)

	# Decals project along local -Y. Build the receiving orientation in world
	# space so the API remains correct even if the Director itself is transformed.
	# Sink most of the projection volume into the receiving surface so decorative
	# floor/wall history has minimal opportunity to overlap dynamic actors.
	var orientation := Basis(Quaternion(Vector3.DOWN, -normal))
	var embedded_position: Vector3 = world_position - normal * depth * 0.44
	decal.global_transform = Transform3D(orientation, embedded_position)
	if absf(rotation_radians) > 0.00001:
		decal.rotate_object_local(Vector3.UP, rotation_radians)

	decal.add_to_group("surface_story_stamp")
	decal.set_meta("surface_story_kind", normalized_kind)
	decal.set_meta("surface_story_intensity", intensity)
	decal.set_meta("surface_story_contact_point", world_position)
	decal.set_meta("surface_story_projection_embedded", true)
	decals.append(decal)
	counts_by_kind[normalized_kind] = int(counts_by_kind.get(normalized_kind, 0)) + 1
	stamp_created.emit(normalized_kind, decal.name)
	return decal


func clear_stamps() -> void:
	for decal: Decal in decals:
		if decal != null and is_instance_valid(decal):
			decal.queue_free()
	decals.clear()
	counts_by_kind.clear()
	created_count = 0


func _resolved_intensity(kind: String, authored_intensity: float) -> float:
	var kind_scale: float = 1.0
	match kind:
		"crack":
			kind_scale = profile.crack_intensity
		"moss":
			kind_scale = profile.moss_intensity
		"wet":
			kind_scale = profile.wet_intensity
		"grime":
			kind_scale = profile.grime_intensity
		"wear":
			kind_scale = profile.wear_intensity
		"carving":
			kind_scale = profile.carving_intensity
	return clampf(
		maxf(authored_intensity, 0.0)
		* profile.global_intensity
		* kind_scale,
		0.0,
		1.0
	)


func _albedo_mix_for_kind(kind: String) -> float:
	match kind:
		"wet":
			return 0.58
		"wear":
			return 0.44
		"carving":
			return 0.70
		_:
			return 0.88


func get_debug_data() -> Dictionary:
	var live_count: int = 0
	for decal: Decal in decals:
		if decal != null and is_instance_valid(decal) and not decal.is_queued_for_deletion():
			live_count += 1
	return {
		"surface_story_director": true,
		"initialized": texture_factory != null,
		"profile_id": profile.profile_id if profile != null else "",
		"enabled": enabled,
		"debug_hotkeys": debug_hotkeys_enabled,
		"stamp_count": live_count,
		"counts_by_kind": counts_by_kind.duplicate(true),
		"texture_factory": texture_factory.get_debug_data() if texture_factory != null else {},
		"native_decals": true,
		"geometry_unchanged": true,
		"projection_embedded": true,
	}
