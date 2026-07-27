from __future__ import annotations

import json
from pathlib import Path
from textwrap import dedent


FILES: dict[str, str] = {
    "shaders/environment/modular_surface.gdshader": r'''
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.35, 0.36, 0.34, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.2, 0.22, 0.21, 1.0);
uniform float variation_scale : hint_range(0.05, 4.0, 0.05) = 0.65;
uniform float variation_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float band_scale : hint_range(0.0, 4.0, 0.05) = 0.35;
uniform float roughness_value : hint_range(0.0, 1.0, 0.01) = 0.86;
uniform float metallic_value : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec4 emission_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0, 0.05) = 0.0;
uniform float side_darkening : hint_range(0.0, 0.5, 0.01) = 0.08;

varying vec3 world_position;
varying vec3 world_normal;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float coarse = hash31(floor(world_position * variation_scale));
	float fine = hash31(floor(world_position * variation_scale * 3.7 + vec3(3.1, 7.3, 11.7)));
	float band = 0.5 + 0.5 * sin((world_position.x + world_position.z) * band_scale + coarse * 3.14159);
	float mix_weight = clamp(
		0.5
		+ (coarse - 0.5) * variation_strength * 2.0
		+ (fine - 0.5) * variation_strength
		+ (band - 0.5) * variation_strength * 0.35,
		0.0,
		1.0
	);
	vec3 surface_color = mix(base_color.rgb, secondary_color.rgb, mix_weight);
	float upward = clamp(dot(normalize(world_normal), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	surface_color *= 1.0 - side_darkening * (1.0 - upward);
	ALBEDO = surface_color;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	EMISSION = emission_tint.rgb * emission_strength;
}
''',
    "shaders/environment/modular_water.gdshader": r'''
shader_type spatial;
render_mode blend_mix, depth_draw_alpha_prepass, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.02, 0.10, 0.15, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.05, 0.30, 0.40, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.28, 0.78, 0.95, 1.0);
uniform float wave_scale : hint_range(0.1, 8.0, 0.1) = 1.2;
uniform float wave_speed : hint_range(0.0, 4.0, 0.05) = 0.65;
uniform float alpha_value : hint_range(0.0, 1.0, 0.01) = 0.72;
uniform float emission_strength : hint_range(0.0, 2.0, 0.05) = 0.22;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (
		sin(VERTEX.x * wave_scale + TIME * wave_speed)
		+ cos(VERTEX.z * wave_scale * 0.78 - TIME * wave_speed * 0.83)
	) * 0.018;
}

void fragment() {
	float wave_a = 0.5 + 0.5 * sin((world_position.x + world_position.z) * wave_scale + TIME * wave_speed);
	float wave_b = 0.5 + 0.5 * cos((world_position.x - world_position.z) * wave_scale * 0.72 - TIME * wave_speed * 0.8);
	float blend_weight = clamp(wave_a * 0.62 + wave_b * 0.38, 0.0, 1.0);
	ALBEDO = mix(deep_color.rgb, shallow_color.rgb, blend_weight);
	EMISSION = highlight_color.rgb * emission_strength * smoothstep(0.72, 1.0, blend_weight);
	ROUGHNESS = 0.16;
	METALLIC = 0.06;
	ALPHA = alpha_value;
}
''',
    "art/materials/environment/modular/weathered_stone.tres": r'''
[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/environment/modular_surface.gdshader" id="1_shader"]

[resource]
shader = ExtResource("1_shader")
shader_parameter/base_color = Color(0.33, 0.35, 0.34, 1)
shader_parameter/secondary_color = Color(0.16, 0.20, 0.20, 1)
shader_parameter/variation_scale = 0.72
shader_parameter/variation_strength = 0.24
shader_parameter/band_scale = 0.46
shader_parameter/roughness_value = 0.9
shader_parameter/metallic_value = 0.0
shader_parameter/emission_tint = Color(1, 1, 1, 1)
shader_parameter/emission_strength = 0.0
shader_parameter/side_darkening = 0.12
''',
    "art/materials/environment/modular/trim_stone.tres": r'''
[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/environment/modular_surface.gdshader" id="1_shader"]

[resource]
shader = ExtResource("1_shader")
shader_parameter/base_color = Color(0.43, 0.44, 0.40, 1)
shader_parameter/secondary_color = Color(0.25, 0.28, 0.27, 1)
shader_parameter/variation_scale = 0.9
shader_parameter/variation_strength = 0.16
shader_parameter/band_scale = 0.35
shader_parameter/roughness_value = 0.86
shader_parameter/metallic_value = 0.0
shader_parameter/emission_tint = Color(1, 1, 1, 1)
shader_parameter/emission_strength = 0.0
shader_parameter/side_darkening = 0.08
''',
    "art/materials/environment/modular/wet_stone.tres": r'''
[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/environment/modular_surface.gdshader" id="1_shader"]

[resource]
shader = ExtResource("1_shader")
shader_parameter/base_color = Color(0.18, 0.25, 0.27, 1)
shader_parameter/secondary_color = Color(0.08, 0.13, 0.16, 1)
shader_parameter/variation_scale = 0.74
shader_parameter/variation_strength = 0.2
shader_parameter/band_scale = 0.4
shader_parameter/roughness_value = 0.42
shader_parameter/metallic_value = 0.0
shader_parameter/emission_tint = Color(0.1, 0.2, 0.25, 1)
shader_parameter/emission_strength = 0.02
shader_parameter/side_darkening = 0.1
''',
    "art/materials/environment/modular/aged_wood.tres": r'''
[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/environment/modular_surface.gdshader" id="1_shader"]

[resource]
shader = ExtResource("1_shader")
shader_parameter/base_color = Color(0.31, 0.18, 0.085, 1)
shader_parameter/secondary_color = Color(0.105, 0.055, 0.025, 1)
shader_parameter/variation_scale = 1.15
shader_parameter/variation_strength = 0.28
shader_parameter/band_scale = 1.5
shader_parameter/roughness_value = 0.82
shader_parameter/metallic_value = 0.0
shader_parameter/emission_tint = Color(1, 1, 1, 1)
shader_parameter/emission_strength = 0.0
shader_parameter/side_darkening = 0.1
''',
    "art/materials/environment/modular/aged_metal.tres": r'''
[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/environment/modular_surface.gdshader" id="1_shader"]

[resource]
shader = ExtResource("1_shader")
shader_parameter/base_color = Color(0.23, 0.25, 0.24, 1)
shader_parameter/secondary_color = Color(0.07, 0.09, 0.095, 1)
shader_parameter/variation_scale = 1.35
shader_parameter/variation_strength = 0.2
shader_parameter/band_scale = 0.5
shader_parameter/roughness_value = 0.54
shader_parameter/metallic_value = 0.72
shader_parameter/emission_tint = Color(1, 1, 1, 1)
shader_parameter/emission_strength = 0.0
shader_parameter/side_darkening = 0.07
''',
    "art/materials/environment/modular/moss.tres": r'''
[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/environment/modular_surface.gdshader" id="1_shader"]

[resource]
shader = ExtResource("1_shader")
shader_parameter/base_color = Color(0.12, 0.28, 0.14, 1)
shader_parameter/secondary_color = Color(0.035, 0.12, 0.055, 1)
shader_parameter/variation_scale = 1.8
shader_parameter/variation_strength = 0.32
shader_parameter/band_scale = 0.8
shader_parameter/roughness_value = 0.96
shader_parameter/metallic_value = 0.0
shader_parameter/emission_tint = Color(1, 1, 1, 1)
shader_parameter/emission_strength = 0.0
shader_parameter/side_darkening = 0.05
''',
    "art/materials/environment/modular/warm_glow.tres": r'''
[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/environment/modular_surface.gdshader" id="1_shader"]

[resource]
shader = ExtResource("1_shader")
shader_parameter/base_color = Color(1, 0.48, 0.12, 1)
shader_parameter/secondary_color = Color(1, 0.78, 0.28, 1)
shader_parameter/variation_scale = 2.0
shader_parameter/variation_strength = 0.18
shader_parameter/band_scale = 1.2
shader_parameter/roughness_value = 0.28
shader_parameter/metallic_value = 0.0
shader_parameter/emission_tint = Color(1, 0.32, 0.06, 1)
shader_parameter/emission_strength = 1.7
shader_parameter/side_darkening = 0.0
''',
    "art/materials/environment/modular/weathered_water.tres": r'''
[gd_resource type="ShaderMaterial" load_steps=2 format=3]

[ext_resource type="Shader" path="res://shaders/environment/modular_water.gdshader" id="1_shader"]

[resource]
render_priority = 1
shader = ExtResource("1_shader")
shader_parameter/deep_color = Color(0.015, 0.08, 0.13, 1)
shader_parameter/shallow_color = Color(0.045, 0.27, 0.37, 1)
shader_parameter/highlight_color = Color(0.26, 0.78, 0.96, 1)
shader_parameter/wave_scale = 1.15
shader_parameter/wave_speed = 0.58
shader_parameter/alpha_value = 0.72
shader_parameter/emission_strength = 0.23
''',
    "scripts/environment/modular_environment_piece.gd": r'''
extends Node3D
class_name ModularEnvironmentPiece

const STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_stone.tres")
const TRIM_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/trim_stone.tres")
const WET_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/wet_stone.tres")
const WOOD_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_wood.tres")
const METAL_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_metal.tres")
const MOSS_MATERIAL: Material = preload("res://art/materials/environment/modular/moss.tres")
const WARM_GLOW_MATERIAL: Material = preload("res://art/materials/environment/modular/warm_glow.tres")
const WATER_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_water.tres")

@export var piece_id: String = "modular_piece"
@export var display_name: String = "Modular Environment Piece"
@export_enum("architecture", "prop", "lighting", "water") var category: String = "architecture"
@export_enum(
	"stone_floor",
	"stone_wall",
	"stone_arch",
	"stone_stairs",
	"stone_pillar",
	"timber_frame",
	"stone_pedestal",
	"crate",
	"barrel",
	"wall_sconce",
	"water_channel"
) var piece_type: String = "stone_floor"
@export var footprint: Vector3 = Vector3(4.0, 1.0, 4.0)
@export var requires_collision: bool = true
@export var variant_seed: int = 0
@export var build_on_ready: bool = true

var built: bool = false
var build_counts: Dictionary = {
	"colliders": 0,
	"visuals": 0,
	"lights": 0,
}


func _ready() -> void:
	add_to_group("modular_environment_piece")
	add_to_group("modular_environment_" + category)
	set_meta("piece_id", piece_id)
	set_meta("piece_category", category)
	set_meta("collision_required", requires_collision)
	set_meta("prototype_asset_quality", "modular_v1")
	if build_on_ready:
		build_piece()


func build_piece() -> void:
	if built:
		return
	built = true
	match piece_type:
		"stone_wall":
			_build_stone_wall()
		"stone_arch":
			_build_stone_arch()
		"stone_stairs":
			_build_stone_stairs()
		"stone_pillar":
			_build_stone_pillar()
		"timber_frame":
			_build_timber_frame()
		"stone_pedestal":
			_build_stone_pedestal()
		"crate":
			_build_crate()
		"barrel":
			_build_barrel()
		"wall_sconce":
			_build_wall_sconce()
		"water_channel":
			_build_water_channel()
		_:
			_build_stone_floor()
	set_meta("build_counts", build_counts.duplicate(true))


func _build_stone_floor() -> void:
	_add_static_box("CollisionCore", Vector3(4.0, 0.42, 4.0), Vector3(0.0, -0.21, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	for x_index: int in range(4):
		for z_index: int in range(4):
			var index: int = x_index * 4 + z_index + variant_seed * 7
			var offset_x: float = sin(float(index) * 1.73) * 0.055
			var offset_z: float = cos(float(index) * 1.21) * 0.055
			var height: float = 0.11 + float((index + 2) % 3) * 0.018
			var slab_material: Material = WET_STONE_MATERIAL if (index + variant_seed) % 5 == 0 else STONE_MATERIAL
			_add_visual_box(
				"Slab_%02d_%02d" % [x_index, z_index],
				Vector3(0.93, height, 0.93),
				Vector3(-1.48 + float(x_index) * 0.99 + offset_x, height * 0.5 + 0.015, -1.48 + float(z_index) * 0.99 + offset_z),
				slab_material,
				Vector3(0.0, sin(float(index) * 0.9) * 0.018, 0.0)
			)
	for side: float in [-1.0, 1.0]:
		_add_visual_box("EdgeX_%s" % ("L" if side < 0.0 else "R"), Vector3(0.16, 0.16, 4.08), Vector3(side * 1.94, 0.08, 0.0), TRIM_STONE_MATERIAL)
		_add_visual_box("EdgeZ_%s" % ("N" if side < 0.0 else "S"), Vector3(4.08, 0.16, 0.16), Vector3(0.0, 0.08, side * 1.94), TRIM_STONE_MATERIAL)
	_add_visual_box("MossPatchA", Vector3(0.72, 0.025, 0.26), Vector3(-1.45, 0.145, 1.48), MOSS_MATERIAL, Vector3(0.0, -0.22, 0.0))
	_add_visual_box("MossPatchB", Vector3(0.42, 0.022, 0.2), Vector3(1.55, 0.142, -1.4), MOSS_MATERIAL, Vector3(0.0, 0.35, 0.0))


func _build_stone_wall() -> void:
	_add_static_box("CollisionCore", Vector3(4.0, 3.2, 0.48), Vector3(0.0, 1.6, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	for course: int in range(4):
		var course_offset: float = 0.46 if course % 2 == 1 else 0.0
		for block: int in range(5):
			var x_value: float = -1.82 + float(block) * 0.91 + course_offset
			if x_value > 2.02:
				continue
			var index: int = course * 5 + block + variant_seed * 3
			var width: float = 0.84 + sin(float(index) * 1.41) * 0.045
			var block_material: Material = WET_STONE_MATERIAL if index % 7 == 0 else STONE_MATERIAL
			_add_visual_box(
				"Masonry_%02d_%02d" % [course, block],
				Vector3(width, 0.68, 0.56),
				Vector3(x_value, 0.39 + float(course) * 0.75, sin(float(index) * 0.7) * 0.025),
				block_material,
				Vector3(0.0, sin(float(index) * 0.67) * 0.018, sin(float(index) * 1.11) * 0.012)
			)
	_add_visual_box("WallBase", Vector3(4.25, 0.28, 0.76), Vector3(0.0, 0.14, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("WallCap", Vector3(4.3, 0.32, 0.74), Vector3(0.0, 3.12, 0.0), TRIM_STONE_MATERIAL)
	for side: float in [-1.0, 1.0]:
		_add_visual_box("Pilaster_%s" % ("L" if side < 0.0 else "R"), Vector3(0.36, 3.35, 0.72), Vector3(side * 1.91, 1.67, -0.01), TRIM_STONE_MATERIAL)
	_add_visual_box("MossCreep", Vector3(1.45, 0.05, 0.65), Vector3(-0.9, 0.32, -0.32), MOSS_MATERIAL, Vector3(0.0, 0.0, 0.04))


func _build_stone_arch() -> void:
	_add_static_box("LeftCollision", Vector3(0.76, 2.7, 0.7), Vector3(-1.68, 1.35, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	_add_static_box("RightCollision", Vector3(0.76, 2.7, 0.7), Vector3(1.68, 1.35, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	_add_static_box("TopCollision", Vector3(4.1, 0.72, 0.7), Vector3(0.0, 3.43, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	for side: float in [-1.0, 1.0]:
		for course: int in range(4):
			_add_visual_box(
				"Pier_%s_%02d" % [("L" if side < 0.0 else "R"), course],
				Vector3(0.72, 0.66, 0.78),
				Vector3(side * 1.68, 0.36 + float(course) * 0.69, 0.0),
				STONE_MATERIAL,
				Vector3(0.0, side * 0.012 * float(course % 2), 0.0)
			)
		_add_visual_box("Foot_%s" % ("L" if side < 0.0 else "R"), Vector3(1.02, 0.28, 0.95), Vector3(side * 1.68, 0.14, 0.0), TRIM_STONE_MATERIAL)
	for segment: int in range(9):
		var angle: float = PI - float(segment) * PI / 8.0
		var x_value: float = cos(angle) * 1.56
		var y_value: float = 2.38 + sin(angle) * 1.05
		_add_visual_box(
			"ArchStone%02d" % segment,
			Vector3(0.55, 0.4, 0.82),
			Vector3(x_value, y_value, 0.0),
			TRIM_STONE_MATERIAL,
			Vector3(0.0, 0.0, -(angle - PI * 0.5))
		)
	_add_visual_box("Keystone", Vector3(0.62, 0.56, 0.9), Vector3(0.0, 3.5, -0.01), TRIM_STONE_MATERIAL)
	_add_visual_box("ArchMoss", Vector3(0.5, 0.04, 0.72), Vector3(-1.18, 3.14, -0.39), MOSS_MATERIAL, Vector3(0.0, 0.0, -0.32))


func _build_stone_stairs() -> void:
	var step_count: int = 6
	var step_run: float = 0.62
	var step_rise: float = 0.25
	for index: int in range(step_count):
		var height: float = step_rise * float(index + 1)
		var z_value: float = -1.55 + step_run * float(index)
		_add_static_box(
			"Step%02d" % index,
			Vector3(4.0, height, step_run + 0.04),
			Vector3(0.0, height * 0.5, z_value),
			WET_STONE_MATERIAL
		)
		_add_visual_box("RiserTrim%02d" % index, Vector3(4.12, 0.09, 0.07), Vector3(0.0, height - 0.045, z_value - step_run * 0.46), TRIM_STONE_MATERIAL)
	for side: float in [-1.0, 1.0]:
		_add_visual_box("Cheek_%s" % ("L" if side < 0.0 else "R"), Vector3(0.3, 1.65, 3.95), Vector3(side * 2.08, 0.82, -0.02), TRIM_STONE_MATERIAL, Vector3(-0.17, 0.0, 0.0))
	_add_visual_box("StairMoss", Vector3(0.62, 0.035, 1.1), Vector3(-1.55, 1.53, 1.22), MOSS_MATERIAL, Vector3(0.0, 0.18, 0.0))


func _build_stone_pillar() -> void:
	_add_static_cylinder("CollisionShaft", 0.42, 2.75, Vector3(0.0, 1.5, 0.0), STONE_MATERIAL, Vector3.ZERO, false)
	_add_visual_box("BaseLower", Vector3(1.25, 0.24, 1.25), Vector3(0.0, 0.12, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("BaseUpper", Vector3(0.98, 0.26, 0.98), Vector3(0.0, 0.37, 0.0), STONE_MATERIAL)
	_add_visual_cylinder("Shaft", 0.38, 0.43, 2.45, Vector3(0.0, 1.65, 0.0), STONE_MATERIAL)
	for ring_index: int in range(3):
		_add_visual_torus("ShaftBand%02d" % ring_index, 0.38, 0.45, Vector3(0.0, 0.72 + float(ring_index) * 0.9, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("CapitalLower", Vector3(0.98, 0.25, 0.98), Vector3(0.0, 2.9, 0.0), STONE_MATERIAL)
	_add_visual_box("CapitalUpper", Vector3(1.35, 0.28, 1.35), Vector3(0.0, 3.16, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("PillarMoss", Vector3(0.42, 0.04, 0.7), Vector3(0.38, 0.48, 0.05), MOSS_MATERIAL, Vector3(0.0, 0.0, 0.8))


func _build_timber_frame() -> void:
	for side: float in [-1.0, 1.0]:
		_add_static_box("Post_%s" % ("L" if side < 0.0 else "R"), Vector3(0.34, 3.2, 0.42), Vector3(side * 1.75, 1.6, 0.0), WOOD_MATERIAL)
		_add_visual_box("Brace_%s" % ("L" if side < 0.0 else "R"), Vector3(0.22, 2.65, 0.28), Vector3(side * 1.05, 1.75, 0.0), WOOD_MATERIAL, Vector3(0.0, 0.0, -side * 0.53))
		_add_visual_cylinder("IronFoot_%s" % ("L" if side < 0.0 else "R"), 0.24, 0.26, 0.16, Vector3(side * 1.75, 0.18, 0.0), METAL_MATERIAL)
	_add_static_box("Crossbeam", Vector3(4.05, 0.4, 0.5), Vector3(0.0, 3.05, 0.0), WOOD_MATERIAL)
	_add_visual_box("PegBeam", Vector3(3.5, 0.16, 0.58), Vector3(0.0, 2.67, 0.0), WOOD_MATERIAL)
	for peg: int in range(5):
		_add_visual_cylinder("Peg%02d" % peg, 0.045, 0.045, 0.64, Vector3(-1.35 + float(peg) * 0.68, 2.67, 0.0), METAL_MATERIAL, Vector3(PI * 0.5, 0.0, 0.0))


func _build_stone_pedestal() -> void:
	_add_static_box("Base", Vector3(1.75, 0.3, 1.75), Vector3(0.0, 0.15, 0.0), TRIM_STONE_MATERIAL)
	_add_static_box("LowerPlinth", Vector3(1.42, 0.35, 1.42), Vector3(0.0, 0.47, 0.0), STONE_MATERIAL)
	_add_static_box("Column", Vector3(0.92, 1.15, 0.92), Vector3(0.0, 1.22, 0.0), STONE_MATERIAL)
	_add_static_box("Cap", Vector3(1.5, 0.24, 1.5), Vector3(0.0, 1.91, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box("Inset", Vector3(0.66, 0.55, 0.04), Vector3(0.0, 1.28, -0.48), METAL_MATERIAL)
	_add_visual_box("MossLip", Vector3(0.56, 0.035, 1.12), Vector3(-0.35, 0.67, 0.0), MOSS_MATERIAL, Vector3(0.0, 0.0, 0.08))


func _build_crate() -> void:
	_add_static_box("CollisionCore", Vector3(1.35, 1.25, 1.35), Vector3(0.0, 0.625, 0.0), WOOD_MATERIAL, Vector3.ZERO, false)
	for slat: int in range(6):
		var y_value: float = 0.12 + float(slat) * 0.205
		_add_visual_box("FrontSlat%02d" % slat, Vector3(1.28, 0.16, 0.12), Vector3(0.0, y_value, -0.68), WOOD_MATERIAL)
		_add_visual_box("BackSlat%02d" % slat, Vector3(1.28, 0.16, 0.12), Vector3(0.0, y_value, 0.68), WOOD_MATERIAL)
	for side: float in [-1.0, 1.0]:
		_add_visual_box("SidePanel_%s" % ("L" if side < 0.0 else "R"), Vector3(0.12, 1.18, 1.28), Vector3(side * 0.68, 0.62, 0.0), WOOD_MATERIAL)
		_add_visual_box("Brace_%s" % ("L" if side < 0.0 else "R"), Vector3(0.13, 1.7, 0.15), Vector3(side * 0.44, 0.64, -0.75), METAL_MATERIAL, Vector3(0.0, 0.0, side * 0.65))
	_add_visual_box("Top", Vector3(1.42, 0.15, 1.42), Vector3(0.0, 1.28, 0.0), WOOD_MATERIAL)
	_add_visual_box("CornerMoss", Vector3(0.46, 0.035, 0.28), Vector3(-0.48, 1.37, 0.45), MOSS_MATERIAL)


func _build_barrel() -> void:
	_add_static_cylinder("CollisionCore", 0.62, 1.35, Vector3(0.0, 0.68, 0.0), WOOD_MATERIAL, Vector3.ZERO, false)
	_add_visual_cylinder("Body", 0.52, 0.62, 1.35, Vector3(0.0, 0.68, 0.0), WOOD_MATERIAL)
	for band_y: float in [0.2, 0.67, 1.14]:
		_add_visual_cylinder("Hoop_%s" % str(band_y).replace(".", "_"), 0.635, 0.635, 0.09, Vector3(0.0, band_y, 0.0), METAL_MATERIAL)
	_add_visual_cylinder("TopCap", 0.5, 0.5, 0.08, Vector3(0.0, 1.39, 0.0), WOOD_MATERIAL)
	for slat: int in range(8):
		var angle: float = float(slat) * TAU / 8.0
		_add_visual_box(
			"Stave%02d" % slat,
			Vector3(0.11, 1.23, 0.12),
			Vector3(cos(angle) * 0.57, 0.68, sin(angle) * 0.57),
			WOOD_MATERIAL,
			Vector3(0.0, -angle, 0.0)
		)


func _build_wall_sconce() -> void:
	_add_visual_box("WallPlate", Vector3(0.55, 0.75, 0.1), Vector3(0.0, 0.65, 0.0), METAL_MATERIAL)
	_add_visual_box("Bracket", Vector3(0.12, 0.12, 0.72), Vector3(0.0, 0.52, -0.34), METAL_MATERIAL, Vector3(0.12, 0.0, 0.0))
	_add_visual_cylinder("Bowl", 0.26, 0.14, 0.18, Vector3(0.0, 0.58, -0.73), METAL_MATERIAL, Vector3.ZERO)
	_add_visual_sphere("FlameCore", 0.17, Vector3(0.0, 0.82, -0.73), WARM_GLOW_MATERIAL, Vector3(0.72, 1.5, 0.72))
	_add_visual_sphere("FlameTip", 0.095, Vector3(0.03, 1.06, -0.72), WARM_GLOW_MATERIAL, Vector3(0.55, 1.45, 0.55))
	_add_point_light("WarmLight", Vector3(0.0, 0.88, -0.7), Color(1.0, 0.46, 0.16), 2.2, 6.5)


func _build_water_channel() -> void:
	_add_static_box("BasinFloor", Vector3(2.2, 0.32, 4.0), Vector3(0.0, -0.48, 0.0), WET_STONE_MATERIAL)
	for side: float in [-1.0, 1.0]:
		_add_static_box("ChannelWall_%s" % ("L" if side < 0.0 else "R"), Vector3(0.38, 0.72, 4.05), Vector3(side * 1.1, -0.18, 0.0), TRIM_STONE_MATERIAL)
		_add_visual_box("MossEdge_%s" % ("L" if side < 0.0 else "R"), Vector3(0.24, 0.035, 2.2), Vector3(side * 0.92, 0.2, 0.32), MOSS_MATERIAL)
	_add_visual_box("WaterSurface", Vector3(1.76, 0.035, 3.94), Vector3(0.0, 0.07, 0.0), WATER_MATERIAL)
	_add_visual_box("WaterDepth", Vector3(1.72, 0.06, 3.9), Vector3(0.0, -0.32, 0.0), WET_STONE_MATERIAL)
	for ripple: int in range(4):
		_add_visual_box("Ripple%02d" % ripple, Vector3(1.42, 0.018, 0.055), Vector3(0.0, 0.105, -1.35 + float(ripple) * 0.9), WATER_MATERIAL, Vector3(0.0, sin(float(ripple)) * 0.12, 0.0))


func _add_static_box(
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO,
	visible_mesh: bool = true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation = rotation_value
	body.set_meta("modular_piece_owner", piece_id)
	add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	build_counts["colliders"] = int(build_counts["colliders"]) + 1
	if visible_mesh:
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		visual.material_override = material_value
		body.add_child(visual)
		build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return body


func _add_static_cylinder(
	node_name: String,
	radius: float,
	height: float,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO,
	visible_mesh: bool = true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation = rotation_value
	body.set_meta("modular_piece_owner", piece_id)
	add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	build_counts["colliders"] = int(build_counts["colliders"]) + 1
	if visible_mesh:
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 12
		visual.mesh = mesh
		visual.material_override = material_value
		body.add_child(visual)
		build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return body


func _add_visual_box(
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material_value
	visual.set_meta("modular_piece_owner", piece_id)
	add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func _add_visual_cylinder(
	node_name: String,
	top_radius: float,
	bottom_radius: float,
	height: float,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	visual.mesh = mesh
	visual.material_override = material_value
	visual.set_meta("modular_piece_owner", piece_id)
	add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func _add_visual_sphere(
	node_name: String,
	radius: float,
	position_value: Vector3,
	material_value: Material,
	scale_value: Vector3 = Vector3.ONE
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.scale = scale_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	visual.mesh = mesh
	visual.material_override = material_value
	visual.set_meta("modular_piece_owner", piece_id)
	add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func _add_visual_torus(
	node_name: String,
	inner_radius: float,
	outer_radius: float,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 20
	mesh.ring_segments = 10
	visual.mesh = mesh
	visual.material_override = material_value
	visual.set_meta("modular_piece_owner", piece_id)
	add_child(visual)
	build_counts["visuals"] = int(build_counts["visuals"]) + 1
	return visual


func _add_point_light(
	node_name: String,
	position_value: Vector3,
	color_value: Color,
	energy: float,
	range_value: float
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = color_value
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	add_child(light)
	build_counts["lights"] = int(build_counts["lights"]) + 1
	return light


func get_collision_shape_count() -> int:
	return _count_collision_shapes(self)


func _count_collision_shapes(node: Node) -> int:
	var count: int = 1 if node is CollisionShape3D else 0
	for child: Node in node.get_children():
		count += _count_collision_shapes(child)
	return count


func get_debug_data() -> Dictionary:
	return {
		"piece_id": piece_id,
		"display_name": display_name,
		"category": category,
		"piece_type": piece_type,
		"footprint": footprint,
		"requires_collision": requires_collision,
		"built": built,
		"counts": build_counts.duplicate(true),
	}
''',
    "scripts/environment/modular_environment_gate.gd": r'''
extends Node3D
class_name ModularEnvironmentGate

const STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_stone.tres")
const TRIM_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/trim_stone.tres")
const METAL_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_metal.tres")

signal gate_state_changed(opened: bool)

@export var piece_id: String = "weathered_iron_gate_3m"
@export var display_name: String = "Weathered Iron Gate"
@export var category: String = "architecture"
@export var footprint: Vector3 = Vector3(4.0, 3.5, 0.8)
@export var requires_collision: bool = true
@export var open_angle_degrees: float = -96.0
@export var animation_speed: float = 4.0
@export var starts_open: bool = false

var built: bool = false
var target_open: bool = false
var gate_pivot: Node3D
var gate_body: AnimatableBody3D


func _ready() -> void:
	add_to_group("modular_environment_piece")
	add_to_group("modular_environment_architecture")
	add_to_group("modular_environment_gate")
	set_meta("piece_id", piece_id)
	set_meta("piece_category", category)
	set_meta("collision_required", requires_collision)
	set_meta("prototype_asset_quality", "modular_v1")
	_build_gate()
	set_open(starts_open, true)


func _process(delta: float) -> void:
	if gate_pivot == null:
		return
	var target_angle: float = deg_to_rad(open_angle_degrees) if target_open else 0.0
	gate_pivot.rotation.y = lerp_angle(
		gate_pivot.rotation.y,
		target_angle,
		clampf(maxf(delta, 0.0) * animation_speed, 0.0, 1.0)
	)
	if absf(angle_difference(gate_pivot.rotation.y, target_angle)) <= 0.004:
		gate_pivot.rotation.y = target_angle


func _build_gate() -> void:
	if built:
		return
	built = true
	_add_static_box(self, "LeftPier", Vector3(0.72, 3.35, 0.82), Vector3(-1.85, 1.675, 0.0), STONE_MATERIAL)
	_add_static_box(self, "RightPier", Vector3(0.72, 3.35, 0.82), Vector3(1.85, 1.675, 0.0), STONE_MATERIAL)
	_add_static_box(self, "Lintel", Vector3(4.35, 0.5, 0.88), Vector3(0.0, 3.28, 0.0), TRIM_STONE_MATERIAL)
	gate_pivot = Node3D.new()
	gate_pivot.name = "GatePivot"
	gate_pivot.position = Vector3(-1.48, 0.0, 0.0)
	add_child(gate_pivot)
	gate_body = AnimatableBody3D.new()
	gate_body.name = "GatePanel"
	gate_body.position = Vector3(1.48, 0.0, 0.0)
	gate_pivot.add_child(gate_body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.96, 2.62, 0.22)
	collision.shape = shape
	collision.position.y = 1.45
	gate_body.add_child(collision)
	for bar: int in range(9):
		_add_visual_box(
			gate_body,
			"Bar%02d" % bar,
			Vector3(0.12, 2.62, 0.14),
			Vector3(-1.3 + float(bar) * 0.325, 1.45, 0.0),
			METAL_MATERIAL
		)
	for rail_y: float in [0.42, 1.42, 2.44]:
		_add_visual_box(gate_body, "Rail_%s" % str(rail_y).replace(".", "_"), Vector3(2.96, 0.14, 0.18), Vector3(0.0, rail_y, 0.0), METAL_MATERIAL)
	_add_visual_box(gate_body, "DiagonalA", Vector3(0.13, 3.34, 0.17), Vector3(0.0, 1.45, -0.02), METAL_MATERIAL, Vector3(0.0, 0.0, 0.92))
	_add_visual_box(gate_body, "DiagonalB", Vector3(0.13, 3.34, 0.17), Vector3(0.0, 1.45, 0.02), METAL_MATERIAL, Vector3(0.0, 0.0, -0.92))
	for hinge_y: float in [0.62, 2.28]:
		_add_visual_cylinder(self, "Hinge_%s" % str(hinge_y).replace(".", "_"), 0.13, 0.13, 0.36, Vector3(-1.5, hinge_y, 0.0), METAL_MATERIAL, Vector3(PI * 0.5, 0.0, 0.0))


func set_open(value: bool, instant: bool = false) -> void:
	target_open = value
	if instant and gate_pivot != null:
		gate_pivot.rotation.y = deg_to_rad(open_angle_degrees) if target_open else 0.0
	gate_state_changed.emit(target_open)


func toggle_gate() -> void:
	set_open(not target_open)


func is_open() -> bool:
	return target_open


func get_collision_shape_count() -> int:
	return _count_collision_shapes(self)


func _count_collision_shapes(node: Node) -> int:
	var count: int = 1 if node is CollisionShape3D else 0
	for child: Node in node.get_children():
		count += _count_collision_shapes(child)
	return count


func _add_static_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_add_visual_box(body, "Visual", size, Vector3.ZERO, material_value)
	return body


func _add_visual_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material_value
	parent.add_child(visual)
	return visual


func _add_visual_cylinder(
	parent: Node3D,
	node_name: String,
	top_radius: float,
	bottom_radius: float,
	height: float,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	visual.mesh = mesh
	visual.material_override = material_value
	parent.add_child(visual)
	return visual


func get_debug_data() -> Dictionary:
	return {
		"piece_id": piece_id,
		"category": category,
		"built": built,
		"open": target_open,
		"angle": gate_pivot.rotation.y if gate_pivot != null else 0.0,
		"colliders": get_collision_shape_count(),
	}
''',
    "scripts/environment/modular_environment_catalog.gd": r'''
extends RefCounted
class_name ModularEnvironmentCatalog

const FLOOR_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_floor_4m.tscn")
const WALL_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_wall_4m.tscn")
const ARCH_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_arch_4m.tscn")
const STAIRS_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_stairs_4m.tscn")
const PILLAR_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_pillar_3m.tscn")
const TIMBER_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_timber_frame_4m.tscn")
const GATE_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_iron_gate_3m.tscn")
const PEDESTAL_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_stone_pedestal.tscn")
const CRATE_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_crate.tscn")
const BARREL_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_barrel.tscn")
const SCONCE_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_wall_sconce.tscn")
const WATER_CHANNEL_SCENE: PackedScene = preload("res://scenes/environment/modular/weathered_water_channel_4m.tscn")

const PIECES: Dictionary = {
	"weathered_barrel": BARREL_SCENE,
	"weathered_crate": CRATE_SCENE,
	"weathered_iron_gate_3m": GATE_SCENE,
	"weathered_stone_arch_4m": ARCH_SCENE,
	"weathered_stone_floor_4m": FLOOR_SCENE,
	"weathered_stone_pedestal": PEDESTAL_SCENE,
	"weathered_stone_pillar_3m": PILLAR_SCENE,
	"weathered_stone_stairs_4m": STAIRS_SCENE,
	"weathered_stone_wall_4m": WALL_SCENE,
	"weathered_timber_frame_4m": TIMBER_SCENE,
	"weathered_wall_sconce": SCONCE_SCENE,
	"weathered_water_channel_4m": WATER_CHANNEL_SCENE,
}

const DEFINITIONS: Dictionary = {
	"weathered_barrel": {"category": "prop", "collision": true},
	"weathered_crate": {"category": "prop", "collision": true},
	"weathered_iron_gate_3m": {"category": "architecture", "collision": true},
	"weathered_stone_arch_4m": {"category": "architecture", "collision": true},
	"weathered_stone_floor_4m": {"category": "architecture", "collision": true},
	"weathered_stone_pedestal": {"category": "prop", "collision": true},
	"weathered_stone_pillar_3m": {"category": "architecture", "collision": true},
	"weathered_stone_stairs_4m": {"category": "architecture", "collision": true},
	"weathered_stone_wall_4m": {"category": "architecture", "collision": true},
	"weathered_timber_frame_4m": {"category": "architecture", "collision": true},
	"weathered_wall_sconce": {"category": "lighting", "collision": false},
	"weathered_water_channel_4m": {"category": "water", "collision": true},
}


static func get_piece_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id: Variant in PIECES.keys():
		ids.append(str(raw_id))
	ids.sort()
	return ids


static func has_piece(piece_id: String) -> bool:
	return PIECES.has(piece_id)


static func instantiate_piece(piece_id: String) -> Node3D:
	var scene: PackedScene = PIECES.get(piece_id) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as Node3D


static func get_definition(piece_id: String) -> Dictionary:
	return (DEFINITIONS.get(piece_id, {}) as Dictionary).duplicate(true)


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	if PIECES.size() != DEFINITIONS.size():
		errors.append("Catalog scene and definition counts differ.")
	for piece_id: String in get_piece_ids():
		var scene: PackedScene = PIECES.get(piece_id) as PackedScene
		if scene == null:
			errors.append(piece_id + " has no PackedScene.")
			continue
		if not DEFINITIONS.has(piece_id):
			errors.append(piece_id + " has no catalog definition.")
		var instance: Node3D = scene.instantiate() as Node3D
		if instance == null:
			errors.append(piece_id + " failed to instantiate.")
			continue
		if str(instance.get("piece_id")) != piece_id:
			errors.append(piece_id + " scene exports mismatched piece_id " + str(instance.get("piece_id")) + ".")
		instance.free()
	return errors
''',
    "scenes/environment/modular/weathered_stone_floor_4m.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredStoneFloor4m" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_stone_floor_4m"
display_name = "Weathered Stone Floor 4m"
category = "architecture"
piece_type = "stone_floor"
footprint = Vector3(4, 0.42, 4)
variant_seed = 3
''',
    "scenes/environment/modular/weathered_stone_wall_4m.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredStoneWall4m" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_stone_wall_4m"
display_name = "Weathered Stone Wall 4m"
category = "architecture"
piece_type = "stone_wall"
footprint = Vector3(4, 3.2, 0.76)
variant_seed = 5
''',
    "scenes/environment/modular/weathered_stone_arch_4m.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredStoneArch4m" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_stone_arch_4m"
display_name = "Weathered Stone Arch 4m"
category = "architecture"
piece_type = "stone_arch"
footprint = Vector3(4.1, 3.8, 0.9)
variant_seed = 2
''',
    "scenes/environment/modular/weathered_stone_stairs_4m.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredStoneStairs4m" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_stone_stairs_4m"
display_name = "Weathered Stone Stairs 4m"
category = "architecture"
piece_type = "stone_stairs"
footprint = Vector3(4.3, 1.7, 4)
variant_seed = 4
''',
    "scenes/environment/modular/weathered_stone_pillar_3m.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredStonePillar3m" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_stone_pillar_3m"
display_name = "Weathered Stone Pillar 3m"
category = "architecture"
piece_type = "stone_pillar"
footprint = Vector3(1.35, 3.3, 1.35)
variant_seed = 1
''',
    "scenes/environment/modular/weathered_timber_frame_4m.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredTimberFrame4m" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_timber_frame_4m"
display_name = "Weathered Timber Frame 4m"
category = "architecture"
piece_type = "timber_frame"
footprint = Vector3(4.1, 3.3, 0.7)
variant_seed = 6
''',
    "scenes/environment/modular/weathered_iron_gate_3m.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_gate.gd" id="1_gate"]

[node name="WeatheredIronGate3m" type="Node3D"]
script = ExtResource("1_gate")
''',
    "scenes/environment/modular/weathered_stone_pedestal.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredStonePedestal" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_stone_pedestal"
display_name = "Weathered Stone Pedestal"
category = "prop"
piece_type = "stone_pedestal"
footprint = Vector3(1.75, 2.1, 1.75)
variant_seed = 3
''',
    "scenes/environment/modular/weathered_crate.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredCrate" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_crate"
display_name = "Weathered Supply Crate"
category = "prop"
piece_type = "crate"
footprint = Vector3(1.45, 1.4, 1.45)
variant_seed = 7
''',
    "scenes/environment/modular/weathered_barrel.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredBarrel" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_barrel"
display_name = "Weathered Storage Barrel"
category = "prop"
piece_type = "barrel"
footprint = Vector3(1.35, 1.45, 1.35)
variant_seed = 2
''',
    "scenes/environment/modular/weathered_wall_sconce.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredWallSconce" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_wall_sconce"
display_name = "Weathered Wall Sconce"
category = "lighting"
piece_type = "wall_sconce"
footprint = Vector3(0.8, 1.3, 1)
requires_collision = false
variant_seed = 1
''',
    "scenes/environment/modular/weathered_water_channel_4m.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/environment/modular_environment_piece.gd" id="1_piece"]

[node name="WeatheredWaterChannel4m" type="Node3D"]
script = ExtResource("1_piece")
piece_id = "weathered_water_channel_4m"
display_name = "Weathered Water Channel 4m"
category = "water"
piece_type = "water_channel"
footprint = Vector3(2.6, 0.9, 4.1)
variant_seed = 5
''',
    "scripts/levels/prototype_modular_environment_showcase_v1.gd": r'''
extends Node3D
class_name PrototypeModularEnvironmentShowcaseV1

const Catalog = preload("res://scripts/environment/modular_environment_catalog.gd")
const StoryInteractableScript = preload("res://scripts/interaction/story_interactable.gd")
const PlayableSpaceScript = preload("res://scripts/quality/playable_space_3d.gd")
const RecoveryVolumeScript = preload("res://scripts/quality/playable_recovery_volume_3d.gd")
const STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/weathered_stone.tres")
const TRIM_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/trim_stone.tres")
const WET_STONE_MATERIAL: Material = preload("res://art/materials/environment/modular/wet_stone.tres")
const METAL_MATERIAL: Material = preload("res://art/materials/environment/modular/aged_metal.tres")
const WARM_GLOW_MATERIAL: Material = preload("res://art/materials/environment/modular/warm_glow.tres")

var world: Node3D
var set_root: Node3D
var gate: Node3D
var gate_lever: Area3D
var status_label: Label
var placed_piece_ids: Array[String] = []
var placed_categories: Dictionary = {}


func _ready() -> void:
	add_to_group("modular_environment_showcase")
	world = $World
	_configure_environment()
	_build_playable_space()
	_build_foundation()
	_build_weathered_cloister()
	_build_gate_lever()
	_build_signage()
	_build_hud()
	_show_status("Walk the cloister, inspect the joins, and operate the iron gate.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_scene"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()


func _configure_environment() -> void:
	var environment_node: WorldEnvironment = $WorldEnvironment
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.032, 0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.22, 0.31, 0.42)
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment


func _build_playable_space() -> void:
	var playable_space := Node3D.new()
	playable_space.name = "PlayableSpace"
	playable_space.set_script(PlayableSpaceScript)
	playable_space.set("use_bounds", true)
	playable_space.set("bounds_center", Vector3(0.0, 3.0, 0.0))
	playable_space.set("bounds_size", Vector3(28.0, 18.0, 42.0))
	playable_space.set("minimum_recovery_y", -4.5)
	playable_space.set("generate_boundary_collision", true)
	playable_space.set("boundary_thickness", 1.0)
	playable_space.set("boundary_height", 14.0)
	var default_anchor := Marker3D.new()
	default_anchor.name = "DefaultRecoveryAnchor"
	default_anchor.position = Vector3(0.0, 1.0, -15.0)
	playable_space.add_child(default_anchor)
	playable_space.set("default_recovery_path", NodePath("DefaultRecoveryAnchor"))
	add_child(playable_space)
	var recovery_volume := Area3D.new()
	recovery_volume.name = "ShowcaseRecoveryVolume"
	recovery_volume.position = Vector3(0.0, -6.2, 0.0)
	recovery_volume.set_script(RecoveryVolumeScript)
	recovery_volume.set("recovery_reason", "fell beneath the modular environment showcase")
	var recovery_shape := CollisionShape3D.new()
	var recovery_box := BoxShape3D.new()
	recovery_box.size = Vector3(34.0, 4.0, 50.0)
	recovery_shape.shape = recovery_box
	recovery_volume.add_child(recovery_shape)
	playable_space.add_child(recovery_volume)
	_add_static_box(world, "DeepSafetyCatch", Vector3(32.0, 0.5, 48.0), Vector3(0.0, -8.5, 0.0), WET_STONE_MATERIAL, false)


func _build_foundation() -> void:
	set_root = Node3D.new()
	set_root.name = "WeatheredCloisterSet"
	set_root.add_to_group("modular_environment_set")
	set_root.set_meta("set_id", "weathered_cloister_v1")
	world.add_child(set_root)
	_add_static_box(set_root, "EntryFoundation", Vector3(7.0, 0.45, 11.0), Vector3(0.0, -0.46, -10.5), STONE_MATERIAL, false)
	_add_static_box(set_root, "LeftFoundation", Vector3(5.0, 0.45, 14.0), Vector3(-3.1, -0.46, 0.0), STONE_MATERIAL, false)
	_add_static_box(set_root, "RightFoundation", Vector3(5.0, 0.45, 14.0), Vector3(3.1, -0.46, 0.0), STONE_MATERIAL, false)
	_add_static_box(set_root, "ChannelCatch", Vector3(2.3, 0.4, 14.0), Vector3(0.0, -0.82, 0.0), WET_STONE_MATERIAL, false)
	_add_static_box(set_root, "BridgeFoundation", Vector3(7.0, 0.45, 4.2), Vector3(0.0, -0.46, 7.9), STONE_MATERIAL, false)
	_add_static_box(set_root, "RaisedFoundation", Vector3(10.0, 0.55, 7.0), Vector3(0.0, 1.22, 14.5), TRIM_STONE_MATERIAL, true)


func _build_weathered_cloister() -> void:
	_place_piece("weathered_stone_floor_4m", "EntryFloorSouth", Vector3(0.0, 0.0, -13.0))
	_place_piece("weathered_stone_floor_4m", "EntryFloorNorth", Vector3(0.0, 0.0, -9.0))
	_place_piece("weathered_stone_arch_4m", "EntranceArch", Vector3(0.0, 0.0, -8.2))
	for z_value: float in [-4.0, 0.0, 4.0]:
		_place_piece("weathered_stone_floor_4m", "FloorLeft_%s" % str(z_value).replace(".", "_"), Vector3(-3.1, 0.0, z_value))
		_place_piece("weathered_stone_floor_4m", "FloorRight_%s" % str(z_value).replace(".", "_"), Vector3(3.1, 0.0, z_value))
		_place_piece("weathered_water_channel_4m", "WaterChannel_%s" % str(z_value).replace(".", "_"), Vector3(0.0, 0.0, z_value))
		_place_piece("weathered_stone_wall_4m", "WallLeft_%s" % str(z_value).replace(".", "_"), Vector3(-5.45, 0.0, z_value), Vector3(0.0, PI * 0.5, 0.0))
		_place_piece("weathered_stone_wall_4m", "WallRight_%s" % str(z_value).replace(".", "_"), Vector3(5.45, 0.0, z_value), Vector3(0.0, PI * 0.5, 0.0))
		_place_piece("weathered_stone_pillar_3m", "PillarLeft_%s" % str(z_value).replace(".", "_"), Vector3(-1.55, 0.0, z_value))
		_place_piece("weathered_stone_pillar_3m", "PillarRight_%s" % str(z_value).replace(".", "_"), Vector3(1.55, 0.0, z_value))
		var frame: Node3D = _place_piece("weathered_timber_frame_4m", "TimberFrame_%s" % str(z_value).replace(".", "_"), Vector3(0.0, 0.0, z_value))
		if frame != null:
			frame.scale.x = 2.55
		_place_piece("weathered_wall_sconce", "SconceLeft_%s" % str(z_value).replace(".", "_"), Vector3(-5.05, 1.45, z_value), Vector3(0.0, -PI * 0.5, 0.0))
		_place_piece("weathered_wall_sconce", "SconceRight_%s" % str(z_value).replace(".", "_"), Vector3(5.05, 1.45, z_value), Vector3(0.0, PI * 0.5, 0.0))
	_place_piece("weathered_stone_floor_4m", "CanalBridge", Vector3(0.0, 0.0, 7.0), Vector3.ZERO, Vector3(1.45, 1.0, 0.7))
	_place_piece("weathered_stone_stairs_4m", "RaisedGalleryStairs", Vector3(0.0, 0.0, 9.25))
	gate = _place_piece("weathered_iron_gate_3m", "ShowcaseGate", Vector3(0.0, 1.5, 12.0))
	_place_piece("weathered_stone_floor_4m", "RaisedFloorLeft", Vector3(-2.0, 1.5, 14.7))
	_place_piece("weathered_stone_floor_4m", "RaisedFloorRight", Vector3(2.0, 1.5, 14.7))
	_place_piece("weathered_stone_pedestal", "HeroPedestal", Vector3(0.0, 1.5, 15.0))
	_place_piece("weathered_crate", "SupplyCrate", Vector3(-2.7, 1.5, 14.6), Vector3(0.0, 0.18, 0.0))
	_place_piece("weathered_barrel", "StorageBarrel", Vector3(2.7, 1.5, 14.6), Vector3(0.0, -0.24, 0.0))
	_place_piece("weathered_stone_wall_4m", "GalleryBackWallLeft", Vector3(-2.05, 1.5, 17.55))
	_place_piece("weathered_stone_wall_4m", "GalleryBackWallRight", Vector3(2.05, 1.5, 17.55))


func _build_gate_lever() -> void:
	gate_lever = Area3D.new()
	gate_lever.name = "GateLever"
	gate_lever.position = Vector3(-2.55, 1.5, 10.6)
	gate_lever.set_script(StoryInteractableScript)
	gate_lever.set("prompt_text", "Open the weathered iron gate")
	gate_lever.set("one_shot", false)
	gate_lever.connect("activated", _on_gate_lever_activated)
	set_root.add_child(gate_lever)
	_add_visual_box(gate_lever, "LeverBase", Vector3(0.7, 0.85, 0.55), Vector3(0.0, 0.42, 0.0), TRIM_STONE_MATERIAL)
	_add_visual_box(gate_lever, "LeverPlate", Vector3(0.48, 0.52, 0.08), Vector3(0.0, 0.54, -0.32), METAL_MATERIAL)
	_add_visual_box(gate_lever, "LeverHandle", Vector3(0.12, 0.72, 0.12), Vector3(0.0, 0.9, -0.38), METAL_MATERIAL, Vector3(0.0, 0.0, -0.48))
	_add_visual_sphere(gate_lever, "LeverGrip", 0.13, Vector3(-0.16, 1.2, -0.38), WARM_GLOW_MATERIAL)


func _build_signage() -> void:
	_add_label(set_root, "TitlePlaque", "WEATHERED CLOISTER", Vector3(0.0, 4.25, -8.05), Color(0.72, 0.88, 0.96), 25)
	_add_label(set_root, "ArchitecturePlaque", "ARCHITECTURE", Vector3(-4.7, 2.7, -5.8), Color(0.66, 0.75, 0.78), 17)
	_add_label(set_root, "WaterPlaque", "WATER + TRANSITIONS", Vector3(0.0, 1.2, 5.8), Color(0.42, 0.82, 0.96), 17)
	_add_label(set_root, "PropPlaque", "PROPS", Vector3(0.0, 4.2, 16.85), Color(0.95, 0.72, 0.34), 17)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ModularShowcaseHUD"
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(18.0, 18.0)
	panel.custom_minimum_size = Vector2(520.0, 82.0)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var title := Label.new()
	title.text = "WEATHERED CLOISTER  •  MODULAR ENVIRONMENT KIT v1"
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(0.72, 0.84, 0.9))
	box.add_child(status_label)


func _on_gate_lever_activated(_interactable: Node) -> void:
	if gate == null or not gate.has_method("toggle_gate"):
		return
	gate.call("toggle_gate")
	var opening: bool = bool(gate.get("target_open"))
	gate_lever.set("prompt_text", "Close the weathered iron gate" if opening else "Open the weathered iron gate")
	_show_status("IRON GATE  •  " + ("Opening" if opening else "Closing") + ". Inspect the moving bars and collision.")


func _place_piece(
	piece_id: String,
	node_name: String,
	position_value: Vector3,
	rotation_value: Vector3 = Vector3.ZERO,
	scale_value: Vector3 = Vector3.ONE
) -> Node3D:
	var piece: Node3D = Catalog.instantiate_piece(piece_id)
	if piece == null:
		push_warning("Unknown modular environment piece: " + piece_id)
		return null
	piece.name = node_name
	piece.position = position_value
	piece.rotation = rotation_value
	piece.scale = scale_value
	set_root.add_child(piece)
	placed_piece_ids.append(piece_id)
	var definition: Dictionary = Catalog.get_definition(piece_id)
	placed_categories[str(definition.get("category", "unknown"))] = true
	return piece


func _add_static_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	visible_mesh: bool = true
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	parent.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	if visible_mesh:
		_add_visual_box(body, "Visual", size, Vector3.ZERO, material_value)
	return body


func _add_visual_box(
	parent: Node3D,
	node_name: String,
	size: Vector3,
	position_value: Vector3,
	material_value: Material,
	rotation_value: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	visual.rotation = rotation_value
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material_value
	parent.add_child(visual)
	return visual


func _add_visual_sphere(
	parent: Node3D,
	node_name: String,
	radius: float,
	position_value: Vector3,
	material_value: Material
) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.position = position_value
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	visual.mesh = mesh
	visual.material_override = material_value
	parent.add_child(visual)
	return visual


func _add_label(
	parent: Node3D,
	node_name: String,
	text_value: String,
	position_value: Vector3,
	color_value: Color,
	font_size: int
) -> Label3D:
	var label := Label3D.new()
	label.name = node_name
	label.text = text_value
	label.position = position_value
	label.modulate = color_value
	label.font_size = font_size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 4
	parent.add_child(label)
	return label


func _show_status(message: String) -> void:
	if status_label != null:
		status_label.text = message


func get_showcase_stats() -> Dictionary:
	return {
		"set_id": "weathered_cloister_v1",
		"placed_count": placed_piece_ids.size(),
		"unique_piece_ids": placed_piece_ids.duplicate().reduce(func(accumulator: Dictionary, id: String) -> Dictionary: accumulator[id] = true; return accumulator, {}).size(),
		"categories": placed_categories.keys(),
		"gate": gate != null,
		"lever": gate_lever != null,
	}


func get_placed_piece_ids() -> Array[String]:
	return placed_piece_ids.duplicate()
''',
    "scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn": r'''
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/levels/prototype_modular_environment_showcase_v1.gd" id="1_showcase"]
[ext_resource type="PackedScene" path="res://scenes/actors/player/player.tscn" id="2_player"]
[ext_resource type="PackedScene" path="res://scenes/ui/game_ui.tscn" id="3_ui"]
[ext_resource type="Script" path="res://scripts/systems/focus_time.gd" id="4_focus"]

[node name="PrototypeModularEnvironmentShowcaseV1" type="Node3D"]
script = ExtResource("1_showcase")

[node name="GameUI" parent="." instance=ExtResource("3_ui")]

[node name="FocusTime" type="Node" parent="."]
script = ExtResource("4_focus")

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-48, -28, 0)
light_color = Color(0.58, 0.7, 0.86, 1)
light_energy = 1.05
shadow_enabled = true

[node name="WorldEnvironment" type="WorldEnvironment" parent="."]

[node name="Player" parent="." groups=["player"] instance=ExtResource("2_player")]
position = Vector3(0, 1, -15)
rotation_degrees = Vector3(0, 180, 0)

[node name="World" type="Node3D" parent="."]
''',
    "scripts/tests/modular_environment_showcase_smoke_test.gd": r'''
extends Node

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn")
const Catalog = preload("res://scripts/environment/modular_environment_catalog.gd")
const PlayableSpaceAuditorScript = preload("res://scripts/quality/playable_space_auditor.gd")

var failures: Array[String] = []
var elapsed: float = 0.0
var finished: bool = false
var current_step: String = "startup"


func _process(delta: float) -> void:
	if finished:
		return
	elapsed += maxf(delta, 0.0)
	if elapsed >= 20.0:
		push_error("Modular environment showcase test stalled during: " + current_step)
		print("MODULAR_ENVIRONMENT_SHOWCASE_SMOKE_TEST: STALLED AT " + current_step)
		get_tree().quit(1)


func _ready() -> void:
	GameState.reset_run()
	current_step = "validate catalog"
	var catalog_errors: Array[String] = Catalog.validate_catalog()
	for error: String in catalog_errors:
		failures.append("catalog: " + error)
	var piece_ids: Array[String] = Catalog.get_piece_ids()
	check(piece_ids.size() == 12, "catalog exposes the twelve-piece v1 kit")

	current_step = "instantiate kit pieces"
	var kit_sandbox := Node3D.new()
	kit_sandbox.name = "KitSandbox"
	add_child(kit_sandbox)
	var instantiated: Array[Node3D] = []
	for piece_id: String in piece_ids:
		var piece: Node3D = Catalog.instantiate_piece(piece_id)
		check(piece != null, piece_id + " instantiates")
		if piece == null:
			continue
		kit_sandbox.add_child(piece)
		instantiated.append(piece)
	await get_tree().process_frame
	for piece: Node3D in instantiated:
		var piece_id: String = str(piece.get("piece_id"))
		check(piece.is_in_group("modular_environment_piece"), piece_id + " joins the modular piece group")
		check(str(piece.get_meta("piece_id", "")) == piece_id, piece_id + " publishes canonical metadata")
		var requires_collision: bool = bool(piece.get("requires_collision"))
		var collision_count: int = int(piece.call("get_collision_shape_count")) if piece.has_method("get_collision_shape_count") else 0
		if requires_collision:
			check(collision_count > 0, piece_id + " has collision")
	kit_sandbox.queue_free()
	await get_tree().process_frame

	current_step = "instantiate showcase"
	var showcase := SceneUnderTest.instantiate()
	add_child(showcase)
	for _index: int in range(5):
		await get_tree().process_frame
	await get_tree().physics_frame
	check(showcase.get_node_or_null("Player") != null, "showcase uses the shared player")
	check(showcase.get_node_or_null("PlayableSpace") != null, "showcase declares a PlayableSpace3D")
	check(showcase.get_node_or_null("PlayableSpace/ShowcaseRecoveryVolume") != null, "showcase has explicit recovery coverage")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet") != null, "dedicated Weathered Cloister set exists")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/EntranceArch") != null, "set has a readable entrance arch")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/WaterChannel_0_0") != null, "set demonstrates water transitions")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/RaisedGalleryStairs") != null, "set demonstrates a reusable stair run")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/ShowcaseGate") != null, "set demonstrates the operable gate")
	check(showcase.get_node_or_null("World/WeatheredCloisterSet/HeroPedestal") != null, "set demonstrates prop staging")

	current_step = "inspect showcase composition"
	var stats: Dictionary = showcase.call("get_showcase_stats")
	check(int(stats.get("placed_count", 0)) >= 35, "showcase composes a full set from repeated modules")
	var categories: Array = stats.get("categories", [])
	for required_category: String in ["architecture", "prop", "lighting", "water"]:
		check(categories.has(required_category), "showcase includes " + required_category + " pieces")
	var scene_piece_count: int = 0
	for candidate: Node in get_tree().get_nodes_in_group("modular_environment_piece"):
		if showcase == candidate or showcase.is_ancestor_of(candidate):
			scene_piece_count += 1
	check(scene_piece_count >= 35, "showcase registers every placed module")

	current_step = "operate gate"
	var gate: Node = showcase.get_node("World/WeatheredCloisterSet/ShowcaseGate")
	var lever: Area3D = showcase.get_node("World/WeatheredCloisterSet/GateLever") as Area3D
	check(not bool(gate.get("target_open")), "gate begins closed")
	lever.interact()
	await get_tree().process_frame
	check(bool(gate.get("target_open")), "physical lever opens the gate")
	gate.call("set_open", true, true)
	check(bool(gate.call("is_open")), "gate supports deterministic authored state restoration")

	current_step = "audit playable space"
	var audit: Dictionary = PlayableSpaceAuditorScript.audit_scene(showcase)
	for error: String in audit.get("errors", []):
		failures.append("auditor: " + error)
	check(bool(audit.get("passed", false)), "showcase passes the global playable-space audit")

	showcase.queue_free()
	await get_tree().process_frame
	finished = true
	if failures.is_empty():
		print("MODULAR_ENVIRONMENT_SHOWCASE_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("MODULAR_ENVIRONMENT_SHOWCASE_SMOKE_TEST: " + failure)
		print("MODULAR_ENVIRONMENT_SHOWCASE_SMOKE_TEST: FAIL")
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
''',
    "scenes/tests/modular_environment_showcase_smoke_test.tscn": r'''
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/tests/modular_environment_showcase_smoke_test.gd" id="1_test"]

[node name="ModularEnvironmentShowcaseSmokeTest" type="Node"]
script = ExtResource("1_test")
''',
    "docs/MODULAR_ENVIRONMENT_KIT_V1.md": r'''
# Modular Environment and Prop Kit v1

The modular environment kit is the first production-facing bridge between procedural prototype architecture and future imported art. It provides reusable Godot scenes with shared materials, matched collision, consistent scale, stable pivots, and a dedicated benchmark set.

## Scope

The v1 **Weathered Cloister** kit contains:

```text
weathered_stone_floor_4m
weathered_stone_wall_4m
weathered_stone_arch_4m
weathered_stone_stairs_4m
weathered_stone_pillar_3m
weathered_timber_frame_4m
weathered_iron_gate_3m
weathered_stone_pedestal
weathered_crate
weathered_barrel
weathered_wall_sconce
weathered_water_channel_4m
```

Each asset is a reusable `.tscn` under `scenes/environment/modular/`. The catalog at `scripts/environment/modular_environment_catalog.gd` is the canonical lookup and validation owner.

## Visual target

This is still stylized low-poly prototype art, but it is no longer raw debug geometry. Pieces use:

- layered silhouettes rather than single boxes;
- shared weathered stone, wet stone, timber, metal, moss, glow, and water materials;
- world-space color variation to reduce flat surfaces;
- continuous hidden collision beneath visual breakup where needed;
- architectural trim, masonry courses, braces, slats, hoops, moss, and localized lighting;
- consistent four-meter architecture dimensions.

The kit deliberately stops before imported production meshes, authored UV textures, decals, lightmaps, or final art direction.

## Ownership boundary

The reusable kit owns:

- repeated architecture and prop scenes;
- collision and pivots;
- material identity;
- catalog lookup and validation;
- a benchmark showcase for scale, camera, joins, and lighting.

Authored levels still own:

- floor plans and circulation;
- environmental history;
- landmark placement;
- sightlines and route readability;
- mood and final art direction;
- which modules are replaced by bespoke assets.

The existing `AuthoredEnvironmentBuilder` remains useful for blocking, invisible support collision, and one-off scaffolding. The modular kit should replace repeated runtime-built furniture and architecture as scenes mature.

## Canonical showcase

```text
scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn
```

The **Weathered Cloister** is a coherent walkable set, not an asset grid. It demonstrates a continuous entrance, cloister walks, water channel, masonry walls, columns, timber frames, warm sconces, raised stairs, an operable iron gate, and a small prop gallery.

## Promotion rule

Add a new kit piece only when at least two authored spaces need the same structural or prop pattern. One-off landmarks remain inside their authored level until repetition proves a reusable scene is warranted.

## Next use

The next environment milestone should use this kit to remaster the Drowned Chapel nave and crypt entrance as the first production-representative benchmark room. That pass should replace repeated procedural architecture while preserving the quest, playability, and environment-composition contracts already proven there.
''',
    "docs/modular_environment_showcase_v1_test.md": r'''
# Weathered Cloister Modular Environment Showcase v1 Manual Test

Scene:

```text
scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn
```

## Purpose

Evaluate the first reusable environment and prop kit as one coherent walkable set. This is a visual, collision, scale, and camera benchmark. It adds no quest, combat, progression, or traversal mechanic.

## Route

1. Walk through the weathered entrance arch without jumping.
2. Follow either side of the central water channel.
3. Cross between both cloister walks and inspect floor-to-channel transitions.
4. Circle the stone pillars and timber frames with the camera close behind Grace.
5. Walk up the broad stair run.
6. Interact with the glowing gate lever.
7. Walk through the opening gate and inspect the pedestal, crate, barrel, and rear wall modules.
8. Return to the entrance using the opposite side of the cloister.

## Visual checks

- Stone floors should read as layered slabs while walking on continuous collision.
- Wall courses, trim, pilasters, moss, and shader variation should prevent the walls from reading as naked BoxMeshes.
- The arch should read as a built stone opening with visible voussoirs and a keystone.
- Pillars should have bases, shafts, bands, capitals, and stable collision.
- Timber frames should have posts, braces, pegs, and iron feet.
- The water channel should meet its stone basin cleanly without a floating plane or collision hole.
- Sconces should provide localized warm pools against the cooler environmental light.
- The gate should retain collision while swinging and should not leave a stale invisible blocker.
- Crate, barrel, and pedestal silhouettes should remain readable without floating labels.

## Collision and camera abuse

- Walk every floor seam and both edges of the water channel.
- Press against walls, arches, pillar bases, timber posts, gate piers, and the raised platform.
- Circle the gate while it is moving.
- Try to wedge Grace between every prop and wall.
- Walk backward down the stairs with the camera close to the side cheeks.
- Deliberately leave the outer set boundary and confirm global recovery remains a last resort.
- Blink toward the arch, water channel, gate, raised platform, and exterior bounds.

## Acceptance

The pass succeeds when the set is comfortably traversable, visually more intentional than the procedural debug environments, and useful as a reference for future asset replacement. It does not need final production fidelity. Any repeated snag, visible collision mismatch, unreadable transition, or camera trap should be treated as a kit defect rather than patched only in the showcase.

Automated coverage:

```text
scenes/tests/modular_environment_showcase_smoke_test.tscn
```
''',
}


def write_files() -> None:
    for relative_path, content in FILES.items():
        path = Path(relative_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(dedent(content).lstrip("\n"), encoding="utf-8")


def update_feature_registry() -> None:
    path = Path("data/features/feature_registry.json")
    data = json.loads(path.read_text(encoding="utf-8"))
    features = data["features"]
    features = [feature for feature in features if feature.get("id") != "modular_environment_showcase"]
    features.append(
        {
            "id": "modular_environment_showcase",
            "order": 19,
            "display_name": "Weathered Cloister: Modular Environment Showcase",
            "category": "Environment Showcase",
            "version": "v1",
            "status": "prototype_verified",
            "description": "Dedicated walkable benchmark for the reusable Weathered Cloister environment and prop kit, including layered architecture, shared weathered materials, water transitions, localized lighting, stairs, props, an operable iron gate, and global playability coverage.",
            "scene": "res://scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn",
            "validation_scenes": [
                "res://scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn"
            ],
            "automated_tests": [
                "res://scenes/tests/modular_environment_showcase_smoke_test.tscn"
            ],
            "dependencies": [],
            "controls": [
                "MOVE",
                "CAMERA",
                "INTERACT",
                "JUMP",
                "DODGE",
                "RESET",
            ],
            "manual_test": "docs/modular_environment_showcase_v1_test.md",
            "temporary_state": "runtime_only",
            "story_integrated": False,
            "limitations": [
                "The first kit uses stylized primitive-based scene assemblies rather than imported production meshes or authored UV texture sets.",
                "Only the Weathered Cloister material family and a compact architecture/prop vocabulary are represented in v1.",
                "The water channel is a shallow decorative transition and does not replace the shared swimming-volume system.",
                "Final decals, lightmaps, baked occlusion, destruction variants, and environment-specific art direction remain future asset work.",
            ],
            "launchable": True,
            "visible_in_launcher": True,
            "ci_validate": True,
            "timeout_seconds": 12,
        }
    )
    features.sort(key=lambda feature: (int(feature.get("order", 9999)), str(feature.get("id", ""))))
    data["features"] = features
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def update_capability_inventory() -> None:
    path = Path("data/features/capability_inventory.json")
    data = json.loads(path.read_text(encoding="utf-8"))
    updated = False
    for capability in data["capabilities"]:
        if capability.get("id") != "authored_environment_composition":
            continue
        capability["display_name"] = "Authored Environment Composition and Modular Asset Kit"
        capability["owner_files"] = [
            "scripts/environment/authored_environment_palette.gd",
            "scripts/environment/authored_environment_builder.gd",
            "scripts/environment/authored_environment_auditor.gd",
            "scripts/environment/modular_environment_piece.gd",
            "scripts/environment/modular_environment_gate.gd",
            "scripts/environment/modular_environment_catalog.gd",
            "scripts/levels/drowned_bell_environment_pass.gd",
            "scenes/environment/modular/",
            "art/materials/environment/modular/",
            "shaders/environment/",
        ]
        capability["canonical_scene"] = "scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn"
        capability["aliases"] = [
            "environment pass",
            "global environment polish",
            "authored space builder",
            "modular level art",
            "prototype architecture kit",
            "collision matched geometry",
            "level dressing",
            "environment palette",
            "modular environment kit",
            "environment asset kit",
            "prop kit",
            "dungeon set pieces",
            "environment showcase",
            "weathered cloister",
        ]
        capability["next_use"] = "Apply the reusable scenes to the Drowned Chapel benchmark and future dungeons instead of rebuilding repeated architecture and props from raw runtime primitives. Keep layout, landmarks, and environmental storytelling authored."
        capability["story_reference"] = "The Drowned Bell"
        capability["limitations"] = [
            "The v1 reusable kit is a stylized primitive-based benchmark rather than final imported production art.",
            "Only one weathered architecture family is represented so far.",
        ]
        updated = True
        break
    if not updated:
        raise RuntimeError("authored_environment_composition capability was not found")
    data["updated"] = "2026-07-27"
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def update_project_map() -> None:
    path = Path("docs/project_map.md")
    text = path.read_text(encoding="utf-8")
    marker = "## Development infrastructure\n"
    section = dedent(
        '''
        ## Modular environment assets

        Repeated architecture and props now have production-facing scene owners under `scenes/environment/modular/`, with shared weathered materials under `art/materials/environment/modular/` and canonical lookup through `scripts/environment/modular_environment_catalog.gd`. The dedicated Weathered Cloister showcase is `scenes/levels/prototypes/prototype_modular_environment_showcase_v1.tscn`.

        The modular kit extends the authored environment-composition capability rather than replacing it. Use modular scenes for repeated floors, walls, arches, stairs, pillars, timber frames, gates, props, lighting, and water-edge vocabulary. Keep blocking support, bespoke landmarks, floor plans, sightlines, mood, and environmental storytelling authored per level.

        Architecture and manual quality gates are documented in:

        ```text
        docs/MODULAR_ENVIRONMENT_KIT_V1.md
        docs/modular_environment_showcase_v1_test.md
        ```

        ''').lstrip()
    if "## Modular environment assets" not in text:
        if marker not in text:
            raise RuntimeError("project_map development infrastructure marker missing")
        text = text.replace(marker, section + marker, 1)
    path.write_text(text, encoding="utf-8")


def update_repository_audit() -> None:
    path = Path("docs/REPOSITORY_AUDIT.md")
    text = path.read_text(encoding="utf-8")
    marker = "## Canonical development scenes\n"
    section = dedent(
        '''
        ### Modular environment assets

        Owner areas:

        ```text
        scenes/environment/modular/
        scripts/environment/modular_environment_piece.gd
        scripts/environment/modular_environment_gate.gd
        scripts/environment/modular_environment_catalog.gd
        art/materials/environment/modular/
        shaders/environment/
        ```

        The Weathered Cloister kit provides reusable scene assets for floors, walls, arches, stairs, pillars, timber frames, gates, pedestals, crates, barrels, sconces, and water channels. Its canonical benchmark is `prototype_modular_environment_showcase_v1.tscn`.

        Do not propose another generic modular architecture framework, prop kit, or environment showcase as new work. Extend this kit only when repeated authored-content needs justify additional modules or material families.

        ''').lstrip()
    if "### Modular environment assets" not in text:
        if marker not in text:
            raise RuntimeError("repository audit development scene marker missing")
        text = text.replace(marker, section + marker, 1)
    text = text.replace(
        "| Authored quest template | `prototype_broken_waystation_mission_v1.tscn` |",
        "| Authored quest template | `prototype_broken_waystation_mission_v1.tscn` |\n| Modular environment assets | `prototype_modular_environment_showcase_v1.tscn` |",
        1,
    )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    write_files()
    update_feature_registry()
    update_capability_inventory()
    update_project_map()
    update_repository_audit()
    print(f"Generated {len(FILES)} modular environment files and updated repository inventories.")


if __name__ == "__main__":
    main()
