extends Node
## Player-only rocket loops. Authored players fade in and out with active boosters.
@export var base_volume_db := -6.0
@export var additional_layer_volume_db := -16.0
@export var fade_response := 6.0
var _players: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for child in get_children():
		if child is AudioStreamPlayer:
			_players.append(child)
			child.volume_linear = 0.0
			child.pitch_scale = _rng.randf_range(0.97, 1.03)
			if child.stream is AudioStreamMP3:
				child.stream.loop = true


func update_layers(booster_count: int, enabled: bool, delta: float) -> void:
	var count := clampi(booster_count, 1, _players.size()) if enabled else 0
	var response := 1.0 - exp(-fade_response * delta) if delta > 0.0 else 1.0
	for index in range(_players.size()):
		var player := _players[index]
		var volume_db := base_volume_db if index == 0 else additional_layer_volume_db
		var target := db_to_linear(volume_db) if index < count else 0.0
		# Set the gain before starting playback so the first audio block is audible.
		player.volume_linear = lerpf(player.volume_linear, target, response)
		if target > 0.0 and not player.playing:
			player.play(_rng.randf_range(0.0, maxf(player.stream.get_length() - 0.1, 0.0)))
		if target == 0.0 and player.volume_linear < 0.0001:
			player.volume_linear = 0.0
			player.stop()


func stop() -> void:
	for player in _players:
		player.stop()
		player.volume_linear = 0.0
