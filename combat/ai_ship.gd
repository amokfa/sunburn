extends "res://ship/ship.gd"
## AI supplies controls; the player ship controller owns all motion and visuals.
@export var spawn_direction := Vector3.UP
@export var spawn_heading := Vector3.FORWARD
@export var cruise_altitude: float = 45.0
@export var velocity_response_seconds: float = 0.6
var up: Vector3:
	get:
		return _local_up
var heading: Vector3:
	get:
		return _local_forward
var facing: Vector3:
	get:
		return -_flight_basis().z
var combat_velocity: Vector3:
	get:
		return _velocity
var previous_position := Vector3.ZERO
var target: Node3D
var target_remaining: float = 0.0
var reload_remaining: float = 0.0
var fire_reaction_remaining: float = -1.0
var think_remaining: float = 0.0
var target_altitude_offset: float = 0.0
var desired_orbit_radius: float = 0.0
var separation_velocity := Vector3.ZERO
var separation_priority: float = 0.0


func maximum_lives() -> int:
	return 4

func _ready() -> void:
	super._ready()
	for exhaust: ThrusterController in _thrusters.values():
		exhaust.light_enabled = false
		exhaust.light.visible = false
	_set_static_exhausts(false)
	set_process(false)


func bind_to_planet(planet_node: Node3D) -> void:
	super.bind_to_planet(planet_node)
	_set_static_exhausts(bound_planet != null)


func _set_static_exhausts(active: bool) -> void:
	for marker_name: StringName in _thrusters:
		var power := 0.0
		if active:
			if marker_name == &"back":
				power = 1.0
			elif String(marker_name).begins_with("down_"):
				power = hover_thrust_power
		var exhaust: ThrusterController = _thrusters[marker_name]
		exhaust.set_static_power(power)


func _update_thrusters(_horizontal: Vector2, _vertical: float, _yaw_torque: float) -> void:
	# AI exhaust is set once on binding; control signals do not animate it.
	pass


func _update_visual_tilt(_delta: float, _horizontal: Vector2) -> void:
	# Keep the model's authored transform; impact rotation lives on the ship itself.
	pass


func _process(_delta: float) -> void:
	# The battle manager advances AI once, after selecting its controls.
	pass


func reset(planet_node: Node3D) -> void:
	reset_health()
	var spawn_up := spawn_direction.normalized()
	var spawn_forward := (spawn_heading - spawn_up * spawn_heading.dot(spawn_up)).normalized()
	position = spawn_up * (_planet_radius(planet_node) + cruise_altitude)
	basis = Basis(spawn_forward.cross(spawn_up), spawn_up, -spawn_forward)
	bind_to_planet(planet_node)
	set_movement_profile(0)
	set_process(false)
	previous_position = position
	target = null
	target_remaining = 0.0
	target_altitude_offset = 0.0
	desired_orbit_radius = position.length()
	separation_velocity = Vector3.ZERO
	separation_priority = 0.0


func fly(delta: float, speed: float, aim: Vector3, movement: Vector3) -> void:
	if bound_planet == null:
		return
	set_view_direction(_planet.global_basis.orthonormalized() * aim)
	var desired_velocity := movement * speed
	var desired_radial := clampf(desired_velocity.dot(up), -speed, speed)
	var desired_tangent := (desired_velocity - up * desired_velocity.dot(up)).limit_length(speed)
	var radial_speed := _velocity.dot(up)
	var tangent_velocity := _velocity - up * radial_speed
	# Velocity feedback plus drag compensation, bounded by real available thrust.
	var response := maxf(velocity_response_seconds, 0.05)
	var acceleration := (
		(desired_tangent - tangent_velocity) / response + tangent_velocity * horizontal_damping
	)
	var body := _flight_basis()
	var radial_acceleration := (
		(desired_radial - radial_speed) / response + radial_speed * vertical_damping
	)
	acceleration += up * radial_acceleration
	var horizontal := (
		Vector2(acceleration.dot(body.x), -acceleration.dot(body.z))
		* mass
		/ maxf(horizontal_thrust_force, 0.001)
	)
	var vertical := acceleration.dot(body.y) * mass / maxf(vertical_thrust_force, 0.001)
	apply_flight_controls(delta, horizontal, vertical)
