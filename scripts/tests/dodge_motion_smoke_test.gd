extends Node

const GraceDodgeProfile: DodgeMotionProfile = preload(
	"res://data/player/grace_dodge_motion_profile.tres"
)
const PlayerScene: PackedScene = preload("res://scenes/actors/player/player.tscn")


func _ready() -> void:
	GameState.set_stat("max_stamina", 100)
	GameState.set_stat("stamina", 100)
	GameState.player_invulnerable = false
	GameState.player_invulnerability_timer = 0.0

	var actor: CharacterBody3D = CharacterBody3D.new()
	actor.name = "DodgeActor"
	var action_state: PlayerActionState = PlayerActionState.new()
	action_state.name = "PlayerActionState"
	actor.add_child(action_state)
	var dodge: PlayerDodgeController = PlayerDodgeController.new()
	dodge.name = "PlayerDodgeController"
	dodge.profile = GraceDodgeProfile
	actor.add_child(dodge)
	add_child(actor)
	await get_tree().process_frame
	dodge.set_process(false)

	assert(dodge.actor == actor)
	assert(dodge.action_state == action_state)
	assert(dodge.is_in_group("player_dodge_motion_controller"))
	assert(GraceDodgeProfile.validate_profile().is_empty())
	assert(GraceDodgeProfile.get_phase(0.05) == "launch")
	assert(GraceDodgeProfile.get_phase(0.4) == "travel")
	assert(GraceDodgeProfile.get_phase(0.72) == "landing")
	assert(GraceDodgeProfile.get_phase(0.92) == "recovery")
	assert(GraceDodgeProfile.get_distance_multiplier("side") < 1.0)
	assert(GraceDodgeProfile.get_distance_multiplier("backstep") < GraceDodgeProfile.get_distance_multiplier("side"))

	assert(dodge.begin_dodge_in_direction(Vector3.FORWARD, "forward", true))
	assert(dodge.is_dodge_active())
	assert(action_state.is_dodging)
	assert(dodge.chain_count == 1)
	assert(dodge.get_dodge_phase() == "launch")
	var launch_velocity: Vector3 = dodge.get_dodge_velocity()
	assert(launch_velocity.length() > 0.0)

	dodge._process(dodge.dodge_duration * 0.12)
	assert(dodge.get_dodge_phase() == "launch")
	assert(dodge.is_invulnerability_window_active())
	assert(GameState.is_player_invulnerable())
	var iframe_weight: float = dodge.get_iframe_visual_weight()
	assert(iframe_weight > 0.0)

	dodge._process(dodge.dodge_duration * 0.25)
	assert(dodge.get_dodge_phase() == "travel")
	var travel_velocity: Vector3 = dodge.get_dodge_velocity()
	assert(travel_velocity.length() > launch_velocity.length())

	dodge._process(dodge.dodge_duration * 0.3)
	assert(dodge.get_dodge_phase() == "landing")
	assert(dodge.is_invulnerability_window_active())

	dodge._process(dodge.dodge_duration * 0.08)
	assert(not dodge.is_invulnerability_window_active())
	assert(dodge.can_cancel_into_cast())

	var before_steer: Vector3 = dodge.dodge_direction
	dodge.apply_debug_steering(Vector3.RIGHT, 0.1)
	assert(dodge.dodge_direction.x > before_steer.x)
	assert(dodge.dodge_direction.length() > 0.99)

	dodge.dodge_elapsed = dodge.dodge_duration * 0.82
	dodge.dodge_timer = dodge.dodge_duration - dodge.dodge_elapsed
	dodge.dodge_progress = 0.82
	assert(dodge.can_chain_dodge())
	assert(dodge.request_dodge_chain())
	assert(dodge.is_dodge_active())
	assert(dodge.chain_count == 2)
	assert(dodge.get_normalized_progress() == 0.0)
	assert(dodge.get_dodge_phase() == "launch")

	var carried_direction: Vector3 = dodge.cancel_into_weapon_technique()
	assert(carried_direction.length() > 0.99)
	assert(not dodge.is_dodge_active())
	assert(not action_state.is_dodging)
	assert(dodge.last_finish_reason == "weapon_technique")

	assert(dodge.begin_dodge_in_direction(Vector3.LEFT, "side", true))
	var expected_distance: float = dodge.dodge_distance
	var integrated_distance: float = 0.0
	var samples: int = 240
	for index: int in range(samples):
		var progress: float = (float(index) + 0.5) / float(samples)
		integrated_distance += (
			dodge.dodge_speed
			* GraceDodgeProfile.sample_speed_multiplier(progress)
			* dodge.dodge_duration
			/ float(samples)
		)
	assert(absf(integrated_distance - expected_distance) < 0.03)
	dodge._process(dodge.dodge_duration + 0.01)
	assert(not dodge.is_dodge_active())
	assert(not action_state.is_dodging)
	assert(dodge.last_finish_reason == "completed")

	var shared_player: CharacterBody3D = PlayerScene.instantiate() as CharacterBody3D
	shared_player.name = "SharedPlayer"
	shared_player.position = Vector3(0.0, 3.0, 0.0)
	add_child(shared_player)
	await get_tree().process_frame
	var shared_dodge: PlayerDodgeController = (
		shared_player.get_node_or_null("PlayerDodgeController") as PlayerDodgeController
	)
	var shared_visual: GraceWireMotionVisual = (
		shared_player.get_node_or_null("GraceVisualV1") as GraceWireMotionVisual
	)
	var wire: GraceWireSkeletonRenderer = (
		shared_player.get_node_or_null("GraceVisualV1/WireSkeletonRenderer") as GraceWireSkeletonRenderer
	)
	assert(shared_dodge != null)
	assert(shared_dodge.profile != null)
	assert(shared_dodge.profile == GraceDodgeProfile)
	assert(shared_visual != null)
	assert(wire != null)
	shared_dodge.set_process(false)
	GameState.set_stat("stamina", 100)
	assert(shared_dodge.begin_dodge_in_direction(Vector3.FORWARD, "forward", true))
	shared_dodge._process(shared_dodge.dodge_duration * 0.14)
	shared_visual.sample_animation_pose(1.0 / 60.0)
	wire.sample_now(1.0)
	var visual_debug: Dictionary = shared_visual.get_animation_debug_data()
	assert(str(visual_debug.get("dodge_phase", "")) == "launch")
	assert(bool(visual_debug.get("dodge_iframe", false)))
	assert(float(visual_debug.get("dodge_iframe_weight", 0.0)) > 0.0)
	assert(wire.center_material.emission_energy_multiplier > 1.35)
	assert(wire.has_finite_pose())

	var dodge_debug: Dictionary = shared_dodge.get_debug_data()
	for key: String in [
		"phase",
		"progress",
		"kind",
		"speed",
		"iframe",
		"chain_ready",
		"cast_cancel_ready",
		"guard_cancel_ready",
	]:
		assert(dodge_debug.has(key))

	print("DODGE_MOTION_SMOKE_TEST: PASS")
	get_tree().quit(0)
