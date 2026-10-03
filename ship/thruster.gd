extends Node3D
## +Y is the exhaust direction; scene placement sets the direction and size.
@export var response: float = 18.0
@export var light_enabled: bool = true
@onready var plume: MeshInstance3D = $Plume
@onready var light: OmniLight3D = $Light
var target_power: float = 0.0
var _power: float = 0.0
var _material: ShaderMaterial
var _light_energy: float

func _ready() -> void:
	_material = plume.material_override.duplicate() as ShaderMaterial
	plume.material_override = _material
	_light_energy = light.light_energy
	light.light_energy = 0.0
	visible = false

func set_power(value: float) -> void:
	target_power = clampf(value, 0.0, 1.0)

func _process(delta: float) -> void:
	_power = lerpf(_power, target_power, 1.0 - exp(-response * delta))
	visible = _power > 0.002
	_material.set_shader_parameter("power", _power)
	light.light_energy = _light_energy * _power if light_enabled else 0.0
