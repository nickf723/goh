extends Node

const SkeletalGraceScene: PackedScene = preload(
	"res://scenes/actors/player/grace_humanoid_skeletal_proxy_v1.tscn"
)
const HumanoidRigContractScript = preload(
	"res://scripts/visuals/grace_humanoid_rig_contract.gd"
)
const ImportedHumanoidAdapterScript = preload(
	"res://scripts/visuals/grace_imported_humanoid_adapter.gd"
)
const AnimationLibraryContractScript = preload(
	"res://scripts/visuals/grace_animation_library_contract.gd"
)
const ImportedAnimationAdapterScript = preload(
	"res://scripts/visuals/grace_imported_animation_adapter.gd"
)
const AnimationSemanticResolverScript = preload(
	"res://scripts/visuals/grace_animation_semantic_resolver.gd"
)
const PresentationAssetAuditorScript = preload(
	"res://scripts/visuals/grace_presentation_asset_auditor.gd"
)

const EXPECTED_WEAPON_LANGUAGES: Array[String] = [
	"sword", "lance", "axe", "bow", "hammer", "mace", "daggers", "whip",
	"chains", "gauntlets", "flail", "halberd", "boomerang", "scythe", "staff", "shuriken",
]

var failures: Array[String] = []


func _ready() -> void:
	var rig: Node = SkeletalGraceScene.instantiate()
	add_child(rig)
	await get_tree().process_frame

	var data: Dictionary = {}
	if rig != null and rig.has_method("get_debug_data"):
		data = rig.call("get_debug_data") as Dictionary
	else:
		failures.append("skeletal Grace exposes debug data")

	_expect(bool(data.get("grounding_fix", false)), "grounding correction is active")
	_expect(bool(data.get("rest_pose_initialized", false)), "child bone pose translations initialize from rest")
	_expect(bool(data.get("pelvis_rest_preserved", false)), "pelvis animation preserves authored rest height")
	_expect(bool(data.get("weapon_language_v2", false)), "skeletal Grace owns diversified weapon language layer")
	_expect(bool(data.get("all_weapon_languages_candidate", false)), "active rig reports complete sixteen-class candidate coverage")

	var language_classes: Array = data.get("authored_language_classes", []) as Array
	_expect(language_classes.size() >= EXPECTED_WEAPON_LANGUAGES.size(), "active rig reports at least sixteen weapon languages")
	for weapon_class: String in EXPECTED_WEAPON_LANGUAGES:
		_expect(language_classes.has(weapon_class), weapon_class + " has intentional skeletal combat language")

	var foot_height: float = float(data.get("foot_height", 999.0))
	var span: float = float(data.get("head_to_foot_span", 0.0))
	var hand_span: float = float(data.get("hand_span", 0.0))
	var leg_span: float = float(data.get("leg_span", 0.0))
	_expect(absf(foot_height) < 0.16, "feet remain near the skeletal ground plane")
	_expect(span > 1.45, "head remains a full humanoid height above the feet")
	_expect(hand_span > 0.55, "left and right hands remain separated by articulated arms")
	_expect(leg_span > 0.6, "thigh-to-foot chain preserves articulated leg length")

	_validate_current_rig_contract(rig)
	_validate_godot_humanoid_profile_aliases()
	_validate_mixamo_aliases()
	_validate_animation_library_contract()

	if rig != null and is_instance_valid(rig):
		rig.queue_free()
	await get_tree().process_frame
	_finish()


func _validate_current_rig_contract(rig: Node) -> void:
	var skeleton: Skeleton3D = rig.get_node_or_null("Skeleton3D") as Skeleton3D if rig != null else null
	_expect(skeleton != null, "current Grace exposes Skeleton3D for import contract validation")
	if skeleton == null:
		return
	var contract: Dictionary = HumanoidRigContractScript.validate_skeleton(skeleton)
	_expect(bool(contract.get("compatible", false)), "current Grace satisfies humanoid rig semantic contract")
	_expect(int(contract.get("mapped_count", 0)) >= 17, "current Grace maps all required humanoid semantics")
	var semantic_map: Dictionary = contract.get("semantic_map", {}) as Dictionary
	_expect(semantic_map.has("hand_r"), "rig contract resolves weapon hand semantic")
	_expect(semantic_map.has("hand_l"), "rig contract resolves support hand semantic")
	_expect(semantic_map.has("head"), "rig contract resolves head semantic")
	_expect(semantic_map.has("foot_l") and semantic_map.has("foot_r"), "rig contract resolves both foot semantics")
	_expect((contract.get("hierarchy_errors", []) as Array).is_empty(), "current Grace semantic chains preserve hierarchy")

	var adapter: Node = ImportedHumanoidAdapterScript.new()
	adapter.set("skeleton_path", NodePath("../Skeleton3D"))
	rig.add_child(adapter)
	var resolved: bool = bool(adapter.call("resolve_rig"))
	_expect(resolved, "runtime humanoid adapter accepts current Grace skeleton")
	var adapter_data: Dictionary = adapter.call("get_debug_data") as Dictionary
	_expect(bool(adapter_data.get("weapon_hand_mapped", false)), "runtime adapter exposes primary weapon hand")
	_expect(bool(adapter_data.get("support_hand_mapped", false)), "runtime adapter exposes support hand")
	_expect(bool(adapter_data.get("feet_mapped", false)), "runtime adapter exposes both feet")
	var weapon_hand_transform: Transform3D = adapter.call("get_semantic_world_transform", "hand_r") as Transform3D
	_expect(weapon_hand_transform.origin.length() > 0.01, "runtime adapter returns a real weapon-hand transform")
	adapter.queue_free()


func _validate_godot_humanoid_profile_aliases() -> void:
	var specs: Array = [
		["Root", ""], ["Hips", "Root"], ["Spine", "Hips"], ["Chest", "Spine"],
		["UpperChest", "Chest"], ["Neck", "UpperChest"], ["Head", "Neck"],
		["LeftShoulder", "UpperChest"], ["LeftUpperArm", "LeftShoulder"],
		["LeftLowerArm", "LeftUpperArm"], ["LeftHand", "LeftLowerArm"],
		["RightShoulder", "UpperChest"], ["RightUpperArm", "RightShoulder"],
		["RightLowerArm", "RightUpperArm"], ["RightHand", "RightLowerArm"],
		["LeftUpperLeg", "Hips"], ["LeftLowerLeg", "LeftUpperLeg"],
		["LeftFoot", "LeftLowerLeg"], ["LeftToes", "LeftFoot"],
		["RightUpperLeg", "Hips"], ["RightLowerLeg", "RightUpperLeg"],
		["RightFoot", "RightLowerLeg"], ["RightToes", "RightFoot"],
	]
	var skeleton: Skeleton3D = _build_named_skeleton("GodotHumanoidProfileSkeleton", specs)
	var contract: Dictionary = HumanoidRigContractScript.validate_skeleton(skeleton)
	_expect(bool(contract.get("compatible", false)), "Godot humanoid-profile bone names satisfy Grace semantic contract")
	var semantic_map: Dictionary = contract.get("semantic_map", {}) as Dictionary
	_expect(int(semantic_map.get("pelvis", -1)) == skeleton.find_bone("Hips"), "Hips maps to Grace pelvis semantic")
	_expect(int(semantic_map.get("hand_r", -1)) == skeleton.find_bone("RightHand"), "RightHand maps to weapon hand semantic")
	_expect(int(semantic_map.get("forearm_l", -1)) == skeleton.find_bone("LeftLowerArm"), "LeftLowerArm maps to support forearm semantic")
	_expect(int(semantic_map.get("foot_r", -1)) == skeleton.find_bone("RightFoot"), "RightFoot maps to Grace foot semantic")
	skeleton.queue_free()


func _validate_mixamo_aliases() -> void:
	var specs: Array = [
		["mixamorig:Hips", ""], ["mixamorig:Spine", "mixamorig:Hips"],
		["mixamorig:Spine1", "mixamorig:Spine"], ["mixamorig:Spine2", "mixamorig:Spine1"],
		["mixamorig:Neck", "mixamorig:Spine2"], ["mixamorig:Head", "mixamorig:Neck"],
		["mixamorig:LeftShoulder", "mixamorig:Spine2"], ["mixamorig:LeftArm", "mixamorig:LeftShoulder"],
		["mixamorig:LeftForeArm", "mixamorig:LeftArm"], ["mixamorig:LeftHand", "mixamorig:LeftForeArm"],
		["mixamorig:RightShoulder", "mixamorig:Spine2"], ["mixamorig:RightArm", "mixamorig:RightShoulder"],
		["mixamorig:RightForeArm", "mixamorig:RightArm"], ["mixamorig:RightHand", "mixamorig:RightForeArm"],
		["mixamorig:LeftUpLeg", "mixamorig:Hips"], ["mixamorig:LeftLeg", "mixamorig:LeftUpLeg"],
		["mixamorig:LeftFoot", "mixamorig:LeftLeg"], ["mixamorig:LeftToeBase", "mixamorig:LeftFoot"],
		["mixamorig:RightUpLeg", "mixamorig:Hips"], ["mixamorig:RightLeg", "mixamorig:RightUpLeg"],
		["mixamorig:RightFoot", "mixamorig:RightLeg"], ["mixamorig:RightToeBase", "mixamorig:RightFoot"],
	]
	var skeleton: Skeleton3D = _build_named_skeleton("MixamoSkeleton", specs)
	var contract: Dictionary = HumanoidRigContractScript.validate_skeleton(skeleton)
	_expect(bool(contract.get("compatible", false)), "Mixamo humanoid bone names satisfy Grace semantic contract")
	var semantic_map: Dictionary = contract.get("semantic_map", {}) as Dictionary
	_expect(int(semantic_map.get("upper_arm_l", -1)) == skeleton.find_bone("mixamorig:LeftArm"), "Mixamo LeftArm maps to Grace upper-arm semantic")
	_expect(int(semantic_map.get("forearm_r", -1)) == skeleton.find_bone("mixamorig:RightForeArm"), "Mixamo RightForeArm maps to Grace forearm semantic")
	_expect(int(semantic_map.get("thigh_l", -1)) == skeleton.find_bone("mixamorig:LeftUpLeg"), "Mixamo LeftUpLeg maps to Grace thigh semantic")
	skeleton.queue_free()


func _validate_animation_library_contract() -> void:
	var player := AnimationPlayer.new()
	player.name = "ImportedAnimationPlayer"
	add_child(player)
	var library := AnimationLibrary.new()
	var clip_names: Array[String] = [
		"Armature|Idle", "Run_Loop", "Jump", "Fall", "Landing", "Combat_Roll", "Hit_Reaction",
		"Sword_Light_1", "Sword_Light_2", "Sword_Light_3", "Sword_Light_4", "Reprise_Thrust",
		"Sword_Heavy", "Sword_H1", "Sword_H2", "Sword_H3", "Sword_H4",
		"Passing_Cut", "Rush_Break", "Comet_Slash", "Falling_Edge",
	]
	for clip_name: String in clip_names:
		var animation := Animation.new()
		animation.length = 0.5
		library.add_animation(StringName(clip_name), animation)
	player.add_animation_library(StringName(), library)

	var validation: Dictionary = AnimationLibraryContractScript.validate_player(player)
	_expect(bool(validation.get("compatible_core", false)), "imported animation library satisfies Grace core clip contract")
	_expect(bool(validation.get("sword_calibration_ready", false)), "imported animation library satisfies complete Sword calibration clip contract")
	_expect((validation.get("missing_sword", []) as Array).is_empty(), "complete Sword import library has no missing calibration roles")
	_expect(AnimationLibraryContractScript.get_animation_name(player, "idle") == StringName("Armature|Idle"), "wrapper animation name resolves to idle semantic")
	_expect(AnimationLibraryContractScript.get_animation_name(player, "dodge") == StringName("Combat_Roll"), "combat roll resolves to dodge semantic")
	_expect(AnimationLibraryContractScript.get_animation_name(player, "sword_reprise") == StringName("Reprise_Thrust"), "Reprise Thrust resolves to Sword reprise semantic")
	_expect(AnimationLibraryContractScript.get_animation_name(player, "sword_heavy_3") == StringName("Sword_H3"), "Sword H3 resolves to depth-three Heavy semantic")
	_expect(AnimationLibraryContractScript.get_animation_name(player, "sword_dash_light") == StringName("Passing_Cut"), "Passing Cut resolves to Sword Dash Light semantic")
	_expect(AnimationLibraryContractScript.get_animation_name(player, "sword_aerial_heavy") == StringName("Falling_Edge"), "Falling Edge resolves to Sword Aerial Heavy semantic")

	var adapter: Node = ImportedAnimationAdapterScript.new()
	adapter.set("animation_player_path", NodePath("../ImportedAnimationPlayer"))
	add_child(adapter)
	var resolved: bool = bool(adapter.call("resolve_library"))
	_expect(resolved, "runtime imported animation adapter accepts core library")
	var adapter_data: Dictionary = adapter.call("get_debug_data") as Dictionary
	_expect(bool(adapter_data.get("core_ready", false)), "runtime animation adapter reports core readiness")
	_expect(bool(adapter_data.get("sword_calibration_ready", false)), "runtime animation adapter reports complete Sword calibration readiness")
	var sword_animation: Animation = adapter.call("get_animation", "sword_light_1") as Animation
	_expect(sword_animation != null, "runtime animation adapter returns semantic Sword clip")

	var sword_l3 := WeaponAttackDefinition.new()
	sword_l3.attack_id = "sword_l3"
	_expect(
		str(adapter.call("get_requested_semantic", "attack", "sword", sword_l3)) == "sword_light_3",
		"gameplay Sword L3 resolves to imported Sword Light 3 semantic"
	)
	_expect(
		StringName(adapter.call("get_requested_animation_name", "attack", "sword", sword_l3)) == StringName("Sword_Light_3"),
		"gameplay Sword L3 resolves through semantic adapter to imported clip"
	)

	var dash_heavy := WeaponAttackDefinition.new()
	dash_heavy.extra_tags.append("dash_heavy")
	_expect(
		AnimationSemanticResolverScript.resolve_attack_semantic("hammer", dash_heavy) == "hammer_dash_heavy",
		"universal Dash Heavy produces class-qualified imported semantic"
	)

	var unapproved_axe_ground := WeaponAttackDefinition.new()
	unapproved_axe_ground.attack_id = "axe_l1"
	_expect(
		AnimationSemanticResolverScript.resolve_attack_semantic("axe", unapproved_axe_ground) == "",
		"unapproved non-Sword ground combo keeps procedural fallback"
	)

	var audit: Dictionary = PresentationAssetAuditorScript.audit(self)
	_expect(str(audit.get("migration_stage", "")) == "sword_candidate", "complete synthetic package reaches Sword migration candidate stage")
	_expect(bool(audit.get("skeleton_ready", false)), "presentation auditor sees compatible humanoid skeleton")
	_expect(bool(audit.get("core_animation_ready", false)), "presentation auditor sees core imported animation readiness")
	_expect(bool(audit.get("sword_animation_ready", false)), "presentation auditor sees full Sword imported animation readiness")

	adapter.queue_free()
	player.queue_free()


func _build_named_skeleton(skeleton_name: String, specs: Array) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = skeleton_name
	add_child(skeleton)
	var indices: Dictionary = {}
	for spec_variant: Variant in specs:
		var spec: Array = spec_variant as Array
		var bone_name: String = str(spec[0])
		var parent_name: String = str(spec[1])
		skeleton.add_bone(bone_name)
		var index: int = skeleton.find_bone(bone_name)
		indices[bone_name] = index
		if parent_name != "":
			_expect(indices.has(parent_name), skeleton_name + " builds parent before child: " + bone_name)
			if indices.has(parent_name):
				skeleton.set_bone_parent(index, int(indices[parent_name]))
		skeleton.set_bone_rest(index, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.1, 0.0)))
	return skeleton


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("GRACE_SKELETAL_GROUNDING_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("GRACE_SKELETAL_GROUNDING_SMOKE_TEST: " + failure)
	get_tree().quit(1)
