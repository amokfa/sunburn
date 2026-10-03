extends SceneTree

const SHIP = preload("res://ship/ship.tscn")

func _initialize() -> void:
	call_deferred("run_checks")

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func force_and_torque(ship: Node3D) -> Array[Vector3]:
	var force := Vector3.ZERO
	var torque := Vector3.ZERO
	for marker in ship.get_node("Model/markers").get_children():
		var exhaust = marker.get_node("Exhaust")
		var reaction: Vector3 = -exhaust.global_basis.y.normalized() * exhaust.target_power
		force += reaction
		torque += (marker.global_position - ship.global_position).cross(reaction)
	return [force, torque]

func run_checks() -> void:
	var planet := Node3D.new()
	root.add_child(planet)
	planet.scale = Vector3.ONE * 300.0
	var ship = SHIP.instantiate()
	root.add_child(ship)
	ship.wobble_degrees = 0.0
	ship.wobble_distance = 0.0
	ship.pitch_tilt_degrees = 0.0
	ship.roll_tilt_degrees = 0.0
	ship.position = Vector3(0, 345, 0)
	ship.bind_to_planet(planet)
	ship.set_process(false)
	var placed: Transform3D = ship.global_transform
	var markers := ship.get_node("Model/markers")
	assert(markers.get_child_count() == 14)
	var materials := {}
	for marker in markers.get_children():
		var exhaust = marker.get_node("Exhaust")
		var size := 2.0 if marker.name in [&"front", &"back"] else 1.0
		assert(is_equal_approx(exhaust.basis.y.length(), size))
		var material_id: int = exhaust.plume.material_override.get_instance_id()
		assert(not materials.has(material_id))
		materials[material_id] = true
		assert(is_equal_approx(exhaust.target_power, ship.hover_thrust_power if String(marker.name).begins_with("down_") else 0.0))
		assert(exhaust.light.light_energy == 0.0)
		assert(exhaust.light.position.y > 0.0)
		exhaust._process(0.5)
		assert(is_equal_approx(exhaust.light.light_energy, 2.0 * exhaust.plume.material_override.get_shader_parameter("power")))
		assert(exhaust.light.light_energy > 0.0 if String(marker.name).begins_with("down_") else exhaust.light.light_energy == 0.0)
	var idle_force := force_and_torque(ship)[0]
	# Check actual exhaust geometry produces the requested translation.
	for control in [[KEY_W, Vector3.FORWARD], [KEY_S, Vector3.BACK], [KEY_A, Vector3.LEFT], [KEY_D, Vector3.RIGHT], [KEY_Q, Vector3.UP], [KEY_E, Vector3.DOWN]]:
		ship.global_transform = placed
		ship.bind_to_planet(planet)
		ship.set_process(false)
		key(control[0], true)
		ship._move(1.0 / 120.0)
		key(control[0], false)
		if control[0] == KEY_E:
			for marker in markers.get_children():
				if String(marker.name).begins_with("down_"):
					assert(marker.get_node("Exhaust").target_power == 0.0)
		var added_force := force_and_torque(ship)[0] - idle_force
		assert(added_force.normalized().dot(control[1]) > 0.999)
	# Downward input also suppresses bottom exhaust used by stabilization.
	ship._last_stabilization_torque = Vector3(1000.0, 0.0, 1000.0)
	ship._update_thrusters(Vector2.ZERO, -1.0, 0.0)
	for marker in markers.get_children():
		if String(marker.name).begins_with("down_"):
			assert(marker.get_node("Exhaust").target_power == 0.0)
	ship._last_stabilization_torque = Vector3.ZERO
	# Turning and braking must use opposite physical torque, without side force.
	for turn in [-0.5, 0.5]:
		ship.global_transform = placed
		ship.bind_to_planet(planet)
		ship.set_process(false)
		ship.rotate_view(turn)
		ship._move(1.0 / 120.0)
		var result := force_and_torque(ship)
		assert(result[1].dot(ship.radial_up) * turn > 0.0)
		assert((result[0] - idle_force).length() < 0.001)
		ship.set_view_direction(ship.forward)
		ship._move(1.0 / 120.0)
		result = force_and_torque(ship)
		assert(result[1].dot(ship.radial_up) * turn < 0.0)
	ship.bind_to_planet(null)
	for marker in markers.get_children():
		var exhaust = marker.get_node("Exhaust")
		assert(exhaust.target_power == 0.0)
		exhaust._process(1.0)
		assert(not exhaust.visible)
		assert(exhaust.light.light_energy < 0.0001)
	ship.free()
	planet.free()
	print("Thruster checks passed: translation, physical yaw/braking torque, size, hover, independent materials and unbinding.")
	quit()
