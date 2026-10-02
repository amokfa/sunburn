extends Node3D
## A scale sandbox. All movement is geometric; there are no physics bodies.

@export_group("Solar system scale")
@export var planet_radii := Vector3(300.0, 240.0, 180.0)
@export var orbit_radii := Vector3(1800.0, 3600.0, 6000.0)
@export var orbit_angles_degrees := Vector3(0.0, 10.0, -10.0)
@export var initial_sun_radius: float = 500.0
@export var sun_scroll_step: float = 100.0

@export_group("Sun lighting")
@export var sunlight_ship_offset: float = 200.0
@export var sunlight_reference_distance: float = 1300.0
@export var sunlight_reference_energy: float = 1.5
@export var sunlight_falloff: float = 1.0
@export var sunlight_max_energy: float = 4.0

@export_group("Flight")
@export var starting_altitude: float = 45.0
@export var flight_speed: float = 100.0
@export var altitude_speed: float = 65.0
@export var turn_speed_degrees: float = 90.0
@export var travel_duration: float = 3.0

@export_group("Camera")
@export var camera_distance: float = 14.0
@export var mouse_sensitivity: float = 0.003

@onready var planets: Array[MeshInstance3D] = [$Planet1, $Planet2, $Planet3]
var solar_positions: Array[Vector3] = []
@onready var sun: MeshInstance3D = $Sun
@onready var ship: Node3D = $Ship
@onready var camera: Camera3D = $Camera
@onready var hud: Label = $HUD/Readout
@onready var sunlight: DirectionalLight3D = $Sunlight
var current_planet: int = 0
var altitude: float
var sun_radius: float
var radial_up := Vector3.UP
var forward := Vector3.FORWARD
var camera_yaw: float = 0.0
var camera_pitch: float = -0.15
var travelling: bool = false
var frame_origin := Vector3.ZERO


func _ready() -> void:
	for index in range(3):
		var angle := deg_to_rad(orbit_angles_degrees[index])
		solar_positions.append(Vector3(cos(angle), 0.0, sin(angle)) * orbit_radii[index])
		planets[index].scale = Vector3.ONE * planet_radii[index]
	_reset()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _reset() -> void:
	current_planet = 0
	altitude = starting_altitude
	sun_radius = maxf(initial_sun_radius, 1.0)
	frame_origin = solar_positions[0]
	_set_frame_origin(frame_origin)
	radial_up = Vector3(-0.8, 0.6, 0.0).normalized()
	# Start looking toward the sun along the local tangent plane.
	forward = (Vector3.LEFT - radial_up * Vector3.LEFT.dot(radial_up)).normalized()
	ship.position = radial_up * (planet_radii[0] + altitude)
	camera_yaw = 0.0
	camera_pitch = -0.15
	_update_ship_basis()
	_update_sun()
	_update_camera()
	_update_sunlight()
	_update_hud()


func _set_frame_origin(origin: Vector3) -> void:
	frame_origin = origin
	for index in range(3):
		planets[index].position = solar_positions[index] - frame_origin
	sun.position = -frame_origin


func _process(delta: float) -> void:
	if not travelling and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_move_ship(delta)
	_update_camera()
	_update_sunlight()
	_update_hud()


func _move_ship(delta: float) -> void:
	var turn := float(Input.is_physical_key_pressed(KEY_A)) - float(Input.is_physical_key_pressed(KEY_D))
	forward = forward.rotated(radial_up, turn * deg_to_rad(turn_speed_degrees) * delta)
	var thrust := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var climb := float(Input.is_physical_key_pressed(KEY_Q)) - float(Input.is_physical_key_pressed(KEY_E))
	altitude = maxf(4.0, altitude + climb * altitude_speed * delta)
	var radius := planet_radii[current_planet] + altitude
	if thrust != 0.0:
		# Rotate the local frame along a great circle, preserving altitude and heading.
		var axis := radial_up.cross(forward).normalized()
		var angle := thrust * flight_speed * delta / radius
		radial_up = radial_up.rotated(axis, angle).normalized()
		forward = forward.rotated(axis, angle).normalized()
	ship.position = radial_up * radius
	_update_ship_basis()


func _update_ship_basis() -> void:
	forward = (forward - radial_up * forward.dot(radial_up)).normalized()
	ship.basis = Basis(forward.cross(radial_up).normalized(), radial_up, -forward)


func _update_camera() -> void:
	var direction := forward.rotated(radial_up, camera_yaw)
	var offset := -direction * cos(camera_pitch) + radial_up * -sin(camera_pitch)
	var target := ship.position + radial_up * 1.5
	camera.position = target + offset * camera_distance
	camera.look_at(target, radial_up)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, -1.4, 1.4)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			sun_radius += sun_scroll_step
			_update_sun()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			sun_radius = maxf(1.0, sun_radius - sun_scroll_step)
			_update_sun()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_P and not travelling:
			if current_planet == 2:
				_reset()
			else:
				_travel_to_next_planet()


func _update_sun() -> void:
	sun.scale = Vector3.ONE * sun_radius
	_update_sunlight()


func _update_sunlight() -> void:
	var sun_to_ship := ship.global_position - sun.global_position
	sunlight.global_position = ship.global_position - sun_to_ship.normalized() * sunlight_ship_offset
	if sun_to_ship.length_squared() > 0.000001:
		# Choose a different up axis when looking parallel to world up.
		var up := Vector3.FORWARD if absf(sun_to_ship.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
		sunlight.look_at(ship.global_position, up)
	var surface_distance := maxf(sun_to_ship.length() - sun_radius, 1.0)
	# Reference energy at reference distance, capped as the sun reaches the ship.
	var energy := sunlight_reference_energy * pow(maxf(sunlight_reference_distance, 1.0) / surface_distance, sunlight_falloff)
	sunlight.light_energy = clampf(energy, 0.0, maxf(sunlight_max_energy, 0.0))


func _travel_to_next_planet() -> void:
	travelling = true
	var destination := current_planet + 1
	var fixed_ship_position := ship.position
	# Move the destination under the stationary ship with its current radial orientation.
	var destination_center := fixed_ship_position - radial_up * (planet_radii[destination] + altitude)
	var target_origin := solar_positions[destination] - destination_center
	var tween := create_tween()
	tween.tween_method(_set_frame_origin, frame_origin, target_origin, maxf(travel_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	# Rebase everything together: destination at zero, no visible camera/ship jump.
	current_planet = destination
	_set_frame_origin(solar_positions[destination])
	ship.position = fixed_ship_position - destination_center
	travelling = false
	_update_camera()
	_update_sunlight()
	_update_hud()


func _update_hud() -> void:
	var state := "Travelling to planet %d" % (current_planet + 2) if travelling else "Planet %d" % (current_planet + 1)
	var surface_gap := orbit_radii[current_planet] - planet_radii[current_planet] - sun_radius
	hud.text = "%s | Altitude: %.0f | Sun radius: %.0f\nPlanet radius: %.0f | Orbit radius: %.0f | Sun-to-surface gap: %.0f\nW/S move | A/D turn | Q/E altitude | Mouse look\nP next planet (on planet 3: reset) | Wheel expand/shrink sun | Esc release mouse" % [state, altitude, sun_radius, planet_radii[current_planet], orbit_radii[current_planet], surface_gap]
