class_name PlanetShip
extends Node3D
## Thrust and damped yaw around uniformly scaled unit-sphere planets; no physics bodies.
## Bind after placing the ship in the scene. Unbinding preserves its transform.
const ThrusterController = preload("res://ship/thruster.gd")
const SurfaceCollider = preload("res://planets/surface_collider.gd")
signal destroyed(ship: PlanetShip)
const MAX_LIVES := 5
var lives_remaining := MAX_LIVES
var is_dying := false
var is_destroyed := false
var _wreck_remaining := 0.0
var _wreck_velocity := Vector3.ZERO
var _wreck_spin := Vector3.ZERO
var can_fight: bool:
	get:
		return lives_remaining > 0 and not is_destroyed
var is_parked := false

const MovementSettings = preload("res://ship/movement_settings.gd")
@export_group("Movement profiles")
@export var planet_1_movement: MovementSettings = preload("res://ship/movement_planet1.tres").duplicate() as MovementSettings
@export var planet_2_and_3_movement: MovementSettings = preload("res://ship/movement_planet2_and_3.tres").duplicate() as MovementSettings
var _use_planet_2_movement := false
var movement_settings: MovementSettings:
	get:
		return planet_2_and_3_movement if _use_planet_2_movement else planet_1_movement

# Existing callers read and modify the active profile through these properties.
var mass: float:
	get:
		return movement_settings.mass
	set(value):
		movement_settings.mass = value
var horizontal_thrust_force: float:
	get:
		return movement_settings.horizontal_thrust_force
	set(value):
		movement_settings.horizontal_thrust_force = value
var vertical_thrust_force: float:
	get:
		return movement_settings.vertical_thrust_force
	set(value):
		movement_settings.vertical_thrust_force = value
var horizontal_damping: float:
	get:
		return movement_settings.horizontal_damping
	set(value):
		movement_settings.horizontal_damping = value
var vertical_damping: float:
	get:
		return movement_settings.vertical_damping
	set(value):
		movement_settings.vertical_damping = value
var yaw_inertia: float:
	get:
		return movement_settings.yaw_inertia
	set(value):
		movement_settings.yaw_inertia = value
var view_turn_torque: float:
	get:
		return movement_settings.view_turn_torque
	set(value):
		movement_settings.view_turn_torque = value
var yaw_damping: float:
	get:
		return movement_settings.yaw_damping
	set(value):
		movement_settings.yaw_damping = value
var impact_angular_inertia: float:
	get:
		return movement_settings.impact_angular_inertia
	set(value):
		movement_settings.impact_angular_inertia = value
var attitude_stabilization_frequency: float:
	get:
		return movement_settings.attitude_stabilization_frequency
	set(value):
		movement_settings.attitude_stabilization_frequency = value
var surface_clearance: float:
	get:
		return movement_settings.surface_clearance
	set(value):
		movement_settings.surface_clearance = value
var boundary_spring_stiffness: float:
	get:
		return movement_settings.boundary_spring_stiffness
	set(value):
		movement_settings.boundary_spring_stiffness = value
var boundary_spring_damping: float:
	get:
		return movement_settings.boundary_spring_damping
	set(value):
		movement_settings.boundary_spring_damping = value
var maximum_altitude_ratio: float:
	get:
		return movement_settings.maximum_altitude_ratio
	set(value):
		movement_settings.maximum_altitude_ratio = value

@export var surface_repulsion_enabled := true

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
		return (_planet.global_basis.orthonormalized() * _local_up).normalized() if is_instance_valid(_planet) else global_basis.y.normalized()
var forward: Vector3:
	get:
		return -global_basis.z.normalized()

var view_forward: Vector3:
	get:
		return (_planet.global_basis * _local_view_forward).normalized() if is_instance_valid(_planet) else _unbound_view_forward
var velocity: Vector3:
	get:
		if is_dying:
			return _wreck_velocity
		if is_destroyed:
			return Vector3.ZERO
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
var _impact_rotation := Quaternion.IDENTITY
var _impact_angular_velocity := Vector3.ZERO
var _last_stabilization_torque := Vector3.ZERO
var _model_rest_transform := Transform3D.IDENTITY
var _visual_tilt := Vector2.ZERO
var _visual_time: float = 0.0
var _wobble_noise := FastNoiseLite.new()
var _thrusters: Dictionary = {}
var _last_yaw_torque: float = 0.0


func _ready() -> void:
	lives_remaining = maximum_lives()
	_model_rest_transform = model.transform
	_wobble_noise.seed = 73129
	_wobble_noise.frequency = 1.0
	for marker in $Model/markers.get_children():
		var exhaust := marker.get_node_or_null("Exhaust") as ThrusterController
		if exhaust != null:
			_thrusters[marker.name] = exhaust
	set_process(is_instance_valid(_planet))


func bind_to_planet(planet: Node3D) -> void:
	set_parked(false)
	_unbound_view_forward = view_forward
	_planet = planet
	_surface_collider = _planet.get_node_or_null("SurfaceCollider") as SurfaceCollider if is_instance_valid(_planet) else null
	set_process(is_instance_valid(_planet))
	if not is_instance_valid(_planet):
		_impact_angular_velocity = Vector3.ZERO
		_last_stabilization_torque = Vector3.ZERO
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
	_impact_rotation = Quaternion.IDENTITY
	_impact_angular_velocity = Vector3.ZERO
	_last_stabilization_torque = Vector3.ZERO
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


func set_movement_profile(planet_index: int) -> void:
	_use_planet_2_movement = planet_index >= 1

func set_parked(value: bool) -> void:
	if is_parked == value:
		return
	is_parked = value
	for exhaust: ThrusterController in _thrusters.values():
		if value:
			exhaust.set_static_power(0.0)
		else:
			exhaust.set_process(true)
	if value:
		model.transform = _model_rest_transform

func maximum_lives() -> int:
	return MAX_LIVES

func reset_health() -> void:
	lives_remaining = maximum_lives()
	is_dying = false
	is_destroyed = false
	_wreck_remaining = 0.0
	visible = true
	for exhaust: ThrusterController in _thrusters.values():
		exhaust.set_process(true)

func receive_missile_hit(impulse: Vector3, torque_impulse: Vector3) -> void:
	if not can_fight:
		return
	apply_impulse(impulse)
	apply_torque_impulse(torque_impulse)
	lives_remaining -= 1
	if lives_remaining == 0:
		_wreck_velocity = velocity
		_wreck_spin = _planet.global_basis.orthonormalized() * _navigation_basis() * _impact_angular_velocity
		_wreck_spin += radial_up * _yaw_velocity
		_wreck_remaining = 2.0
		is_dying = true
		_last_stabilization_torque = Vector3.ZERO
		for exhaust: ThrusterController in _thrusters.values():
			exhaust.set_static_power(0.0)

func step_wreck(delta: float) -> void:
	if not is_dying:
		return
	var step := minf(maxf(delta, 0.0), _wreck_remaining)
	global_position += _wreck_velocity * step
	var speed := _wreck_spin.length()
	if speed > 0.000001:
		global_basis = Basis(Quaternion(_wreck_spin / speed, speed * step)) * global_basis
	_wreck_remaining -= step
	if _wreck_remaining <= 0.000001:
		is_dying = false
		is_destroyed = true
		destroyed.emit(self)
		visible = false
		set_process(false)


func apply_impulse(world_impulse: Vector3) -> void:
	if not is_instance_valid(_planet):
		return
	_velocity += _planet.global_basis.orthonormalized().inverse() * world_impulse / maxf(mass, 0.001)


func apply_torque_impulse(world_impulse: Vector3) -> void:
	if not is_instance_valid(_planet):
		return
	var world_frame := _planet.global_basis.orthonormalized() * _navigation_basis()
	_impact_angular_velocity += world_frame.inverse() * world_impulse / maxf(impact_angular_inertia, 0.001)


func _navigation_basis() -> Basis:
	return Basis(_local_forward.cross(_local_up).normalized(), _local_up, -_local_forward)


func _flight_basis() -> Basis:
	return _navigation_basis() * Basis(_impact_rotation)


func _step_attitude(delta: float) -> void:
	var settings := movement_settings
	# Critically damped torque restores the actual ship attitude, independently of view yaw.
	var rotation := _impact_rotation
	if rotation.w < 0.0:
		rotation = -rotation
	var imaginary := Vector3(rotation.x, rotation.y, rotation.z)
	var sine := imaginary.length()
	var angle := 2.0 * atan2(sine, rotation.w)
	var error := imaginary * (angle / sine) if sine > 0.000001 else Vector3.ZERO
	var frequency := maxf(settings.attitude_stabilization_frequency, 0.0)
	var acceleration := -error * frequency * frequency - _impact_angular_velocity * 2.0 * frequency
	_last_stabilization_torque = Basis(_impact_rotation).inverse() * acceleration * settings.impact_angular_inertia
	_impact_angular_velocity += acceleration * delta
	var speed := _impact_angular_velocity.length()
	if speed < 0.00001 and angle < 0.00001:
		_impact_rotation = Quaternion.IDENTITY
		_impact_angular_velocity = Vector3.ZERO
	elif speed > 0.000001:
		_impact_rotation = (Quaternion(_impact_angular_velocity / speed, speed * delta) * _impact_rotation).normalized()
		if _impact_rotation.w < 0.0:
			_impact_rotation = -_impact_rotation


func _process(delta: float) -> void:
	if is_dying:
		step_wreck(delta)
		return
	if is_destroyed:
		return
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
	if not can_fight:
		return
	if not is_instance_valid(_planet):
		return
	var local_direction := _planet.global_basis.inverse() * direction
	local_direction -= _local_up * local_direction.dot(_local_up)
	if local_direction.length_squared() > 0.000001:
		_local_view_forward = local_direction.normalized()


func rotate_view(angle: float) -> void:
	if can_fight and not is_parked and is_instance_valid(_planet):
		_local_view_forward = _local_view_forward.rotated(_local_up, angle).normalized()


func _move(delta: float) -> void:
	if not is_instance_valid(_planet):
		return
	var horizontal := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))).limit_length()
	var vertical := float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_E))
	if is_parked:
		if horizontal.is_zero_approx() and is_zero_approx(vertical):
			return
		set_parked(false)
	apply_flight_controls(delta, horizontal, vertical)


func apply_flight_controls(delta: float, horizontal: Vector2, vertical: float) -> void:
	if not can_fight or not is_instance_valid(_planet):
		return
	horizontal = horizontal.limit_length()
	vertical = clampf(vertical, -1.0, 1.0)
	var remaining := minf(maxf(delta, 0.0), 0.25)
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 120.0)
		_step_thrust(step, horizontal, vertical)
		remaining -= step
	_update_transform()
	_update_visual_tilt(minf(maxf(delta, 0.0), 0.25), horizontal)
	_update_thrusters(horizontal, vertical, _last_yaw_torque)


func _update_thrusters(horizontal: Vector2, vertical: float, yaw_torque: float) -> void:
	var active := is_instance_valid(_planet) and not is_parked
	var torque_scale := maxf(full_yaw_thrust_torque, 0.001)
	var turn := clampf((yaw_torque + _last_stabilization_torque.y) / torque_scale, -1.0, 1.0)
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
			if name_text.begins_with("up_") or name_text.begins_with("down_"):
				var pitch_sign := 1.0 if name_text.contains("_front_") else -1.0
				var roll_sign := 1.0 if name_text.ends_with("_right") else -1.0
				var correction := (_last_stabilization_torque.x * pitch_sign + _last_stabilization_torque.z * roll_sign) / torque_scale
				power = maxf(power, maxf(correction if name_text.begins_with("down_") else -correction, 0.0))
			if vertical < 0.0 and name_text.begins_with("down_"):
				power = 0.0
		var exhaust: ThrusterController = _thrusters[marker_name]
		exhaust.set_power(power)


func _update_visual_tilt(delta: float, horizontal: Vector2) -> void:
	if not is_instance_valid(model):
		return
	if is_parked:
		model.transform = _model_rest_transform
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
	var settings := movement_settings
	# The view target is independent of ship yaw, so turning cannot chase the camera.
	var error := atan2(_local_forward.cross(_local_view_forward).dot(_local_up), _local_forward.dot(_local_view_forward))
	var torque := settings.view_turn_torque * error - settings.yaw_damping * _yaw_velocity
	_last_yaw_torque = torque
	_yaw_velocity += torque / maxf(settings.yaw_inertia, 0.001) * delta
	_local_forward = _local_forward.rotated(_local_up, _yaw_velocity * delta).normalized()
	_step_attitude(delta)
	var radial_speed := _velocity.dot(_local_up)
	var tangent_velocity := _velocity - _local_up * radial_speed
	tangent_velocity *= exp(-maxf(settings.horizontal_damping, 0.0) * delta)
	radial_speed *= exp(-maxf(settings.vertical_damping, 0.0) * delta)
	var body := _flight_basis()
	var acceleration := (body.x * horizontal.x - body.z * horizontal.y) * settings.horizontal_thrust_force / maxf(settings.mass, 0.001)
	acceleration += body.y * vertical * settings.vertical_thrust_force / maxf(settings.mass, 0.001)
	var radius := _planet_radius(_planet)
	var boundary_force := 0.0
	if surface_repulsion_enabled and is_instance_valid(_surface_collider):
		var penetration := _surface_collider.surface_radius(_local_up) + settings.surface_clearance - (radius + _altitude)
		if penetration > 0.0:
			boundary_force += maxf(0.0, settings.boundary_spring_stiffness * penetration - settings.boundary_spring_damping * radial_speed)
	var ceiling_penetration := _altitude - radius * settings.maximum_altitude_ratio
	if ceiling_penetration > 0.0:
		boundary_force -= maxf(0.0, settings.boundary_spring_stiffness * ceiling_penetration + settings.boundary_spring_damping * radial_speed)
	acceleration += _local_up * boundary_force / maxf(settings.mass, 0.001)
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
	var local_basis := _flight_basis()
	global_transform = Transform3D(_planet.global_basis.orthonormalized() * local_basis, _planet.to_global(local_position))
