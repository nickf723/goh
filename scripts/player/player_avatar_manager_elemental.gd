extends "res://scripts/player/player_avatar_manager.gd"
class_name PlayerAvatarManagerElemental

var elemental_authority_controller: PlayerElementalAuthorityController


func _resolve_bindings() -> void:
	super._resolve_bindings()
	if actor != null:
		elemental_authority_controller = actor.get_node_or_null(
			"ElementalAuthorityController"
		) as PlayerElementalAuthorityController


func _validate_bindings() -> Array[String]:
	var failures: Array[String] = super._validate_bindings()
	if elemental_authority_controller == null:
		failures.append("ElementalAuthorityController is missing")
	return failures


func _capture_configuration() -> Dictionary:
	var snapshot: Dictionary = super._capture_configuration()
	snapshot["authority_profile"] = (
		elemental_authority_controller.get_authority_profile()
		if elemental_authority_controller != null
		else null
	)
	return snapshot


func _apply_definition(definition: PlayableAvatarDefinition) -> Array[String]:
	var failures: Array[String] = super._apply_definition(definition)
	if elemental_authority_controller == null:
		failures.append("elemental authority controller is unavailable")
		return failures
	elemental_authority_controller.set_authority_profile(
		definition.elemental_authority_profile
	)
	return failures


func _restore_configuration(snapshot: Dictionary) -> bool:
	if not super._restore_configuration(snapshot):
		return false
	if elemental_authority_controller == null:
		return false
	var authority_value: Variant = snapshot.get("authority_profile", null)
	if authority_value == null:
		elemental_authority_controller.set_authority_profile(null)
		return true
	if authority_value is ElementalAuthorityProfile:
		elemental_authority_controller.set_authority_profile(
			authority_value as ElementalAuthorityProfile
		)
		return true
	return false


func _validate_live_contract(
	definition: PlayableAvatarDefinition
) -> Array[String]:
	var failures: Array[String] = super._validate_live_contract(definition)
	if definition == null:
		return failures
	if elemental_authority_controller == null:
		failures.append("elemental authority controller is unavailable")
	elif (
		elemental_authority_controller.get_authority_profile()
		!= definition.elemental_authority_profile
	):
		failures.append(
			"elemental authority does not match " + definition.avatar_id
		)
	return failures


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	if elemental_authority_controller != null:
		var authority: Dictionary = elemental_authority_controller.get_debug_data()
		data["elemental_authority"] = authority
		data["authority_id"] = str(authority.get("authority_id", "none"))
		data["authority_element"] = str(authority.get("element", "none"))
		data["authority_owned_fields"] = int(authority.get("owned_fields", 0))
		data["authority_last_weave"] = str(authority.get("last_weave", "none"))
	else:
		data["elemental_authority"] = {}
		data["authority_id"] = "none"
		data["authority_element"] = "none"
		data["authority_owned_fields"] = 0
		data["authority_last_weave"] = "none"
	return data
