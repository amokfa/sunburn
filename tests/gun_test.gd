extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var prototype = load("res://scale_prototype.tscn").instantiate()
	root.add_child(prototype)
	prototype.set_process(false)
	prototype.ship.set_process(false)
	var ship = prototype.ship
	var gun = ship.gun
	assert(not gun.enabled and not gun.visible)
	assert(not prototype.combat_hud.visible)
	assert(ship.speed_multiplier == 1.0)
	assert(not gun.try_fire())
	for destination in [1, 2]:
		prototype.travel_duration = 0.05
		prototype._travel_to_next_planet()
		assert(not gun.enabled and not prototype.combat_hud.visible)
		assert(not gun.try_fire())
		while prototype.travelling:
			await process_frame
		ship.set_process(false)
		assert(gun.enabled and gun.visible)
		assert(prototype.combat_hud.visible)
		assert(ship.speed_multiplier == 2.0)
		assert(gun.try_fire())
		assert(gun.shots.get_child_count() == 1)
		assert(not gun.try_fire())
		var projectile = gun.shots.get_child(0)
		projectile.set_process(false)
		var origin: Vector3 = projectile.global_position
		var direction: Vector3 = (gun._aim_target - origin).normalized()
		assert(projectile._velocity.normalized().distance_to(direction) < 0.00001)
		assert(absf(projectile._velocity.length() - gun.projectile_speed) < 0.001)
		# The projectile retains its world pose when the ship moves or turns.
		ship.position += Vector3(3, 7, -2)
		assert(projectile.global_position.distance_to(origin) < 0.001)
		ship.position -= Vector3(3, 7, -2)
		projectile._process(0.01)
		assert(projectile.global_position.distance_to(origin + direction * gun.projectile_speed * 0.01) < 0.001)
		gun.clear_shots()
		gun._process(1.0 / gun.rounds_per_second + 0.01)
		assert(gun.try_fire())
		gun.clear_shots()
		ship.set_combat_enabled(true)
		assert(ship.speed_multiplier == 2.0)

	# Same force input produces exactly twice the terminal velocity after unlock.
	prototype._reset()
	var pose: Transform3D = ship.global_transform
	for axis in [Vector2(0, 1), Vector2(1, 0), Vector2.ZERO]:
		ship.bind_to_planet(null)
		ship.global_transform = pose
		ship.bind_to_planet(prototype.planets[0])
		ship.set_process(false)
		ship.set_combat_enabled(false)
		var vertical := 1.0 if axis == Vector2.ZERO else 0.0
		for step in range(600):
			ship._step_thrust(1.0 / 120.0, axis, vertical)
		var normal_speed: float = ship.velocity.length()
		ship.bind_to_planet(null)
		ship.global_transform = pose
		ship.bind_to_planet(prototype.planets[0])
		ship.set_process(false)
		ship.set_combat_enabled(true)
		for step in range(600):
			ship._step_thrust(1.0 / 120.0, axis, vertical)
		assert(absf(ship.velocity.length() - 2.0 * normal_speed) < 0.01)

	prototype._reset()
	ship.set_process(false)
	assert(not gun.enabled and not prototype.combat_hud.visible)
	assert(ship.speed_multiplier == 1.0)
	ship.set_combat_enabled(true)
	gun.aim_at(gun.global_position + ship.forward * 1000.0, ship.radial_up)
	assert(gun.try_fire())
	ship.bind_to_planet(null)
	prototype._update_combat_hud()
	assert(not gun.enabled and gun.shots.get_child_count() == 0)
	assert(not prototype.combat_hud.visible)
	assert(not gun.try_fire())
	prototype.free()
	print("PASS: planet-two unlock, crosshair, aim, tracers, cooldown, double speed on each axis, persistent unlock, cutscene disable, shot cleanup, and reset")
	quit()
