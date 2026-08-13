extends RefCounted
class_name WeaponPresentationAssetContract

# Semantic marker contract for imported/runtime weapon presentation scenes.
# Combat ownership remains in WeaponController; this only discovers presentation
# anchors that production assets may author.

const MARKER_ALIASES: Dictionary = {
	"support_grip": ["SupportGrip", "support_grip"],
	"trail_base": ["TrailBase", "TrailOrigin", "trail_base", "trail_origin"],
	"trail_tip": ["TrailTip", "trail_tip"],
	"projectile_origin": ["ProjectileOrigin", "ThrowOrigin", "Muzzle", "projectile_origin"],
}

const TWO_HANDED_CLASSES: Array[String] = [
	"hammer", "lance", "halberd", "staff", "scythe",
]


static func build_marker_map(root: Node) -> Dictionary:
	var result: Dictionary = {}
	if root == null:
		return result
	for semantic_variant: Variant in MARKER_ALIASES.keys():
		var semantic: String = str(semantic_variant)
		var marker: Node3D = find_marker(root, semantic)
		if marker != null:
			result[semantic] = marker
	return result


static func find_marker(root: Node, semantic: String) -> Node3D:
	if root == null or not MARKER_ALIASES.has(semantic):
		return null
	var aliases: Array = MARKER_ALIASES[semantic] as Array
	return _find_matching_node(root, aliases)


static func validate_asset(root: Node, weapon_class: String = "") -> Dictionary:
	var markers: Dictionary = build_marker_map(root)
	var support_grip_expected: bool = TWO_HANDED_CLASSES.has(weapon_class)
	return {
		"valid_root": root is Node3D,
		"marker_map": markers,
		"marker_count": markers.size(),
		"support_grip_expected": support_grip_expected,
		"support_grip_present": markers.has("support_grip"),
		"two_handed_quality_ready": not support_grip_expected or markers.has("support_grip"),
		"trail_pair_present": markers.has("trail_base") and markers.has("trail_tip"),
		"projectile_origin_present": markers.has("projectile_origin"),
	}


static func get_marker_world_transform(root: Node, semantic: String) -> Transform3D:
	var marker: Node3D = find_marker(root, semantic)
	return marker.global_transform if marker != null else Transform3D.IDENTITY


static func _find_matching_node(root: Node, aliases: Array) -> Node3D:
	if root is Node3D:
		var normalized_name: String = _normalize(root.name)
		for alias_variant: Variant in aliases:
			if normalized_name == _normalize(str(alias_variant)):
				return root as Node3D
	for child: Node in root.get_children():
		var found: Node3D = _find_matching_node(child, aliases)
		if found != null:
			return found
	return null


static func _normalize(value: String) -> String:
	return value.to_lower().replace("_", "").replace("-", "").replace(" ", "")
