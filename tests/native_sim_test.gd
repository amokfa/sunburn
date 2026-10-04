extends SceneTree

func _initialize():
	call_deferred("run")

func make_game(native: bool):
	var game = load("res://scale_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.ship.set_process(false)
	game.battle._population_rng.seed = 8294
	game.battle._rng.seed = 73129
	if not native:
		game.battle._native_sim = null
	game.battle.set_active(true)
	game.battle.set_process(false)
	for ship in game.battle.ships:
		ship.reload_remaining = 1000.0
	return game

func run():
	assert(ClassDB.class_exists("SunburnSimulation"))
	var native_game = make_game(true)
	var script_game = make_game(false)
	assert(native_game.battle.ships.size() == script_game.battle.ships.size())
	for frame in range(180):
		native_game.battle._process(1.0 / 60.0)
		script_game.battle._process(1.0 / 60.0)
	var max_position := 0.0
	var max_velocity := 0.0
	for i in range(native_game.battle.ships.size()):
		var a = native_game.battle.ships[i]
		var b = script_game.battle.ships[i]
		max_position = maxf(max_position, a.position.distance_to(b.position))
		max_velocity = maxf(max_velocity, a._velocity.distance_to(b._velocity))
		assert(a.target.get_index() == b.target.get_index())
	print("Native parity: max position ", max_position, "m; velocity ", max_velocity, "m/s")
	assert(max_position < 0.03)
	assert(max_velocity < 0.03)
	var native_time := 0
	var script_time := 0
	for frame in range(120):
		var start := Time.get_ticks_usec()
		native_game.battle._process(1.0 / 60.0)
		native_time += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		script_game.battle._process(1.0 / 60.0)
		script_time += Time.get_ticks_usec() - start
	print("CPU fleet: native ", native_time / 120.0, "us/frame; GDScript ", script_time / 120.0, "us/frame")
	var sim = native_game.battle._native_sim
	for target in [Vector3(240,0,0), Vector3(240,50,0), Vector3(0,0,240)]:
		var tangent := Vector3.UP
		var a: Vector3 = sim.intercept_direction(Vector3(250,0,10),target,tangent,40.0,2.0,90.0)
		var b: Vector3 = load("res://combat/orbital_intercept.gd").direction(Vector3(250,0,10),target,tangent,40.0,2.0,90.0,8.0)
		assert(a.distance_to(b) < 0.0001)
	native_game.free()
	script_game.free()
	print("PASS: native fleet behavior and orbital intercept match GDScript")
	quit()
