extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var game = load("res://scale_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.ship.set_process(false)
	var battle = game.battle
	var planet: Node3D = game.planets[1]
	planet.rotation.z = 0.3
	battle.follow_planet()
	battle.ships.assign(battle.ships.slice(0, 1))
	game.ship.global_transform = Transform3D(
		planet.global_basis.orthonormalized(), battle.to_global(Vector3(20, 285, 0))
	)
	game.ship.bind_to_planet(planet)
	game.ship.set_process(false)
	battle.set_active(true)
	battle.set_process(false)
	var enemy = battle.ships[0]
	enemy.spawn_direction = Vector3.UP
	enemy.cruise_altitude = 45.0
	enemy.reset(planet)
	battle._player_position = battle.to_local(game.ship.global_position)
	battle._player_previous = battle._player_position
	var missile = battle.Missile.instantiate()
	battle.get_node("Missiles").add_child(missile)
	missile.launch(
		enemy.position - Vector3.RIGHT * 5.0, Vector3.RIGHT, 100.0, game.ship, Vector3.UP
	)
	battle._step_missiles(0.1)
	var kick: Vector3 = battle.global_basis * Vector3.RIGHT * battle.missile_impact_impulse
	assert(enemy.velocity.distance_to(kick / enemy.mass) < 0.001)
	assert(enemy._impact_angular_velocity.length() < 0.001)
	assert(game.ship.velocity.length() == 0.0)
	assert(battle.get_node("Missiles").get_child_count() == 0)
	assert(battle.get_node("Explosions").get_child_count() == 1)
	# Player hits use the same world-space impulse; a heavier ship gets a smaller kick.
	game.ship.mass *= 2.0
	missile = battle.Missile.instantiate()
	battle.get_node("Missiles").add_child(missile)
	missile.launch(
		battle._player_position - Vector3.RIGHT * 5.0 + Vector3.BACK * 0.5,
		Vector3.RIGHT,
		100.0,
		enemy,
		Vector3.UP
	)
	battle._step_missiles(0.1)
	assert(game.ship.velocity.distance_to(kick / game.ship.mass) < 0.001)
	var world_spin: Vector3 = (
		planet.global_basis.orthonormalized()
		* game.ship._navigation_basis()
		* game.ship._impact_angular_velocity
	)
	var expected_spin: Vector3 = (
		battle.global_basis
		* Vector3.UP
		* (0.5 * battle.missile_torque_impulse / game.ship.impact_angular_inertia)
	)
	assert(world_spin.distance_to(expected_spin) < 0.001)
	assert(enemy.velocity.distance_to(kick / enemy.mass) < 0.001)
	assert(battle.get_node("Explosions").get_child_count() == 2)
	# Timeout explosions do not apply a hit impulse.
	var before: Vector3 = enemy.velocity
	var before_spin: Vector3 = enemy._impact_angular_velocity
	missile = battle.Missile.instantiate()
	battle.get_node("Missiles").add_child(missile)
	missile.launch(Vector3(100, 500, 0), Vector3.RIGHT, 100.0, enemy, Vector3.UP)
	missile.remaining = 0.01
	battle._step_missiles(0.1)
	assert(enemy.velocity == before)
	assert(enemy._impact_angular_velocity == before_spin)
	assert(battle.get_node("Explosions").get_child_count() == 3)
	# Let PhysicsServer register the scene's actual planet colliders.
	await physics_frame
	await physics_frame
	var ground_radius: float = planet.get_node("SurfaceCollider").surface_radius(Vector3.UP)
	missile = battle.Missile.instantiate()
	battle.get_node("Missiles").add_child(missile)
	missile.launch(Vector3.UP * (ground_radius + 5.0), Vector3.DOWN, 200.0, enemy, Vector3.FORWARD)
	battle._step_missiles(0.1)
	assert(battle.get_node("Missiles").get_child_count() == 0)
	assert(battle.get_node("Explosions").get_child_count() == 4)
	var ground_flash: Node3D = battle.get_node("Explosions").get_child(3)
	assert(absf(ground_flash.position.length() - ground_radius) < 0.02)
	assert(enemy.velocity == before)
	assert(enemy._impact_angular_velocity == before_spin)
	# Impulses add momentum, which the shared damping subsequently reduces.
	enemy.apply_impulse(kick)
	assert(enemy.velocity.distance_to(kick * 2.0 / enemy.mass) < 0.001)
	var before_speed: float = enemy.velocity.length()
	enemy.apply_flight_controls(0.1, Vector2.ZERO, 0.0)
	assert(enemy.velocity.length() < before_speed)
	assert(enemy._impact_rotation.get_angle() < 0.001)
	for step in range(600):
		enemy.apply_flight_controls(1.0 / 120.0, Vector2.ZERO, 0.0)
	assert(enemy._impact_rotation.get_angle() < 0.001)
	assert(enemy._impact_angular_velocity.length() < 0.001)
	# Hits on opposite sides spin oppositely; use a moving target to verify
	# the lever arm is measured from its center at collision time.
	for side in [-1.0, 1.0]:
		enemy.reset(planet)
		var start_center: Vector3 = enemy.position
		enemy.previous_position = start_center
		enemy.position += Vector3.BACK
		missile = battle.Missile.instantiate()
		battle.get_node("Missiles").add_child(missile)
		# At contact t=0.4, target z=0.4 and missile z=0.4+side*0.6.
		missile.launch(
			start_center + Vector3(-4.8, 0.0, 0.4 + side * 0.6),
			Vector3.RIGHT,
			100.0,
			game.ship,
			Vector3.UP
		)
		battle._step_missiles(0.1)
		world_spin = (
			planet.global_basis.orthonormalized()
			* enemy._navigation_basis()
			* enemy._impact_angular_velocity
		)
		expected_spin = (
			battle.global_basis
			* Vector3.UP
			* (side * 0.6 * battle.missile_torque_impulse / enemy.impact_angular_inertia)
		)
		assert(world_spin.distance_to(expected_spin) < 0.001)
	# Pure pitch, yaw and roll all change the real ship orientation and recover.
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]:
		enemy.reset(planet)
		var original_basis: Basis = enemy.global_basis
		var torque: Vector3 = battle.global_basis * axis * battle.missile_torque_impulse
		enemy.apply_torque_impulse(torque)
		enemy.apply_flight_controls(1.0 / 120.0, Vector2.ZERO, 0.0)
		assert(not enemy.global_basis.is_equal_approx(original_basis))
		for step in range(600):
			enemy.apply_flight_controls(1.0 / 120.0, Vector2.ZERO, 0.0)
		assert(enemy.global_basis.is_equal_approx(original_basis))
		assert(enemy._impact_angular_velocity.length() < 0.001)
	enemy.bind_to_planet(null)
	enemy.apply_impulse(kick)
	enemy.apply_torque_impulse(kick)
	assert(enemy.velocity == Vector3.ZERO)
	assert(enemy._impact_angular_velocity == Vector3.ZERO)
	game.free()
	print("PASS: linear/torque impacts, pitch/yaw/roll recovery, world frame, mass and explosions.")
	quit()
