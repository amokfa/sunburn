extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game = load("res://scale_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.ship.set_process(false)
	var battle = game.battle
	var ship = battle.ships[0]
	var delays: Array[float] = []
	for enemy in battle.ships:
		assert(not battle._ready_to_fire(enemy, true, 0.01))
		assert(enemy.fire_reaction_remaining >= 0.2 and enemy.fire_reaction_remaining <= 1.2)
		delays.append(enemy.fire_reaction_remaining)
	assert(delays.max() - delays.min() > 0.8)
	assert(not battle._ready_to_fire(ship, false, 0.01))
	assert(ship.fire_reaction_remaining == -1.0)
	assert(not battle._ready_to_fire(ship, true, 0.01))
	var delay: float = ship.fire_reaction_remaining
	assert(not battle._ready_to_fire(ship, true, delay * 0.5))
	assert(battle._ready_to_fire(ship, true, delay * 0.5 + 0.001))
	var reloads: Array[float] = []
	for index in range(30):
		battle._fire(ship, Vector3.FORWARD)
		assert(ship.reload_remaining >= battle.reload_seconds * 0.8)
		assert(ship.reload_remaining <= battle.reload_seconds * 1.2)
		assert(ship.fire_reaction_remaining == -1.0)
		reloads.append(ship.reload_remaining)
	assert(reloads.max() - reloads.min() > battle.reload_seconds * 0.2)
	var phases: Array[float] = []
	var materials: Array[Material] = []
	for missile in battle.get_node("Missiles").get_children():
		var material: ShaderMaterial = missile.get_node("Body").material_override
		assert(not materials.has(material))
		materials.append(material)
		phases.append(material.get_shader_parameter("pulse_phase"))
	assert(phases.max() - phases.min() > 3.0)
	game.free()
	print("PASS: staggered reaction delays, cancellation, countdown, random reloads, shot reset and independent missile color phases")
	quit()
