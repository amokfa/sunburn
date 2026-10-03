extends SceneTree
const AI = preload("res://combat/ai_ship.tscn")
const SHIP = preload("res://ship/ship.tscn")


func _initialize():
	call_deferred("run_checks")


func run_checks():
	var frame := Node3D.new()
	root.add_child(frame)
	frame.position = Vector3(100, 20, -50)
	frame.rotation = Vector3(0.2, 0.3, -0.1)
	var planet := Node3D.new()
	frame.add_child(planet)
	planet.scale = Vector3.ONE * 240.0
	var ai = AI.instantiate()
	frame.add_child(ai)
	ai.reset(planet)
	var player = SHIP.instantiate()
	frame.add_child(player)
	player.global_transform = ai.global_transform
	player.bind_to_planet(planet)
	player.set_process(false)
	assert(ai.velocity.length() == 0.0)
	assert(not ai.is_processing())
	assert(ai.get_node("Model/markers").get_child_count() == 14)
	# Both ships respond identically to identical control signals.
	for step in range(120):
		ai.apply_flight_controls(1.0 / 120.0, Vector2(0.4, 0.7), 0.2)
		player.apply_flight_controls(1.0 / 120.0, Vector2(0.4, 0.7), 0.2)
	assert(ai.global_position.distance_to(player.global_position) < 0.001)
	assert(ai.velocity.distance_to(player.velocity) < 0.0001)
	ai.reset(planet)
	ai.fly(1.0 / 120.0, 40.0, Vector3.RIGHT, Vector3.FORWARD)
	assert(ai.combat_velocity.length() > 0.0 and ai.combat_velocity.length() < 0.5)
	assert(ai.facing.dot(Vector3.RIGHT) < 0.1)
	var old_velocity: Vector3 = ai.combat_velocity
	ai.fly(1.0 / 120.0, 40.0, Vector3.RIGHT, Vector3.BACK)
	assert(ai.combat_velocity.distance_to(old_velocity) < 0.5)
	for step in range(120):
		ai.fly(1.0 / 120.0, 40.0, Vector3.RIGHT, Vector3.RIGHT)
	assert(ai.model.transform == ai._model_rest_transform)
	var active := 0
	for marker_name in ai._thrusters:
		var exhaust = ai._thrusters[marker_name]
		assert(not exhaust.light_enabled and exhaust.light.light_energy == 0.0)
		assert(not exhaust.is_processing())
		var expected: float = (
			1.0
			if marker_name == &"back"
			else (ai.hover_thrust_power if String(marker_name).begins_with("down_") else 0.0)
		)
		assert(is_equal_approx(exhaust.target_power, expected))
		assert(exhaust.visible == (expected > 0.0))
		assert(
			is_equal_approx(exhaust.plume.material_override.get_shader_parameter("power"), expected)
		)
		if exhaust.target_power > 0.0:
			active += 1
	assert(active == 5)
	ai.bind_to_planet(null)
	for exhaust in ai._thrusters.values():
		assert(exhaust.target_power == 0.0)
		assert(not exhaust.visible and not exhaust.is_processing())
	frame.free()
	var game = load("res://scale_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.ship.set_process(false)
	game.battle.set_active(true)
	game.battle.set_process(false)
	for step in range(120):
		game.battle._process(1.0 / 60.0)
	for enemy in game.battle.ships:
		assert(enemy.bound_planet == game.planets[1])
		assert(enemy.position.is_finite() and enemy.velocity.is_finite())
		assert(enemy.velocity.length() > 0.1)
		assert(not enemy.is_processing())
	game.battle.set_active(false)
	for enemy in game.battle.ships:
		assert(enemy.bound_planet == null)
	game.free()
	print(
		"PASS: AI shares player forces, inertia and damped turning; ",
		"static emissive thrusters, fixed model pose, battle integration and unbinding work."
	)
	quit()
