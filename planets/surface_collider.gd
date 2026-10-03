extends StaticBody3D
## A closed radial mesh, also sampled directly so penetration works from inside.
@export_range(8, 256) var radial_segments := 64
@export_range(4, 128) var rings := 32
@onready var collision_shape: CollisionShape3D = $Shape
var _triangles := TriangleMesh.new()

func _ready() -> void:
	var terrain := get_parent().get_node("Terrain") as MeshInstance3D
	var terrain_triangles := TriangleMesh.new()
	terrain_triangles.create_from_faces(terrain.mesh.get_faces())
	var terrain_to_collider := transform.affine_inverse() * terrain.transform
	var collider_to_terrain := terrain_to_collider.affine_inverse()
	var water_radius := 0.0
	var ocean := get_parent().get_node_or_null("Ocean") as MeshInstance3D
	if ocean != null:
		var ocean_to_collider := transform.affine_inverse() * ocean.transform
		water_radius = (ocean.mesh as SphereMesh).radius * ocean_to_collider.basis.x.length()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = radial_segments
	sphere.rings = rings
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in range(vertices.size()):
		var direction := vertices[index].normalized()
		var origin := collider_to_terrain * Vector3.ZERO
		var ray := collider_to_terrain.basis * direction
		var hit := terrain_triangles.intersect_ray(origin, ray)
		if hit.is_empty():
			var reference := Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT
			var retry := (direction + direction.cross(reference).normalized() * 0.00001).normalized()
			hit = terrain_triangles.intersect_ray(origin, collider_to_terrain.basis * retry)
		if hit.is_empty():
			push_error("Missing terrain intersection while generating planet collider")
			return
		var ground_radius: float = (terrain_to_collider * hit.position).length()
		vertices[index] = direction * maxf(water_radius, ground_radius)
	var faces := PackedVector3Array()
	var mesh_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in mesh_indices:
		faces.append(vertices[index])
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collision_shape.shape = shape
	_triangles.create_from_faces(faces)

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
