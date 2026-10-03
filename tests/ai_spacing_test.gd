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
	game.ship.global_transform = Transform3D(
		Basis.IDENTITY, planet.global_position + Vector3.UP * 285.0
	)
	game.ship.bind_to_planet(planet)
	game.ship.set_process(false)
	battle.ships.assign(battle.ships.slice(0, 12))
	battle.set_active(true)
	battle.set_process(false)
	game.camera.global_position = game.ship.global_position + Vector3.UP * 100.0
	game.camera.look_at(game.ship.global_position, Vector3.FORWARD)
	var assigned_offsets: Array[float] = []
	for enemy in battle.ships:
		assert(absf(enemy.target_altitude_offset) <= battle.target_altitude_spread)
		assigned_offsets.append(enemy.target_altitude_offset)
	assert(assigned_offsets.max() - assigned_offsets.min() > 10.0)
	# Nearby ships above/below one another request opposite vertical thrust.
	var first = battle.ships[0]
	var second = battle.ships[1]
	first.previous_position = Vector3(0.0, 280.0, 0.0)
	second.previous_position = Vector3(0.0, 284.0, 0.0)
	for index in range(2, battle.ships.size()):
		battle.ships[index].previous_position = Vector3(1000.0 + index * 20.0, 280.0, 0.0)
	battle._rebuild_spacing_grid()
	battle._update_spacing(first, 240.0)
	battle._update_spacing(second, 240.0)
	assert(first.separation_velocity.y < 0.0 and second.separation_velocity.y > 0.0)
	assert(first.separation_priority > 0.0 and second.separation_priority > 0.0)
	# Exact overlaps must also produce opposite escape requests.
	second.previous_position = first.previous_position
	battle._rebuild_spacing_grid()
	battle._update_spacing(first, 240.0)
	battle._update_spacing(second, 240.0)
	assert(first.separation_velocity.dot(second.separation_velocity) < 0.0)
	# Terrain and ceiling constrain preferences, without changing ship position.
	first.target = game.ship
	var before: Vector3 = first.position
	first.target_altitude_offset = -10000.0
	battle._update_spacing(first, 240.0)
	assert(first.desired_orbit_radius >= first._surface_collider.surface_radius(first.up))
	first.target_altitude_offset = 10000.0
	battle._update_spacing(first, 240.0)
	assert(first.desired_orbit_radius <= 240.0 * (1.0 + first.maximum_altitude_ratio))
	assert(first.position == before)
	# Start a tight same-altitude cluster around a stationary target.
	for index in range(battle.ships.size()):
		var enemy = battle.ships[index]
		enemy.spawn_direction = (
			Vector3(float(index % 4 - 2) * 0.01, 1.0, float(index / 4 - 1) * 0.01).normalized()
		)
		enemy.cruise_altitude = 45.0
		enemy.reset(planet)
		enemy.target = game.ship
		enemy.target_remaining = 1000.0
		enemy.target_altitude_offset = -20.0 if index % 2 == 0 else 20.0
		enemy.think_remaining = 0.0
	var initial_gap: float = battle.ships[0].position.distance_to(battle.ships[1].position)
	var peak_missiles := 0
	for step in range(2400):
		battle._process(1.0 / 60.0)
		peak_missiles = maxi(peak_missiles, battle.get_node("Missiles").get_child_count())
	var low := INF
	var high := -INF
	for index in range(battle.ships.size()):
		var enemy = battle.ships[index]
		low = minf(low, enemy.altitude)
		high = maxf(high, enemy.altitude)
		assert(enemy.position.is_finite() and enemy.velocity.is_finite())
		assert(is_equal_approx(enemy.target_altitude_offset, -20.0 if index % 2 == 0 else 20.0))
	var final_gap: float = battle.ships[0].position.distance_to(battle.ships[1].position)
	print(
		"Spacing: altitude span=",
		high - low,
		"m, neighbor gap=",
		initial_gap,
		" -> ",
		final_gap,
		"m, peak missiles=",
		peak_missiles
	)
	assert(high - low > 10.0)
	assert(final_gap > initial_gap)
	assert(peak_missiles > 0)
	battle.set_active(false)
	assert(battle._spacing_grid.is_empty())
	game.free()
	print(
		"PASS: persistent height offsets, 3D separation, exact overlaps, terrain/ceiling bounds and sustained combat."
	)
	quit()
