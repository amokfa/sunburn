extends Node3D
const Missile = preload("res://combat/missile.tscn")
const Explosion = preload("res://combat/explosion.tscn")
const AIShip = preload("res://combat/ai_ship.gd")
const MissileState = preload("res://combat/missile.gd")
const CollisionGrid = preload("res://combat/ship_collision_grid.gd")
const SurfaceCollider = preload("res://planets/surface_collider.gd")

@export var vision_cone_degrees: float = 60.0
@export var missile_spread_degrees: float = 2.0
@export var firing_range: float = 55.0
@export var minimum_target_distance: float = 25.0
@export var reload_seconds: float = 5.0
@export var target_duration_min: float = 15.0
@export var target_duration_max: float = 30.0
@export var ai_turn_speed: float = 0.8
@export var dodge_detection_time: float = 1.5
@export var dodge_clearance: float = 8.0
@export var ship_hit_radius: float = 1.0
var planet: Node3D
var player: Node3D
var ships: Array[AIShip] = []
var active: bool = false
var ai_speed: float = 40.0
var missile_speed: float = 80.0
var _player_previous := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _player_position := Vector3.ZERO
var _surface_collider: SurfaceCollider
var _frame_missiles: Array[Node] = []
var _collision_grid := CollisionGrid.new()
var _ship_indices: Dictionary = {}
@onready var _missiles: Node3D = $Missiles
@onready var _explosions: Node3D = $Explosions

func _ready() -> void:
	for child in $Ships.get_children():
		ships.append(child)
	_rng.seed = 73129
	set_process(false)
	visible = false

func configure(planet_node: Node3D, player_ship: Node3D) -> void:
	planet = planet_node
	player = player_ship
	_surface_collider = planet.get_node("SurfaceCollider")
	var base_speed: float = player.horizontal_thrust_force / player.mass / maxf(player.horizontal_damping, 0.001)
	ai_speed = base_speed
	follow_planet()

func follow_planet() -> void:
	if is_instance_valid(planet):
		global_transform = Transform3D(planet.global_basis.orthonormalized(), planet.global_position)

func set_active(value: bool) -> void:
	active = value
	visible = value
	set_process(value)
	_frame_missiles.clear()
	for container in [_missiles, _explosions]:
		for child in container.get_children():
			child.free()
	if not value:
		return
	follow_planet()
	var radius := planet.global_basis.x.length()
	for index in range(ships.size()):
		var ship = ships[index]
		ship.reset(radius)
		ship.velocity = ship.heading * ai_speed
		ship.reload_remaining = _rng.randf_range(0.0, reload_seconds)
		ship.think_remaining = float(index % 10) * 0.01
	# Choose in order so later ships can respond to earlier ships' choices.
	for ship in ships:
		_choose_target(ship)
	_player_previous = to_local(player.global_position)
	_player_position = _player_previous

func _process(delta: float) -> void:
	if not is_instance_valid(planet) or not is_instance_valid(player):
		set_active(false)
		return
	follow_planet()
	delta = minf(delta, 0.1)
	var radius := planet.global_basis.x.length()
	_player_position = to_local(player.global_position)
	_frame_missiles = _missiles.get_children()
	var camera := get_viewport().get_camera_3d()
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
		var movement: Vector3 = ship.heading
		if is_instance_valid(ship.target):
			aim = _target_position(ship.target) - ship.position
			var separation := aim.length() - minimum_target_distance
			var closing := clampf(separation / 10.0, -1.0, 1.0)
			var circling: Vector3 = ship.up.cross(aim).normalized()
			if circling.length_squared() < 0.0001:
				circling = ship.heading
			# Trade closing speed for sideways motion while keeping full speed.
			movement = (aim.normalized() * closing + circling * sqrt(1.0 - closing * closing)).normalized()
		# Nearby targets sweep across the nose faster during a tight orbit.
		var tracking_speed := maxf(ai_turn_speed, ai_speed * 1.5 / maxf(aim.length(), minimum_target_distance))
		ship.fly(delta, radius, ai_speed, tracking_speed, aim, movement)
		ship.altitude = clampf(ship.altitude, _surface_collider.surface_radius(ship.up) + 2.0 - radius, radius * 0.5)
		ship.position = ship.up * (radius + ship.altitude)
		ship.velocity = (ship.position - ship.previous_position) / maxf(delta, 0.0001)
		if ship.reload_remaining <= 0.0 and is_instance_valid(ship.target):
			if ship.target == player and (camera == null or not camera.is_position_in_frustum(ship.global_position)):
				continue
			var offset: Vector3 = _target_position(ship.target) - ship.position
			if offset.length() <= firing_range and _visible(ship, offset, radius):
				var target_velocity: Vector3 = ship.target.velocity
				if ship.target == player:
					target_velocity = global_basis.inverse() * target_velocity
				_fire(ship, _intercept_direction(offset, target_velocity))
	# Correct orbit movement that would cross the minimum-distance boundary,
	# including a target moving toward a circling ship.
	for pass_index in range(2):
		for ship in ships:
			if is_instance_valid(ship.target):
				ship.keep_target_distance(_target_position(ship.target), minimum_target_distance, delta)
	_step_missiles(delta)
	_player_previous = _player_position

func _target_position(target: Node3D) -> Vector3:
	return _player_position if target == player else target.position

func _visible(ship: AIShip, offset: Vector3, radius: float) -> bool:
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

func _choose_target(ship: AIShip) -> void:
	var candidates: Array[Node3D] = []
	candidates.assign(ships)
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

func _check_dodge(ship: AIShip) -> void:
	for missile: MissileState in _frame_missiles:
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

func _intercept_direction(offset: Vector3, target_velocity: Vector3) -> Vector3:
	# Solve |offset + velocity * t| = launch_offset + missile_speed * t.
	# Missiles have world velocity of their own; they do not inherit ship speed.
	var launch_offset := 1.5
	var a := target_velocity.length_squared() - missile_speed * missile_speed
	var b := 2.0 * (offset.dot(target_velocity) - launch_offset * missile_speed)
	var c := offset.length_squared() - launch_offset * launch_offset
	var intercept_time := INF
	if absf(a) < 0.000001:
		if absf(b) > 0.000001:
			var t := -c / b
			if t >= 0.0:
				intercept_time = t
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var root := sqrt(discriminant)
			for t in [(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)]:
				if t >= 0.0:
					intercept_time = minf(intercept_time, t)
	# A faster, receding target may have no reachable intercept.
	if is_inf(intercept_time):
		return offset.normalized()
	return (offset + target_velocity * intercept_time).normalized()

func _fire(ship: AIShip, aim: Vector3) -> void:
	var direction := aim
	if missile_spread_degrees > 0.0:
		var axis := aim.cross(ship.up).normalized()
		if axis.length_squared() < 0.001:
			axis = aim.cross(Vector3.RIGHT).normalized()
		var angle := acos(lerpf(1.0, cos(deg_to_rad(missile_spread_degrees * 0.5)), _rng.randf()))
		direction = aim.rotated(axis, angle).rotated(aim, _rng.randf_range(0.0, TAU)).normalized()
	var missile: MissileState = Missile.instantiate()
	_missiles.add_child(missile)
	_frame_missiles.append(missile)
	missile.launch(ship.position + direction * 1.5, direction, missile_speed, ship, ship.up)
	ship.reload_remaining = reload_seconds

func _step_missiles(delta: float) -> void:
	if _missiles.get_child_count() == 0:
		return
	var previous := PackedVector3Array()
	var current := PackedVector3Array()
	previous.resize(ships.size())
	current.resize(ships.size())
	_ship_indices.clear()
	for index in range(ships.size()):
		var ship := ships[index]
		previous[index] = ship.previous_position
		current[index] = ship.position
		_ship_indices[ship] = index
	if player.bound_planet == planet:
		previous.append(_player_previous)
		current.append(_player_position)
	_collision_grid.rebuild(previous, current, ship_hit_radius)
	var space := get_world_3d().direct_space_state
	var frame_transform := global_transform
	var inverse_transform := frame_transform.affine_inverse()
	for missile: MissileState in _missiles.get_children():
		var start: Vector3 = missile.position
		var end: Vector3 = start + missile.velocity * delta
		var hit_t := _collision_grid.first_hit(start, end, _ship_indices.get(missile.launcher, -1))
		var hit_index := _collision_grid.hit_index
		var query := PhysicsRayQueryParameters3D.create(frame_transform * start, frame_transform * end)
		var ground := space.intersect_ray(query)
		if not ground.is_empty():
			var ground_t := start.distance_to(inverse_transform * ground.position) / maxf(start.distance_to(end), 0.001)
			if ground_t < hit_t:
				hit_t = ground_t
				hit_index = -1
		if hit_t <= 1.0:
			if hit_index == ships.size():
				print("Player ship hit by missile from %s" % missile.launcher.name)
			var explosion = Explosion.instantiate()
			_explosions.add_child(explosion)
			explosion.position = start.lerp(end, hit_t)
			missile.free()
			continue
		missile.position = end
		missile.remaining -= delta
		if missile.remaining <= 0.0:
			missile.free()
