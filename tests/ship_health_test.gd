extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func kill_ship(ship: PlanetShip) -> void:
	var lives := ship.maximum_lives()
	assert(ship.lives_remaining == lives)
	for hit in range(lives - 1):
		ship.receive_missile_hit(Vector3.ZERO, Vector3.ZERO)
		assert(ship.lives_remaining == lives - 1 - hit)
		assert(ship.can_fight and not ship.is_dying)
	ship.receive_missile_hit(Vector3(200000, 0, 0), Vector3(0, 30000, 10000))
	assert(ship.lives_remaining == 0 and ship.is_dying and not ship.can_fight)
	assert(ship._wreck_spin.length() > 0.0)
	for exhaust in ship._thrusters.values():
		assert(exhaust.target_power == 0.0 and not exhaust.visible)
	var initial: Transform3D = ship.global_transform
	var momentum: Vector3 = ship.velocity
	var spin: Vector3 = ship._wreck_spin
	ship.apply_flight_controls(0.1, Vector2.ONE, 1.0)
	assert(ship.global_transform.is_equal_approx(initial))
	ship.receive_missile_hit(Vector3.ONE * 1000000, Vector3.ONE * 1000000)
	assert(ship.velocity == momentum and ship._wreck_spin == spin)
	ship.step_wreck(0.5)
	assert(ship.global_position.distance_to(initial.origin + momentum * 0.5) < 0.001)
	assert(not ship.global_basis.is_equal_approx(initial.basis))
	assert(ship._wreck_spin == spin and ship.velocity == momentum)
	ship.step_wreck(1.49)
	assert(ship.is_dying and ship.visible)
	ship.step_wreck(0.01)
	assert(ship.is_destroyed and not ship.visible and not ship.is_dying)

func run_checks() -> void:
	var game = load("res://scale_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.ship.set_process(false)
	var battle = game.battle
	battle.ships.assign(battle.ships.slice(0, 2))
	var planet: Node3D = game.planets[1]
	game.ship.global_position = planet.global_position + Vector3.UP * 285
	game.ship.bind_to_planet(planet)
	game.ship.set_process(false)
	battle.set_active(true)
	battle.set_process(false)
	var enemy = battle.ships[0]
	var survivor = battle.ships[1]
	kill_ship(enemy)
	assert(battle.get_node("Explosions").get_child_count() == 1)
	var flash = battle.get_node("Explosions").get_child(0)
	assert(flash.size_multiplier == 3 and flash.initial_scale == 1)
	assert(flash.global_position.distance_to(enemy.global_position) < 0.001)
	battle._choose_target(survivor)
	assert(survivor.target == game.ship)
	battle._rebuild_spacing_grid()
	for bucket in battle._spacing_grid.values():
		assert(not bucket.has(enemy))
	kill_ship(game.ship)
	assert(battle.get_node("Explosions").get_child_count() == 2)
	battle._choose_target(survivor)
	assert(survivor.target == null)
	# AI wreck timers are advanced by the battle even though AI node processing is off.
	enemy.reset(planet)
	for hit in range(3):
		enemy.receive_missile_hit(Vector3.RIGHT * 1000, Vector3.UP * 1000)
	for step in range(20):
		battle._process(0.1)
	assert(enemy.is_destroyed)
	game._reset()
	assert(game.ship.lives_remaining == 5 and game.ship.visible and game.ship.can_fight)
	battle.set_active(true)
	assert(enemy.lives_remaining == 3 and enemy.visible and enemy.can_fight)
	game.free()
	print("PASS: five player lives, three AI lives, lethal impulses, disabled controls/thrusters/stabilization, two-second ballistic tumble, large explosion, target exclusion, AI timer and reset")
	quit()
