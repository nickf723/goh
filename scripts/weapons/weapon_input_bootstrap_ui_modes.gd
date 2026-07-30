extends "res://scripts/weapons/weapon_input_bootstrap.gd"
class_name WeaponInputBootstrapUIModes


const InputModeRouterScript = preload(
	"res://scripts/input/player_control_router_input_modes.gd"
)
const PerformanceDockScript = preload(
	"res://scripts/ui/quick_spell_belt_performance.gd"
)


func install_player_control_router() -> void:
	var weapon_controller: Node = get_parent()
	var player: Node = weapon_controller.get_parent() if weapon_controller != null else null
	if player == null or player.get_node_or_null("PlayerControlRouter") != null:
		return
	var router: Node = InputModeRouterScript.new()
	router.name = "PlayerControlRouter"
	player.add_child(router)


func install_quick_spell_belt() -> void:
	var weapon_controller: Node = get_parent()
	var player: Node = weapon_controller.get_parent() if weapon_controller != null else null
	if (
		player == null
		or player.get_node_or_null("QuickSpellBeltPresentation") != null
	):
		return
	var presentation: Node = PerformanceDockScript.new()
	presentation.name = "QuickSpellBeltPresentation"
	player.add_child(presentation)
