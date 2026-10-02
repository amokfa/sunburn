class_name PlanetShip
extends Node3D
## Thrust and damped yaw around uniformly scaled unit-sphere planets; no physics bodies.
## Bind after placing the ship in the scene. Unbinding preserves its transform.
const ThrusterController = preload("res://ship/thruster.gd")
const SurfaceCollider = preload("res://planets/surface_collider.gd")

@export var mass: float = 1000.0
@export var horizontal_thrust_force: float = 32000.0
@export var vertical_thrust_force: float = 40000.0
@export var horizontal_damping: float = 0.8
@export var vertical_damping: float = 1.2
@export var yaw_inertia: float = 100.0
@export var view_turn_torque: float = 1200.0
@export var yaw_damping: float = 700.0

@export_group("Planet two agility")
@export var upgraded_speed_multiplier: float = 2.0
@export var upgraded_acceleration_multiplier: float = 3.0
@export var upgraded_turn_multiplier: float = 2.0
var agility_boost: bool = false

@export_group("Planet boundaries")
@export_range(0.0, 100.0, 0.1, "or_greater") var surface_clearance: float = 5.0
@export var boundary_spring_stiffness: float = 5000.0
@export var boundary_spring_damping: float = 9000.0
@export var maximum_altitude_ratio: float = 0.5

@export_group("Visual tilt")
@export var pitch_tilt_degrees: float = 12.0
@export var backward_pitch_tilt_degrees: float = 6.0
@export var roll_tilt_degrees: float = 15.0
@export var tilt_response: float = 4.0
@export var wobble_degrees: float = 2.0
@export var wobble_speed: float = 0.35
@export var wobble_distance: float = 0.035

@export_group("Thruster visuals")
@export_range(0.0, 1.0) var hover_thrust_power: float = 0.35
@export var full_yaw_thrust_torque: float = 1200.0

@onready var model: Node3D = $Model

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

var view_forward: Vector3:
	get:
		return (_planet.global_basis * _local_view_forward).normalized() if is_instance_valid(_planet) else _unbound_view_forward
var velocity: Vector3:
	get:
		return _planet.global_basis.orthonormalized() * _velocity if is_instance_valid(_planet) else Vector3.ZERO
var yaw_velocity: float:
	get:
		return _yaw_velocity

var _planet: Node3D
var _surface_collider: SurfaceCollider
var _altitude: float = 0.0
var _local_up := Vector3.UP
var _local_forward := Vector3.FORWARD
var _local_view_forward := Vector3.FORWARD
var _unbound_view_forward := Vector3.FORWARD
var _velocity := Vector3.ZERO
var _yaw_velocity: float = 0.0
var _model_rest_transform := Transform3D.IDENTITY
var _visual_tilt := Vector2.ZERO
var _visual_time: float = 0.0
var _wobble_noise := FastNoiseLite.new()
var _thrusters: Dictionary = {}
var _last_yaw_torque: float = 0.0


func _ready() -> void:
	_model_rest_transform = model.transform
	_wobble_noise.seed = 73129
	_wobble_noise.frequency = 1.0
	for marker in $Model/markers.get_children():
		var exhaust := marker.get_node_or_null("Exhaust") as ThrusterController
		if exhaust != null:
			_thrusters[marker.name] = exhaust
	set_process(is_instance_valid(_planet))


func bind_to_planet(planet: Node3D) -> void:
	_unbound_view_forward = view_forward
	_planet = planet
	_surface_collider = _planet.get_node_or_null("SurfaceCollider") as SurfaceCollider if is_instance_valid(_planet) else null
	set_process(is_instance_valid(_planet))
	if not is_instance_valid(_planet):
		_update_thrusters(Vector2.ZERO, 0.0, 0.0)
		# The owner now has complete control of position and orientation.
		return
	var relative_position := _planet.to_local(global_position)
	_local_up = relative_position.normalized() if relative_position.length_squared() > 0.000001 else Vector3.UP
	_local_forward = (_planet.global_basis.inverse() * forward).normalized()
	_orthonormalize_heading()
	_local_view_forward = _local_forward
	_velocity = Vector3.ZERO
	_yaw_velocity = 0.0
	_last_yaw_torque = 0.0
	_visual_tilt = Vector2.ZERO
	_visual_time = 0.0
	_update_visual_tilt(0.0, Vector2.ZERO)
	var radius := _planet_radius(_planet)
	_altitude = relative_position.length() * radius - radius
	_update_transform()
	_update_thrusters(Vector2.ZERO, 0.0, 0.0)


func _planet_radius(planet: Node3D) -> float:
	return maxf(planet.global_basis.x.length(), 0.0001)


func set_agility_boost(enabled: bool) -> void:
	agility_boost = enabled


func _process(delta: float) -> void:
	if not is_instance_valid(_planet):
		bind_to_planet(null)
		return
	# Releasing the mouse pauses flight input, but the ship still follows its planet.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_move(delta)
	else:
		_update_transform()
		_update_visual_tilt(delta, Vector2.ZERO)
		_update_thrusters(Vector2.ZERO, 0.0, 0.0)


func set_view_direction(direction: Vector3) -> void:
	if not is_instance_valid(_planet):
		return
	var local_direction := _planet.global_basis.inverse() * direction
	local_direction -= _local_up * local_direction.dot(_local_up)
	if local_direction.length_squared() > 0.000001:
		_local_view_forward = local_direction.normalized()


func rotate_view(angle: float) -> void:
	if is_instance_valid(_planet):
		_local_view_forward = _local_view_forward.rotated(_local_up, angle).normalized()


func _move(delta: float) -> void:
	if not is_instance_valid(_planet):
		return
	var horizontal := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))).limit_length()
	var vertical := float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_E))
	var remaining := minf(maxf(delta, 0.0), 0.25)
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 120.0)
		_step_thrust(step, horizontal, vertical)
		remaining -= step
	_update_transform()
	_update_visual_tilt(minf(maxf(delta, 0.0), 0.25), horizontal)
	_update_thrusters(horizontal, vertical, _last_yaw_torque)


func _update_thrusters(horizontal: Vector2, vertical: float, yaw_torque: float) -> void:
	var active := is_instance_valid(_planet)
	var turn := clampf(yaw_torque / maxf(full_yaw_thrust_torque, 0.001), -1.0, 1.0)
	for marker_name: StringName in _thrusters:
		var name_text := String(marker_name)
		var power := 0.0
		if active:
			if name_text == "back":
				power = maxf(horizontal.y, 0.0)
			elif name_text == "front":
				power = maxf(-horizontal.y, 0.0)
			elif name_text.begins_with("down_"):
				power = maxf(hover_thrust_power, vertical)
			elif name_text.begins_with("up_"):
				power = maxf(-vertical, 0.0)
			elif name_text.begins_with("side_"):
				var left := name_text.ends_with("_left")
				power = maxf(horizontal.x if left else -horizontal.x, 0.0)
				# Positive torque turns left: front-right and back-left push oppositely.
				var turns_left := (name_text.begins_with("side_front_") and not left) or (name_text.begins_with("side_back_") and left)
				power = maxf(power, maxf(turn if turns_left else -turn, 0.0))
		var exhaust: ThrusterController = _thrusters[marker_name]
		exhaust.set_power(power)


func _update_visual_tilt(delta: float, horizontal: Vector2) -> void:
	if not is_instance_valid(model):
		return
	var pitch_amplitude := backward_pitch_tilt_degrees if horizontal.y < 0.0 else pitch_tilt_degrees
	var target := Vector2(-horizontal.y * deg_to_rad(pitch_amplitude), -horizontal.x * deg_to_rad(roll_tilt_degrees))
	_visual_tilt = _visual_tilt.lerp(target, 1.0 - exp(-maxf(tilt_response, 0.0) * delta))
	_visual_time += delta
	# Continuous noise adds gentle, irregular motion rather than frame-random shaking.
	var t := _visual_time * wobble_speed
	var wobble := Vector3(_wobble_noise.get_noise_2d(t, 3.7), _wobble_noise.get_noise_2d(t, 19.4), _wobble_noise.get_noise_2d(t, -11.9))
	var drift := Vector3(_wobble_noise.get_noise_2d(t, 41.3), _wobble_noise.get_noise_2d(t, -27.1), _wobble_noise.get_noise_2d(t, 64.8)) * wobble_distance
	# Rotate the centered visual in ship space, retaining the imported scale/offset.
	# Its thrust markers move with it; controller orientation and camera stay level.
	var tilt := Basis.from_euler(Vector3(_visual_tilt.x, 0.0, _visual_tilt.y) + wobble * deg_to_rad(wobble_degrees))
	model.transform = Transform3D(tilt, drift) * _model_rest_transform


func _step_thrust(delta: float, horizontal: Vector2, vertical: float) -> void:
	# The view target is independent of ship yaw, so turning cannot chase the camera.
	var error := atan2(_local_forward.cross(_local_view_forward).dot(_local_up), _local_forward.dot(_local_view_forward))
	var turn_multiplier := upgraded_turn_multiplier if agility_boost else 1.0
	var torque := view_turn_torque * turn_multiplier * turn_multiplier * error - yaw_damping * turn_multiplier * _yaw_velocity
	_last_yaw_torque = torque
	_yaw_velocity += torque / maxf(yaw_inertia, 0.001) * delta
	_local_forward = _local_forward.rotated(_local_up, _yaw_velocity * delta).normalized()
	var radial_speed := _velocity.dot(_local_up)
	var tangent_velocity := _velocity - _local_up * radial_speed
	var thrust_multiplier := upgraded_acceleration_multiplier if agility_boost else 1.0
	var drag_multiplier := thrust_multiplier / maxf(upgraded_speed_multiplier, 0.001) if agility_boost else 1.0
	tangent_velocity *= exp(-maxf(horizontal_damping, 0.0) * drag_multiplier * delta)
	radial_speed *= exp(-maxf(vertical_damping, 0.0) * drag_multiplier * delta)
	var right := _local_forward.cross(_local_up).normalized()
	var acceleration := (right * horizontal.x + _local_forward * horizontal.y) * horizontal_thrust_force * thrust_multiplier / maxf(mass, 0.001)
	acceleration += _local_up * vertical * vertical_thrust_force * thrust_multiplier / maxf(mass, 0.001)
	var radius := _planet_radius(_planet)
	var boundary_force := 0.0
	if is_instance_valid(_surface_collider):
		var penetration := _surface_collider.surface_radius(_local_up) + surface_clearance - (radius + _altitude)
		if penetration > 0.0:
			boundary_force += maxf(0.0, boundary_spring_stiffness * penetration - boundary_spring_damping * radial_speed)
	var ceiling_penetration := _altitude - radius * maximum_altitude_ratio
	if ceiling_penetration > 0.0:
		boundary_force -= maxf(0.0, boundary_spring_stiffness * ceiling_penetration + boundary_spring_damping * radial_speed)
	acceleration += _local_up * boundary_force / maxf(mass, 0.001)
	_velocity = tangent_velocity + _local_up * radial_speed + acceleration * delta
	_altitude += _velocity.dot(_local_up) * delta
	tangent_velocity = _velocity - _local_up * _velocity.dot(_local_up)
	if tangent_velocity.length_squared() > 0.000001:
		# Transport momentum, ship heading, and view together across the sphere.
		var axis := _local_up.cross(tangent_velocity.normalized()).normalized()
		var angle := tangent_velocity.length() * delta / maxf(_planet_radius(_planet) + _altitude, 0.001)
		_local_up = _local_up.rotated(axis, angle).normalized()
		_local_forward = _local_forward.rotated(axis, angle).normalized()
		_local_view_forward = _local_view_forward.rotated(axis, angle).normalized()
		_velocity = _velocity.rotated(axis, angle)


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
