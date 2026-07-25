extends Node

const StimulusManagerScript = preload("res://scripts/perception/perception_stimulus_manager.gd")
const StealthControllerScript = preload("res://scripts/player/player_stealth_controller.gd")
const MovementEmitterScript = preload("res://scripts/perception/perception_movement_emitter.gd")


func _ready() -> void:
	var manager: PerceptionStimulusManager = StimulusManagerScript.new() as PerceptionStimulusManager
	add_child(manager)
	var actor := CharacterBody3D.new()
	actor.name = "StealthTestActor"
	add_child(actor)
	var stealth: Node = StealthControllerScript.new()
	stealth.name = "StealthController"
	actor.add_child(stealth)
	assert(stealth.has_method("set_crouched"))
	stealth.call("set_crouched", true)
	assert(bool(stealth.call("is_crouched")))
	assert(float(stealth.call("get_movement_multiplier")) < 1.0)
	assert(float(stealth.call("get_noise_multiplier")) < 1.0)
	assert(float(stealth.call("get_visibility_multiplier")) < 1.0)
	var emitter: Node = MovementEmitterScript.new()
	emitter.name = "ManualMovementEmitter"
	actor.add_child(emitter)
	assert(emitter.has_method("sample_surface"))
	var stimulus: PerceptionStimulus = manager.emit_stimulus(
		Vector3.ZERO, 18.0, "echolocation", 1.0, actor,
		"Echolocation test", 1.5,
		["acoustic", "echolocation", "frequency:broadband"]
	)
	assert(stimulus.tags.has("echolocation"))
	assert(stimulus.loudness == 18.0)
	print("PASS: Crouch multipliers and unified acoustic stimuli loaded.")
