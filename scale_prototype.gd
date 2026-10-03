extends Node3D
## Ship movement uses forces and radial geometry; planets have static mesh colliders.
const ShipController = preload("res://ship/ship.gd")
const IntroDialogue = preload("res://ui/intro_dialogue.gd")
@onready var terminal = $AssistantTerminal
@onready var forest_ambience: AudioStreamPlayer = $ForestAmbience
@onready var launch_audio: AudioStreamPlayer = $LaunchAudio
@onready var launch_audio_duration: Timer = $LaunchAudioDuration
@onready var rocket_audio = $RocketAudio
@onready var intro_music: AudioStreamPlayer = $IntroMusic
var _intro_music_fade: Tween
var _launch_started := false
var _rocket_audio_enabled := false
var _intro_in_progress := false
var _intro_wait_altitude := -1.0

@export_group("Solar system scale")
@export var planet_radii := Vector3(300.0, 240.0, 180.0)
@export var orbit_radii := Vector3(1800.0, 3600.0, 6000.0)
@export var orbit_angles_degrees := Vector3(0.0, 10.0, -10.0)
@export var initial_sun_radius: float = 250.0
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
@export var platform_repulsion_delay: float = 3.0

@export_group("Forest ambience")
@export var forest_silence_altitude: float = 50.0
@export var forest_volume_db: float = 0.0

@export_group("Camera")
@export var camera_distance: float = 5.5
@export var opening_camera_angle_degrees: float = 20.0
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
var _left_platform := false
var _repulsion_countdown := -1.0
var _opening_camera_blend := 1.0
var _opening_framing_weight := 1.0
var _opening_camera_moved := false
var _platform_clearance := 0.5
@onready var launch_platform = $Planet1/platform/LaunchPlatform


func _ready() -> void:
	terminal.message_finished.connect(_on_intro_message_finished)
	terminal.dialogue_finished.connect(_on_intro_finished)
	launch_audio_duration.timeout.connect(launch_audio.stop)
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
	launch_audio_duration.stop()
	launch_audio.stop()
	rocket_audio.stop()
	_launch_started = false
	_rocket_audio_enabled = false
	_intro_in_progress = true
	_intro_wait_altitude = -1.0
	if _intro_music_fade != null:
		_intro_music_fade.kill()
	intro_music.volume_db = 0.0
	intro_music.play()
	battle.set_active(false)
	ship.reset_health()
	ship.set_movement_profile(0)
	ship.bind_to_planet(null)
	current_planet = 0
	_update_occluders()
	sun_radius = maxf(initial_sun_radius, 1.0)
	frame_origin = solar_positions[0]
	_set_frame_origin(frame_origin)
	launch_platform.align_to_planet()
	launch_platform.visible = true
	var radial_up: Vector3 = launch_platform.global_basis.y.normalized()
	var sun_direction: Vector3 = sun.global_position - launch_platform.global_position
	var forward: Vector3 = (sun_direction - radial_up * sun_direction.dot(radial_up)).normalized()
	var ship_forward := forward.rotated(radial_up, deg_to_rad(45.0))
	_platform_clearance = _ship_platform_clearance()
	ship.global_position = launch_platform.global_position + radial_up * _platform_clearance
	ship.basis = Basis(ship_forward.cross(radial_up).normalized(), radial_up, -ship_forward)
	ship.surface_repulsion_enabled = false
	_left_platform = false
	_repulsion_countdown = -1.0
	_opening_camera_blend = 1.0
	_opening_framing_weight = 1.0
	_opening_camera_moved = false
	ship.bind_to_planet(planets[0])
	ship.set_view_direction(forward)
	ship.set_parked(true)
	ship.takeoff_enabled = false
	ship.set_launch_boosters(false)
	camera_pitch = -0.15
	_update_sun()
	_update_camera()
	_update_sunlight()
	ship.controls_enabled = false
	ship.mouse_look_enabled = false
	ship.ascend_input_enabled = false
	ship.descend_input_enabled = false
	ship.horizontal_input_enabled = false
	ship.allow_parked_view = false
	terminal.play_dialogue(IntroDialogue.MESSAGES)
	_update_forest_ambience()
	forest_ambience.play()


func _on_intro_message_finished(index: int) -> void:
	if not _intro_in_progress or index < 0 or index >= IntroDialogue.MESSAGES.size():
		return
	var message: Dictionary = IntroDialogue.MESSAGES[index]
	match message.get("unlock", ""):
		"mouse":
			ship.controls_enabled = true
			ship.mouse_look_enabled = true
			ship.allow_parked_view = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		"ascend":
			ship.ascend_input_enabled = true
		"descend":
			ship.descend_input_enabled = true
		"horizontal":
			ship.horizontal_input_enabled = true
	if message.has("wait_altitude"):
		_intro_wait_altitude = float(message["wait_altitude"])
		terminal.set_progress_blocked(true)


func _on_intro_finished() -> void:
	_intro_in_progress = false
	_intro_wait_altitude = -1.0


func _set_frame_origin(origin: Vector3) -> void:
	frame_origin = origin
	for index in range(3):
		planets[index].position = solar_positions[index] - frame_origin
	sun.position = -frame_origin
	battle.follow_planet()


func _fade_out_planet_1_music() -> void:
	if _intro_music_fade != null:
		_intro_music_fade.kill()
	_intro_music_fade = create_tween()
	_intro_music_fade.tween_property(intro_music, "volume_db", -80.0, 1.0)
	_intro_music_fade.tween_callback(intro_music.stop)


func _process(delta: float) -> void:
	if _intro_wait_altitude >= 0.0 and current_planet == 0 and not travelling and ship.altitude >= _intro_wait_altitude:
		_intro_wait_altitude = -1.0
		terminal.resume_dialogue()
	_update_platform_departure(delta)
	_update_forest_ambience()
	rocket_audio.update_layers(ship.active_booster_count(), _rocket_audio_enabled and ship.can_fight, delta)
	if _opening_camera_moved:
		_opening_framing_weight = maxf(0.0, _opening_framing_weight - delta * 5.0)
	_update_camera()
	_update_sunlight()
	_update_ocean_sun()


func _update_forest_ambience() -> void:
	var gain := 0.0
	if current_planet == 0 and not travelling:
		gain = clampf(1.0 - ship.altitude / maxf(forest_silence_altitude, 0.001), 0.0, 1.0)
	forest_ambience.volume_linear = db_to_linear(forest_volume_db) * gain


func _begin_launch_sequence() -> void:
	if _launch_started or not ship.controls_enabled or not ship.ascend_input_enabled or not ship.is_parked:
		return
	_launch_started = true
	ship.set_launch_boosters(true)
	launch_audio.play()
	launch_audio_duration.start()
	_rocket_audio_enabled = true
	rocket_audio.update_layers(ship.active_booster_count(), true, 0.0)
	ship.takeoff_enabled = true
	ship.set_parked(false)

func _ship_platform_clearance() -> float:
	var minimum_y := 0.0
	var pending: Array[Node] = [ship.model]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if node.name == &"markers":
			continue
		if node is MeshInstance3D and node.mesh != null:
			var bounds: AABB = node.mesh.get_aabb()
			var local_transform: Transform3D = ship.global_transform.affine_inverse() * node.global_transform
			for index in range(8):
				minimum_y = minf(minimum_y, (local_transform * bounds.get_endpoint(index)).y)
		pending.append_array(node.get_children())
	return -minimum_y + 0.05

func _update_platform_departure(delta: float) -> void:
	if travelling or current_planet != 0:
		return
	if not _left_platform:
		if ship.is_parked:
			return
		_left_platform = true
		_repulsion_countdown = platform_repulsion_delay
		return
	_opening_camera_blend = maxf(0.0, _opening_camera_blend - delta / maxf(platform_repulsion_delay, 0.001))
	if _repulsion_countdown >= 0.0:
		_repulsion_countdown -= delta
		if _repulsion_countdown <= 0.0:
			ship.surface_repulsion_enabled = true
			_repulsion_countdown = -1.0


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
	var orbit_direction := direction.rotated(radial_up, deg_to_rad(opening_camera_angle_degrees) * _opening_camera_blend)
	var offset := -orbit_direction * cos(camera_pitch) + radial_up * -sin(camera_pitch)
	var target := ship.global_position + radial_up * lerpf(1.5, 0.35, _opening_camera_blend)
	camera.global_position = target + offset * lerpf(camera_distance, 8.0, _opening_camera_blend)
	var look_direction := (target - camera.global_position).normalized()
	if _opening_camera_blend * _opening_framing_weight > 0.0:
		var ship_direction := (ship.global_position - camera.global_position).normalized()
		var sun_direction := (sun.global_position - camera.global_position).normalized()
		var opening_direction := (ship_direction + sun_direction).normalized()
		look_direction = look_direction.slerp(opening_direction, _opening_camera_blend * _opening_framing_weight)
	camera.look_at(camera.global_position + look_direction, radial_up)
func _unhandled_input(event: InputEvent) -> void:
	if not ship.controls_enabled:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and ship.bound_planet != null:
		if not ship.mouse_look_enabled:
			return
		if ship.is_parked and not ship.allow_parked_view:
			return
		if not event.relative.is_zero_approx():
			_opening_camera_moved = true
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
		if event.physical_keycode == KEY_Q:
			_begin_launch_sequence()
		elif event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.keycode == KEY_P and not travelling:
			if _intro_in_progress:
				return
			if ship.is_parked and not ship.takeoff_enabled:
				return
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
	if current_planet == 0:
		_fade_out_planet_1_music()
	forest_ambience.stop()
	ship.surface_repulsion_enabled = true
	_left_platform = true
	_repulsion_countdown = -1.0
	_opening_camera_blend = 0.0
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
	ship.set_movement_profile(current_planet)
	battle.set_active(current_planet == 1)
	travelling = false
	_update_occluders()
	_update_camera()
	_update_sunlight()
