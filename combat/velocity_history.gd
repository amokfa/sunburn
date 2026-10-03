extends RefCounted
## Time-weighted velocity over the most recent second.
const WINDOW_SECONDS := 1.0
var _velocities: Array[Vector3] = []
var _durations: Array[float] = []
var _head := 0
var _duration := 0.0
var _integral := Vector3.ZERO

func add_sample(velocity: Vector3, delta: float) -> void:
	if delta <= 0.0:
		return
	if delta >= WINDOW_SECONDS:
		_velocities.assign([velocity])
		_durations.assign([WINDOW_SECONDS])
		_head = 0
		_duration = WINDOW_SECONDS
		_integral = velocity * WINDOW_SECONDS
		return
	_velocities.append(velocity)
	_durations.append(delta)
	_duration += delta
	_integral += velocity * delta
	var excess := _duration - WINDOW_SECONDS
	while excess > 0.0 and _head < _durations.size():
		var removed := minf(excess, _durations[_head])
		_integral -= _velocities[_head] * removed
		_duration -= removed
		_durations[_head] -= removed
		excess -= removed
		if _durations[_head] <= 0.0:
			_head += 1
	if _head >= 128:
		_velocities = _velocities.slice(_head)
		_durations = _durations.slice(_head)
		_head = 0

func average() -> Vector3:
	return _integral / _duration if _duration > 0.0 else Vector3.ZERO
