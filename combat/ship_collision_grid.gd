extends RefCounted
## Broad phase over each ship's swept bounds; narrow phase remains continuous.
const CELL_SIZE := 32.0
var hit_index: int = -1

var _cells: Dictionary = {}
var _previous := PackedVector3Array()
var _current := PackedVector3Array()
var _visited := PackedInt32Array()
var _query_id: int = 0
var _radius_squared: float

func rebuild(previous: PackedVector3Array, current: PackedVector3Array, radius: float) -> void:
	_previous = previous
	_current = current
	_radius_squared = radius * radius
	_cells.clear()
	_visited.resize(current.size())
	_visited.fill(0)
	_query_id = 0
	var padding := Vector3.ONE * radius
	for index in range(current.size()):
		var first := _cell(previous[index].min(current[index]) - padding)
		var last := _cell(previous[index].max(current[index]) + padding)
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				for z in range(first.z, last.z + 1):
					var key := Vector3i(x, y, z)
					if not _cells.has(key):
						_cells[key] = []
					_cells[key].append(index)

func first_hit(start: Vector3, end: Vector3, excluded_index: int) -> float:
	hit_index = -1
	_query_id += 1
	var hit_t := INF
	var motion := end - start
	var first := _cell(start.min(end))
	var last := _cell(start.max(end))
	for x in range(first.x, last.x + 1):
		for y in range(first.y, last.y + 1):
			for z in range(first.z, last.z + 1):
				var key := Vector3i(x, y, z)
				if not _cells.has(key):
					continue
				for index: int in _cells[key]:
					if index == excluded_index or _visited[index] == _query_id:
						continue
					_visited[index] = _query_id
					var relative_start := start - _previous[index]
					var c := relative_start.length_squared() - _radius_squared
					if c <= 0.0:
						hit_index = index
						return 0.0
					var relative_motion := motion - (_current[index] - _previous[index])
					var a := relative_motion.length_squared()
					if a <= 0.000001:
						continue
					var b := relative_start.dot(relative_motion)
					var discriminant := b * b - a * c
					if discriminant >= 0.0:
						var t := (-b - sqrt(discriminant)) / a
						if t >= 0.0 and t <= 1.0 and t < hit_t:
							hit_t = t
							hit_index = index
	return hit_t

func _cell(position: Vector3) -> Vector3i:
	return Vector3i((position / CELL_SIZE).floor())
