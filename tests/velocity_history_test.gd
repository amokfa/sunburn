extends SceneTree
const VelocityHistory = preload("res://combat/velocity_history.gd")

func _initialize() -> void:
	var history := VelocityHistory.new()
	assert(history.average() == Vector3.ZERO)
	history.add_sample(Vector3(10, 0, 0), 0.25)
	assert(history.average().is_equal_approx(Vector3(10, 0, 0)))
	history.add_sample(Vector3(0, 10, 0), 0.75)
	assert(history.average().is_equal_approx(Vector3(2.5, 7.5, 0)))
	# Trim the oldest samples, including part of the next sample.
	history.add_sample(Vector3(0, 0, 10), 0.5)
	assert(history.average().is_equal_approx(Vector3(0, 5, 5)))
	for index in range(600):
		history.add_sample(Vector3(3, 4, 5), 1.0 / 60.0)
	assert(history.average().is_equal_approx(Vector3(3, 4, 5)))
	history.add_sample(Vector3(20, 0, 0), 3.0)
	assert(history.average().is_equal_approx(Vector3(20, 0, 0)))
	print("PASS: one-second velocity average, time weighting, partial eviction, warmup and history compaction")
	quit()
