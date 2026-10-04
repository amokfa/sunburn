extends Node3D
## Ship movement uses forces and radial geometry; planets have static mesh colliders.
const ShipController = preload("res://ship/ship.gd")
const IntroDialogue = preload("res://ui/intro_dialogue.gd")
const ExplosionDialogue = preload("res://ui/planet_1_explosion_dialogue.gd")
const ArrivalDialogue = preload("res://ui/planet_2_arrival_dialogue.gd")
const Planet3Dialogue = preload("res://ui/planet_3_dialogue.gd")
const EngulfedSurface = preload("res://planets/engulfed_surface.gdshader")
var _heated_surfaces: Array[Dictionary] = []
var _heat_material: ShaderMaterial
var _heat_atmosphere: ShaderMaterial
var _heat_atmosphere_color := Color.WHITE
var _heat_color := Color.WHITE
var _heat_tween: Tween
var _arrival_dialogue_phase := ""
var _arrival_skipping := false
var _weapons_ejected := false
var _player_death_pending := false
var _planet2_fight_elapsed := 0.0
var _planet2_overheat_elapsed := 0.0
var _planet2_overheat_started := false
var _planet2_dialogue_started := false
var _planet2_explanation_finished := false
var _planet2_dialogue_phase := ""
var _planet2_fleet_destroyed := false
var _planet2_cells_spawned := false
var _planet2_cells_collected := false
var _sun_passed_planet2_200m := false
var _sun_passed_planet2_100m := false
var _gameplay_camera_blend := 1.0
var _gameplay_camera_local := Transform3D.IDENTITY
@onready var planet_2_music: AudioStreamPlayer = $Planet2Music
@onready var departure_music: AudioStreamPlayer = $DepartureMusic
@onready var sun_ambience: AudioStreamPlayer = $SunAmbience
@onready var warzone_audio = $WarzoneAudio
@onready var player_hit_audio: AudioStreamPlayer = $PlayerHitAudio
@onready var player_death_explosion_audio: AudioStreamPlayer = $PlayerDeathExplosionAudio
@onready var weapons_module: Node3D = $Ship/Model/WeaponsModule
@onready var cutscene_debris: Node3D = $CutsceneDebris
@onready var departure = $PlanetDeparture
@onready var planet_3_departure = $Planet3Departure
var _crash_landed := false
var _crash_camera_direction := Vector3.FORWARD
var _planet3_dialogue_phase := ""
var _planet3_sun_stop_radius := -1.0
@onready var booster_dialogue_delay: Timer = $BoosterDialogueDelay
@onready var landing_dialogue_delay: Timer = $LandingDialogueDelay
var _travel_tween: Tween
var _fuel_departure_pending := false
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
var _sun_halo_material: ShaderMaterial
var _sun_yellow_halo := Color.WHITE
var _normal_ambient_energy := 0.0
var _sun_final_started := false
var _sun_collapse_elapsed := -1.0
var _sun_collapse_start_radius := 0.0
var _sun_blue_blend := 0.0
var _sun_normal_wave_amplitude := 0.0
var _sun_normal_wave_speed := 0.65
var _sun_wave_phase := 0.0
var _sun_normal_aabb := AABB()
var _sun_normal_halo_scale := Vector3.ONE
var _sun_normal_halo_intensity := 1.2
var _sun_normal_halo_surface_ratio := 0.7
var _collapse_dialogue_countdown := -1.0
var _planet3_surface_material: StandardMaterial3D

@export_group("Sun final phase")
@export var sun_final_radius := 100.0
@export var sun_collapse_duration := 20.0
@export var sun_final_trigger_distance := 500.0
@export var sun_final_light_energy := 0.005
@export var sun_final_ambient_energy := 0.0005

@export_group("Solar system scale")
@export var planet_radii := Vector3(300.0, 240.0, 180.0)
@export var orbit_radii := Vector3(1800.0, 3600.0, 6000.0)
@export var orbit_angles_degrees := Vector3(0.0, 10.0, -10.0)
@export var initial_sun_radius: float = 250.0

@export_group("Sun expansion")
@export var sun_expansion_time_to_planet_1: float = 150.0
@export var planet_2_sun_approach_time: float = 200.0
@export var planet_2_fight_duration: float = 175.0
@export var planet_2_sun_approach_gap: float = 200.0
@export var planet_2_final_100m_time: float = 120.0
@export var planet_3_sun_approach_time: float = 120.0
@export var planet_3_sun_approach_gap: float = 100.0

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
@onready var game_menu = $GameMenu
var _gameplay_started := false
var _base_mouse_sensitivity := 0.003
var _shader_time := 0.0


func _ready() -> void:
	_base_mouse_sensitivity = mouse_sensitivity
	game_menu.begin_requested.connect(_begin_intro)
	game_menu.pause_requested.connect(_pause_game)
	game_menu.resume_requested.connect(_resume_game)
	game_menu.abort_requested.connect(_return_to_main_menu)
	game_menu.quit_requested.connect(get_tree().quit)
	game_menu.skip_cutscene_requested.connect(_skip_active_cutscene)
	game_menu.sensitivity_changed.connect(_set_camera_sensitivity)
	_set_camera_sensitivity(game_menu.sensitivity_value)
	planet_3_departure.boosters_failed.connect(_on_planet_3_boosters_failed)
	booster_dialogue_delay.timeout.connect(_begin_booster_dialogue)
	landing_dialogue_delay.timeout.connect(_begin_landing_dialogue)
	planet_3_departure.source_heated.connect(_heat_planet_2)
	planet_3_departure.missile_impact.connect(_on_player_missile_hit)
	planet_3_departure.crash_impact.connect(_on_planet_3_crash_impact)
	planet_3_departure.crash_finished.connect(_finish_planet_3_crash)
	departure.source_heated.connect(_heat_planet_1)
	departure.rear_view_ready.connect(_begin_departure_farewell)
	departure.destination_view_ready.connect(_begin_arrival_conversation)
	departure.descent_finished.connect(_finish_planet_2_arrival)
	battle.player_hit.connect(_on_player_missile_hit)
	battle.player_destroyed.connect(_on_player_destroyed)
	battle.enemy_fleet_destroyed.connect(_on_planet2_fleet_destroyed)
	battle.enemy_destroyed.connect(warzone_audio.enemy_destroyed)
	terminal.message_advanced.connect(_on_arrival_message_advanced)
	fuel_cells.all_collected.connect(_on_planet_1_fuel_collected)
	# Set runtime looping too, so this works before the editor reimports the audio.
	var looping_music := phase_2_music.stream.duplicate() as AudioStreamOggVorbis
	looping_music.loop = true
	phase_2_music.stream = looping_music
	var looping_departure_music := departure_music.stream.duplicate() as AudioStreamMP3
	looping_departure_music.loop = true
	departure_music.stream = looping_departure_music
	var looping_sun := sun_ambience.stream.duplicate() as AudioStreamMP3
	looping_sun.loop = true
	sun_ambience.stream = looping_sun
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
	_reset(false)
	game_menu.show_main()


func _update_occluders() -> void:
	for index in range(planets.size()):
		var occluder := planets[index].get_node_or_null("CoreOccluder") as OccluderInstance3D
		if occluder != null:
			occluder.visible = not travelling and index == current_planet


func _reset(start_intro := true) -> void:
	_gameplay_started = start_intro
	_shader_time = 0.0
	RenderingServer.global_shader_parameter_set("game_time", _shader_time)
	_sun_final_started = false
	_sun_collapse_elapsed = -1.0
	_collapse_dialogue_countdown = -1.0
	_sun_blue_blend = 0.0
	_planet3_surface_material.roughness = 1.0
	_sun_material.set_shader_parameter("wave_amplitude", _sun_normal_wave_amplitude)
	_sun_wave_phase = 0.0
	_sun_material.set_shader_parameter("wave_speed", _sun_normal_wave_speed)
	_sun_material.set_shader_parameter("wave_time", _sun_wave_phase)
	sun.custom_aabb = _sun_normal_aabb
	var halo := sun.get_node("GlowShell") as MeshInstance3D
	halo.scale = _sun_normal_halo_scale
	halo.show()
	_sun_halo_material.set_shader_parameter("glow_intensity", _sun_normal_halo_intensity)
	_sun_halo_material.set_shader_parameter("surface_radius_ratio", _sun_normal_halo_surface_ratio)
	planets[0].show()
	planets[1].show()
	warzone_audio.stop()
	sun_ambience.stop()
	sun_ambience.volume_db = -80.0
	departure_music.stop()
	booster_dialogue_delay.stop()
	landing_dialogue_delay.stop()
	_planet3_dialogue_phase = ""
	_planet3_sun_stop_radius = -1.0
	planet_3_departure.cancel()
	_crash_landed = false
	_arrival_dialogue_phase = ""
	_arrival_skipping = false
	_weapons_ejected = false
	_player_death_pending = false
	_planet2_fight_elapsed = 0.0
	_planet2_overheat_elapsed = 0.0
	_planet2_overheat_started = false
	_planet2_dialogue_started = false
	_planet2_explanation_finished = false
	_planet2_dialogue_phase = ""
	_planet2_fleet_destroyed = false
	_planet2_cells_spawned = false
	_planet2_cells_collected = false
	_sun_passed_planet2_200m = false
	_sun_passed_planet2_100m = false
	_gameplay_camera_blend = 1.0
	weapons_module.show()
	for child in cutscene_debris.get_children():
		child.queue_free()
	planet_2_music.stop()
	player_hit_audio.stop()
	player_death_explosion_audio.stop()
	battle.set_protected_mode(false)
	battle.set_hud_enabled(false)
	terminal.allow_toggle = true
	departure.cancel()
	_restore_planet_1_materials()
	if _travel_tween != null:
		_travel_tween.kill()
	travelling = false
	_fuel_departure_pending = false
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
	_intro_in_progress = start_intro
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
	_update_forest_ambience()
	forest_ambience.play()
	if start_intro:
		_begin_intro()
	else:
		ship.set_process(false)
		terminal.stop_dialogue()
		terminal.set_process_input(false)


func _begin_intro() -> void:
	_gameplay_started = true
	_intro_in_progress = true
	ship.set_process(true)
	terminal.set_process(true)
	terminal.set_process_input(true)
	terminal.play_dialogue(IntroDialogue.MESSAGES)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pause_game() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _solar_death else Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false


func _return_to_main_menu() -> void:
	_reset(false)
	get_tree().paused = false
	game_menu.show_main()


func menu_expects_mouse_capture() -> bool:
	return _gameplay_started and not _solar_death


func menu_can_skip_cutscene() -> bool:
	if not _gameplay_started or _solar_death or _player_death_pending:
		return false
	return (
		_intro_in_progress or departure.active or planet_3_departure.active or travelling
		or _explosion_dialogue_in_progress or not explosion_dialogue_delay.is_stopped()
		or not _planet2_dialogue_phase.is_empty()
		or _planet3_dialogue_phase in ["malfunction", "landing", "collapse_wait", "collapse"]
		or not landing_dialogue_delay.is_stopped() or _sun_collapse_elapsed >= 0.0
	)


func _skip_active_cutscene() -> void:
	if not menu_can_skip_cutscene():
		return
	if _intro_in_progress:
		terminal.finish_dialogue()
	elif planet_3_departure.active:
		planet_3_departure.skip_to_crash()
	elif departure.active:
		_skip_arrival_cutscene()
	elif travelling and _travel_tween != null:
		_travel_tween.custom_step(10000.0)
	elif _sun_final_started:
		# Finish the visual transition as well as the conversation. Keep the
		# final transcript open after BX loses power, just like normal playback.
		if _sun_flash_tween != null and _sun_flash_tween.is_running():
			_sun_flash_tween.custom_step(10000.0)
		if _sun_collapse_elapsed >= 0.0:
			_step_sun_collapse(sun_collapse_duration)
		if _planet3_dialogue_phase == "collapse_wait":
			_collapse_dialogue_countdown = -1.0
			_planet3_dialogue_phase = "collapse"
			terminal.play_dialogue(Planet3Dialogue.ON_COLLAPSE, true, false)
		if _planet3_dialogue_phase == "collapse":
			terminal.finish_dialogue()
			terminal.open()
	elif not landing_dialogue_delay.is_stopped():
		landing_dialogue_delay.stop()
		_begin_landing_dialogue()
		terminal.finish_dialogue()
	elif not explosion_dialogue_delay.is_stopped():
		explosion_dialogue_delay.stop()
		_begin_planet_1_phase_2()
		terminal.finish_dialogue()
	else:
		terminal.finish_dialogue()


func _set_camera_sensitivity(value: float) -> void:
	var multiplier := lerpf(0.5, 1.0, (value - 1.0) / 4.0) if value <= 5.0 else lerpf(1.0, 2.0, (value - 5.0) / 5.0)
	mouse_sensitivity = _base_mouse_sensitivity * multiplier


func _on_intro_message_finished(index: int) -> void:
	if _planet3_dialogue_phase == "collapse" and index >= 0 and index < Planet3Dialogue.ON_COLLAPSE.size():
		if Planet3Dialogue.ON_COLLAPSE[index].get("event", "") == "assistant_power_lost":
			_planet3_dialogue_phase = "ended"
			terminal.set_progress_blocked(true)
			terminal.allow_toggle = false
			terminal.set_process_input(false)
		return
	if not _planet3_dialogue_phase.is_empty():
		return
	if not _planet2_dialogue_phase.is_empty():
		return
	if not _arrival_dialogue_phase.is_empty():
		_on_arrival_message_finished(index)
		return
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
	if _planet3_dialogue_phase in ["collapse", "ended"]:
		_planet3_dialogue_phase = "ended"
		terminal.allow_toggle = false
		terminal.set_process_input(false)
		return
	if not _planet3_dialogue_phase.is_empty():
		_planet3_dialogue_phase = ""
		return
	if _planet2_dialogue_phase == "overheat":
		_planet2_dialogue_phase = ""
		_planet2_explanation_finished = true
		if _planet2_fleet_destroyed:
			_show_planet2_fuel_dialogue()
		return
	if _planet2_dialogue_phase == "fuel":
		_planet2_dialogue_phase = ""
		return
	if _arrival_dialogue_phase == "arrival":
		_arrival_dialogue_phase = ""
		departure.begin_descent()
		return
	if _arrival_dialogue_phase == "farewell":
		return
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
	if current_planet == 1 and _planet2_cells_spawned:
		_planet2_cells_collected = true
		await get_tree().create_timer(0.25, false).timeout
		if current_planet == 1 and _planet2_cells_collected and not travelling:
			terminal.stop_dialogue()
			_travel_to_next_planet()
		return
	if current_planet != 0 or travelling or _solar_death or _fuel_departure_pending:
		return
	_fuel_departure_pending = true
	# Let the final collection animation and 10/10 counter read before departure.
	await get_tree().create_timer(0.25, false).timeout
	if current_planet != 0 or travelling or not _fuel_cells_spawned or not _planet_1_phase_2_started:
		return
	if _explosion_dialogue_in_progress:
		_on_intro_finished()
	terminal.close()
	_fuel_departure_pending = false
	_travel_to_next_planet()


func _begin_planet2_overheat(force_instant: bool) -> void:
	if current_planet != 1:
		return
	if not _planet2_overheat_started:
		_planet2_overheat_started = true
		_planet2_overheat_elapsed = 0.0
		_planet2_dialogue_started = false
		_planet2_explanation_finished = false
		_planet2_fleet_destroyed = false
		battle.begin_weapon_overheat(0.0 if force_instant else 15.0)
	elif force_instant:
		battle.force_finish_weapon_overheat()
	if force_instant:
		var snap_radius := sun.global_position.distance_to(planets[1].global_position) - planet_radii.y - 300.0
		sun_radius = maxf(snap_radius, 0.0)
		_sun_expanding = true
		_sun_passed_planet2_200m = true
		_sun_passed_planet2_100m = false
		sun_expansion_speed = 100.0 / 60.0
		_update_sun()
		if _planet2_cells_spawned:
			fuel_cells.collect_all()


func _on_planet2_fleet_destroyed() -> void:
	_planet2_fleet_destroyed = true
	_spawn_planet2_fuel_cells()


func _spawn_planet2_fuel_cells() -> void:
	if _planet2_cells_spawned or not _planet2_fleet_destroyed:
		return
	_planet2_cells_spawned = true
	fuel_cells.begin(planets[1], ship, 10, true)
	if _planet2_explanation_finished:
		_show_planet2_fuel_dialogue()


func _show_planet2_fuel_dialogue() -> void:
	if _planet2_dialogue_phase == "fuel":
		return
	_planet2_dialogue_phase = "fuel"
	terminal.play_dialogue(ArrivalDialogue.PLANET2_FUEL, true, false)


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
	_shader_time += delta
	RenderingServer.global_shader_parameter_set("game_time", _shader_time)
	# Integrate speed so changing it accelerates the waves without jumping phase.
	var wave_speed: float = _sun_material.get_shader_parameter("wave_speed")
	_sun_wave_phase += delta * wave_speed
	_sun_material.set_shader_parameter("wave_time", _sun_wave_phase)
	if not _gameplay_started:
		return
	if _solar_death:
		return
	if _sun_final_started:
		_sun_expanding = false
	if _sun_collapse_elapsed >= 0.0:
		_step_sun_collapse(delta)
	if _collapse_dialogue_countdown >= 0.0:
		_collapse_dialogue_countdown -= delta
		if _collapse_dialogue_countdown <= 0.0:
			_collapse_dialogue_countdown = -1.0
			_planet3_dialogue_phase = "collapse"
			terminal.play_dialogue(Planet3Dialogue.ON_COLLAPSE, true, false)
	if _sun_expanding:
		var next_radius := sun_radius + maxf(sun_expansion_speed, 0.0) * delta
		if departure.active:
			next_radius = minf(next_radius, maxf(sun_radius, departure.sun_stop_radius()))
		if _planet3_sun_stop_radius >= 0.0 and (planet_3_departure.active or current_planet == 2):
			next_radius = minf(next_radius, _planet3_sun_stop_radius)
			if next_radius >= _planet3_sun_stop_radius:
				_sun_expanding = false
		sun_radius = next_radius
		sun.scale = Vector3.ONE * sun_radius
		_update_sun_color()
	if planets[0].visible and sun_radius >= sun.global_position.distance_to(planets[0].global_position) + planet_radii.x * 1.4:
		planets[0].hide()
	if _crash_landed and not _sun_final_started:
		var planet3_gap := sun.global_position.distance_to(planets[2].global_position) - sun_radius - planet_radii.z
		if planet3_gap <= sun_final_trigger_distance:
			trigger_sun_final_phase()
	if current_planet == 1 and _sun_expanding and not planet_3_departure.active:
		var planet2_gap := sun.global_position.distance_to(planets[1].global_position) - sun_radius - planet_radii.y
		if not _sun_passed_planet2_200m and planet2_gap <= planet_2_sun_approach_gap:
			_sun_passed_planet2_200m = true
			sun_expansion_speed = 100.0 / 60.0
		if not _sun_passed_planet2_100m and planet2_gap <= 100.0:
			_sun_passed_planet2_100m = true
			sun_expansion_speed = 100.0 / maxf(planet_2_final_100m_time, 0.001)
		if planet2_gap <= 100.0 and not _planet2_cells_collected:
			_show_solar_death()
			return
	if current_planet == 1 and planet_2_music.playing and not travelling:
		if not _planet2_overheat_started:
			_planet2_fight_elapsed += delta
			if _planet2_fight_elapsed >= planet_2_fight_duration:
				_begin_planet2_overheat(false)
		elif not _planet2_dialogue_started:
			_planet2_overheat_elapsed += delta
			if _planet2_overheat_elapsed >= 10.0:
				_planet2_dialogue_started = true
				_planet2_dialogue_phase = "overheat"
				terminal.play_dialogue(ArrivalDialogue.PLANET2_OVERHEAT, true, false)
	# The sun reaches the near side of the flight shell at center distance - 1.5R.
	if current_planet == 0 and not travelling and not _fuel_departure_pending and _sun_expanding:
		var sun_gap := sun.global_position.distance_to(planets[0].global_position) - sun_radius
		if sun_gap <= planet_radii.x * 1.5:
			_show_solar_death()
			return
	if _intro_wait_altitude >= 0.0 and current_planet == 0 and not travelling and ship.altitude >= _intro_wait_altitude:
		_intro_wait_altitude = -1.0
		terminal.resume_dialogue()
	_gameplay_camera_blend = minf(_gameplay_camera_blend + delta / 1.2, 1.0)
	_update_platform_departure(delta)
	_update_forest_ambience()
	rocket_audio.update_layers(ship.active_booster_count(), _rocket_audio_enabled and ship.can_fight, delta)
	if _opening_camera_moved:
		_opening_framing_weight = maxf(0.0, _opening_framing_weight - delta * 5.0)
	if planet_3_departure.active:
		planet_3_departure.step(delta)
	elif departure.active:
		departure.step(delta)
	else:
		_update_camera()
	_update_sunlight()
	_update_ocean_sun()
	_update_sun_ambience()


func _show_solar_death() -> void:
	warzone_audio.stop()
	sun_ambience.stop()
	departure_music.stop()
	booster_dialogue_delay.stop()
	landing_dialogue_delay.stop()
	if _solar_death:
		return
	_solar_death = true
	battle.set_active(false)
	planet_2_music.stop()
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
	var terrain := planets[2].get_node("Terrain") as MeshInstance3D
	_planet3_surface_material = terrain.material_override.duplicate() as StandardMaterial3D
	terrain.material_override = _planet3_surface_material
	_sun_material = sun.material_override.duplicate() as ShaderMaterial
	sun.material_override = _sun_material
	_sun_normal_wave_amplitude = _sun_material.get_shader_parameter("wave_amplitude")
	_sun_normal_wave_speed = _sun_material.get_shader_parameter("wave_speed")
	_sun_normal_aabb = sun.custom_aabb
	var halo := sun.get_node("GlowShell") as MeshInstance3D
	_sun_normal_halo_scale = halo.scale
	_sun_halo_material = halo.material_override.duplicate() as ShaderMaterial
	_sun_normal_halo_intensity = _sun_halo_material.get_shader_parameter("glow_intensity")
	_sun_normal_halo_surface_ratio = _sun_halo_material.get_shader_parameter("surface_radius_ratio")
	_sun_yellow_halo = _sun_halo_material.get_shader_parameter("glow_color")
	halo.material_override = _sun_halo_material
	var world_environment: WorldEnvironment = $WorldEnvironment
	_environment = world_environment.environment.duplicate() as Environment
	_environment.sky = _environment.sky.duplicate() as Sky
	_sky_material = _environment.sky.sky_material.duplicate() as ShaderMaterial
	_environment.sky.sky_material = _sky_material
	world_environment.environment = _environment
	_normal_ambient_energy = _environment.ambient_light_energy


func trigger_sun_expansion() -> void:
	if _sun_final_started:
		return
	sun_trigger_audio.play()
	sun_expansion_delay.stop()
	_sun_expansion_triggered = true
	if current_planet == 0 and not _planet_1_phase_2_started:
		_planet_1_phase_2_started = true
		if _intro_music_fade != null:
			_intro_music_fade.kill()
		intro_music.stop()
		explosion_dialogue_delay.start()
	_play_sun_flash()


func _play_sun_flash() -> void:
	if _sun_flash_tween != null:
		_sun_flash_tween.kill()
	_sun_flash_tween = create_tween()
	_sun_flash_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_sun_flash_tween.tween_method(_set_sun_flash, 0., 1.0, 0.3)
	_sun_flash_tween.tween_method(_set_sun_flash, 1.0, 0.0, 3.0)


func _begin_sun_growth() -> void:
	if _sun_expanding or _sun_final_started:
		return
	var target_radius := sun.global_position.distance_to(planets[0].global_position) - 2.0 * planet_radii.x
	sun_expansion_speed = maxf(target_radius - sun_radius, 0.0) / maxf(sun_expansion_time_to_planet_1, 0.001)
	_sun_expanding = true


func _set_sun_flash(strength: float) -> void:
	strength = strength * 10.
	_sun_flash_strength = strength
	_environment.ambient_light_energy = _normal_ambient_energy * lerpf(1.0, 100.0, strength)
	_sky_material.set_shader_parameter("flash_intensity", strength)
	var flash_color := Color.WHITE
	if _sun_final_started:
		var red: Color = _sun_material.get_shader_parameter("red_color")
		var brightness := maxf(maxf(red.r, red.g), maxf(red.b, 0.001))
		flash_color = Color(red.r / brightness, red.g / brightness, red.b / brightness, 1.0)
	_sky_material.set_shader_parameter("flash_color", flash_color)
	_sun_material.set_shader_parameter("explosion_strength", strength)
	_update_sunlight()


func trigger_sun_final_phase() -> void:
	if _sun_final_started or _solar_death:
		return
	_sun_final_started = true
	_sun_expanding = false
	booster_dialogue_delay.stop()
	landing_dialogue_delay.stop()
	_planet3_dialogue_phase = "collapse_wait"
	terminal.stop_dialogue()
	terminal.allow_toggle = false
	terminal.set_process(true)
	terminal.set_process_input(true)
	_collapse_dialogue_countdown = 5.0
	planets[0].hide()
	planets[1].hide()
	sun_expansion_delay.stop()
	explosion_dialogue_delay.stop()
	_sun_blue_blend = 0.0
	_update_sun_color()
	sun_trigger_audio.play()
	_play_sun_flash()
	_sun_flash_tween.tween_callback(_begin_sun_collapse)


func _begin_sun_collapse() -> void:
	_sun_collapse_start_radius = sun_radius
	_sun_collapse_elapsed = 0.0
	# Large waves need matching render bounds throughout the collapse.
	var extent := 1.02 + _sun_normal_wave_amplitude * 10.0
	sun.custom_aabb = AABB(Vector3.ONE * -extent, Vector3.ONE * extent * 2.0)


func _step_sun_collapse(delta: float) -> void:
	_sun_collapse_elapsed = minf(_sun_collapse_elapsed + delta, sun_collapse_duration)
	var t := _sun_collapse_elapsed
	_sun_material.set_shader_parameter("wave_speed", _sun_normal_wave_speed * lerpf(1.0, 10.0, smoothstep(0.0, 10.0, t)))
	_sun_blue_blend = smoothstep(0.0, sun_collapse_duration, t)
	_planet3_surface_material.roughness = lerpf(1.0, 0.5, _sun_blue_blend)
	sun_radius = lerpf(_sun_collapse_start_radius, sun_final_radius, _sun_blue_blend)
	var wave_multiplier := lerpf(1.0, 10.0, smoothstep(0.0, 5.0, t))
	wave_multiplier *= 1.0 - smoothstep(sun_collapse_duration - 5.0, sun_collapse_duration, t)
	_sun_material.set_shader_parameter("wave_amplitude", _sun_normal_wave_amplitude * wave_multiplier)
	# Counter the parent's shrinking scale to preserve the original shell radius.
	var halo := sun.get_node("GlowShell") as MeshInstance3D
	halo.scale = _sun_normal_halo_scale * (_sun_collapse_start_radius / maxf(sun_radius, 0.001))
	# The outer shell stays fixed; its density gradient starts at the current core.
	var shell_radius := _sun_collapse_start_radius * _sun_normal_halo_scale.x
	_sun_halo_material.set_shader_parameter("surface_radius_ratio", clampf(sun_radius / maxf(shell_radius, 0.001), 0.00001, 0.999))
	var glow_fade := smoothstep(0.0, sun_collapse_duration * 0.75, t)
	_sun_halo_material.set_shader_parameter("glow_intensity", _sun_normal_halo_intensity * (1.0 - glow_fade))
	_update_sun()
	if t >= sun_collapse_duration:
		_sun_collapse_elapsed = -1.0
		sun.custom_aabb = _sun_normal_aabb
		halo.hide()


func _update_sun_ambience() -> void:
	var surface_distance := camera.global_position.distance_to(sun.global_position) - sun_radius
	var silent_distance := 1500.0 if current_planet == 2 else 800.0
	var full_volume_distance := 700.0 if current_planet == 2 else 500.0
	var gain := clampf((silent_distance - surface_distance) / (silent_distance - full_volume_distance), 0.0, 1.0)
	if gain <= 0.0:
		sun_ambience.stop()
		sun_ambience.volume_db = -80.0
		return
	sun_ambience.volume_linear = gain + 2.
	if not sun_ambience.playing:
		sun_ambience.play()


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
	var direction := _crash_camera_direction if _crash_landed else ship.view_forward
	var orbit_direction := direction.rotated(radial_up, deg_to_rad(opening_camera_angle_degrees) * _opening_camera_blend)
	var offset := -orbit_direction * cos(camera_pitch) + radial_up * -sin(camera_pitch)
	var target := ship.global_position + radial_up * lerpf(1.5, 0.35, _opening_camera_blend)
	var orbit_radius := lerpf(camera_distance, 8.0, _opening_camera_blend)
	if _crash_landed:
		orbit_radius *= 3.0
	camera.global_position = target + offset * orbit_radius
	var look_direction := (target - camera.global_position).normalized()
	if _opening_camera_blend * _opening_framing_weight > 0.0:
		var ship_direction := (ship.global_position - camera.global_position).normalized()
		var sun_direction := (sun.global_position - camera.global_position).normalized()
		var opening_direction := (ship_direction + sun_direction).normalized()
		look_direction = look_direction.slerp(opening_direction, _opening_camera_blend * _opening_framing_weight)
	camera.look_at(camera.global_position + look_direction, radial_up)
	if _gameplay_camera_blend < 1.0:
		var attached := ship.global_transform * _gameplay_camera_local
		camera.global_transform = attached.interpolate_with(camera.global_transform, smoothstep(0.0, 1.0, _gameplay_camera_blend))


func _skip_checkpoint() -> void:
	if planet_3_departure.active:
		planet_3_departure.skip_to_crash()
		return
	if departure.active:
		_skip_arrival_cutscene()
		return
	if travelling:
		if _travel_tween != null and _travel_tween.is_running():
			_travel_tween.custom_step(10000.0)
		return
	if _fuel_departure_pending:
		return
	if current_planet == 0:
		if _intro_in_progress:
			terminal.finish_dialogue()
		elif not _sun_expansion_triggered:
			trigger_sun_expansion()
		elif not explosion_dialogue_delay.is_stopped():
			explosion_dialogue_delay.stop()
			_begin_planet_1_phase_2()
		elif _explosion_dialogue_in_progress:
			terminal.finish_dialogue()
		elif _fuel_cells_spawned:
			fuel_cells.collect_all()
			if _fuel_departure_pending:
				var contact_radius := sun.global_position.distance_to(planets[0].global_position) - planet_radii.x
				sun_radius = maxf(sun_radius, contact_radius)
				_update_sun()
	elif current_planet == 1:
		_begin_planet2_overheat(true)
	elif current_planet == 2 or ship.is_destroyed:
		_reset()
	else:
		_travel_to_next_planet()


func _unhandled_input(event: InputEvent) -> void:
	if not _gameplay_started:
		return
	if _solar_death:
		return
	if ship.is_dying or _player_death_pending:
		return
	if departure.active:
		return
	if planet_3_departure.active and planet_3_departure.camera_controls_enabled:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			planet_3_departure.rotate_camera(-event.relative.x * mouse_sensitivity, -event.relative.y * mouse_sensitivity)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if travelling:
		return
	if _crash_landed:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_crash_camera_direction = _crash_camera_direction.rotated(ship.radial_up, -event.relative.x * mouse_sensitivity).normalized()
			camera_pitch = clampf(camera_pitch - event.relative.y * mouse_sensitivity, -1.4, 1.4)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if not ship.controls_enabled:
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



func _update_sun() -> void:
	sun.scale = Vector3.ONE * sun_radius
	_update_sun_color()
	_update_sunlight()
	_update_ocean_sun()


func _update_sun_color() -> void:
	if _sun_final_started:
		_sun_material.set_shader_parameter("color_progress", 1.0)
		_sun_material.set_shader_parameter("collapse_progress", _sun_blue_blend)
		var red: Color = _sun_material.get_shader_parameter("red_color")
		var blue: Color = _sun_material.get_shader_parameter("blue_color")
		var red_brightness := maxf(maxf(red.r, red.g), maxf(red.b, 0.001))
		var blue_brightness := maxf(maxf(blue.r, blue.g), maxf(blue.b, 0.001))
		var red_tint := Color(red.r / red_brightness, red.g / red_brightness, red.b / red_brightness, 1.0)
		var blue_tint := Color(blue.r / blue_brightness, blue.g / blue_brightness, blue.b / blue_brightness, 1.0)
		var tint := red_tint.lerp(blue_tint, _sun_blue_blend)
		_sun_halo_material.set_shader_parameter("glow_color", tint * _sun_yellow_halo.r)
		sunlight.light_color = tint
		_environment.ambient_light_color = tint
		_environment.ambient_light_energy = lerpf(_normal_ambient_energy, sun_final_ambient_energy, _sun_blue_blend)
		return
	_sun_material.set_shader_parameter("collapse_progress", 0.0)
	# Fully red when the surface first touches the near side of planet 2.
	var red_radius := orbit_radii.y - planet_radii.y
	var progress := smoothstep(initial_sun_radius, maxf(red_radius, initial_sun_radius + 0.001), sun_radius)
	_sun_material.set_shader_parameter("color_progress", progress)
	var red: Color = _sun_material.get_shader_parameter("red_color")
	var brightness := maxf(maxf(red.r, red.g), maxf(red.b, 0.001))
	var red_halo := Color(red.r, red.g, red.b, red.a) * (_sun_yellow_halo.r / brightness)
	red_halo.a = _sun_yellow_halo.a
	_sun_halo_material.set_shader_parameter("glow_color", _sun_yellow_halo.lerp(red_halo, progress))
	# Keep some white illumination so terrain retains detail under the red sun.
	var red_tint := Color(red.r / brightness, red.g / brightness, red.b / brightness, 1.0)
	var light_tint := Color.WHITE.lerp(red_tint, progress * 0.7)
	sunlight.light_color = light_tint
	_environment.ambient_light_color = light_tint


func _sun_surface_color() -> Color:
	var yellow: Color = _sun_material.get_shader_parameter("yellow_color")
	var red: Color = _sun_material.get_shader_parameter("red_color")
	var progress: float = _sun_material.get_shader_parameter("color_progress")
	var blue: Color = _sun_material.get_shader_parameter("blue_color")
	return yellow.lerp(red, progress).lerp(blue, _sun_blue_blend)


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
	energy = clampf(energy, 0.0, maxf(sunlight_max_energy, 0.0))
	if _sun_final_started:
		energy = lerpf(energy, sun_final_light_energy, _sun_blue_blend)
	sunlight.light_energy = energy * lerpf(1.0, 10.0, _sun_flash_strength)


func _travel_to_next_planet(continue_from_departure := false) -> void:
	if _solar_death or (travelling and not continue_from_departure):
		return
	explosion_dialogue_delay.stop()
	fuel_cells.clear()
	_explosion_dialogue_in_progress = false
	if current_planet == 0:
		_fade_out_planet_1_music()
		phase_2_music.stop()
	elif current_planet == 1:
		planet_2_music.stop()
	forest_ambience.stop()
	terminal.close()
	if current_planet == 0 and not continue_from_departure:
		_begin_planet_1_departure()
		return
	if current_planet == 1:
		_begin_planet_3_departure()
		return
	departure.cancel()
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
	_travel_tween = create_tween()
	_travel_tween.tween_method(_set_frame_origin, frame_origin, target_origin, maxf(travel_duration, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _travel_tween.finished
	# Rebase everything together: destination at zero, no visible camera/ship jump.
	current_planet = destination
	_set_frame_origin(solar_positions[destination])
	ship.position = fixed_ship_position - destination_center
	ship.bind_to_planet(planets[destination])
	ship.set_view_direction(view_direction)
	ship.set_movement_profile(current_planet)
	ship.controls_enabled = true
	ship.mouse_look_enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	terminal.set_process(true)
	terminal.set_process_input(true)
	battle.set_active(current_planet == 1)
	travelling = false
	_update_occluders()
	_update_camera()
	_update_sunlight()


func _heat_planet_1() -> void:
	if not _heated_surfaces.is_empty():
		return
	_heat_color = _sun_surface_color()
	_heat_color = Color(_heat_color.r * 0.3, _heat_color.g * 0.3, _heat_color.b * 0.5, _heat_color.a)
	_heat_material = ShaderMaterial.new()
	_heat_material.shader = EngulfedSurface
	_heat_material.set_shader_parameter("surface_color", _heat_color)
	_heat_material.set_shader_parameter("reveal", 0.0)
	var pending: Array[Node] = [planets[0]]
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if node is GeometryInstance3D:
			var geometry := node as GeometryInstance3D
			if node.name == &"Atmosphere":
				_heated_surfaces.append({"node": geometry, "override": geometry.material_override})
				_heat_atmosphere = geometry.material_override.duplicate() as ShaderMaterial
				_heat_atmosphere_color = _heat_atmosphere.get_shader_parameter("glow_color")
				geometry.material_override = _heat_atmosphere
			else:
				_heated_surfaces.append({"node": geometry, "overlay": geometry.material_overlay})
				geometry.material_overlay = _heat_material
		pending.append_array(node.get_children())
	_set_planet_1_heat(0.1)
	_heat_tween = create_tween()
	_heat_tween.tween_method(_set_planet_1_heat, 0.1, 1.0, 60.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_planet_1_heat(strength: float) -> void:
	_heat_material.set_shader_parameter("reveal", strength)
	if _heat_atmosphere != null:
		_heat_atmosphere.set_shader_parameter("glow_color", _heat_atmosphere_color.lerp(_heat_color, strength))


func _restore_planet_1_materials() -> void:
	if _heat_tween != null:
		_heat_tween.kill()
	for entry in _heated_surfaces:
		if not is_instance_valid(entry["node"]):
			continue
		if entry.has("override"):
			entry["node"].material_override = entry["override"]
		else:
			entry["node"].material_overlay = entry["overlay"]
	_heated_surfaces.clear()
	_heat_material = null
	_heat_atmosphere = null


func _begin_planet_1_departure() -> void:
	departure_music.play()
	travelling = true
	_left_platform = true
	_repulsion_countdown = -1.0
	_opening_camera_blend = 0.0
	_opening_framing_weight = 0.0
	_rocket_audio_enabled = true
	battle.set_active(false)
	terminal.set_process(false)
	terminal.set_process_input(false)
	terminal.allow_toggle = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	departure.begin(ship, planets[0], planets[1], camera, sun)
	_update_occluders()


func _begin_departure_farewell() -> void:
	if _arrival_skipping or not departure.active:
		return
	_arrival_dialogue_phase = "farewell"
	terminal.set_process(true)
	terminal.set_process_input(true)
	terminal.play_dialogue(ArrivalDialogue.FAREWELL, true, false)


func _begin_arrival_conversation() -> void:
	if _arrival_skipping or _arrival_dialogue_phase != "farewell":
		return
	_arrival_dialogue_phase = "arrival"
	terminal.play_dialogue(ArrivalDialogue.ARRIVAL, true, false)


func _on_arrival_message_finished(index: int) -> void:
	var messages: Array = ArrivalDialogue.FAREWELL if _arrival_dialogue_phase == "farewell" else ArrivalDialogue.ARRIVAL
	if index < 0 or index >= messages.size():
		return
	match messages[index].get("event", ""):
		"face_planet_2":
			terminal.set_progress_blocked(true)
			departure.face_destination()
		"begin_combat":
			_start_protected_combat()
		"enable_threatwatch":
			battle.set_hud_enabled(true)


func _on_arrival_message_advanced(index: int) -> void:
	if _arrival_dialogue_phase != "arrival" or index < 0 or index >= ArrivalDialogue.ARRIVAL.size():
		return
	if ArrivalDialogue.ARRIVAL[index].get("advance_event", "") == "eject_weapons":
		_eject_weapons_module()


func _start_protected_combat() -> void:
	battle.set_protected_mode(true)
	if not battle.active:
		battle.set_active(true)
		warzone_audio.start()


func _eject_weapons_module() -> void:
	if _weapons_ejected:
		return
	_weapons_ejected = true
	var debris := weapons_module.duplicate() as Node3D
	cutscene_debris.add_child(debris)
	debris.global_transform = weapons_module.global_transform
	weapons_module.hide()
	var target: Vector3 = debris.global_position + departure.velocity * 2.0 - ship.global_basis.y.normalized() * 10.0
	var animation := create_tween().bind_node(debris)
	animation.set_parallel(true)
	animation.tween_property(debris, "global_position", target, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	animation.tween_property(debris, "rotation", debris.rotation + Vector3(0.8, 1.5, 0.4), 2.0)
	animation.chain().tween_interval(3.0)
	animation.chain().tween_property(debris, "scale", Vector3.ONE * 0.01, 0.5)
	animation.chain().tween_callback(debris.queue_free)


func _skip_arrival_cutscene() -> void:
	_arrival_skipping = true
	_arrival_dialogue_phase = ""
	terminal.stop_dialogue()
	_start_protected_combat()
	_eject_weapons_module()
	battle.set_hud_enabled(true)
	departure.skip_to_gameplay()
	_arrival_skipping = false


func _finish_planet_2_arrival() -> void:
	departure_music.stop()
	var flight_velocity: Vector3 = departure.velocity
	var offset := solar_positions[1] - frame_origin
	ship.position -= offset
	camera.position -= offset
	current_planet = 1
	_set_frame_origin(solar_positions[1])
	ship.set_movement_profile(1)
	ship.bind_to_planet(planets[1])
	ship.set_world_velocity(flight_velocity)
	ship.controls_enabled = true
	ship.mouse_look_enabled = true
	ship.horizontal_input_enabled = true
	ship.ascend_input_enabled = true
	ship.descend_input_enabled = true
	ship.surface_repulsion_enabled = true
	travelling = false
	_arrival_dialogue_phase = ""
	terminal.allow_toggle = true
	terminal.set_process(true)
	terminal.set_process_input(true)
	terminal.stop_dialogue()
	_gameplay_camera_local = ship.global_transform.affine_inverse() * camera.global_transform
	_gameplay_camera_blend = 0.0
	_update_occluders()
	battle.sync_player_position()
	battle.set_protected_mode(false)
	_planet2_fight_elapsed = 0.0
	_planet2_overheat_elapsed = 0.0
	_planet2_overheat_started = false
	_planet2_dialogue_started = false
	_planet2_explanation_finished = false
	_planet2_fleet_destroyed = false
	_planet2_cells_spawned = false
	_planet2_cells_collected = false
	_sun_passed_planet2_200m = false
	_sun_passed_planet2_100m = false
	# This clock starts with mus3 and the return of full player controls.
	var target_radius := sun.global_position.distance_to(planets[1].global_position) - planet_radii.y - planet_2_sun_approach_gap
	sun_expansion_speed = maxf(target_radius - sun_radius, 0.0) / maxf(planet_2_sun_approach_time, 0.001)
	_sun_expanding = true
	planet_2_music.play()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _begin_planet_3_departure() -> void:
	warzone_audio.stop()
	departure_music.play()
	travelling = true
	_planet2_dialogue_phase = ""
	terminal.stop_dialogue()
	terminal.allow_toggle = false
	terminal.set_process_input(false)
	battle.set_active(false)
	_opening_camera_blend = 0.0
	_opening_framing_weight = 0.0
	_rocket_audio_enabled = true
	planet_3_departure.begin(ship, planets[1], planets[2], camera, sun)
	var target_radius := sun.global_position.distance_to(planets[2].global_position) - planet_radii.z - planet_3_sun_approach_gap
	_planet3_sun_stop_radius = target_radius
	sun_expansion_speed = maxf(target_radius - sun_radius, 0.0) / maxf(planet_3_sun_approach_time, 0.001)
	_sun_expanding = true
	_update_occluders()


func _heat_planet_2() -> void:
	_heat_color = _sun_surface_color()
	_heat_color = Color(_heat_color.r * 0.3, _heat_color.g * 0.3, _heat_color.b * 0.5, _heat_color.a)
	var material := ShaderMaterial.new()
	material.shader = EngulfedSurface
	material.set_shader_parameter("surface_color", _heat_color)
	material.set_shader_parameter("reveal", 0.0)
	var pending: Array[Node] = [planets[1]]
	var atmospheres: Array[Dictionary] = []
	while not pending.is_empty():
		var node := pending.pop_back() as Node
		if node is GeometryInstance3D:
			var geometry := node as GeometryInstance3D
			if node.name == &"Atmosphere":
				_heated_surfaces.append({"node": geometry, "override": geometry.material_override})
				var atmosphere := geometry.material_override.duplicate() as ShaderMaterial
				atmospheres.append({"material": atmosphere, "color": atmosphere.get_shader_parameter("glow_color")})
				geometry.material_override = atmosphere
			else:
				_heated_surfaces.append({"node": geometry, "overlay": geometry.material_overlay})
				geometry.material_overlay = material
		pending.append_array(node.get_children())
	_heat_tween = create_tween()
	_heat_tween.tween_method(_set_planet_2_heat.bind(material, atmospheres), 0.0, 1.0, planet_3_departure.source_color_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_planet_2_heat(strength: float, material: ShaderMaterial, atmospheres: Array[Dictionary]) -> void:
	material.set_shader_parameter("reveal", strength)
	for entry in atmospheres:
		var color: Color = entry["color"]
		entry["material"].set_shader_parameter("glow_color", color.lerp(_heat_color, strength))


func _finish_planet_3_crash() -> void:
	booster_dialogue_delay.stop()
	landing_dialogue_delay.start()
	var landed_transform := ship.global_transform
	var offset := solar_positions[2] - frame_origin
	ship.position -= offset
	camera.position -= offset
	for effect: Node3D in cutscene_debris.get_children():
		effect.global_position -= offset
	current_planet = 2
	_set_frame_origin(solar_positions[2])
	ship.set_movement_profile(2)
	ship.bind_to_planet(planets[2])
	# Binding prepares radial camera coordinates; freeze motion and retain the
	# authored crash attitude instead of letting stabilization level the hull.
	ship.global_basis = landed_transform.basis
	ship.controls_enabled = false
	ship.mouse_look_enabled = false
	ship.set_process(false)
	ship.set_cutscene_thrust(0.0, 0.0)
	ship.set_model_emission_enabled(false)
	_crash_landed = true
	travelling = false
	_rocket_audio_enabled = false
	rocket_audio.stop()
	var up := ship.radial_up
	var forward := -camera.global_basis.z
	_crash_camera_direction = (forward - up * forward.dot(up)).normalized()
	if _crash_camera_direction.length_squared() < 0.001:
		_crash_camera_direction = ship.view_forward
	camera_pitch = clampf(asin(clampf(forward.dot(up), -1.0, 1.0)), -1.4, 1.4)
	_gameplay_camera_local = ship.global_transform.affine_inverse() * camera.global_transform
	_gameplay_camera_blend = 0.0
	terminal.allow_toggle = true
	terminal.set_process_input(true)
	_update_occluders()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_planet_3_boosters_failed() -> void:
	terminal.set_process(true)
	terminal.set_process_input(true)
	terminal.allow_toggle = false
	booster_dialogue_delay.start()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _begin_booster_dialogue() -> void:
	if not planet_3_departure.active or _solar_death or _sun_final_started:
		return
	_planet3_dialogue_phase = "malfunction"
	terminal.play_dialogue(Planet3Dialogue.MALFUNCTION, true, false)


func _begin_landing_dialogue() -> void:
	if not _crash_landed or _solar_death or _sun_final_started:
		return
	_planet3_dialogue_phase = "landing"
	terminal.play_dialogue(Planet3Dialogue.AFTER_LANDING, true, false)


func _on_planet_3_crash_impact() -> void:
	var explosion = preload("res://combat/explosion.tscn").instantiate()
	explosion.size_multiplier = 3.0
	explosion.initial_scale = 1.0
	explosion.lifetime = 1.2
	cutscene_debris.add_child(explosion)
	explosion.global_position = ship.global_position
	player_death_explosion_audio.play()


func _on_player_missile_hit() -> void:
	if not _solar_death:
		player_hit_audio.play()


func _on_player_destroyed() -> void:
	if _player_death_pending or _solar_death:
		return
	_player_death_pending = true
	ship.controls_enabled = false
	ship.mouse_look_enabled = false
	planet_2_music.stop()
	rocket_audio.stop()
	_rocket_audio_enabled = false
	player_death_explosion_audio.play()
	await get_tree().create_timer(1.2, false).timeout
	if _player_death_pending and not _solar_death:
		_show_solar_death()
