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
	# Headless cannot capture the mouse; step flight directly with real key events.
	ship.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var old_up: Vector3 = ship.radial_up
	key(KEY_W, true)
	ship._move(0.25)
	assert(ship.velocity.dot(ship.forward) > 0.0)
	var first_speed: float = ship.velocity.length()
	ship._move(0.25)
	key(KEY_W, false)
	assert(ship.velocity.length() > first_speed)
	assert(absf(ship.global_position.distance_to(planet.global_position) - 345.0) < 0.001)
	assert(old_up.dot(ship.radial_up) < 0.99999)
	var before_coast: Vector3 = ship.global_position
	var before_speed: float = ship.velocity.length()
	ship._move(0.25)
	assert(ship.global_position.distance_to(before_coast) > 0.1)
	assert(ship.velocity.length() < before_speed)
	assert(absf(ship.forward.dot(ship.radial_up)) < 0.00001)

	# A/D are sideways thrust, and do not turn the ship.
	ship.global_transform = placed
	ship.bind_to_planet(planet)
	ship.set_process(false)
	key(KEY_A, true)
	ship._move(0.25)
	key(KEY_A, false)
	assert(ship.velocity.dot(ship.global_basis.x) < -1.0)
	assert(absf(ship.yaw_velocity) < 0.00001)
	key(KEY_D, true)
	for step in range(60):
		ship._move(1.0 / 60.0)
	key(KEY_D, false)
	assert(ship.velocity.dot(ship.global_basis.x) > 1.0)
	key(KEY_Q, true)
	ship._move(0.25)
	key(KEY_Q, false)
	assert(ship.altitude > 45.0 and ship.velocity.dot(ship.radial_up) > 1.0)
	key(KEY_E, true)
	for step in range(300):
		ship._move(1.0 / 60.0)
	key(KEY_E, false)
	# An uncollided mock planet has no artificial altitude floor.
	assert(ship.altitude < 0.0)
	assert(ship.velocity.dot(ship.radial_up) < -1.0)

	# View heading stays still while torque gradually aligns the ship with it.
	ship.global_transform = placed
	ship.bind_to_planet(planet)
	ship.set_process(false)
	ship.rotate_view(PI * 0.5)
	var desired_view: Vector3 = ship.view_forward
	var before_turn: Vector3 = ship.forward
	ship._move(1.0 / 120.0)
	assert(ship.forward.distance_to(before_turn) > 0.0001)
	assert(ship.forward.dot(desired_view) < 0.1)
	for step in range(480):
		ship._move(1.0 / 60.0)
	assert(ship.view_forward.distance_to(desired_view) < 0.00001)
	assert(ship.forward.dot(desired_view) > 0.99999)
	assert(absf(ship.yaw_velocity) < 0.001)
	assert(ship.global_position.distance_to(placed.origin) < 0.001)
	ship.rotate_view(PI)
	for step in range(480):
		ship._move(1.0 / 60.0)
	assert(ship.forward.dot(ship.view_forward) > 0.99999)

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
	var rebound_pose: Transform3D = ship.global_transform
	ship.bind_to_planet(planet)
	assert(ship.bound_planet == planet and ship.is_processing())
	assert(ship.radial_up.dot((ship.global_position - planet.global_position).normalized()) > 0.99999)
	assert(ship.global_position.distance_to(rebound_pose.origin) < 0.001)
	planet.free()
	ship._process(0.0)
	assert(ship.bound_planet == null and not ship.is_processing())
	world.free()

	# Existing transitions use the same unbind/rebind contract.
	var prototype = load("res://scale_prototype.tscn").instantiate()
	root.add_child(prototype)
	assert(prototype.ship.bound_planet == prototype.planets[0])
	assert(prototype.ship.horizontal_thrust_force == 32000.0)
	prototype.ship.set_process(false)
	var parked_heading: Vector3 = prototype.ship.forward
	prototype.ship.rotate_view(0.8)
	prototype._update_camera()
	var camera_basis: Basis = prototype.camera.global_basis
	for step in range(480):
		prototype.ship._move(1.0 / 60.0)
		prototype._update_camera()
		assert(prototype.camera.global_basis.is_equal_approx(camera_basis))
	assert(prototype.ship.forward.is_equal_approx(parked_heading))
	for destination in [1, 2]:
		prototype.travel_duration = 0.05
		var departure_altitude: float = prototype.ship.altitude
		var initial_ship: Transform3D = prototype.ship.transform
		prototype._travel_to_next_planet()
		assert(prototype.ship.bound_planet == null and not prototype.ship.is_processing())
		prototype._unhandled_input(_mouse_motion())
		var cutscene_view: Vector3 = prototype.ship.view_forward
		prototype.ship.rotate_view(0.2)
		assert(prototype.ship.view_forward.is_equal_approx(cutscene_view))
		while prototype.travelling:
			assert(prototype.ship.transform.is_equal_approx(initial_ship))
			await process_frame
		assert(prototype.ship.bound_planet == prototype.planets[destination])
		assert(prototype.planets[destination].position.is_zero_approx())
		assert(absf(prototype.ship.altitude - departure_altitude) < 0.001)
	prototype._reset()
	assert(prototype.ship.bound_planet == prototype.planets[0])
	prototype.free()
	print("PASS: force-based thrust, strafing, vertical momentum, damping, stable view heading, damped yaw torque, binding, cutscenes, transitions, and reset")
	quit()


func _mouse_motion() -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = Vector2(100, 50)
	return event
