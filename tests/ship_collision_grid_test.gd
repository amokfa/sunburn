extends SceneTree
const CollisionGrid = preload("res://combat/ship_collision_grid.gd")

func _initialize() -> void:
	var grid := CollisionGrid.new()
	var previous := PackedVector3Array([Vector3(-50, 0, 0)])
	var current := PackedVector3Array([Vector3(50, 0, 0)])
	grid.rebuild(previous, current, 1.0)
	assert(is_equal_approx(grid.first_hit(Vector3.ZERO, Vector3.ZERO, -1), 0.49))
	assert(is_inf(grid.first_hit(Vector3.ZERO, Vector3.ZERO, 0)))
	# Include negative cell boundaries and a hit at the very end of the segment.
	previous = PackedVector3Array([Vector3(-32, 0, 0), Vector3(32, 0, 0)])
	grid.rebuild(previous, previous, 1.0)
	assert(is_equal_approx(grid.first_hit(Vector3(-34, 0, 0), Vector3(-33, 0, 0), -1), 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4829
	var hit_count := 0
	for sample in range(10):
		previous.clear()
		current.clear()
		for index in range(200):
			var position := _random_vector(rng, 80.0)
			previous.append(position)
			current.append(position + _random_vector(rng, 60.0))
		grid.rebuild(previous, current, 1.0)
		for query in range(100):
			var start := _random_vector(rng, 100.0)
			var end := _random_vector(rng, 100.0)
			var excluded := rng.randi_range(-1, 199)
			var expected := _brute_force(previous, current, start, end, excluded)
			var actual := grid.first_hit(start, end, excluded)
			if is_inf(expected):
				assert(is_inf(actual))
			else:
				hit_count += 1
				assert(absf(actual - expected) < 0.00001)
	assert(hit_count > 0)
	print("PASS: swept collision grid matches brute force for 1,000 randomized queries (", hit_count, " hits), crossing ships, cell boundaries, and launcher exclusion.")
	quit()

func _random_vector(rng: RandomNumberGenerator, extent: float) -> Vector3:
	return Vector3(rng.randf_range(-extent, extent), rng.randf_range(-extent, extent), rng.randf_range(-extent, extent))

func _brute_force(previous: PackedVector3Array, current: PackedVector3Array, start: Vector3, end: Vector3, excluded: int) -> float:
	var result := INF
	for index in range(current.size()):
		if index == excluded:
			continue
		var offset := start - previous[index]
		var motion := (end - start) - (current[index] - previous[index])
		var a := motion.length_squared()
		var c := offset.length_squared() - 1.0
		if c <= 0.0:
			return 0.0
		if a <= 0.000001:
			continue
		var b := offset.dot(motion)
		var discriminant := b * b - a * c
		if discriminant >= 0.0:
			var t := (-b - sqrt(discriminant)) / a
			if t >= 0.0 and t <= 1.0:
				result = minf(result, t)
	return result
