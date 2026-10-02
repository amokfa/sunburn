extends StaticBody3D
## A closed radial mesh, also sampled directly so penetration works from inside.
@onready var collision_shape: CollisionShape3D = $Shape
var _triangles := TriangleMesh.new()

func _ready() -> void:
	_triangles.create_from_faces((collision_shape.shape as ConcavePolygonShape3D).get_faces())

func surface_radius(local_direction: Vector3) -> float:
	return _sample_radius(_triangles, local_direction)

func _sample_radius(triangles: TriangleMesh, local_direction: Vector3) -> float:
	var direction := local_direction.normalized()
	var hit := triangles.intersect_ray(Vector3.ZERO, direction)
	if hit.is_empty():
		# Floating point rays can fall between faces at an exact edge or pole.
		# Retry a nearly identical direction (millimetres at our planet sizes).
		var reference := Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT
		var tangent := direction.cross(reference).normalized()
		hit = triangles.intersect_ray(Vector3.ZERO, (direction + tangent * 0.00001).normalized())
	return hit.position.length() * global_basis.x.length() if not hit.is_empty() else 0.0
