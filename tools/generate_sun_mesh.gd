extends SceneTree
## Run with: godot --headless --path . --script tools/generate_sun_mesh.gd
## Rebuild the static unit-radius mesh after changing SUBDIVISIONS or DENSITY_DOUBLINGS.
const SUBDIVISIONS := 5
# A shared-edge bisection doubles the final triangle count without cracks.
const DENSITY_DOUBLINGS := 2
var vertices: Array[Vector3] = []
var edge_midpoints: Dictionary = {}

func midpoint(a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if edge_midpoints.has(key):
		return edge_midpoints[key]
	var index := vertices.size()
	vertices.append((vertices[a] + vertices[b]).normalized())
	edge_midpoints[key] = index
	return index

func _initialize() -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	vertices.assign([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)])
	for index in range(vertices.size()):
		vertices[index] = vertices[index].normalized()
	var faces: Array[Vector3i] = []
	faces.assign([
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
		Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1)])
	# Paired edges form a matching of the 20 base faces. Propagate that matching
	# through subdivision so every final face shares its split edge with a neighbor.
	var split_edges: Array[Vector2i] = [
		Vector2i(0, 5), Vector2i(0, 5), Vector2i(0, 7), Vector2i(0, 7), Vector2i(10, 11),
		Vector2i(5, 9), Vector2i(4, 11), Vector2i(10, 11), Vector2i(6, 10), Vector2i(7, 8),
		Vector2i(3, 4), Vector2i(3, 4), Vector2i(3, 6), Vector2i(3, 6), Vector2i(8, 9),
		Vector2i(5, 9), Vector2i(4, 11), Vector2i(6, 10), Vector2i(7, 8), Vector2i(8, 9)]
	for level in range(SUBDIVISIONS):
		edge_midpoints.clear()
		var refined: Array[Vector3i] = []
		var refined_edges: Array[Vector2i] = []
		for face_index in range(faces.size()):
			var face := faces[face_index]
			var edge := split_edges[face_index]
			# Cyclic rotation keeps winding while placing the paired edge at X-Y.
			while not (face.x in [edge.x, edge.y] and face.y in [edge.x, edge.y]):
				face = Vector3i(face.y, face.z, face.x)
			var ab := midpoint(face.x, face.y)
			var bc := midpoint(face.y, face.z)
			var ca := midpoint(face.z, face.x)
			refined.append(Vector3i(face.x, ab, ca))
			refined.append(Vector3i(face.y, bc, ab))
			refined.append(Vector3i(face.z, ca, bc))
			refined.append(Vector3i(ab, bc, ca))
			refined_edges.append(Vector2i(face.x, ab))
			refined_edges.append(Vector2i(face.y, ab))
			refined_edges.append(Vector2i(ca, bc))
			refined_edges.append(Vector2i(ca, bc))
		faces = refined
		split_edges = refined_edges
	for level in range(DENSITY_DOUBLINGS):
		edge_midpoints.clear()
		var doubled: Array[Vector3i] = []
		var doubled_edges: Array[Vector2i] = []
		for face_index in range(faces.size()):
			var face := faces[face_index]
			var edge := split_edges[face_index]
			while not (face.x in [edge.x, edge.y] and face.y in [edge.x, edge.y]):
				face = Vector3i(face.y, face.z, face.x)
			var middle := midpoint(face.x, face.y)
			doubled.append(Vector3i(face.x, middle, face.z))
			doubled.append(Vector3i(middle, face.y, face.z))
			doubled_edges.append(Vector2i(middle, face.z))
			doubled_edges.append(Vector2i(middle, face.z))
		faces = doubled
		split_edges = doubled_edges
	var indices := PackedInt32Array()
	for face in faces:
		# Godot front faces use clockwise winding; normals point radially outward.
		indices.append_array(PackedInt32Array([face.x, face.z, face.y]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var result := ResourceSaver.save(mesh, "res://sun/icosphere.res")
	if result != OK:
		push_error("Could not save sun mesh: %s" % error_string(result))
		quit(1)
		return
	print("Baked sun icosphere: %d vertices, %d triangles" % [vertices.size(), faces.size()])
	quit()
