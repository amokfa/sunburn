extends Node3D
const Missile = preload("res://combat/missile.tscn")
const Explosion = preload("res://combat/explosion.tscn")

@export var vision_cone_degrees: float = 60.0
@export var missile_spread_degrees: float = 10.0
@export var firing_range: float = 55.0
@export var minimum_target_distance: float = 25.0
@export var reload_seconds: float = 5.0
@export var target_duration_min: float = 150.0
@export var target_duration_max: float = 300.0
@export var ai_turn_speed: float = 0.8
@export var dodge_detection_time: float = 1.5
@export var dodge_clearance: float = 8.0
@export var ship_hit_radius: float = 1.0
var planet: Node3D
var player: Node3D
var ships: Array[Node3D] = []
var active: bool = false
var ai_speed: float = 40.0
var missile_speed: float = 40.0
var _player_previous := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	for child in $Ships.get_children():
		ships.append(child)
	_rng.seed = 73129
	set_process(false)
	visible = false

func configure(planet_node: Node3D, player_ship: Node3D) -> void:
	planet = planet_node
	player = player_ship
	ai_speed = player.horizontal_thrust_force / player.mass / maxf(player.horizontal_damping, 0.001)
	missile_speed = ai_speed * player.upgraded_speed_multiplier * 0.5
	follow_planet()

func follow_planet() -> void:
	if is_instance_valid(planet):
		global_transform = Transform3D(planet.global_basis.orthonormalized(), planet.global_position)

func set_active(value: bool) -> void:
	active = value
	visible = value
	set_process(value)
	for container in [$Missiles, $Explosions]:
		for child in container.get_children():
			child.free()
	if not value:
		return
	follow_planet()
	var radius := planet.global_basis.x.length()
	for index in range(ships.size()):
		var ship = ships[index]
		ship.reset(radius)
		ship.reload_remaining = _rng.randf_range(0.0, reload_seconds)
		ship.think_remaining = float(index % 10) * 0.01
	# Choose in order so later ships can respond to earlier ships' choices.
	for ship in ships:
		_choose_target(ship)
	_player_previous = to_local(player.global_position)

func _process(delta: float) -> void:
	if not is_instance_valid(planet) or not is_instance_valid(player):
		set_active(false)
		return
	follow_planet()
	delta = minf(delta, 0.1)
	var radius := planet.global_basis.x.length()
	for ship in ships:
		ship.previous_position = ship.position
	for ship in ships:
		ship.reload_remaining -= delta
		ship.target_remaining -= delta
		if ship.target_remaining <= 0.0 or not is_instance_valid(ship.target):
			_choose_target(ship)
		ship.think_remaining -= delta
		if ship.think_remaining <= 0.0:
			ship.think_remaining += 0.1
			_check_dodge(ship)
		var aim: Vector3 = ship.heading
		var movement_speed := ai_speed
		var movement_sign := 1.0
		var vertical_speed := 0.0
		if is_instance_valid(ship.target):
			aim = to_local(ship.target.global_position) - ship.position
			var separation := aim.length() - minimum_target_distance
			movement_sign = -1.0 if separation < 0.0 else 1.0
			movement_speed *= clampf(absf(separation) / 10.0, 0.0, 1.0)
			vertical_speed = movement_sign * movement_speed * aim.normalized().dot(ship.up)
		if ship.dodge_remaining > 0.0:
			movement_speed = ai_speed
		ship.fly(delta, radius, movement_speed, ai_turn_speed, aim, movement_sign, vertical_speed)
		var collider = planet.get_node("SurfaceCollider")
		ship.altitude = clampf(ship.altitude, collider.surface_radius(ship.up) + 2.0 - radius, radius * 0.5)
		ship.position = ship.up * (radius + ship.altitude)
		ship.velocity = (ship.position - ship.previous_position) / maxf(delta, 0.0001)
		if ship.reload_remaining <= 0.0 and is_instance_valid(ship.target):
			var offset: Vector3 = to_local(ship.target.global_position) - ship.position
			if offset.length() <= firing_range and _visible(ship, offset, radius):
				_fire(ship, offset.normalized())
	# Correct orbit movement that would cross the minimum-distance boundary,
	# including a target moving toward a ship that has already stopped closing.
	for pass_index in range(2):
		for ship in ships:
			if is_instance_valid(ship.target):
				ship.keep_target_distance(to_local(ship.target.global_position), minimum_target_distance, delta)
	_step_missiles(delta)
	_player_previous = to_local(player.global_position)

func _visible(ship, offset: Vector3, radius: float) -> bool:
	if offset.length_squared() < 0.001:
		return false
	if ship.facing.dot(offset.normalized()) < cos(deg_to_rad(vision_cone_degrees * 0.5)):
		return false
	# The solid planet hides ships on the other side of the horizon.
	var t := clampf(-ship.position.dot(offset) / offset.length_squared(), 0.0, 1.0)
	# Terrain can sit slightly below the nominal radius. Do not hide a nearby
	# surface target merely because its centre is inside that nominal sphere.
	var occluding_radius := minf(radius, (ship.position + offset).length()) - ship_hit_radius
	return (ship.position + offset * t).length() > maxf(occluding_radius, 0.0)

func _choose_target(ship) -> void:
	var candidates: Array[Node3D] = ships.duplicate()
	candidates.erase(ship)
	if player.bound_planet == planet:
		candidates.append(player)
	var weights: Array[float] = []
	var total_weight := 0.0
	for candidate in candidates:
		var weight := 6.0 if candidate == player else (3.0 if candidate.get("target") == ship else 1.0)
		weights.append(weight)
		total_weight += weight
	ship.target = null
	if not candidates.is_empty():
		var roll := _rng.randf() * total_weight
		ship.target = candidates.back()
		for index in range(candidates.size()):
			roll -= weights[index]
			if roll < 0.0:
				ship.target = candidates[index]
				break
	ship.target_remaining = _rng.randf_range(target_duration_min, target_duration_max)

func _check_dodge(ship) -> void:
	for missile in $Missiles.get_children():
		if missile.launcher == ship:
			continue
		var offset: Vector3 = missile.position - ship.position
		if offset.length_squared() < 0.001 or ship.facing.dot(offset.normalized()) < cos(deg_to_rad(vision_cone_degrees * 0.5)):
			continue
		var relative_velocity: Vector3 = missile.velocity - ship.velocity
		var approach_time := -offset.dot(relative_velocity) / maxf(relative_velocity.length_squared(), 0.001)
		if approach_time <= 0.0 or approach_time > dodge_detection_time:
			continue
		if (offset + relative_velocity * approach_time).length() < dodge_clearance:
			var right: Vector3 = ship.heading.cross(ship.up).normalized()
			ship.dodge_direction = right * (-1.0 if offset.dot(right) >= 0.0 else 1.0)
			ship.dodge_remaining = 0.7
			return

func _fire(ship, aim: Vector3) -> void:
	var direction := aim
	if missile_spread_degrees > 0.0:
		var axis := aim.cross(ship.up).normalized()
		if axis.length_squared() < 0.001:
			axis = aim.cross(Vector3.RIGHT).normalized()
		var angle := acos(lerpf(1.0, cos(deg_to_rad(missile_spread_degrees * 0.5)), _rng.randf()))
		direction = aim.rotated(axis, angle).rotated(aim, _rng.randf_range(0.0, TAU)).normalized()
	var missile = Missile.instantiate()
	$Missiles.add_child(missile)
	missile.launch(ship.position + direction * 1.5, direction, missile_speed, ship, ship.up)
	ship.reload_remaining = reload_seconds

func _step_missiles(delta: float) -> void:
	var candidates: Array[Node3D] = ships.duplicate()
	if player.bound_planet == planet:
		candidates.append(player)
	for missile in $Missiles.get_children():
		var start: Vector3 = missile.position
		var end: Vector3 = start + missile.velocity * delta
		var hit_t := INF
		for candidate in candidates:
			if candidate == missile.launcher:
				continue
			var previous: Vector3 = _player_previous if candidate == player else candidate.previous_position
			var current := to_local(candidate.global_position)
			var relative_start := start - previous
			var relative_motion := (end - start) - (current - previous)
			var a := relative_motion.length_squared()
			if relative_start.length_squared() <= ship_hit_radius * ship_hit_radius:
				hit_t = 0.0
			elif a > 0.000001:
				var b := relative_start.dot(relative_motion)
				var c := relative_start.length_squared() - ship_hit_radius * ship_hit_radius
				var discriminant := b * b - a * c
				if discriminant >= 0.0:
					var t := (-b - sqrt(discriminant)) / a
					if t >= 0.0 and t <= 1.0:
						hit_t = minf(hit_t, t)
		var query := PhysicsRayQueryParameters3D.create(to_global(start), to_global(end))
		var ground := get_world_3d().direct_space_state.intersect_ray(query)
		if not ground.is_empty():
			hit_t = minf(hit_t, start.distance_to(to_local(ground.position)) / maxf(start.distance_to(end), 0.001))
		if hit_t <= 1.0:
			var explosion = Explosion.instantiate()
			$Explosions.add_child(explosion)
			explosion.position = start.lerp(end, hit_t)
			missile.free()
			continue
		missile.position = end
		missile.remaining -= delta
		if missile.remaining <= 0.0:
			missile.free()
