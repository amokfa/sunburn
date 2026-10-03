extends Node3D
## Ship movement uses forces and radial geometry; planets have static mesh colliders.
const ShipController = preload("res://ship/ship.gd")

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

@export_group("Planet travel")
@export var starting_altitude: float = 45.0
@export var travel_duration: float = 3.0

@export_group("Camera")
@export var camera_distance: float = 5.5
@export var mouse_sensitivity: float = 0.003

@onready var planets: Array[Node3D] = [$Planet1, $Planet2, $Planet3]
var solar_positions: Array[Vector3] = []
@onready var sun: MeshInstance3D = $Sun
@onready var ship: ShipController = $Ship
@onready var camera: Camera3D = $Camera
@onready var sunlight: DirectionalLight3D = $Sunlight
@onready var battle = $Battlefield
var current_planet: int = 0
var sun_radius: float
var camera_pitch: float = -0.15
var travelling: bool = false
var frame_origin := Vector3.ZERO


func _ready() -> void:
	for index in range(3):
		var angle := deg_to_rad(orbit_angles_degrees[index])
		solar_positions.append(Vector3(cos(angle), 0.0, sin(angle)) * orbit_radii[index])
		planets[index].scale = Vector3.ONE * planet_radii[index]
	battle.configure(planets[1], ship)
	_reset()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_occluders() -> void:
	for index in range(planets.size()):
		planets[index].get_node("CoreOccluder").visible = not travelling and index == current_planet


func _reset() -> void:
	battle.set_active(false)
	ship.reset_health()
	ship.set_agility_boost(false)
	ship.bind_to_planet(null)
	current_planet = 0
	_update_occluders()
	var altitude := starting_altitude
	sun_radius = maxf(initial_sun_radius, 1.0)
	frame_origin = solar_positions[0]
	_set_frame_origin(frame_origin)
	var radial_up := Vector3(-0.8, 0.6, 0.0).normalized()
	# Start looking toward the sun along the local tangent plane.
	var forward := (Vector3.LEFT - radial_up * Vector3.LEFT.dot(radial_up)).normalized()
	ship.position = radial_up * (planet_radii[0] + altitude)
	ship.basis = Basis(forward.cross(radial_up).normalized(), radial_up, -forward)
	ship.bind_to_planet(planets[0])
	camera_pitch = -0.15
	_update_sun()
	_update_camera()
	_update_sunlight()


func _set_frame_origin(origin: Vector3) -> void:
	frame_origin = origin
	for index in range(3):
		planets[index].position = solar_positions[index] - frame_origin
	sun.position = -frame_origin
	battle.follow_planet()


func _process(_delta: float) -> void:
	_update_camera()
	_update_sunlight()
	_update_ocean_sun()


func _update_ocean_sun() -> void:
	var ocean := planets[0].get_node_or_null("Ocean") as MeshInstance3D
	if ocean == null or not ocean.material_override is ShaderMaterial:
		return
	var material := ocean.material_override as ShaderMaterial
	material.set_shader_parameter("sun_position", sun.global_position)
	material.set_shader_parameter("sun_radius", sun_radius)
	var glow_shell := sun.get_node("GlowShell") as MeshInstance3D
	material.set_shader_parameter("sun_halo_radius", glow_shell.global_basis.x.length())
	var halo_material := glow_shell.material_override as ShaderMaterial
	if halo_material != null:
		material.set_shader_parameter("sun_halo_color", halo_material.get_shader_parameter("glow_color"))


func _update_camera() -> void:
	var radial_up := ship.radial_up
	var direction := ship.view_forward
	var offset := -direction * cos(camera_pitch) + radial_up * -sin(camera_pitch)
	var target := ship.global_position + radial_up * 1.5
	camera.global_position = target + offset * camera_distance
	camera.look_at(target, radial_up)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and ship.bound_planet != null:
		ship.rotate_view(-event.relative.x * mouse_sensitivity)
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
			if ship.is_dying:
				return
			if current_planet == 2 or ship.is_destroyed:
				_reset()
			else:
				_travel_to_next_planet()


func _update_sun() -> void:
	sun.scale = Vector3.ONE * sun_radius
	_update_sunlight()
	_update_ocean_sun()


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
	battle.set_active(false)
	travelling = true
	var view_direction := ship.view_forward
	ship.bind_to_planet(null)
	_update_occluders()
	var destination := current_planet + 1
	var fixed_ship_position := ship.position
	var altitude := ship.altitude
	var radial_up := ship.basis.y.normalized()
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
	ship.bind_to_planet(planets[destination])
	ship.set_view_direction(view_direction)
	ship.set_agility_boost(current_planet >= 1)
	battle.set_active(current_planet == 1)
	travelling = false
	_update_occluders()
	_update_camera()
	_update_sunlight()
