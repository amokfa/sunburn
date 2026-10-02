extends SceneTree
## Run: godot --headless --path . --script tests/ship_test.gd
const SHIP = preload("res://ship/ship.tscn")


func _initialize() -> void:
	call_deferred("run_checks")


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func run_checks() -> void:
	var world := Node3D.new()
	root.add_child(world)
	world.position = Vector3(27, -9, 13)
	world.rotation.z = 0.4
	var planet := Node3D.new()
	world.add_child(planet)
	planet.position = Vector3(90, 10, -40)
	planet.rotation = Vector3(0.2, 0.3, 0.4)
	planet.scale = Vector3.ONE * 300.0
	planet.set_meta("maximum_surface_radius", 1.06)
	var ship = SHIP.instantiate()
	world.add_child(ship)
	assert(ship.bound_planet == null and not ship.is_processing())
	var up := Vector3(-0.8, 0.6, 0.0)
	var forward := Vector3(-0.6, -0.8, 0.0)
	var frame := Basis(forward.cross(up), up, -forward)
	ship.global_transform = Transform3D(planet.global_basis.orthonormalized() * frame, planet.to_global(up * 1.15))
	var placed: Transform3D = ship.global_transform
	ship.bind_to_planet(planet)
	assert(ship.bound_planet == planet and ship.is_processing())
	assert(ship.global_position.distance_to(placed.origin) < 0.001)
	assert(absf(ship.altitude - 45.0) < 0.001)
	assert(absf(ship.minimum_altitude_for_planet(planet) - 22.0) < 0.001)
	# Headless cannot capture the mouse; step flight directly with real key events.
	ship.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var old_up: Vector3 = ship.radial_up
	key(KEY_W, true)
	ship._move(0.25)
	key(KEY_W, false)
	assert(absf(ship.global_position.distance_to(planet.global_position) - 345.0) < 0.001)
	assert(absf(old_up.dot(ship.radial_up) - cos(ship.flight_speed * 0.25 / 345.0)) < 0.00001)
	assert(absf(ship.forward.dot(ship.radial_up)) < 0.00001)
	key(KEY_Q, true)
	ship._move(0.25)
	key(KEY_Q, false)
	assert(absf(ship.altitude - 61.25) < 0.001)
	key(KEY_E, true)
	ship._move(10.0)
	key(KEY_E, false)
	assert(absf(ship.altitude - 22.0) < 0.001)
	var old_forward: Vector3 = ship.forward
	key(KEY_A, true)
	ship._move(0.25)
	key(KEY_A, false)
	assert(ship.forward.distance_to(old_forward.rotated(ship.radial_up, deg_to_rad(ship.turn_speed_degrees) * 0.25)) < 0.00001)

	# Binding follows the planet's frame, even while input is paused.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var relative: Transform3D = planet.global_transform.affine_inverse() * ship.global_transform
	planet.position += Vector3(17, -23, 41)
	planet.rotation.y += 0.6
	ship._process(0.0)
	assert((planet.global_transform.affine_inverse() * ship.global_transform).is_equal_approx(relative))
	ship.set_process(true)
	var before_unbind: Transform3D = ship.global_transform
	ship.bind_to_planet(null)
	assert(not ship.is_processing() and ship.bound_planet == null)
	assert(ship.global_transform.is_equal_approx(before_unbind))

	# Held flight keys cannot overwrite an owner-authored cutscene tween.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	key(KEY_W, true)
	key(KEY_A, true)
	key(KEY_Q, true)
	var cutscene := Transform3D(Basis.from_euler(Vector3(0.7, -0.9, 0.2)), Vector3(-110, 42, 60))
	var tween := ship.create_tween()
	tween.tween_property(ship, "global_transform", cutscene, 0.05)
	await tween.finished
	ship._process(1.0)
	assert(ship.global_transform.is_equal_approx(cutscene))
	key(KEY_W, false)
	key(KEY_A, false)
	key(KEY_Q, false)
	ship.bind_to_planet(planet)
	assert(ship.bound_planet == planet and ship.is_processing())
	assert(ship.radial_up.dot((ship.global_position - planet.global_position).normalized()) > 0.99999)
	assert(ship.altitude >= ship.minimum_altitude_for_planet(planet) - 0.001)
	planet.free()
	ship._process(0.0)
	assert(ship.bound_planet == null and not ship.is_processing())
	world.free()

	# Existing transitions use the same unbind/rebind contract.
	var prototype = load("res://scale_prototype.tscn").instantiate()
	root.add_child(prototype)
	assert(prototype.ship.bound_planet == prototype.planets[0])
	assert(prototype.ship.flight_speed == 40.0)
	for destination in [1, 2]:
		prototype.travel_duration = 0.05
		var initial_ship: Transform3D = prototype.ship.transform
		prototype._travel_to_next_planet()
		assert(prototype.ship.bound_planet == null and not prototype.ship.is_processing())
		prototype._unhandled_input(_mouse_motion())
		assert(prototype.camera_yaw == 0.0)
		while prototype.travelling:
			assert(prototype.ship.transform.is_equal_approx(initial_ship))
			await process_frame
		assert(prototype.ship.bound_planet == prototype.planets[destination])
		assert(prototype.planets[destination].position.is_zero_approx())
		assert(absf(prototype.ship.altitude - 45.0) < 0.001)
	prototype._reset()
	assert(prototype.ship.bound_planet == prototype.planets[0])
	prototype.free()
	print("PASS: binding, spherical flight, altitude floor, moving/rotating planets, unbound cutscene ownership, freed planet, transfers, and reset")
	quit()


func _mouse_motion() -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(100, 50)
	return event
