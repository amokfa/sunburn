extends Node3D
@export var lifetime: float = 0.6
@export var size_multiplier: float = 1.0
@export var initial_scale: float = 0.15
var age: float = 0.0
var material: StandardMaterial3D

func _ready() -> void:
	material = $Flash.material_override.duplicate()
	$Flash.material_override = material
	scale = Vector3.ONE * initial_scale * size_multiplier

func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age / lifetime, 0.0, 1.0)
	scale = Vector3.ONE * lerpf(initial_scale, 3.5, sqrt(progress)) * size_multiplier
	material.albedo_color = Color(1.0, lerpf(0.9, 0.25, progress), 0.05, (1.0 - progress) * 0.8)
	material.emission_energy_multiplier = 5.0 * (1.0 - progress)
	if age >= lifetime:
		queue_free()
