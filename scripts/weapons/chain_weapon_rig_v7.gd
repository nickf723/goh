extends "res://scripts/weapons/chain_weapon_rig_v5.gd"
class_name ChainWeaponRigV7

@export_range(0.2, 1.2, 0.05) var head_contact_radius: float = 0.62
@export_range(3, 12, 1) var trail_sample_count: int = 7

var tip_history: Array[Vector3] = []


func _ready() -> void:
	chain_length = 4.0
	tip_mass = 3.3
	contact_radius = head_contact_radius
	line_sag = 0.42
	super._ready()
