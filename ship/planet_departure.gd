extends Node
## Kinematic departure and a continuous transfer into orbit around the next planet.
const ShipController = preload("res://ship/ship.gd")
signal source_heated
signal rear_view_ready
signal destination_view_ready
signal descent_finished
enum Stage { INACTIVE, ORBIT, TRANSFER, DESTINATION_ORBIT, DESCENT }
@export var transfer_duration := 20.0
@export var camera_distance := 9.0
@export var camera_height := 3.0
@export var camera_turn_duration := 3.0
@export var source_reveal_distance := 200.0
@export var source_color_duration := 0.6
@export var sun_stop_margin := 50.0
@export var orbit_speed := 80.0
@export var destination_orbit_speed := 35.0
@export var orbit_climb_speed := 12.0
@export var departure_acceleration_time := 1.2
@export var turn_response := 4.0
@export var descent_duration := 5.0
@export var descent_altitude := 65.0
var stage := Stage.INACTIVE
var active: bool:
	get:
		return stage != Stage.INACTIVE
var _ship: ShipController
var _source: Node3D
var _destination: Node3D
var _camera: Camera3D
var _sun: Node3D
var _start := Vector3.ZERO
var _departure_velocity := Vector3.ZERO
var _flight_duration := 20.0
var _end := Vector3.ZERO
var _up := Vector3.UP
var _elapsed := 0.0
var _camera_angle := 0.0
var _rear_ready_emitted := false
var _destination_ready_emitted := false
var _face_destination := false
var _descent_requested := false
var _descent_elapsed := 0.0
var _descent_start_radius := 480.0
var _descent_end_radius := 305.0
var velocity: Vector3:
	get:
		return _departure_velocity
var _camera_blend := 0.0
var _initial_camera_local := Transform3D.IDENTITY
var _orbit_up := Vector3.UP
var _orbit_heading := Vector3.FORWARD
var _orbit_altitude := 0.0
var _orbit_initial_speed := 0.0
var _orbit_initial_climb := 0.0
var _orbit_radius := 300.0
var _arrival_up := Vector3.UP
var _arrival_heading := Vector3.FORWARD
var _arrival_velocity := Vector3.ZERO
var _arrival_acceleration := Vector3.ZERO
var _arrival_axis := Vector3.RIGHT
var _arrival_radius := 480.0
var _transfer_up := Vector3.UP
var _up_rotation := Quaternion.IDENTITY
var _destination_elapsed := 0.0
var _rear_started := false
var _rear_elapsed := 0.0
var _return_elapsed := -1.0
var _camera_up := Vector3.UP


func begin(player: ShipController, source: Node3D, destination: Node3D, view: Camera3D, sun: Node3D) -> void:
	_ship = player
	_source = source
	_destination = destination
	_camera = view
	_sun = sun
	_ship.controls_enabled = false
	_ship.mouse_look_enabled = false
	_ship.set_parked(false)
	# Capture the live trajectory before unbinding. Everything from here on is
	# prescribed motion; neither the player loop nor the flight forces run.
	_orbit_up = (_ship.global_position - _source.global_position).normalized()
	_orbit_radius = _source.global_basis.x.length()
	_orbit_altitude = _ship.global_position.distance_to(_source.global_position) - _orbit_radius
	var incoming_velocity := _ship.velocity
	_orbit_initial_climb = incoming_velocity.dot(_orbit_up)
	var tangent_velocity := incoming_velocity - _orbit_up * _orbit_initial_climb
	_orbit_initial_speed = tangent_velocity.length()
	_orbit_heading = tangent_velocity.normalized() if _orbit_initial_speed > 0.01 else _ship.forward
	_orbit_heading = (_orbit_heading - _orbit_up * _orbit_heading.dot(_orbit_up)).normalized()
	_up = _orbit_up
	_ship.bind_to_planet(null)
	_ship.set_cutscene_thrust(1.0, 0.0)
	_elapsed = 0.0
	stage = Stage.ORBIT
	_camera_angle = 0.0
	_camera_blend = 0.0
	_initial_camera_local = _ship.global_transform.affine_inverse() * _camera.global_transform
	_rear_started = false
	_rear_ready_emitted = false
	_destination_ready_emitted = false
	_face_destination = false
	_descent_requested = false
	_rear_elapsed = 0.0
	_return_elapsed = -1.0
	_destination_elapsed = 0.0
	_camera_up = _camera.global_basis.y.normalized()
	_prepare_arrival()
	_up = _orbit_up


func step(delta: float) -> void:
	if not active:
		return
	if stage == Stage.ORBIT:
		_step_orbit(delta)
	elif stage == Stage.TRANSFER:
		_elapsed += delta
		var t := clampf(_elapsed / _flight_duration, 0.0, 1.0)
		# Quintic Hermite interpolation preserves the full incoming velocity,
		# including climb, and matches the destination orbit's velocity and
		# centripetal acceleration rather than stopping at its entry point.
		var t2 := t * t
		var t3 := t2 * t
		var t4 := t3 * t
		var t5 := t4 * t
		var position_weight := 10.0 * t3 - 15.0 * t4 + 6.0 * t5
		var velocity_weight := t - 6.0 * t3 + 8.0 * t4 - 3.0 * t5
		var displacement := _end - _start
		var momentum := _departure_velocity * _flight_duration
		var arrival_momentum := _arrival_velocity * _flight_duration
		var arrival_acceleration := _arrival_acceleration * _flight_duration * _flight_duration
		_ship.global_position = _start + displacement * position_weight + momentum * velocity_weight + arrival_momentum * (-4.0 * t3 + 7.0 * t4 - 3.0 * t5) + arrival_acceleration * (0.5 * t3 - t4 + 0.5 * t5)
		var tangent := displacement * (30.0 * t2 - 60.0 * t3 + 30.0 * t4) + momentum * (1.0 - 18.0 * t2 + 32.0 * t3 - 15.0 * t4) + arrival_momentum * (-12.0 * t2 + 28.0 * t3 - 15.0 * t4) + arrival_acceleration * (1.5 * t2 - 4.0 * t3 + 2.5 * t4)
		_departure_velocity = tangent / _flight_duration
		_up = Basis(Quaternion.IDENTITY.slerp(_up_rotation, position_weight)) * _transfer_up
		if tangent.length_squared() > 0.0001:
			var desired := _flight_basis(tangent.normalized())
			_ship.global_basis = _ship.global_basis.orthonormalized().slerp(desired, 1.0 - exp(-delta * 3.0))
		_ship.set_cutscene_thrust(1.0, 0.0, delta)
		if t >= 1.0:
			stage = Stage.DESTINATION_ORBIT
			_destination_elapsed = 0.0
			# Carry any remainder of this frame into the orbit instead of pausing
			# for a fraction of a frame at the entry point.
			_step_destination_orbit(maxf(_elapsed - _flight_duration, 0.0))
	elif stage == Stage.DESTINATION_ORBIT:
		_step_destination_orbit(delta)
		if _descent_requested:
			_start_descent()
	elif stage == Stage.DESCENT:
		_step_descent(delta)
	_step_rear_view(delta)
	_camera_blend = minf(_camera_blend + delta, 1.0)
	if active:
		_update_camera()


func _step_orbit(delta: float) -> void:
	_elapsed += delta
	var to_planet := (_destination.global_position - _ship.global_position).normalized()
	var heading := to_planet - _orbit_up * to_planet.dot(_orbit_up)
	if heading.length_squared() < 0.0001:
		var away := _ship.global_position - _sun.global_position
		heading = away - _orbit_up * away.dot(_orbit_up)
	if heading.length_squared() < 0.0001:
		heading = _orbit_heading
	heading = heading.normalized()
	var turn_weight := 1.0 - exp(-maxf(turn_response, 0.0) * delta)
	# Normalized interpolation also handles opposite headings without a roll flip.
	var turn_angle := atan2(_orbit_heading.cross(heading).dot(_orbit_up), _orbit_heading.dot(heading))
	_orbit_heading = _orbit_heading.rotated(_orbit_up, turn_angle * turn_weight).normalized()
	var ramp := smoothstep(0.0, maxf(departure_acceleration_time, 0.01), _elapsed)
	var speed := lerpf(_orbit_initial_speed, orbit_speed, ramp)
	var target_climb := minf(orbit_climb_speed, maxf(_orbit_radius * 0.45 - _orbit_altitude, 0.0) * 0.8)
	var climb := lerpf(_orbit_initial_climb, target_climb, ramp)
	var previous_position := _ship.global_position
	_orbit_altitude += climb * delta
	var axis := _orbit_up.cross(_orbit_heading).normalized()
	var angle := speed * delta / maxf(_orbit_radius + _orbit_altitude, 0.001)
	_orbit_up = _orbit_up.rotated(axis, angle).normalized()
	_orbit_heading = _orbit_heading.rotated(axis, angle).normalized()
	_ship.global_position = _source.global_position + _orbit_up * (_orbit_radius + _orbit_altitude)
	_up = _orbit_up
	var desired := _flight_basis((_orbit_heading * speed + _orbit_up * climb).normalized())
	_ship.global_basis = _ship.global_basis.orthonormalized().slerp(desired, turn_weight)
	_ship.set_cutscene_thrust(1.0, 0.0, delta)
	if delta > 0.000001:
		_departure_velocity = (_ship.global_position - previous_position) / delta
	to_planet = (_destination.global_position - _ship.global_position).normalized()
	if _elapsed >= departure_acceleration_time and _orbit_up.dot(to_planet) > 0.3:
		_begin_transfer()


func _flight_basis(direction: Vector3) -> Basis:
	var up := _up
	if absf(direction.dot(up)) > 0.98:
		up = Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(direction, up)


func _begin_transfer() -> void:
	_start = _ship.global_position
	_flight_duration = maxf(transfer_duration, 0.01)
	_up = _orbit_up
	_ship.bind_to_planet(null)
	_ship.set_cutscene_thrust(1.0, 0.0)
	_prepare_arrival()
	_transfer_up = _up
	_up_rotation = Quaternion(_transfer_up, _arrival_up)
	_elapsed = 0.0
	stage = Stage.TRANSFER


func skip() -> void:
	if not active:
		return
	if stage == Stage.DESTINATION_ORBIT:
		return
	_prepare_arrival()
	_ship.global_position = _end
	_up = _arrival_up
	_ship.global_basis = _flight_basis(_arrival_heading)
	_ship.set_cutscene_thrust(1.0, 0.0)
	stage = Stage.DESTINATION_ORBIT
	_destination_elapsed = 0.0
	if not _rear_started:
		_rear_started = true
		source_heated.emit()
	_rear_elapsed = source_color_duration + camera_turn_duration
	_camera_angle = PI
	_camera_blend = 1.0
	_update_camera()


func cancel() -> void:
	if active:
		_ship.set_cutscene_thrust(0.0, 0.0)
	stage = Stage.INACTIVE


func sun_stop_radius() -> float:
	return _sun.global_position.distance_to(_source.global_position) + _source.global_basis.x.length() + sun_stop_margin


func _prepare_arrival() -> void:
	_arrival_radius = _destination.global_basis.x.length() * 2.0
	# Enter the planet's horizontal equatorial plane, with a world-Y orbit axis.
	var radial := _ship.global_position - _destination.global_position
	radial.y = 0.0
	_arrival_up = radial.normalized() if radial.length_squared() > 0.0001 else Vector3.RIGHT
	_arrival_axis = Vector3.UP
	_arrival_heading = _arrival_axis.cross(_arrival_up).normalized()
	var incoming := _departure_velocity if _departure_velocity.length_squared() > 0.0001 else _ship.forward
	if _arrival_heading.dot(incoming) < 0.0:
		_arrival_axis = -_arrival_axis
		_arrival_heading = -_arrival_heading
	_end = _destination.global_position + _arrival_up * _arrival_radius
	_arrival_velocity = _arrival_heading * destination_orbit_speed
	_arrival_acceleration = -_arrival_up * destination_orbit_speed * destination_orbit_speed / _arrival_radius


func _step_destination_orbit(delta: float) -> void:
	_destination_elapsed += delta
	var angle := destination_orbit_speed * delta / _arrival_radius
	_arrival_up = _arrival_up.rotated(_arrival_axis, angle).normalized()
	_arrival_heading = _arrival_heading.rotated(_arrival_axis, angle).normalized()
	_ship.global_position = _destination.global_position + _arrival_up * _arrival_radius
	_departure_velocity = _arrival_heading * destination_orbit_speed
	_up = _arrival_up
	_ship.global_basis = _ship.global_basis.orthonormalized().slerp(_flight_basis(_arrival_heading), 1.0 - exp(-turn_response * delta))
	_ship.set_cutscene_thrust(1.0, 0.0, delta)


func face_destination() -> void:
	_return_elapsed = 0.0
	_face_destination = true


func begin_descent() -> void:
	_descent_requested = true
	if stage == Stage.DESTINATION_ORBIT:
		_start_descent()


func _start_descent() -> void:
	stage = Stage.DESCENT
	_descent_elapsed = 0.0
	_descent_start_radius = _arrival_radius
	var radius := _destination.global_basis.x.length()
	_descent_end_radius = radius + minf(descent_altitude, radius * 0.45)


func _step_descent(delta: float) -> void:
	_descent_elapsed += delta
	var duration := maxf(descent_duration, 0.01)
	var t := clampf(_descent_elapsed / duration, 0.0, 1.0)
	var weight := t * t * t * (10.0 + t * (-15.0 + 6.0 * t))
	var radius := lerpf(_descent_start_radius, _descent_end_radius, weight)
	var angular_step := destination_orbit_speed * delta / radius
	_arrival_up = _arrival_up.rotated(_arrival_axis, angular_step).normalized()
	_arrival_heading = _arrival_heading.rotated(_arrival_axis, angular_step).normalized()
	_ship.global_position = _destination.global_position + _arrival_up * radius
	_up = _arrival_up
	_ship.global_basis = _ship.global_basis.orthonormalized().slerp(_flight_basis(_arrival_heading), 1.0 - exp(-turn_response * delta))
	var radial_speed := (_descent_end_radius - _descent_start_radius) * (30.0 * t * t * pow(1.0 - t, 2.0)) / duration
	_departure_velocity = _arrival_heading * destination_orbit_speed + _arrival_up * radial_speed
	_ship.set_cutscene_thrust(1.0, 0.0, delta)
	_update_camera()
	if t >= 1.0:
		stage = Stage.INACTIVE
		descent_finished.emit()


func skip_to_gameplay() -> void:
	if not active:
		return
	skip()
	_face_destination = true
	_camera_angle = 0.0
	_destination_ready_emitted = true
	_start_descent()
	_step_descent(maxf(descent_duration, 0.01))


func _step_rear_view(delta: float) -> void:
	if not active:
		return
	if not _rear_started:
		var source_gap := _ship.global_position.distance_to(_source.global_position) - _source.global_basis.x.length()
		if source_gap < source_reveal_distance:
			return
		_rear_started = true
		source_heated.emit()
	_rear_elapsed += delta
	var turn_time := maxf(camera_turn_duration, 0.01)
	_camera_angle = PI * smoothstep(source_color_duration, source_color_duration + turn_time, _rear_elapsed)
	if _rear_elapsed >= source_color_duration + turn_time and not _rear_ready_emitted:
		_rear_ready_emitted = true
		rear_view_ready.emit()
	if _return_elapsed >= 0.0:
		_return_elapsed += delta
		_camera_angle = PI * (1.0 - smoothstep(0.0, turn_time, _return_elapsed))
		if _return_elapsed >= turn_time and not _destination_ready_emitted:
			_destination_ready_emitted = true
			destination_view_ready.emit()


func _view_basis(direction: Vector3) -> Basis:
	var up := _camera_up
	if absf(direction.dot(up)) > 0.98:
		up = _arrival_axis
	if absf(direction.dot(up)) > 0.98:
		up = Vector3.UP if absf(direction.y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(direction, up)


func _update_camera() -> void:
	var front := _view_basis(_ship.forward)
	if _face_destination:
		front = _view_basis((_destination.global_position - _ship.global_position).normalized())
	elif stage == Stage.DESTINATION_ORBIT:
		var planet_view := _view_basis((_destination.global_position - _ship.global_position).normalized())
		front = front.slerp(planet_view, smoothstep(0.0, 2.0, _destination_elapsed))
	var rear := _view_basis((_source.global_position - _ship.global_position).normalized())
	var view := front.slerp(rear, _camera_angle / PI)
	var position := _ship.global_position + view.z * camera_distance + view.y * camera_height
	var target := Transform3D(Basis.looking_at((_ship.global_position - position).normalized(), view.y), position)
	# Ease the initial framing in ship space, so even that blend follows the
	# ship immediately. Camera turns change the offset, never its follow speed.
	var initial_attached := _ship.global_transform * _initial_camera_local
	_camera.global_transform = initial_attached.interpolate_with(target, smoothstep(0.0, 1.0, _camera_blend))
