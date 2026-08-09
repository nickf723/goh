extends "res://scripts/presentation/presentation_director_spells.gd"
class_name SpellPresentationDirectorAudio

const SpellAudioScript = preload(
	"res://scripts/presentation/presentation_audio_spells.gd"
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
