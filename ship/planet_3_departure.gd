extends "res://ship/planet_departure.gd"
## Fixed-duration departure followed by a damaged, kinematic crash landing.
const ImpactScene = preload("res://combat/explosion.tscn")
signal missile_impact
signal crash_finished
signal crash_impact
signal boosters_failed
var camera_controls_enabled := false
var _player_camera_basis := Basis.IDENTITY
var _player_camera_yaw := 0.0
var _player_camera_pitch := 0.0
@export var journey_duration := 50.0
@export var rear_hold_duration := 2.0
@export var damage_delay := 5.0
@export var departure_altitude := 220.0
@export var crash_approach_distance := 180.0
@export var camera_rotation_response := 5.0
@export var camera_maximum_turn_speed := 1.8
var _journey_elapsed := 0.0
var _front_elapsed := -1.0
var _rear_hold_elapsed := 0.0
var _damage_started := false
var _impact_times: Array[float] = []
var _damage_elapsed := 0.0
var _rng := RandomNumberGenerator.new()
var _landing_up := Vector3.UP
var _landing_position := Vector3.ZERO
var _landing_ground_position := Vector3.ZERO
var _landing_surface_normal := Vector3.UP
var _landing_basis := Basis.IDENTITY
var _route := Curve3D.new()
var _route_length := 0.0
var _route_speed := 0.0
var _departure_distance := 0.0
var _wobble_basis := Basis.IDENTITY
var _camera_offset := Vector3.ZERO
var _camera_view := Basis.IDENTITY
var _camera_delta := 0.0
var _camera_updated := false
var _camera_returning := false
var _camera_turn_start := Basis.IDENTITY
var _camera_turn_end := Basis.IDENTITY
var _camera_rear_turning := false


func begin(player: ShipController, source: Node3D, destination: Node3D, view: Camera3D, sun: Node3D) -> void:
	_journey_elapsed = 0.0
	_front_elapsed = -1.0
	_rear_hold_elapsed = 0.0
	_damage_started = false
	camera_controls_enabled = false
	_player_camera_yaw = 0.0
	_player_camera_pitch = 0.0
	_damage_elapsed = 0.0
	_impact_times.clear()
	_wobble_basis = Basis.IDENTITY
	_rng.randomize()
	_camera_offset = view.global_position - player.global_position
	_camera_view = view.global_basis.orthonormalized()
	_camera_returning = false
	_camera_rear_turning = false
	super.begin(player, source, destination, view, sun)
	_build_route()


func _prepare_arrival() -> void:
	var toward_sun := (_sun.global_position - _destination.global_position).normalized()
	_landing_up = (Vector3.UP * 0.94 + toward_sun * 0.34).normalized()
	var terrain := _destination.get_node("Terrain") as MeshInstance3D
	var triangles := TriangleMesh.new()
	triangles.create_from_faces(terrain.mesh.get_faces())
	var ray := (terrain.global_basis.inverse() * _landing_up).normalized()
	var hit := triangles.intersect_ray(terrain.to_local(_destination.global_position), ray)
	var ground := _destination.global_basis.x.length()
	_landing_surface_normal = _landing_up
	if not hit.is_empty():
		ground = terrain.to_global(hit.position).distance_to(_destination.global_position)
		_landing_surface_normal = (terrain.global_basis.inverse().transposed() * hit.normal).normalized()
		if _landing_surface_normal.dot(_landing_up) < 0.0:
			_landing_surface_normal = -_landing_surface_normal
	var heading := toward_sun - _landing_up * toward_sun.dot(_landing_up)
	_landing_basis = Basis.looking_at(-heading.normalized(), _landing_up) * Basis.from_euler(Vector3(-0.08, 0.0, 0.18))
	_landing_ground_position = _destination.global_position + _landing_up * ground
	_landing_position = _landing_ground_position + _landing_up * _hull_clearance(_landing_basis)
	_arrival_up = _landing_up
	_arrival_axis = _landing_basis.x
	_arrival_heading = heading.normalized()
	_end = _landing_position + _landing_up * 90.0
	_arrival_velocity = -_landing_up * 10.0
	_arrival_acceleration = Vector3.ZERO


func _hull_clearance(attitude: Basis) -> float:
	# Contact uses the actual hull vertices in its resting model transform;
	# thruster flames and bounding-box corners must not hold the ship aloft.
	var minimum := INF
	var model_inverse := _ship.model.global_transform.affine_inverse()
	var pending: Array[Node] = [_ship.model]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if node.name == &"markers":
			continue
		if node is Node3D and not node.visible:
			continue
		if node is MeshInstance3D and node.mesh != null:
			var local_transform: Transform3D = _ship._model_rest_transform * model_inverse * node.global_transform
			for surface in range(node.mesh.get_surface_count()):
				var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					minimum = minf(minimum, (attitude * (local_transform * vertex)).dot(_landing_surface_normal))
		pending.append_array(node.get_children())
	if is_inf(minimum):
		return 0.0
	return (0.02 - minimum) / maxf(_landing_surface_normal.dot(_landing_up), 0.1) - 0.5


func _build_route() -> void:
	_route = Curve3D.new()
	_route.bake_interval = 0.5
	var center := _source.global_position
	var start_up := (_ship.global_position - center).normalized()
	var exit_up := (_landing_position - center).normalized()
	var angle := acos(clampf(start_up.dot(exit_up), -1.0, 1.0))
	var axis := start_up.cross(exit_up)
	if axis.length_squared() < 0.000001:
		axis = start_up.cross(_orbit_heading)
	axis = axis.normalized()
	# Only skirt as far as the forward hemisphere, rather than orbiting all
	# the way to its center and spending the travel budget on takeoff.
	angle = maxf(angle - acos(0.4), 0.0)
	var start_radius := _ship.global_position.distance_to(center)
	var exit_radius := maxf(start_radius, _source.global_basis.x.length() + departure_altitude)
	var points := PackedVector3Array()
	var arc_steps := maxi(ceili(angle / 0.12), 4)
	for index in range(arc_steps + 1):
		var t := float(index) / arc_steps
		var radial := start_up.rotated(axis, angle * t)
		points.append(center + radial * lerpf(start_radius, exit_radius, t))
	var departure_index := points.size() - 1
	# A broad glide approaches the near pole from the sun-facing side.
	# The final tangent still has forward/downward speed at impact.
	var toward_sun := (_sun.global_position - _destination.global_position).normalized()
	var tangent := (toward_sun - _landing_up * toward_sun.dot(_landing_up)).normalized()
	var approach := _landing_position + _landing_up * 70.0 + tangent * 200.0
	var exit := points[departure_index]
	points.append(exit.lerp(approach, 0.35))
	points.append(exit.lerp(approach, 0.7))
	points.append(approach)
	points.append(_landing_position)
	for index in range(points.size()):
		var handle := Vector3.ZERO
		if index == 0:
			handle = (points[1] - points[0]) / 3.0
		elif index == points.size() - 1:
			handle = -(_landing_up * 30.0 + tangent * 60.0)
		else:
			handle = (points[index + 1] - points[index - 1]) / 6.0
			var shorter_segment := minf(points[index].distance_to(points[index - 1]), points[index].distance_to(points[index + 1]))
			handle = handle.limit_length(shorter_segment / 3.0)
		_route.add_point(points[index], -handle, handle)
	_route_length = _route.get_baked_length()
	_route_speed = _route_length / maxf(journey_duration, 0.001)
	# Locate the end of the curved departure in the baked arc-length table.
	var baked := _route.get_baked_points()
	var best_distance := INF
	var distance := 0.0
	for index in range(baked.size()):
		if index > 0:
			distance += baked[index - 1].distance_to(baked[index])
		var gap := baked[index].distance_squared_to(exit)
		if gap < best_distance:
			best_distance = gap
			_departure_distance = distance
	_landing_basis = Basis.looking_at(-tangent, _landing_up) * Basis.from_euler(Vector3(-0.08, 0.0, 0.18))


func _step_route(delta: float) -> void:
	var distance := minf(_journey_elapsed * _route_speed, _route_length)
	_ship.global_position = _route.sample_baked(distance, true)
	var before := _route.sample_baked(maxf(distance - 0.5, 0.0), true)
	var after := _route.sample_baked(minf(distance + 0.5, _route_length), true)
	var heading := (after - before).normalized()
	_departure_velocity = heading * _route_speed
	var progress := distance / maxf(_route_length, 0.001)
	_up = Basis(Quaternion.IDENTITY.slerp(Quaternion(_orbit_up, _landing_up), progress)) * _orbit_up
	var desired := _flight_basis(heading)
	var landing_weight := smoothstep(maxf(_route_length - _route_speed, 0.0), _route_length, distance)
	desired = desired.slerp(_landing_basis, landing_weight)
	_ship.global_basis = _ship.global_basis.orthonormalized().slerp(desired, 1.0 - exp(-turn_response * delta))
	stage = Stage.ORBIT if distance < _departure_distance else Stage.TRANSFER
	if _route_length - distance <= crash_approach_distance:
		stage = Stage.DESCENT
	_ship.set_cutscene_thrust(1.0, 0.0, delta)


func step(delta: float) -> void:
	if not active:
		return
	# Remove last frame's visual offset so the wobble never accumulates into spins.
	_ship.global_basis *= _wobble_basis.inverse()
	_wobble_basis = Basis.IDENTITY
	delta = minf(delta, maxf(journey_duration - _journey_elapsed, 0.0))
	_camera_delta = delta
	_camera_updated = false
	_journey_elapsed += delta
	_step_route(delta)
	_step_rear_view(delta)
	if _rear_ready_emitted and not _face_destination:
		_rear_hold_elapsed += delta
		if _rear_hold_elapsed >= rear_hold_duration:
			face_destination()
	if _destination_ready_emitted and not _damage_started:
		if _front_elapsed < 0.0:
			_front_elapsed = 0.0
		else:
			_front_elapsed += delta
		if _front_elapsed >= damage_delay:
			_damage_started = true
			camera_controls_enabled = true
			_player_camera_basis = _camera_view
			boosters_failed.emit()
			_impact_times = [0.0, _rng.randf_range(0.35, 0.7), _rng.randf_range(0.9, 1.3), _rng.randf_range(1.5, 2.0)]
	if _damage_started:
		_damage_elapsed += delta
		while not _impact_times.is_empty() and _impact_times[0] <= _damage_elapsed:
			_impact_times.pop_front()
			_spawn_impact()
		if active:
			var strength := smoothstep(0.0, 1.5, _damage_elapsed)
			var settle := 1.0 - smoothstep(journey_duration - 1.0, journey_duration, _journey_elapsed)
			var roll := (sin(_damage_elapsed * 3.7) * 0.16 + sin(_damage_elapsed * 7.1) * 0.07) * strength * settle
			var pitch := sin(_damage_elapsed * 2.9) * 0.09 * strength * settle
			_wobble_basis = Basis.from_euler(Vector3(pitch, 0.0, roll))
			_ship.global_basis *= _wobble_basis
			_ship.set_cutscene_thrust(0.25 * settle, 0.0, delta)
	_update_camera()
	if _journey_elapsed >= journey_duration:
		# Constant speed ends in a hard impact, rather than easing to a stop.
		var contact_position := _landing_ground_position + _landing_up * _hull_clearance(_ship.global_basis)
		_camera.global_position += contact_position - _ship.global_position
		_ship.global_position = contact_position
		_ship.set_cutscene_thrust(0.0, 0.0)
		stage = Stage.INACTIVE
		crash_finished.emit()
		# Landing rebases the scene. Spawn the death explosion in that new frame.
		crash_impact.emit()


func _spawn_impact() -> void:
	var explosion := ImpactScene.instantiate() as Node3D
	get_parent().get_node("CutsceneDebris").add_child(explosion)
	explosion.global_position = _ship.global_position + _ship.global_basis * Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.3, 0.5), _rng.randf_range(-1.0, 1.0))
	missile_impact.emit()


func rotate_camera(horizontal: float, vertical: float) -> void:
	if camera_controls_enabled:
		_player_camera_yaw += horizontal
		_player_camera_pitch = clampf(_player_camera_pitch + vertical, -1.4, 1.4)


func _continuous_view(direction: Vector3) -> Basis:
	# Transport the existing camera up rather than switching world axes at
	# a dot-product threshold, which previously caused sudden roll changes.
	var up := _camera_view.y - direction * _camera_view.y.dot(direction)
	if up.length_squared() < 0.000001:
		up = _camera_view.x - direction * _camera_view.x.dot(direction)
	return Basis.looking_at(direction, up.normalized())


func _update_camera() -> void:
	# The base controller and crash path can both request this in one frame.
	if _camera_updated:
		return
	_camera_updated = true
	var front_direction := _ship.forward
	if _face_destination:
		front_direction = (_destination.global_position - _ship.global_position).normalized()
	var front := _continuous_view(front_direction)
	var rear := _continuous_view((_source.global_position - _ship.global_position).normalized())
	var desired := front
	if _rear_started and not _camera_rear_turning:
		_camera_rear_turning = true
		_camera_turn_start = _camera_view
		_camera_turn_end = rear
	if _face_destination and not _camera_returning:
		_camera_returning = true
		_camera_turn_start = _camera_view
		_camera_turn_end = front
	if _camera_returning:
		var progress := smoothstep(0.0, maxf(camera_turn_duration, 0.01), _return_elapsed)
		desired = _camera_turn_start.slerp(_camera_turn_end, progress) if progress < 1.0 else front
	elif _camera_rear_turning:
		var progress := smoothstep(source_color_duration, source_color_duration + maxf(camera_turn_duration, 0.01), _rear_elapsed)
		desired = _camera_turn_start.slerp(_camera_turn_end, progress) if progress < 1.0 else rear
	if camera_controls_enabled:
		desired = _player_camera_basis * Basis.from_euler(Vector3(_player_camera_pitch, _player_camera_yaw, 0.0))
	# Smooth only the orientation and ship-relative offset: world translation
	# follows the ship exactly, including during acceleration and the crash.
	var weight := 1.0 - exp(-camera_rotation_response * _camera_delta)
	var angle := _camera_view.get_rotation_quaternion().angle_to(desired.get_rotation_quaternion())
	if angle > 0.000001:
		weight = minf(weight, camera_maximum_turn_speed * _camera_delta / angle)
	_camera_view = _camera_view.slerp(desired, weight).orthonormalized()
	var desired_offset := _camera_view.z * camera_distance + _camera_view.y * camera_height
	_camera_offset = _camera_offset.lerp(desired_offset, 1.0 - exp(-camera_rotation_response * _camera_delta))
	_camera.global_position = _ship.global_position + _camera_offset
	_camera.global_basis = Basis.looking_at(-_camera_offset.normalized(), _camera_view.y)


func skip_to_crash() -> void:
	# Advance the same sequence so skip also applies the burn and impact events.
	while active:
		step(1.0 / 60.0)
