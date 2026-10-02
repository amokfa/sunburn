extends Node3D
## Geometric flight on the planet; combat decisions are made by the battle scene.
@export var spawn_direction := Vector3.UP
@export var spawn_heading := Vector3.FORWARD
@export var cruise_altitude: float = 45.0
var up := Vector3.UP
var heading := Vector3.FORWARD
var facing := Vector3.FORWARD
var altitude: float = 45.0
var velocity := Vector3.ZERO
var previous_position := Vector3.ZERO
var target: Node3D
var target_remaining: float = 0.0
var reload_remaining: float = 0.0
var think_remaining: float = 0.0
var dodge_remaining: float = 0.0
var dodge_direction := Vector3.ZERO

func reset(radius: float) -> void:
	up = spawn_direction.normalized()
	heading = (spawn_heading - up * spawn_heading.dot(up)).normalized()
	facing = heading
	altitude = cruise_altitude
	position = up * (radius + altitude)
	velocity = Vector3.ZERO
	previous_position = position
	target = null
	target_remaining = 0.0
	dodge_remaining = 0.0
	_update_basis()

func fly(delta: float, radius: float, speed: float, turn_speed: float, aim: Vector3, movement: Vector3) -> void:
	if aim.length_squared() > 0.0001:
		var desired_facing := aim.normalized()
		var facing_angle := acos(clampf(facing.dot(desired_facing), -1.0, 1.0))
		var facing_axis := facing.cross(desired_facing)
		if facing_axis.length_squared() < 0.000001:
			facing_axis = heading.cross(up)
		facing = facing.rotated(facing_axis.normalized(), minf(facing_angle, turn_speed * delta)).normalized()
	var vertical_speed := speed * movement.dot(up)
	var travel := movement - up * movement.dot(up)
	if travel.length_squared() > 0.0001:
		travel = travel.normalized()
		heading = travel
	else:
		travel = heading
	if dodge_remaining > 0.0:
		dodge_remaining -= delta
		var side := dodge_direction - up * dodge_direction.dot(up)
		travel = (travel + side * 1.5).normalized()
	var axis := up.cross(travel).normalized()
	vertical_speed = clampf(vertical_speed, -speed, speed)
	var tangent_speed := sqrt(maxf(speed * speed - vertical_speed * vertical_speed, 0.0))
	altitude += vertical_speed * delta
	var angle := tangent_speed * delta / maxf(radius + altitude, 0.001)
	up = up.rotated(axis, angle).normalized()
	heading = heading.rotated(axis, angle).normalized()
	facing = facing.rotated(axis, angle).normalized()
	velocity = travel.rotated(axis, angle) * tangent_speed + up * vertical_speed
	position = up * (radius + altitude)
	_update_basis()

func keep_target_distance(target_position: Vector3, minimum_distance: float, delta: float) -> void:
	var orbit_radius := position.length()
	var target_radius := target_position.length()
	if position.distance_to(target_position) >= minimum_distance or target_radius < 0.001:
		return
	# Stay on the current altitude sphere while moving to the separation circle.
	var target_up := target_position / target_radius
	var cosine := clampf((orbit_radius * orbit_radius + target_radius * target_radius - minimum_distance * minimum_distance) / (2.0 * orbit_radius * target_radius), -1.0, 1.0)
	var side := up - target_up * up.dot(target_up)
	if side.length_squared() < 0.000001:
		side = heading - target_up * heading.dot(target_up)
	side = side.normalized()
	var next_up := (target_up * cosine + side * sqrt(maxf(1.0 - cosine * cosine, 0.0))).normalized()
	var axis := up.cross(next_up)
	if axis.length_squared() > 0.000001:
		var angle := acos(clampf(up.dot(next_up), -1.0, 1.0))
		heading = heading.rotated(axis.normalized(), angle).normalized()
		facing = facing.rotated(axis.normalized(), angle).normalized()
	up = next_up
	position = up * orbit_radius
	velocity = (position - previous_position) / maxf(delta, 0.0001)
	_update_basis()

func _update_basis() -> void:
	heading = (heading - up * heading.dot(up)).normalized()
	var right := facing.cross(up)
	if right.length_squared() < 0.000001:
		right = heading.cross(up)
	right = right.normalized()
	basis = Basis(right, right.cross(facing).normalized(), -facing)
