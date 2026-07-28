extends Resource
class_name PlayableAvatarDefinition

@export_group("Identity")
@export var avatar_id: String = "avatar"
@export var display_name: String = "Playable Avatar"
@export_enum("mortal", "divine_incarnation", "transformation", "possession") var avatar_kind: String = "mortal"
@export var element: String = ""
@export var patron_id: String = ""
@export_multiline var description: String = ""
@export var tags: Array[String] = []

@export_group("Availability")
@export var required_unlock_id: String = ""
@export var debug_available: bool = false
@export_range(0.0, 600.0, 0.5) var manifestation_duration: float = 0.0

@export_group("Combat Kit")
@export var weapon_definition: WeaponDefinition
@export var ability_loadout: AbilityLoadout
@export_range(0, 32, 1) var starting_ability_index: int = 0

@export_group("Movement Identity")
@export var ground_motion_profile: GroundMotionProfile
@export var dodge_motion_profile: DodgeMotionProfile
@export var combat_footwork_profile: CombatFootworkProfile
@export var vertical_motion_profile: VerticalMotionProfile

@export_group("Wire Presentation")
@export var override_wire_palette: bool = false
@export var wire_center_color: Color = Color(0.88, 0.9, 1.0)
@export var wire_left_color: Color = Color(0.28, 0.82, 1.0)
@export var wire_right_color: Color = Color(1.0, 0.42, 0.78)
@export var wire_joint_color: Color = Color(1.0, 0.76, 0.24)
@export_range(0.5, 4.0, 0.05) var wire_emission_multiplier: float = 1.35

@export_group("Shared Anchor Contract")
@export var preserve_shared_health: bool = true
@export var preserve_world_transform: bool = true
@export var preserve_velocity: bool = true
@export var preserve_lock_on_target: bool = true


func validate_definition() -> Array[String]:
	var failures: Array[String] = []
	if avatar_id.strip_edges() == "":
		failures.append("avatar_id must not be empty")
	if display_name.strip_edges() == "":
		failures.append(avatar_id + ": display_name must not be empty")
	if avatar_kind not in ["mortal", "divine_incarnation", "transformation", "possession"]:
		failures.append(avatar_id + ": avatar_kind is invalid")
	if avatar_kind == "divine_incarnation" and element.strip_edges() == "":
		failures.append(avatar_id + ": divine incarnations require an element")
	if weapon_definition == null:
		failures.append(avatar_id + ": weapon_definition is required")
	if ability_loadout == null:
		failures.append(avatar_id + ": ability_loadout is required")
	elif ability_loadout.get_equipped_ability_count() <= 0:
		failures.append(avatar_id + ": ability_loadout has no equipped abilities")
	elif starting_ability_index < 0 or starting_ability_index >= ability_loadout.get_equipped_ability_count():
		failures.append(avatar_id + ": starting_ability_index is outside the equipped loadout")
	if ground_motion_profile == null:
		failures.append(avatar_id + ": ground_motion_profile is required")
	elif not ground_motion_profile.validate_profile().is_empty():
		failures.append(avatar_id + ": ground_motion_profile is invalid")
	if dodge_motion_profile == null:
		failures.append(avatar_id + ": dodge_motion_profile is required")
	elif not dodge_motion_profile.validate_profile().is_empty():
		failures.append(avatar_id + ": dodge_motion_profile is invalid")
	if combat_footwork_profile == null:
		failures.append(avatar_id + ": combat_footwork_profile is required")
	elif not combat_footwork_profile.validate_profile().is_empty():
		failures.append(avatar_id + ": combat_footwork_profile is invalid")
	if vertical_motion_profile == null:
		failures.append(avatar_id + ": vertical_motion_profile is required")
	elif not vertical_motion_profile.validate_profile().is_empty():
		failures.append(avatar_id + ": vertical_motion_profile is invalid")
	if manifestation_duration < 0.0:
		failures.append(avatar_id + ": manifestation_duration must not be negative")
	if wire_emission_multiplier <= 0.0:
		failures.append(avatar_id + ": wire_emission_multiplier must be positive")
	if not preserve_shared_health:
		failures.append(avatar_id + ": v1 avatars must preserve the shared health anchor")
	if not preserve_world_transform:
		failures.append(avatar_id + ": v1 avatars must preserve the stable world transform")
	return failures


func get_wire_palette() -> Dictionary:
	return {
		"center": wire_center_color,
		"left": wire_left_color,
		"right": wire_right_color,
		"joint": wire_joint_color,
		"emission": wire_emission_multiplier,
	}


func get_equipped_element_rows() -> Array[String]:
	var elements: Array[String] = []
	if ability_loadout == null:
		return elements
	for ability: AbilityDefinition in ability_loadout.equipped_abilities:
		if ability == null or ability.element == "" or elements.has(ability.element):
			continue
		elements.append(ability.element)
	return elements


func has_only_matching_element_spells() -> bool:
	if element == "" or ability_loadout == null:
		return true
	for ability: AbilityDefinition in ability_loadout.equipped_abilities:
		if ability != null and ability.element != element:
			return false
	return true


func get_debug_summary() -> Dictionary:
	return {
		"avatar_id": avatar_id,
		"display_name": display_name,
		"kind": avatar_kind,
		"element": element,
		"patron_id": patron_id,
		"required_unlock": required_unlock_id,
		"debug_available": debug_available,
		"manifestation_duration": manifestation_duration,
		"weapon": weapon_definition.display_name if weapon_definition != null else "none",
		"weapon_class": weapon_definition.weapon_class if weapon_definition != null else "none",
		"spell_count": ability_loadout.get_equipped_ability_count() if ability_loadout != null else 0,
		"spell_elements": get_equipped_element_rows(),
		"matching_element_only": has_only_matching_element_spells(),
		"wire_override": override_wire_palette,
	}
