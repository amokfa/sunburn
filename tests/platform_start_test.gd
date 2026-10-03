extends SceneTree
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var game = load("res://scale_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.ship.set_process(false)
	var ship = game.ship
	var platform = game.launch_platform
	assert(game.sun_radius == 250)
	assert(platform.global_basis.y.dot((platform.global_position - game.planets[0].global_position).normalized()) > 0.999)
	assert(absf(platform.global_basis.x.length() - 1.0) < 0.001)
	assert(absf(platform.global_position.distance_to(platform.get_parent().global_position) - 2.0) < 0.001)
	assert(platform.contains_ship(ship.global_position, game._platform_clearance))
	assert(ship.is_parked and not ship.surface_repulsion_enabled)
	assert(absf(ship.forward.dot(ship.view_forward) - cos(deg_to_rad(45.0))) < 0.001)
	assert(game.camera.to_local(ship.global_position).x * game.camera.to_local(game.sun.global_position).x < 0.0)
	var initial: Transform3D = ship.global_transform
	var view: Vector3 = ship.view_forward
	var camera_initial: Transform3D = game.camera.global_transform
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(100.0, -30.0)
	ship.rotate_view(0.5)
	game._unhandled_input(mouse)
	game._process(0.25)
	ship._move(0.5)
	assert(ship.global_transform.is_equal_approx(initial))
	assert(ship.view_forward.is_equal_approx(view))
	assert(game.camera.global_transform.is_equal_approx(camera_initial))
	assert(ship.is_parked)
	var parked_model: Transform3D = ship.model.transform
	ship._update_visual_tilt(1.0, Vector2.ONE)
	assert(ship.model.transform.is_equal_approx(parked_model))
	for exhaust in ship._thrusters.values():
		assert(not exhaust.visible and exhaust.target_power == 0.0)
	game._update_platform_departure(5.0)
	assert(not ship.surface_repulsion_enabled)
	var press := InputEventKey.new()
	press.physical_keycode = KEY_Q
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	ship._move(0.05)
	var release := InputEventKey.new()
	release.physical_keycode = KEY_Q
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	assert(not ship.is_parked)
	assert(ship._thrusters[&"down_front_left"].target_power > 0.0)
	# Takeoff starts the timer even before the ship clears the deck.
	game._update_platform_departure(0.1)
	assert(not ship.surface_repulsion_enabled)
	game._update_platform_departure(2.9)
	assert(not ship.surface_repulsion_enabled)
	ship.global_position = initial.origin
	game._update_platform_departure(0.11)
	assert(ship.surface_repulsion_enabled)
	game._reset()
	assert(ship.is_parked and not ship.surface_repulsion_enabled)
	game._travel_to_next_planet()
	assert(ship.surface_repulsion_enabled and not ship.is_parked)
	while game.travelling:
		await process_frame
	assert(ship.surface_repulsion_enabled and ship.bound_planet == game.planets[1])
	game.free()
	print("PASS: raised upright platform, ship spawn, half sun, parked mouse/exhaust lock, takeoff, three-second repulsion delay, reset and travel")
	quit()
