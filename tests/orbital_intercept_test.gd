extends SceneTree
const Intercept = preload("res://combat/orbital_intercept.gd")
const History = preload("res://combat/velocity_history.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func closest_approach(origin: Vector3, aim: Vector3, position: Vector3, tangent: Vector3, speed: float, radial_speed: float) -> float:
	var nearest := INF
	for step in range(1921):
		var time := float(step) / 240.0
		var missile := origin + aim * (Intercept.LAUNCH_OFFSET + 80.0 * time)
		var target := Intercept.predicted_position(position, tangent, speed, radial_speed, time)
		nearest = minf(nearest, missile.distance_to(target))
	return nearest

func run_checks() -> void:
	# This receding target is reachable after eight seconds: aim directly instead.
	var distant_target := Vector3(0, 10000, 0)
	var shooter := distant_target + Vector3.BACK * 100.0
	var future := Intercept.predicted_position(distant_target, Vector3.FORWARD, 70.0, 0.0, 8.0)
	assert(shooter.distance_to(future) > 80.0 * 8.0 + Intercept.LAUNCH_OFFSET)
	future = Intercept.predicted_position(distant_target, Vector3.FORWARD, 70.0, 0.0, 16.0)
	assert(shooter.distance_to(future) < 80.0 * 16.0 + Intercept.LAUNCH_OFFSET)
	var direct := (distant_target - shooter).normalized()
	assert(Intercept.direction(shooter, distant_target, Vector3.FORWARD, 70.0, 0.0, 80.0, 8.0).is_equal_approx(direct))
	assert(Intercept.direction(shooter, distant_target, Vector3.FORWARD, 70.0, 0.0, 80.0, 16.0).is_equal_approx(direct))
	var position := Vector3(0, 285, 0)
	var tangent := Vector3.FORWARD
	for angle in [-0.3, 0.3, 0.1]:
		var origin := position.rotated(Vector3.LEFT, angle)
		for speed in [0.0, 40.0, 60.0]:
			var aim := Intercept.direction(origin, position, tangent, speed, 0.0, 80.0, 8.0)
			assert(closest_approach(origin, aim, position, tangent, speed, 0.0) < 0.4)
	var climbing_origin := Vector3(50, 285, 0)
	var climbing_aim := Intercept.direction(climbing_origin, position, tangent, 60.0, 5.0, 80.0, 8.0)
	assert(closest_approach(climbing_origin, climbing_aim, position, tangent, 60.0, 5.0) < 0.4)
	# Check against the actual boosted player flight integrator, holding W.
	var game = load("res://scale_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var ship = game.ship
	ship.set_process(false)
	var planet: Node3D = game.planets[1]
	ship.global_position = planet.global_position + Vector3.UP * 285.0
	ship.bind_to_planet(planet)
	ship.set_movement_profile(1)
	var history := History.new()
	var delta := 1.0 / 240.0
	for step in range(1440):
		ship.apply_flight_controls(delta, Vector2(0, 1), 0.0)
		var up: Vector3 = (ship.global_position - planet.global_position).normalized()
		var velocity: Vector3 = ship.velocity
		var radial_speed := velocity.dot(up)
		history.add_sample(Vector3((velocity - up * radial_speed).length(), radial_speed, 0), delta)
	position = ship.global_position - planet.global_position
	var velocity: Vector3 = ship.velocity
	tangent = (velocity - position.normalized() * velocity.dot(position.normalized())).normalized()
	var axis := position.normalized().cross(tangent).normalized()
	var origin := position.rotated(axis, -75.0 / position.length())
	var speeds := history.average()
	var aim := Intercept.direction(origin, position, tangent, speeds.x, speeds.y, 80.0, 8.0)
	var missile := origin + aim * Intercept.LAUNCH_OFFSET
	var nearest := INF
	for step in range(1920):
		var before: Vector3 = missile - (ship.global_position - planet.global_position)
		ship.apply_flight_controls(delta, Vector2(0, 1), 0.0)
		missile += aim * 80.0 * delta
		var after: Vector3 = missile - (ship.global_position - planet.global_position)
		var segment := after - before
		var fraction := clampf(-before.dot(segment) / maxf(segment.length_squared(), 0.000001), 0, 1)
		nearest = minf(nearest, (before + segment * fraction).length())
	print("Holding-W boosted player: closest missile approach ", nearest, "m")
	assert(nearest < 1.0)
	game.free()
	print("PASS: stationary, approaching/receding surface flight, climbing and actual holding-W flight intercepts")
	quit()
