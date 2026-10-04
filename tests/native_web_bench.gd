extends Node

var game: Node3D
var clock := 0.0
var elapsed := 0.0
var frames := 0
var cpu_us := 0
var peak_missiles := 0
var finished := false

func _ready():
	game = load("res://scale_prototype.tscn").instantiate()
	add_child(game)
	game.set_process(false)
	game.ship.set_process(false)
	game.game_menu.panel.hide()
	game.game_menu.mode = game.game_menu.Mode.MAIN
	game._gameplay_started = true
	game._intro_in_progress = false
	game._left_platform = true
	game._opening_camera_blend = 0.0
	game._opening_framing_weight = 0.0
	game.intro_music.stop()
	game.forest_ambience.stop()
	game.ship.set_parked(false)
	game.ship.position = game.solar_positions[1] - game.frame_origin + Vector3.UP * (game.planet_radii.y + 40.0)
	game._finish_planet_2_arrival()
	if OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).get('native') === '0'"):
		game.battle._native_sim = null
	game.battle._population_rng.seed = 8294
	game.battle._rng.seed = 73129
	game.battle.set_active(true)
	game.battle.set_process(false)
	game.battle.damage_enabled = false
	game.battle.set_hud_enabled(true)
	game._gameplay_camera_blend = 1.0
	game._update_camera()
	game._update_sunlight()
	game.ship.set_process(false)
	# Keep the same views and population; invulnerability prevents benchmark length
	# from changing the number of ships through deaths.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("WEB_BENCH_START native=", game.battle._native_sim != null, " ships=", game.battle.ships.size())

func _process(delta):
	if finished:
		return
	clock += delta
	var start := Time.get_ticks_usec()
	game.battle._process(delta)
	var cpu := Time.get_ticks_usec() - start
	peak_missiles = maxi(peak_missiles, game.battle._missiles.get_child_count())
	if clock < 30.0:
		return
	elapsed += delta
	frames += 1
	cpu_us += cpu
	if elapsed >= 10.0:
		finished = true
		print("WEB_BENCH_RESULT ", JSON.stringify({"native": game.battle._native_sim != null, "ships": game.battle.ships.size(), "fps": frames / elapsed, "cpu_ms": cpu_us / float(frames) / 1000.0, "peak_missiles": peak_missiles}))
