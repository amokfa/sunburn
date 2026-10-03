class_name FuelCellPickup
extends Node3D

@export var electron_speed := 2.4
@export var spin_speed := 0.2
@export var orbit_radius := 1.1
var _age := 0.0
var _rng := RandomNumberGenerator.new()
var _tumble_velocity := Vector3.ZERO
var _target_tumble_velocity := Vector3.ZERO
var _tumble_change_remaining := 0.0
@onready var _atom: Node3D = $Atom
@onready var _orbits: Array[Node3D] = [$Atom/Orbit1, $Atom/Orbit2, $Atom/Orbit3]

func _ready() -> void:
	_rng.randomize()
	animate(0.0)

func _process(delta: float) -> void:
	animate(delta)

func animate(delta: float) -> void:
	_age += delta
	_tumble_change_remaining -= delta
	if _tumble_change_remaining <= 0.0:
		var axis := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
		_target_tumble_velocity = axis * spin_speed
		_tumble_change_remaining = _rng.randf_range(2.0, 4.0)
	_tumble_velocity = _tumble_velocity.lerp(_target_tumble_velocity, 1.0 - exp(-delta * 1.5))
	var tumble_speed := _tumble_velocity.length()
	if tumble_speed > 0.000001:
		_atom.quaternion = (Quaternion(_tumble_velocity / tumble_speed, tumble_speed * delta) * _atom.quaternion).normalized()
	_atom.position.y = sin(_age * 1.5) * 0.12
	for index in range(_orbits.size()):
		var phase := _age * electron_speed + TAU * float(index) / 3.0
		_orbits[index].get_node("Ring").scale = Vector3.ONE * (orbit_radius / 1.1)
		_orbits[index].get_node("Electron").position = Vector3(cos(phase), 0.0, sin(phase)) * orbit_radius
