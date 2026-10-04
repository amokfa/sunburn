extends SceneTree
## Bake a uniformly tessellated planet 3: 20 * FREQUENCY^2 triangles.
## godot --headless --path . --script tools/generate_planet3_mesh.gd
const FREQUENCY := 70
var vertices := PackedVector3Array()
var faces: Array[Vector3i] = []
var shared_vertices: Dictionary = {}

func grid_vertex(face: Vector3i, face_index: int, row: int, column: int, base: PackedVector3Array) -> int:
	var weights := Vector3i(FREQUENCY - row, row - column, column)
	var ids := [face.x, face.y, face.z]
	var nonzero: Array[int] = []
	for index in range(3):
		if weights[index] > 0:
			nonzero.append(index)
	var key: Vector3i
	if nonzero.size() == 1:
		key = Vector3i(-1, ids[nonzero[0]], 0)
	elif nonzero.size() == 2:
		var first := nonzero[0]
		var second := nonzero[1]
		var low: int = mini(ids[first], ids[second])
		var high: int = maxi(ids[first], ids[second])
		var high_weight: int = weights[first] if ids[first] == high else weights[second]
		key = Vector3i(low, high, high_weight)
	else:
		key = Vector3i(-face_index - 2, row, column)
	if shared_vertices.has(key):
		return shared_vertices[key]
	var index := vertices.size()
	var position := base[face.x] * weights.x + base[face.y] * weights.y + base[face.z] * weights.z
	vertices.append(position.normalized())
	shared_vertices[key] = index
	return index

func _initialize() -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	vertices = PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)])
	for index in range(vertices.size()):
		vertices[index] = vertices[index].normalized()
	faces.assign([
		Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
		Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1)])
	var base := vertices
	vertices = PackedVector3Array()
	var indices := PackedInt32Array()
	for face_index in range(faces.size()):
		var face := faces[face_index]
		var rows: Array[PackedInt32Array] = []
		for row in range(FREQUENCY + 1):
			var points := PackedInt32Array()
			for column in range(row + 1):
				points.append(grid_vertex(face, face_index, row, column, base))
			rows.append(points)
		for row in range(FREQUENCY):
			for column in range(row + 1):
				# Reverse winding for Godot's clockwise front faces.
				indices.append_array(PackedInt32Array([rows[row][column], rows[row + 1][column + 1], rows[row + 1][column]]))
				if column < row:
					indices.append_array(PackedInt32Array([rows[row][column], rows[row][column + 1], rows[row + 1][column + 1]]))
	var edge_counts := {}
	for index in range(0, indices.size(), 3):
		for offset in range(3):
			var a := indices[index + offset]
			var b := indices[index + (offset + 1) % 3]
			var key := Vector2i(mini(a, b), maxi(a, b))
			edge_counts[key] = int(edge_counts.get(key, 0)) + 1
	for count in edge_counts.values():
		if count != 2:
			push_error("Planet 3 topology is not closed")
			quit(1)
			return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var error := ResourceSaver.save(mesh, "res://planets/planet3_terrain.res")
	if error != OK:
		push_error("Could not save planet 3 mesh: %s" % error_string(error))
		quit(1)
		return
	print("Planet 3: %d triangles, uniform density. Closed topology verified." % (indices.size() / 3))
	quit()
