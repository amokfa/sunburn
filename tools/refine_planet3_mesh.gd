extends SceneTree
## Run explicitly to quadruple the stored planet 3 mesh, without rebaking other planets.
## godot --headless --path . --script tools/refine_planet3_mesh.gd
var vertices := PackedVector3Array()
var edges: Dictionary = {}

func midpoint(a: int, b: int) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if edges.has(key):
		return edges[key]
	var index := vertices.size()
	vertices.append((vertices[a] + vertices[b]).normalized())
	edges[key] = index
	return index

func _initialize() -> void:
	var source := load("res://planets/planet3_terrain.res") as ArrayMesh
	var source_arrays := source.surface_get_arrays(0)
	vertices = source_arrays[Mesh.ARRAY_VERTEX]
	for index in range(vertices.size()):
		vertices[index] = vertices[index].normalized()
	var original: PackedInt32Array = source_arrays[Mesh.ARRAY_INDEX]
	var indices := PackedInt32Array()
	for index in range(0, original.size(), 3):
		var a := original[index]
		var b := original[index + 1]
		var c := original[index + 2]
		var ab := midpoint(a, b)
		var bc := midpoint(b, c)
		var ca := midpoint(c, a)
		indices.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))
	# The terrain script generates height, vertex colors, and final normals at load.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var error := ResourceSaver.save(result, "res://planets/planet3_terrain.res")
	if error != OK:
		push_error("Could not save planet 3 mesh: %s" % error_string(error))
		quit(1)
		return
	print("Planet 3 mesh: %d -> %d triangles" % [original.size() / 3, indices.size() / 3])
	quit()
