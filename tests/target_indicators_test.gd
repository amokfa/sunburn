extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	var game = load("res://scale_prototype.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.ship.set_process(false)
	var battle = game.battle
	var layer: CanvasLayer = battle.get_node("TargetIndicators")
	var indicators = layer.get_node("Crosshairs")
	assert(not layer.visible and not indicators.is_processing())
	battle.ships.assign(battle.ships.slice(0, 2))
	battle.set_active(true)
	battle.set_process(false)
	assert(layer.visible and indicators.is_processing())
	assert(indicators.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var first = battle.ships[0]
	var second = battle.ships[1]
	first.target = game.ship
	second.target = first
	assert(indicators._indicator_color(first) == indicators.targeting_player_color)
	assert(indicators._indicator_color(second).a == 0.0)
	first.target = second
	assert(indicators._indicator_color(first).a == 0.0)
	battle.set_active(false)
	assert(not layer.visible and not indicators.is_processing())
	game.free()
	print(
		"PASS: player-targeting reticles stay red; other reticles are hidden. ",
		"Travel/reset hides and stops the HUD."
	)
	quit()
