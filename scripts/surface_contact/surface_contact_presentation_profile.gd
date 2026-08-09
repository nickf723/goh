extends Resource
class_name SurfaceContactPresentationProfile

@export var profile_id: String = "surface_contact_presentation"
@export var display_name: String = "Surface Contact Presentation"
@export_range(0, 12, 1) var performance_footstep_pieces: int = 0
@export_range(0, 18, 1) var performance_landing_pieces: int = 0
@export_range(0, 12, 1) var balanced_footstep_pieces: int = 3
@export_range(0, 18, 1) var balanced_landing_pieces: int = 7
@export_range(0, 12, 1) var cinematic_footstep_pieces: int = 5
@export_range(0, 18, 1) var cinematic_landing_pieces: int = 11
@export_range(0.05, 1.5, 0.01) var footstep_duration: float = 0.34
@export_range(0.05, 2.0, 0.01) var landing_duration: float = 0.52
@export_range(8, 128, 1) var maximum_live_pieces: int = 72
@export_range(0.0, 1.0, 0.01) var global_opacity_scale: float = 0.72


func get_piece_count(event_type: String, quality: int) -> int:
	var landing: bool = event_type == "landing"
	match clampi(quality, 0, 2):
		0:
			return performance_landing_pieces if landing else performance_footstep_pieces
		1:
			return balanced_landing_pieces if landing else balanced_footstep_pieces
		_:
			return cinematic_landing_pieces if landing else cinematic_footstep_pieces


func get_debug_data() -> Dictionary:
	return {
		"surface_contact_presentation_profile": true,
		"profile_id": profile_id,
		"balanced_footstep_pieces": balanced_footstep_pieces,
		"cinematic_footstep_pieces": cinematic_footstep_pieces,
		"maximum_live_pieces": maximum_live_pieces,
	}
