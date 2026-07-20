extends Node3D
class_name CombustionPresenter

const FireEventScript = preload("res://scripts/presentation/fire_vfx_event.gd")
const FireProfileScript = preload("res://scripts/presentation/fire_presentation_profile.gd")
const FireVisualScript = preload("res://scripts/presentation/procedural_fire_visual.gd")
const FireRendererScript = preload("res://scripts/presentation/procedural_fire_renderer.gd")

@export var combustion_state_path: NodePath
@export var profile_kind: String = "torch"
@export var visual_offset: Vector3 = Vector3.ZERO
@export var visual_scale: float = 1.0
@export var presentation_enabled: bool = true

var combustion_state: Node
var persistent_visual: Node3D
var burst_renderer: Node3D
var profile: Resource
var last_state: String = ""


func _ready() -> void:
	resolve_combustion_state()
	if not presentation_enabled or combustion_state == null:
		return
	burst_renderer = FireRendererScript.new() as Node3D
	burst_renderer.name = "FireBurstRenderer"
	add_child(burst_renderer)
	profile = FireProfileScript.new()
	profile.apply_kind(profile_kind)
	profile.persistent = true
	var event: RefCounted = FireEventScript.make(
		FireEventScript.KIND_FLAME,
		global_position + visual_offset,
		0.0,
		max(float(profile.flame_radius) * visual_scale, 0.05),
		get_parent().name,
		["combustion", "procedural_fire"]
	)
	event.smoke_strength = 0.0
	event.ember_strength = 0.0
	persistent_visual = FireVisualScript.new() as Node3D
	persistent_visual.name = "PersistentCombustionVisual"
	add_child(persistent_visual)
	persistent_visual.position = visual_offset
	persistent_visual.scale = Vector3.ONE * max(visual_scale, 0.05)
	persistent_visual.configure(event, profile)
	if combustion_state.has_signal("extinguished"):
		combustion_state.extinguished.connect(_on_extinguished)
	update_from_combustion()


func _process(_delta: float) -> void:
	update_from_combustion()


func resolve_combustion_state() -> void:
	if combustion_state != null:
		return
	if not combustion_state_path.is_empty():
		combustion_state = get_node_or_null(combustion_state_path)
	if combustion_state == null:
		combustion_state = get_parent().get_node_or_null("CombustionState")


func update_from_combustion() -> void:
	if combustion_state == null or persistent_visual == null or not combustion_state.has_method("get_visual_state"):
		return
	var visual_state: Dictionary = combustion_state.get_visual_state()
	var state_name: String = str(visual_state.get("state", "cold"))
	var intensity: float = float(visual_state.get("intensity", 0.0))
	var smoke: float = float(visual_state.get("smoke", 0.0))
	var embers: float = float(visual_state.get("embers", 0.0))
	var airflow: Vector3 = visual_state.get("airflow", Vector3.ZERO) as Vector3
	if state_name == "smoldering":
		intensity = min(max(intensity, 0.04), 0.18)
		smoke = max(smoke, 0.8)
		embers = max(embers, 0.12)
	elif state_name in ["extinguished", "spent", "cold", "heating"]:
		intensity = 0.0
		if state_name == "extinguished":
			smoke = max(smoke * 0.35, 0.18)
		else:
			smoke = 0.0
		embers = 0.0
	persistent_visual.apply_state(intensity, airflow, smoke, embers)
	last_state = state_name


func _on_extinguished(source_name: String) -> void:
	if burst_renderer == null:
		return
	var event: RefCounted = FireEventScript.make(
		FireEventScript.KIND_EXTINGUISH,
		global_position + visual_offset,
		0.75,
		max(float(profile.flame_radius) * visual_scale, 0.2),
		source_name,
		["fire", "extinguish", "smoke"]
	)
	event.smoke_strength = 1.4
	event.ember_strength = 0.12
	event.duration_seconds = 1.8
	var extinguish_profile: Resource = FireProfileScript.new()
	extinguish_profile.apply_kind("extinguish")
	burst_renderer.render_event(event, extinguish_profile)


func reset_target() -> void:
	if burst_renderer != null and burst_renderer.has_method("reset_target"):
		burst_renderer.reset_target()
	update_from_combustion()


func get_debug_data() -> Dictionary:
	return {
		"combustion_presenter": true,
		"connected": combustion_state != null,
		"profile_kind": profile_kind,
		"last_state": last_state,
		"visual": persistent_visual.get_debug_data() if persistent_visual != null and persistent_visual.has_method("get_debug_data") else {},
		"bursts": burst_renderer.get_debug_data() if burst_renderer != null and burst_renderer.has_method("get_debug_data") else {},
	}
