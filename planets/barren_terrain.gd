@tool
extends MeshInstance3D
## Gentle geometry and vertex colour noise, sampled in 3D without texture tiles.
@export var bump_height_metres := 1.0
@export var bump_frequency := 18.0
@export var reference_radius_metres := 180.0
var _preview_mesh: ArrayMesh

func _ready() -> void:
	var source := mesh as ArrayMesh
	if source == null:
		return
	var broad := FastNoiseLite.new()
	broad.seed = 73129
	broad.frequency = 1.8
	broad.fractal_type = FastNoiseLite.FRACTAL_FBM
	broad.fractal_octaves = 3
	var detail := FastNoiseLite.new()
	detail.seed = 73130
	detail.frequency = 12.0
	detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail.fractal_octaves = 3
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	normals.resize(vertices.size())
	colors.resize(vertices.size())
	for index in range(vertices.size()):
		var direction := vertices[index].normalized()
		var continent := broad.get_noise_3dv(direction)
		var hills := detail.get_noise_3dv(direction)
		# Short, continuous rises and dips, with no spherical UV seams or tiling.
		var bump := detail.get_noise_3dv(direction * (bump_frequency / 12.0)) * 3.0
		bump /= sqrt(1.0 + bump * bump)
		var bump_height := bump * bump_height_metres / maxf(reference_radius_metres, 0.001)
		vertices[index] = direction * (1.0 + continent * 0.006 + hills * 0.002 + bump_height)
		var shade := clampf(0.5 + continent * 0.8, 0.0, 1.0)
		var grain := 1.0 + detail.get_noise_3dv(direction * 2.0) * 0.04
		colors[index] = Color(0.48, 0.48, 0.46).lerp(Color(0.3, 0.31, 0.32), shade) * grain
	for index in range(0, indices.size(), 3):
		var a := indices[index]
		var b := indices[index + 1]
		var c := indices[index + 2]
		var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for index in range(normals.size()):
		normals[index] = normals[index].normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var terrain := ArrayMesh.new()
	terrain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if Engine.is_editor_hint():
		# Preview the deformation without replacing the serialized mesh reference.
		_preview_mesh = terrain
		RenderingServer.instance_set_base(get_instance(), terrain.get_rid())
	else:
		mesh = terrain
