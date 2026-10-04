extends Node
## Four independently offset loops, thinned as the enemy fleet dies.
var _layers: Array[AudioStreamPlayer] = []
var _fades: Array[Tween] = []
var _enemy_deaths := 0
var _active_layers := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	var stream := $Layer1.stream.duplicate() as AudioStreamMP3
	stream.loop = true
	for child: AudioStreamPlayer in get_children():
		child.stream = stream
		_layers.append(child)


func start() -> void:
	stop()
	_enemy_deaths = 0
	_active_layers = _layers.size()
	for layer in _layers:
		layer.volume_db = 0.0
		layer.play(_rng.randf_range(0.0, layer.stream.get_length()))


func enemy_destroyed(remaining: int) -> void:
	if _active_layers == 0:
		return
	_enemy_deaths += 1
	if remaining == 0:
		stop()
	elif _enemy_deaths % 60 == 0:
		_active_layers -= 1
		var layer := _layers[_active_layers]
		var fade := create_tween()
		fade.tween_property(layer, "volume_db", -80.0, 0.35)
		fade.tween_callback(layer.stop)
		_fades.append(fade)


func stop() -> void:
	for fade in _fades:
		if fade.is_valid():
			fade.kill()
	_fades.clear()
	for layer in _layers:
		layer.stop()
	_active_layers = 0
