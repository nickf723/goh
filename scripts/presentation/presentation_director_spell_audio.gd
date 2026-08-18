extends "res://scripts/presentation/presentation_director_spells.gd"
class_name SpellPresentationDirectorAudio

const SpellAudioScript = preload(
	"res://scripts/presentation/presentation_audio_fidelity_v2.gd"
)


func _ready() -> void:
	super._ready()
	var old_audio: PresentationAudio = audio
	if old_audio != null and is_instance_valid(old_audio):
		if old_audio.get_parent() == self:
			remove_child(old_audio)
		old_audio.queue_free()
	audio = SpellAudioScript.new() as PresentationAudio
	audio.name = "PresentationAudio"
	add_child(audio)


func _get_element_color(element: String) -> Color:
	match element.strip_edges().to_lower():
		"water":
			return Color(0.10, 0.52, 1.0, 1.0)
		"earth":
			return Color(0.27, 0.72, 0.18, 1.0)
		"fire":
			return Color(1.0, 0.24, 0.045, 1.0)
		"air":
			return Color(1.0, 0.48, 0.76, 1.0)
		"ice":
			return Color(0.38, 0.92, 1.0, 1.0)
		"metal":
			return Color(1.0, 0.84, 0.14, 1.0)
		"lightning":
			return Color(0.38, 0.32, 1.0, 1.0)
		"poison":
			return Color(0.58, 1.0, 0.12, 1.0)
		"life":
			return Color(0.12, 0.82, 0.38, 1.0)
		"death":
			return Color(0.82, 0.055, 0.09, 1.0)
		"body":
			return Color(0.95, 0.18, 0.62, 1.0)
		"soul":
			return Color(0.08, 0.88, 0.95, 1.0)
		"dreams":
			return Color(0.18, 0.42, 1.0, 1.0)
		"sound":
			return Color(1.0, 0.43, 0.12, 1.0)
		"space":
			return Color(0.63, 0.24, 1.0, 1.0)
		"time":
			return Color(1.0, 0.62, 0.12, 1.0)
		_:
			return Color(0.82, 0.86, 0.94, 1.0)
