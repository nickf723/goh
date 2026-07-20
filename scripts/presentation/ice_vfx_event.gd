extends Resource
class_name IceVfxEvent

const KIND_FREEZE_FRONT: String = "freeze_front"
const KIND_CRYSTAL_GROWTH: String = "crystal_growth"
const KIND_FROST: String = "frost"
const KIND_CRACK: String = "crack"
const KIND_SHATTER: String = "shatter"
const KIND_THAW: String = "thaw"
const KIND_PROJECTILE: String = "projectile"
const KIND_IMPACT: String = "impact"

@export var kind: String = KIND_FREEZE_FRONT
@export var world_position: Vector3 = Vector3.ZERO
@export var normal: Vector3 = Vector3.UP
@export var direction: Vector3 = Vector3.FORWARD
@export var radius: float = 1.0
@export var intensity: float = 1.0
@export var progress: float = 1.0
@export var duration_seconds: float = 1.2
@export var seed: int = 1
@export var branch_count: int = 6
@export var segment_count: int = 7
@export var shard_count: int = 18
@export var source_id: String = "ice_vfx"
@export var tint: Color = Color(0.58, 0.9, 1.0, 1.0)
@export var tags: Array[String] = []


static func make(
	effect_kind: String,
	position_value: Vector3,
	normal_value: Vector3 = Vector3.UP,
	intensity_value: float = 1.0,
	radius_value: float = 1.0,
	seed_value: int = 1,
	source_value: String = "ice_vfx",
	tag_values: Array[String] = []
) -> IceVfxEvent:
	var event := IceVfxEvent.new()
	event.kind = effect_kind
	event.world_position = position_value
	event.normal = normal_value.normalized() if normal_value.length() > 0.001 else Vector3.UP
	event.intensity = max(intensity_value, 0.0)
	event.radius = max(radius_value, 0.01)
	event.seed = seed_value
	event.source_id = source_value
	event.tags = tag_values.duplicate()
	return event


func is_valid_event() -> bool:
	return (
		world_position.is_finite()
		and normal.is_finite()
		and direction.is_finite()
		and is_finite(radius)
		and is_finite(intensity)
		and is_finite(progress)
		and radius > 0.0
		and intensity >= 0.0
		and segment_count >= 1
		and branch_count >= 0
		and shard_count >= 0
	)


func get_plane_basis() -> Basis:
	var safe_normal: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	var tangent: Vector3 = safe_normal.cross(Vector3.UP)
	if tangent.length() <= 0.05:
		tangent = safe_normal.cross(Vector3.FORWARD)
	if tangent.length() <= 0.05:
		tangent = Vector3.RIGHT
	tangent = tangent.normalized()
	var bitangent: Vector3 = safe_normal.cross(tangent).normalized()
	return Basis(tangent, safe_normal, bitangent)


func has_tag(tag: String) -> bool:
	return tags.has(tag)
