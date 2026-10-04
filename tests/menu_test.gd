extends SceneTree
## Run: godot --headless --path . --script tests/menu_test.gd
## Exercises the menu against a small paused world; does not run the game.
var _checks_failed := false

class Travel extends Node:
	var active := false

class World extends Node:
	var menu: CanvasLayer
	var can_skip := false
	var wants_capture := false
	var began := false
	var aborted := false
	var skipped := false
	var clock := 0.0
	var tween_value := 0.0
	func _process(delta: float) -> void:
		clock += delta
	func menu_expects_mouse_capture() -> bool:
		return wants_capture
	func menu_can_skip_cutscene() -> bool:
		return can_skip
	func begin() -> void:
		began = true
	func pause_game() -> void:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	func resume_game() -> void:
		get_tree().paused = false
	func abort() -> void:
		aborted = true
		get_tree().paused = false
		menu.show_main()
	func skip() -> void:
		skipped = true
		can_skip = false
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		_checks_failed = true
func run() -> void:
	var world := World.new()
	root.add_child(world)
	var menu = load("res://ui/game_menu.tscn").instantiate()
	world.menu = menu
	menu.slide_duration = 0.01
	menu.fade_duration = 0.01
	world.add_child(menu)
	menu.begin_requested.connect(world.begin)
	menu.pause_requested.connect(world.pause_game)
	menu.resume_requested.connect(world.resume_game)
	menu.abort_requested.connect(world.abort)
	menu.skip_cutscene_requested.connect(world.skip)
	var master: float = menu._master_volume_db
	menu.show_main()
	check(menu.mode == menu.Mode.MAIN and not menu.skip.visible, "Main menu should hide skip")
	await create_timer(0.08).timeout
	check(menu.fade.modulate.a == 0.0, "Boot fade should complete")
	check(absf(AudioServer.get_bus_volume_db(0) - master) < 0.001, "Boot must restore master volume")
	menu._on_primary_pressed()
	await create_timer(0.06).timeout
	check(world.began and menu.mode == menu.Mode.PLAYING, "Begin should slide out and start intro")
	var audio := AudioStreamPlayer.new()
	world.add_child(audio)
	var game_timer := create_timer(0.3, false)
	world.create_tween().tween_property(world, "tween_value", 1.0, 0.4)
	menu.request_pause()
	var frozen_clock := world.clock
	var frozen_tween := world.tween_value
	var frozen_timer := game_timer.time_left
	await create_timer(0.08).timeout
	check(paused and menu.mode == menu.Mode.PAUSE, "Pause should freeze scene tree")
	check(world.clock == frozen_clock and world.tween_value == frozen_tween, "Simulation and game tween must freeze")
	check(absf(game_timer.time_left - frozen_timer) < 0.001, "Game timer must freeze")
	check(not audio.can_process(), "Audio node must inherit scene pause")
	check(menu.panel.position.x == 32.0 and not menu.skip.visible, "Pause menu should animate while paused, hide skip outside cutscene")
	menu._on_primary_pressed()
	await create_timer(0.06).timeout
	check(not paused and audio.can_process() and world.clock > frozen_clock, "Resume should restore simulation and audio")
	world.can_skip = true
	menu.request_pause()
	check(menu.skip.visible, "Cutscene skip should be available during cutscene")
	menu._on_skip_pressed()
	await create_timer(0.06).timeout
	check(world.skipped and not paused, "Skip should skip cutscene and resume")
	world.wants_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu._process(0.0)
	check(paused, "Losing pointer lock must pause the whole game")
	world.wants_capture = false
	menu._on_primary_pressed()
	await create_timer(0.06).timeout
	menu._focus_lost()
	check(paused, "Focus loss should pause")
	menu._focus_gained()
	check(paused, "Focus return should wait for Resume")
	menu._on_secondary_pressed()
	await create_timer(0.12).timeout
	check(world.aborted and not paused and menu.mode == menu.Mode.MAIN, "Abort should return to main menu")
	check(menu.primary.text == "Begin" and menu.secondary.text == "Quit", "Main menu labels should restore")
	var main: Node3D = load("res://scale_prototype.tscn").instantiate()
	for pair in [[1.0, 0.5], [5.0, 1.0], [10.0, 2.0]]:
		main._set_camera_sensitivity(pair[0])
		check(absf(main.mouse_sensitivity / main._base_mouse_sensitivity - pair[1]) < 0.0001, "Sensitivity endpoints must match")
	# Exercise the real story's eligibility, not just the menu's mock world.
	main.departure = Travel.new()
	main.planet_3_departure = Travel.new()
	main.explosion_dialogue_delay = main.get_node("ExplosionDialogueDelay")
	main.landing_dialogue_delay = main.get_node("LandingDialogueDelay")
	main._gameplay_started = true
	check(not main.menu_can_skip_cutscene(), "Ordinary gameplay must not expose cutscene skip")
	for flag in ["_intro_in_progress", "_explosion_dialogue_in_progress", "travelling"]:
		main.set(flag, true)
		check(main.menu_can_skip_cutscene(), "Skip must cover " + flag)
		main.set(flag, false)
	for phase in ["overheat", "fuel"]:
		main._planet2_dialogue_phase = phase
		check(main.menu_can_skip_cutscene(), "Planet 2 story conversations must expose skip")
	main._planet2_dialogue_phase = ""
	for phase in ["malfunction", "landing", "collapse_wait", "collapse"]:
		main._planet3_dialogue_phase = phase
		check(main.menu_can_skip_cutscene(), "Planet 3 story sequences must expose skip")
	main._planet3_dialogue_phase = "ended"
	check(not main.menu_can_skip_cutscene(), "Finished finale must not expose skip")
	var story = load("res://ui/assistant_terminal.tscn").instantiate()
	root.add_child(story)
	main.terminal = story
	story.message_finished.connect(main._on_intro_message_finished)
	story.dialogue_finished.connect(main._on_intro_finished)
	main._sun_final_started = true
	main._planet3_dialogue_phase = "collapse"
	story.play_dialogue(main.Planet3Dialogue.ON_COLLAPSE)
	main._skip_active_cutscene()
	check(main._planet3_dialogue_phase == "ended", "Finale skip must retain the ended state")
	check(story._is_open and not story.is_processing_input(), "Finale skip must leave the transcript open with input disabled")
	main.departure.free()
	main.planet_3_departure.free()
	story.free()
	main.free()
	world.free()
	await process_frame
	if _checks_failed:
		quit(1)
		return
	print("Menu checks passed: boot/abort fades, Begin, pause/resume, timers, tweens, audio, focus, cutscene-only skip, sensitivity. Game scene was not run.")
	quit()
