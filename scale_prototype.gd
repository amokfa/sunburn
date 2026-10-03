extends Node3D
## Ship movement uses forces and radial geometry; planets have static mesh colliders.
const ShipController = preload("res://ship/ship.gd")
const IntroDialogue = preload("res://ui/intro_dialogue.gd")
const ExplosionDialogue = preload("res://ui/planet_1_explosion_dialogue.gd")
@onready var fuel_cells = $Planet1FuelCells
var _solar_death := false
var _death_fade: Tween
@onready var death_image: TextureRect = $DeathOverlay/Image
@onready var death_audio: AudioStreamPlayer = $DeathAudio
var _planet_1_phase_2_started := false
var _explosion_dialogue_in_progress := false
var _fuel_cells_spawned := false
@onready var terminal = $AssistantTerminal
@onready var forest_ambience: AudioStreamPlayer = $ForestAmbience
@onready var launch_audio: AudioStreamPlayer = $LaunchAudio
@onready var launch_audio_duration: Timer = $LaunchAudioDuration
@onready var rocket_audio = $RocketAudio
@onready var intro_music: AudioStreamPlayer = $IntroMusic
@onready var phase_2_music: AudioStreamPlayer = $Phase2Music
@onready var sun_trigger_audio: AudioStreamPlayer = $SunTriggerAudio
var _intro_music_fade: Tween
var _launch_started := false
var _rocket_audio_enabled := false
var _intro_in_progress := false
var _intro_wait_altitude := -1.0
@onready var sun_expansion_delay: Timer = $SunExpansionDelay
@onready var explosion_dialogue_delay: Timer = $ExplosionDialogueDelay
var _sun_expanding := false
var _sun_expansion_triggered := false
var sun_expansion_speed := 0.0
var _sun_flash_strength := 0.0
var _sun_flash_tween: Tween
var _environment: Environment
var _sky_material: ShaderMaterial
var _sun_material: ShaderMaterial
var _normal_ambient_energy := 0.0

@export_group("Solar system scale")
@export var planet_radii := Vector3(300.0, 240.0, 180.0)
@export var orbit_radii := Vector3(1800.0, 3600.0, 6000.0)
@export var orbit_angles_degrees := Vector3(0.0, 10.0, -10.0)
@export var initial_sun_radius: float = 250.0

@export_group("Sun expansion")
@export var sun_expansion_time_to_planet_1: float = 120.0

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
	fuel_cells.all_collected.connect(_on_planet_1_fuel_collected)
	# Set runtime looping too, so this works before the editor reimports the audio.
	var looping_music := phase_2_music.stream.duplicate() as AudioStreamOggVorbis
	looping_music.loop = true
	phase_2_music.stream = looping_music
	_setup_sun_flash()
	sun_expansion_delay.timeout.connect(trigger_sun_expansion)
	explosion_dialogue_delay.timeout.connect(_begin_planet_1_phase_2)
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
	_solar_death = false
	if _death_fade != null:
		_death_fade.kill()
	death_audio.stop()
	death_image.hide()
	death_image.modulate = Color.WHITE
	terminal.set_process(true)
	terminal.set_process_input(true)
	phase_2_music.stop()
	explosion_dialogue_delay.stop()
	sun_trigger_audio.stop()
	fuel_cells.clear(true)
	_planet_1_phase_2_started = false
	_explosion_dialogue_in_progress = false
	_fuel_cells_spawned = false
	sun_expansion_delay.stop()
	if _sun_flash_tween != null:
		_sun_flash_tween.kill()
	_sun_expanding = false
	_sun_expansion_triggered = false
	sun_expansion_speed = 0.0
	_set_sun_flash(0.0)
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
	if _explosion_dialogue_in_progress:
		if index == ExplosionDialogue.MESSAGES.size() - 1 and not _fuel_cells_spawned:
			_fuel_cells_spawned = true
			fuel_cells.begin(planets[0], ship)
		return
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
	if _explosion_dialogue_in_progress:
		_begin_sun_growth()
	_intro_in_progress = false
	_intro_wait_altitude = -1.0
	_explosion_dialogue_in_progress = false


func _begin_planet_1_phase_2() -> void:
	if current_planet != 0 or travelling or not _planet_1_phase_2_started:
		return
	_intro_in_progress = false
	_intro_wait_altitude = -1.0
	_explosion_dialogue_in_progress = true
	phase_2_music.play()
	# Testing the explosion during the tutorial must not leave any controls locked.
	ship.controls_enabled = true
	ship.mouse_look_enabled = true
	ship.ascend_input_enabled = true
	ship.descend_input_enabled = true
	ship.horizontal_input_enabled = true
	ship.allow_parked_view = true
	terminal.play_dialogue(ExplosionDialogue.MESSAGES, true, false)


func _on_planet_1_fuel_collected() -> void:
	if current_planet != 0 or travelling:
		return
	# Let the final collection animation and 10/10 counter read before departure.
	await get_tree().create_timer(0.25).timeout
	if current_planet != 0 or travelling or not _fuel_cells_spawned or not _planet_1_phase_2_started:
		return
	if _explosion_dialogue_in_progress:
		_on_intro_finished()
	terminal.close()
	_travel_to_next_planet()


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
	if _solar_death:
		return
	if _sun_expanding:
		sun_radius += maxf(sun_expansion_speed, 0.0) * delta
		sun.scale = Vector3.ONE * sun_radius
	# The sun reaches the near side of the flight shell at center distance - 1.5R.
	if current_planet == 0 and not travelling and _sun_expanding:
		var sun_gap := sun.global_position.distance_to(planets[0].global_position) - sun_radius
		if sun_gap <= planet_radii.x * 1.5:
			_show_solar_death()
			return
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


func _show_solar_death() -> void:
	if _solar_death:
		return
	_solar_death = true
	_sun_expanding = false
	sun_expansion_delay.stop()
	explosion_dialogue_delay.stop()
	launch_audio_duration.stop()
	ship.bind_to_planet(null)
	ship.controls_enabled = false
	terminal.close()
	terminal.set_process(false)
	terminal.set_process_input(false)
	fuel_cells.clear(true)
	rocket_audio.stop()
	forest_ambience.stop()
	launch_audio.stop()
	intro_music.stop()
	phase_2_music.stop()
	sun_trigger_audio.stop()
	if _intro_music_fade != null:
		_intro_music_fade.kill()
	if _sun_flash_tween != null:
		_sun_flash_tween.kill()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	death_image.modulate.a = 0.0
	death_image.show()
	death_audio.play()
	_death_fade = create_tween()
	_death_fade.tween_property(death_image, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _setup_sun_flash() -> void:
	# Keep runtime flash changes out of the shared resources and editor preview.
	_sun_material = sun.material_override.duplicate() as ShaderMaterial
	sun.material_override = _sun_material
	var world_environment: WorldEnvironment = $WorldEnvironment
	_environment = world_environment.environment.duplicate() as Environment
	_environment.sky = _environment.sky.duplicate() as Sky
	_sky_material = _environment.sky.sky_material.duplicate() as ShaderMaterial
	_environment.sky.sky_material = _sky_material
	world_environment.environment = _environment
	_normal_ambient_energy = _environment.ambient_light_energy


func trigger_sun_expansion() -> void:
	sun_trigger_audio.play()
	sun_expansion_delay.stop()
	_sun_expansion_triggered = true
	if current_planet == 0 and not _planet_1_phase_2_started:
		_planet_1_phase_2_started = true
		if _intro_music_fade != null:
			_intro_music_fade.kill()
		intro_music.stop()
		explosion_dialogue_delay.start()
	if _sun_flash_tween != null:
		_sun_flash_tween.kill()
	_sun_flash_tween = create_tween()
	_sun_flash_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sun_flash_tween.tween_method(_set_sun_flash, 0., 1.0, 0.3)
	_sun_flash_tween.tween_method(_set_sun_flash, 1.0, 0.0, 3.0)


func _begin_sun_growth() -> void:
	if _sun_expanding:
		return
	var target_radius := sun.global_position.distance_to(planets[0].global_position) - 2.0 * planet_radii.x
	sun_expansion_speed = maxf(target_radius - sun_radius, 0.0) / maxf(sun_expansion_time_to_planet_1, 0.001)
	_sun_expanding = true


func _set_sun_flash(strength: float) -> void:
	strength = strength * 10.
	_sun_flash_strength = strength
	_environment.ambient_light_energy = _normal_ambient_energy * lerpf(1.0, 100.0, strength)
	_sky_material.set_shader_parameter("flash_intensity", strength)
	_sun_material.set_shader_parameter("explosion_strength", strength)
	_update_sunlight()


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
		if not _sun_expansion_triggered:
			sun_expansion_delay.start()
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
	if _solar_death:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
			_reset()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		trigger_sun_expansion()
		get_viewport().set_input_as_handled()
		return
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
		if event.button_index == MOUSE_BUTTON_LEFT:
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
	sunlight.light_energy = clampf(energy, 0.0, maxf(sunlight_max_energy, 0.0)) * lerpf(1.0, 10.0, _sun_flash_strength)


func _travel_to_next_planet() -> void:
	if _solar_death:
		return
	explosion_dialogue_delay.stop()
	fuel_cells.clear()
	_explosion_dialogue_in_progress = false
	if current_planet == 0:
		_fade_out_planet_1_music()
		phase_2_music.stop()
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
