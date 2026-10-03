extends SceneTree
## Verify runtime collider generation without rebaking any resources.
func _initialize() -> void:
	call_deferred("generate")

func generate() -> void:
	for kind in range(3):
		var planet := load("res://planets/planet%d.tscn" % (kind + 1)).instantiate() as Node3D
		root.add_child(planet)
		var shape := planet.get_node("SurfaceCollider/Shape") as CollisionShape3D
		assert(shape.shape is ConcavePolygonShape3D)
		print("Planet %d: %d runtime collider triangles" % [kind + 1, shape.shape.get_faces().size() / 3])
		planet.free()
	quit()
