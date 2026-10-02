class_name PlanetShip
extends Node3D
## Geometric flight around uniformly scaled unit-sphere planets; no physics.
## Bind after placing the ship in the scene. Unbinding preserves its transform.

@export var flight_speed: float = 40.0
@export var altitude_speed: float = 65.0
@export var turn_speed_degrees: float = 90.0
@export var surface_clearance: float = 4.0

var bound_planet: Node3D:
	get:
		return _planet if is_instance_valid(_planet) else null
var altitude: float:
	get:
		return _altitude
var radial_up: Vector3:
	get:
		return global_basis.y.normalized()
var forward: Vector3:
	get:
		return -global_basis.z.normalized()

var _planet: Node3D
var _altitude: float = 0.0
var _local_up := Vector3.UP
var _local_forward := Vector3.FORWARD


func _ready() -> void:
	set_process(is_instance_valid(_planet))


func bind_to_planet(planet: Node3D) -> void:
	_planet = planet
	set_process(is_instance_valid(_planet))
	if not is_instance_valid(_planet):
		# The owner now has complete control of position and orientation.
		return
	var relative_position := _planet.to_local(global_position)
	_local_up = relative_position.normalized() if relative_position.length_squared() > 0.000001 else Vector3.UP
	_local_forward = (_planet.global_basis.inverse() * forward).normalized()
	_orthonormalize_heading()
	var radius := _planet_radius(_planet)
	_altitude = maxf(minimum_altitude_for_planet(_planet), relative_position.length() * radius - radius)
	_update_transform()


func minimum_altitude_for_planet(planet: Node3D) -> float:
	var extent: float = planet.get_meta("maximum_surface_radius", 1.0)
	return maxf(surface_clearance, (extent - 1.0) * _planet_radius(planet) + surface_clearance)


func _planet_radius(planet: Node3D) -> float:
	return maxf(planet.global_basis.x.length(), 0.0001)


func _process(delta: float) -> void:
	if not is_instance_valid(_planet):
		bind_to_planet(null)
		return
	# Releasing the mouse pauses flight input, but the ship still follows its planet.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_move(delta)
	else:
		_update_transform()


func _move(delta: float) -> void:
	if not is_instance_valid(_planet):
		return
	var turn := float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
	_local_forward = _local_forward.rotated(_local_up, turn * deg_to_rad(turn_speed_degrees) * delta)
	var thrust := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var climb := float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_E))
	_altitude += climb * altitude_speed * delta
	_altitude = maxf(minimum_altitude_for_planet(_planet), _altitude)
	if thrust != 0.0:
		# Parallel-transport the heading along a great circle at fixed altitude.
		var axis := _local_up.cross(_local_forward).normalized()
		var angle := thrust * flight_speed * delta / (_planet_radius(_planet) + _altitude)
		_local_up = _local_up.rotated(axis, angle).normalized()
		_local_forward = _local_forward.rotated(axis, angle).normalized()
	_update_transform()


func _orthonormalize_heading() -> void:
	_local_forward -= _local_up * _local_forward.dot(_local_up)
	if _local_forward.length_squared() < 0.000001:
		var reference := Vector3.UP if absf(_local_up.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		_local_forward = reference - _local_up * reference.dot(_local_up)
	_local_forward = _local_forward.normalized()


func _update_transform() -> void:
	_orthonormalize_heading()
	var radius := _planet_radius(_planet)
	var local_position := _local_up * (1.0 + _altitude / radius)
	var local_basis := Basis(_local_forward.cross(_local_up).normalized(), _local_up, -_local_forward)
	global_transform = Transform3D(_planet.global_basis.orthonormalized() * local_basis, _planet.to_global(local_position))
