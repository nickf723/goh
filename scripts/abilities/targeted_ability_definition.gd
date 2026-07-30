extends AbilityDefinition
class_name TargetedAbilityDefinition


@export_group("Targeting Preview")
@export var targeting_profile: SpellTargetingProfile


func get_targeting_profile() -> SpellTargetingProfile:
	return targeting_profile


func get_targeting_preview_summary() -> Dictionary:
	var profile: SpellTargetingProfile = SpellTargetingCatalog.build_profile(self)
	return SpellTargetingCatalog.get_preview_summary(
		self,
		profile.to_config()
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var profile: SpellTargetingProfile = SpellTargetingCatalog.build_profile(self)
	data["targeting_profile"] = profile.get_summary()
	data["targeting_profile_errors"] = profile.validate_profile()
	return data
