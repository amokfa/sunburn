extends Node3D
const Missile = preload("res://combat/missile.tscn")
const Explosion = preload("res://combat/explosion.tscn")
const AIShip = preload("res://combat/ai_ship.gd")
const MissileState = preload("res://combat/missile.gd")
const CollisionGrid = preload("res://combat/ship_collision_grid.gd")
const VelocityHistory = preload("res://combat/velocity_history.gd")
const OrbitalIntercept = preload("res://combat/orbital_intercept.gd")

@export var vision_cone_degrees: float = 60.0
@export var missile_spread_degrees: float = 0.0
@export var firing_range: float = 150.0
@export var minimum_target_distance: float = 25.0
@export var reload_seconds: float = 3.0
@export var fire_reaction_min: float = 0.2
@export var fire_reaction_max: float = 1.2
@export_range(0.0, 1.0) var reload_variation: float = 0.2
@export var target_duration_min: float = 20.0
@export var target_duration_max: float = 30.0
@export var ship_hit_radius: float = 1.0
## Momentum in N·s; velocity change is impulse / ship mass.
@export_range(0.0, 1000000.0, 100.0, "or_greater") var missile_impact_impulse: float = 200000.0
## Angular impulse per metre of perpendicular offset from the target's center.
@export_range(0.0, 1000000.0, 100.0, "or_greater") var missile_torque_impulse: float = 200000.0
@export_group("AI spacing")
@export var target_altitude_spread: float = 20.0
@export var altitude_response_seconds: float = 2.0
@export var altitude_maximum_speed: float = 12.0
@export var separation_distance: float = 12.0
@export var separation_speed: float = 25.0
var planet: Node3D
var player: Node3D
var ships: Array[AIShip] = []
var active: bool = false
var ai_speed: float = 40.0
var missile_speed: float = 100.0
var _player_previous := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _player_position := Vector3.ZERO
var _collision_grid := CollisionGrid.new()
var _ship_indices: Dictionary = {}
var _collision_targets: Array[PlanetShip] = []
var _spacing_grid: Dictionary = {}
var _velocity_histories: Dictionary = {}
@onready var _missiles: Node3D = $Missiles
@onready var _explosions: Node3D = $Explosions

func _ready() -> void:
	for child in $Ships.get_children():
		ships.append(child)
		child.destroyed.connect(_on_ship_destroyed)
	_rng.seed = 73129
	set_process(false)
	visible = false

func configure(planet_node: Node3D, player_ship: Node3D) -> void:
	planet = planet_node
	player = player_ship
	if not player.destroyed.is_connected(_on_ship_destroyed):
		player.destroyed.connect(_on_ship_destroyed)
	var enemy := ships[0] if not ships.is_empty() else null
	var base_speed: float = enemy.horizontal_thrust_force / enemy.mass / maxf(enemy.horizontal_damping, 0.001) if enemy != null else 40.0
	ai_speed = base_speed
	follow_planet()

func follow_planet() -> void:
	if is_instance_valid(planet):
		global_transform = Transform3D(planet.global_basis.orthonormalized(), planet.global_position)

func set_active(value: bool) -> void:
	active = value
	visible = value
	set_process(value)
	$TargetIndicators.visible = value
	$TargetIndicators/Crosshairs.set_process(value)
	_spacing_grid.clear()
	_velocity_histories.clear()
	for container in [_missiles, _explosions]:
		for child in container.get_children():
			child.free()
	if not value:
		for ship in ships:
			ship.bind_to_planet(null)
		return
	follow_planet()
	for index in range(ships.size()):
		var ship = ships[index]
		ship.reset(planet)
		ship.reload_remaining = _rng.randf_range(0.0, reload_seconds)
		ship.fire_reaction_remaining = -1.0
		ship.think_remaining = float(index % 10) * 0.01
	_player_previous = to_local(player.global_position)
	_player_position = _player_previous
	_velocity_histories[player] = VelocityHistory.new()
	for ship in ships:
		_velocity_histories[ship] = VelocityHistory.new()
	_rebuild_spacing_grid()
	# Choose in order so later ships can respond to earlier ships' choices.
	for ship in ships:
		_choose_target(ship)

func _process(delta: float) -> void:
	if not is_instance_valid(planet) or not is_instance_valid(player):
		set_active(false)
		return
	follow_planet()
	# Snapshot all targets before advancing any AI so firing order has no effect.
	var inverse_basis := global_basis.inverse()
	for target in _velocity_histories:
		if not target.can_fight:
			continue
		var up: Vector3 = to_local(target.global_position).normalized()
		var velocity: Vector3 = inverse_basis * target.velocity
		var radial_speed := velocity.dot(up)
		var tangent_speed := (velocity - up * radial_speed).length()
		# Average speed components rather than world headings, which curve over time.
		_velocity_histories[target].add_sample(Vector3(tangent_speed, radial_speed, 0.0), delta)
	delta = minf(delta, 0.1)
	var radius := planet.global_basis.x.length()
	_player_position = to_local(player.global_position)
	var camera := get_viewport().get_camera_3d()
	for ship in ships:
		ship.previous_position = ship.position
	_rebuild_spacing_grid()
	for ship in ships:
		if ship.is_dying:
			ship.step_wreck(delta)
			continue
		if not ship.can_fight:
			continue
		ship.reload_remaining -= delta
		ship.target_remaining -= delta
		if ship.target_remaining <= 0.0 or not is_instance_valid(ship.target) or not ship.target.can_fight:
			_choose_target(ship)
		ship.think_remaining -= delta
		if ship.think_remaining <= 0.0:
			ship.think_remaining += 0.1
			_update_spacing(ship, radius)
		var aim: Vector3 = ship.heading
		var movement: Vector3 = ship.heading
		if is_instance_valid(ship.target):
			aim = _target_position(ship.target) - ship.position
			movement = _movement_for(ship, aim)
		ship.fly(delta, ai_speed, aim, movement)
		var can_fire := false
		if ship.reload_remaining <= 0.0 and is_instance_valid(ship.target):
			var offset: Vector3 = _target_position(ship.target) - ship.position
			var in_camera := ship.target != player or (camera != null and camera.is_position_in_frustum(ship.global_position))
			can_fire = in_camera and offset.length() <= firing_range # and _visible(ship, offset, radius)
		if _ready_to_fire(ship, can_fire, delta):
			_fire(ship, _intercept_direction(ship.position, ship.target))
	_step_missiles(delta)
	_player_previous = _player_position

func _target_position(target: Node3D) -> Vector3:
	return _player_position if target == player else target.position

func _ready_to_fire(ship: AIShip, eligible: bool, delta: float) -> bool:
	if not eligible:
		ship.fire_reaction_remaining = -1.0
		return false
	if ship.fire_reaction_remaining < 0.0:
		ship.fire_reaction_remaining = _rng.randf_range(fire_reaction_min, fire_reaction_max)
		return false
	ship.fire_reaction_remaining -= delta
	return ship.fire_reaction_remaining <= 0.0

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
	ship.fire_reaction_remaining = -1.0
	var candidates: Array[Node3D] = []
	for candidate in ships:
		if candidate != ship and candidate.can_fight:
			candidates.append(candidate)
	if player.bound_planet == planet and player.can_fight:
		candidates.append(player)
	var weights: Array[float] = []
	var total_weight := 0.0
	for candidate in candidates:
		var weight := 10.0 if candidate == player else (3.0 if candidate.get("target") == ship else 1.0)
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
	ship.target_altitude_offset = _rng.randf_range(-target_altitude_spread, target_altitude_spread)
	# Refresh immediately when choosing a new target, then at the normal think rate.
	if is_instance_valid(planet):
		_update_spacing(ship, planet.global_basis.x.length())

func _spacing_cell(point: Vector3) -> Vector3i:
	return Vector3i((point / maxf(separation_distance, 0.001)).floor())

func _rebuild_spacing_grid() -> void:
	_spacing_grid.clear()
	if separation_distance <= 0.0:
		return
	for ship in ships:
		if not ship.can_fight:
			continue
		var cell := _spacing_cell(ship.previous_position)
		if not _spacing_grid.has(cell):
			_spacing_grid[cell] = []
		_spacing_grid[cell].append(ship)

func _update_spacing(ship: AIShip, radius: float) -> void:
	var preferred_radius := radius + ship.cruise_altitude
	if is_instance_valid(ship.target):
		var target_radius := _target_position(ship.target).length()
		# A weak home-altitude preference prevents mutually targeting ships from
		# endlessly climbing/descending together when their offsets have the same sign.
		preferred_radius = lerpf(preferred_radius, target_radius + ship.target_altitude_offset, 0.7)
		var vertical_reach := maxf(0.0, firing_range * 0.5)
		preferred_radius = clampf(preferred_radius, target_radius - vertical_reach, target_radius + vertical_reach)
	var floor_radius := radius + ship.surface_clearance + 5.0
	if is_instance_valid(ship._surface_collider):
		floor_radius = ship._surface_collider.surface_radius(ship.up) + ship.surface_clearance + 5.0
	var ceiling_radius := radius * (1.0 + ship.maximum_altitude_ratio) - 5.0
	ship.desired_orbit_radius = clampf(preferred_radius, floor_radius, maxf(floor_radius, ceiling_radius))
	ship.separation_velocity = Vector3.ZERO
	ship.separation_priority = 0.0
	if separation_distance <= 0.0:
		return
	var cell := _spacing_cell(ship.previous_position)
	var push := Vector3.ZERO
	var pressure := 0.0
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				for other: AIShip in _spacing_grid.get(cell + Vector3i(x, y, z), []):
					if other == ship:
						continue
					var away := ship.previous_position - other.previous_position
					var distance := away.length()
					if distance >= separation_distance:
						continue
					if distance < 0.0001:
						# Give exact overlaps equal and opposite, repeatable escape directions.
						var pair := float(mini(ship.get_index(), other.get_index()) * 173 + maxi(ship.get_index(), other.get_index()) * 31)
						away = Vector3(sin(pair + 1.0), cos(pair + 2.0), sin(pair + 3.0)).normalized()
						away *= -1.0 if ship.get_index() < other.get_index() else 1.0
					var weight := pow(1.0 - distance / separation_distance, 2.0)
					push += away.normalized() * weight
					pressure += weight
	ship.separation_velocity = push.limit_length() * maxf(separation_speed, 0.0)
	ship.separation_priority = clampf(pressure, 0.0, 1.0)

func _movement_for(ship: AIShip, aim: Vector3) -> Vector3:
	var tangent_aim := aim - ship.up * aim.dot(ship.up)
	var tangent_velocity := ship.combat_velocity - ship.up * ship.combat_velocity.dot(ship.up)
	var anticipated_aim := tangent_aim - tangent_velocity * 0.5
	var vertical_gap := absf(ship.desired_orbit_radius - _target_position(ship.target).length())
	var orbit_distance := sqrt(maxf(minimum_target_distance * minimum_target_distance - vertical_gap * vertical_gap, 0.0)) + 10.0
	var closing := clampf((anticipated_aim.length() - orbit_distance) / 10.0, -1.0, 1.0)
	var circling := ship.up.cross(tangent_aim).normalized()
	if circling.length_squared() < 0.0001:
		circling = ship.heading
	var tangent := tangent_aim.normalized() * closing + circling * sqrt(1.0 - closing * closing)
	var climb := clampf((ship.desired_orbit_radius - ship.position.length()) / maxf(altitude_response_seconds, 0.05), -altitude_maximum_speed, altitude_maximum_speed)
	var desired_velocity := tangent * ai_speed + ship.up * climb
	# Nearby-neighbor avoidance takes priority, but remains a bounded thrust request.
	desired_velocity = desired_velocity.lerp(ship.separation_velocity, ship.separation_priority)
	return desired_velocity / maxf(ai_speed, 0.001)

func _intercept_direction(origin: Vector3, target: Node3D) -> Vector3:
	var position := _target_position(target)
	var up := position.normalized()
	var velocity: Vector3 = global_basis.inverse() * target.velocity
	var tangent := (velocity - up * velocity.dot(up)).normalized()
	var speeds: Vector3 = _velocity_histories[target].average()
	# At rest there is no tangent heading; do not invent tangential movement.
	var tangent_speed := speeds.x if tangent.length_squared() > 0.0 else 0.0
	return OrbitalIntercept.direction(origin, position, tangent, tangent_speed, speeds.y, missile_speed, MissileState.LIFETIME_SECONDS)

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
	missile.launch(ship.position + direction * OrbitalIntercept.LAUNCH_OFFSET, direction, missile_speed, ship, ship.up)
	ship.reload_remaining = reload_seconds * _rng.randf_range(1.0 - reload_variation, 1.0 + reload_variation)
	ship.fire_reaction_remaining = -1.0

func _on_ship_destroyed(wreck: PlanetShip) -> void:
	if wreck != player:
		var remaining := 0
		for ship in ships:
			if ship.can_fight:
				remaining += 1
		print("%d ai ships left" % remaining)
	var explosion = Explosion.instantiate()
	explosion.size_multiplier = 3.0
	explosion.initial_scale = 1.0
	explosion.lifetime = 1.2
	_explosions.add_child(explosion)
	explosion.global_position = wreck.global_position

func _step_missiles(delta: float) -> void:
	if _missiles.get_child_count() == 0:
		return
	var previous := PackedVector3Array()
	var current := PackedVector3Array()
	_ship_indices.clear()
	_collision_targets.clear()
	for ship in ships:
		if not ship.can_fight:
			continue
		_ship_indices[ship] = _collision_targets.size()
		_collision_targets.append(ship)
		previous.append(ship.previous_position)
		current.append(ship.position)
	if player.bound_planet == planet and player.can_fight:
		_collision_targets.append(player)
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
			var contact := start.lerp(end, hit_t)
			var impact := frame_transform.basis * missile.velocity.normalized() * missile_impact_impulse
			if hit_index >= 0:
				var target_ship: PlanetShip = _collision_targets[hit_index]
				# Use the moving target's center at impact time, not its end-of-frame position.
				var center := previous[hit_index].lerp(current[hit_index], hit_t)
				var lever := frame_transform.basis * (contact - center)
				var direction := frame_transform.basis * missile.velocity.normalized()
				target_ship.receive_missile_hit(impact, lever.cross(direction) * missile_torque_impulse)
				if target_ship == player:
					print("Player ship hit by missile from %s" % missile.launcher.name)
			var explosion = Explosion.instantiate()
			_explosions.add_child(explosion)
			explosion.position = contact
			missile.free()
			continue
		missile.position = end
		missile.remaining -= delta
		if missile.remaining <= 0.0:
			var explosion = Explosion.instantiate()
			_explosions.add_child(explosion)
			explosion.position = missile.position
			missile.free()
