extends SceneTree
## Bake editor-visible scenes with: godot --headless --path . --script tools/generate_planets.gd
## Radii stay in scale_prototype.gd; all baked dimensions are relative to a unit sphere.
const WORLD_SEED := 73129
const TREE_CANDIDATES := 26000
const FOREST_PATCHES := 64
# XYZ is the peak direction; W is its height relative to the planet radius.
const MOUNTAINS := [Vector4(-0.55, 0.55, 0.63, 0.065), Vector4(0.75, -0.2, -0.63, 0.05)]
const MOUNTAIN_WIDTH := 0.22
var directions := PackedVector3Array()
var indices := PackedInt32Array()
var broad: FastNoiseLite
var detail: FastNoiseLite
var forest: FastNoiseLite

func noise_source(seed_value: int, frequency: float, octaves: int) -> FastNoiseLite:
	var source := FastNoiseLite.new()
	source.seed = seed_value
	source.frequency = frequency
	source.fractal_type = FastNoiseLite.FRACTAL_FBM
	source.fractal_octaves = octaves
	return source

func _initialize() -> void:
	call_deferred("generate")

func generate() -> void:
	broad = noise_source(WORLD_SEED, 1.8, 3)
	detail = noise_source(WORLD_SEED + 1, 12.0, 3)
	forest = noise_source(WORLD_SEED + 2, 5.0, 2)
	bake_seabed_depth()
	# One extra subdivision halves triangle edge length (four times the faces).
	refine_sphere(2)
	for kind in range(3):
		if kind == 2:
			refine_sphere(1)
		bake_planet(kind)
	print("Generated three static planet scenes in res://planets/")
	quit()

func random_direction(rng: RandomNumberGenerator) -> Vector3:
	var y := rng.randf_range(-1.0, 1.0)
	var longitude := rng.randf_range(0.0, TAU)
	var width := sqrt(1.0 - y * y)
	return Vector3(cos(longitude) * width, y, sin(longitude) * width)

func bake_seabed_depth() -> void:
	# Equirectangular scalar field; wave normals use seamless triplanar mapping.
	# Bake at pixel centers to match the ocean shader's spherical coordinates.
	const WIDTH := 1024
	const HEIGHT := 512
	var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_R8)
	for y in range(HEIGHT):
		var latitude := ((float(y) + 0.5) / HEIGHT - 0.5) * PI
		for x in range(WIDTH):
			var longitude := ((float(x) + 0.5) / WIDTH - 0.5) * TAU
			var p := Vector3(cos(latitude) * cos(longitude), sin(latitude), cos(latitude) * sin(longitude))
			var depth := clampf(-elevation(p, 0) / 0.04, 0.0, 1.0)
			image.set_pixel(x, y, Color(depth, depth, depth))
	image.generate_mipmaps()
	save_resource(image, "res://planets/seabed_depth_image.res")

func refine_sphere(passes: int) -> void:
	var base := load("res://sun/icosphere.res") as ArrayMesh
	var arrays := base.surface_get_arrays(0)
	directions = arrays[Mesh.ARRAY_VERTEX]
	indices = arrays[Mesh.ARRAY_INDEX]
	for pass_index in range(passes):
		var base_indices := indices
		indices = PackedInt32Array()
		var edges: Dictionary = {}
		for index in range(0, base_indices.size(), 3):
			var a := base_indices[index]
			var b := base_indices[index + 1]
			var c := base_indices[index + 2]
			var ab := midpoint(a, b, edges)
			var bc := midpoint(b, c, edges)
			var ca := midpoint(c, a, edges)
			indices.append_array(PackedInt32Array([a, ab, ca, b, bc, ab, c, ca, bc, ab, bc, ca]))

func midpoint(a: int, b: int, edges: Dictionary) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if edges.has(key):
		return edges[key]
	var result := directions.size()
	directions.append((directions[a] + directions[b]).normalized())
	edges[key] = result
	return result

func elevation(p: Vector3, kind: int) -> float:
	var continent := broad.get_noise_3dv(p)
	var hills := detail.get_noise_3dv(p)
	if kind == 2:
		var bump := detail.get_noise_3dv(p * 1.5) * 3.0
		bump /= sqrt(1.0 + bump * bump)
		return continent * 0.006 + hills * 0.002 + bump / 180.0
	if kind == 0:
		return clampf(continent * 0.085 + hills * 0.013 - 0.006, -0.04, 0.06)
	if kind == 1:
		# Most of the surface stays within about a meter of the nominal radius.
		var height := continent * 0.006 + hills * 0.002
		for peak in MOUNTAINS:
			var center := Vector3(peak.x, peak.y, peak.z).normalized()
			var distance := p.distance_to(center) / MOUNTAIN_WIDTH
			# Compact footprints keep the mountains isolated, with smooth foothills.
			height += peak.w * pow(maxf(1.0 - distance, 0.0), 2.0)
		return height
	return 0.0

func land_color(p: Vector3, height: float, kind: int) -> Color:
	var variation := detail.get_noise_3dv(p * 2.0) * 0.08
	if kind == 0:
		var sand := Color(0.72, 0.59, 0.34)
		var grass := Color(0.19, 0.38, 0.1)
		var rock := Color(0.38, 0.36, 0.29)
		var color := sand.lerp(grass, smoothstep(0.003, 0.011, height))
		color = color.lerp(rock, smoothstep(0.029, 0.05, height))
		return color * (1.0 + variation)
	if kind == 1:
		var dust := Color(0.61, 0.26, 0.115)
		var basalt := Color(0.27, 0.115, 0.07)
		return dust.lerp(basalt, smoothstep(0.008, 0.065, height)) * (1.0 + variation)
	var dust := Color(0.48, 0.48, 0.46)
	var rock := Color(0.3, 0.31, 0.32)
	return dust.lerp(rock, clampf(0.5 + broad.get_noise_3dv(p) * 0.8, 0.0, 1.0)) * (1.0 + variation * 0.5)

func bake_planet(kind: int) -> void:
	var root := Node3D.new()
	root.name = "Planet%d" % (kind + 1)
	var mesh_directions := directions
	var mesh_indices := indices
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	normals.resize(mesh_directions.size())
	var maximum_radius := 1.0
	var minimum_radius := 1.0
	for p in mesh_directions:
		var height := elevation(p, kind)
		vertices.append(p * (1.0 + height))
		colors.append(land_color(p, height, kind))
		maximum_radius = maxf(maximum_radius, 1.0 + height)
		minimum_radius = minf(minimum_radius, 1.0 + height)
	for index in range(0, mesh_indices.size(), 3):
		var a := mesh_indices[index]
		var b := mesh_indices[index + 1]
		var c := mesh_indices[index + 2]
		var normal := (vertices[c] - vertices[a]).cross(vertices[b] - vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for index in range(normals.size()):
		normals[index] = normals[index].normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = mesh_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	material.disable_receive_shadows = true
	mesh.surface_set_material(0, material)
	save_resource(mesh, "res://planets/planet%d_terrain.res" % (kind + 1))
	var collider := make_collider(kind)
	add_owned(root, collider)
	collider.get_node("Shape").owner = root
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	terrain.mesh = mesh
	if kind == 0:
		terrain.material_override = load("res://planets/terrain1_material.tres")
	elif kind == 2:
		terrain.material_override = load("res://planets/terrain3_material.tres")
	add_owned(root, terrain)
	if kind < 2:
		var atmosphere := load("res://planets/atmosphere.tscn").instantiate() as MeshInstance3D
		atmosphere.scale = Vector3.ONE * (1.4 if kind == 0 else 1.3)
		atmosphere.material_override = load("res://planets/atmosphere_blue.tres" if kind == 0 else "res://planets/atmosphere_green.tres")
		add_owned(root, atmosphere)
	if kind == 0:
		# Keep the hand-placed story marker when regenerating the terrain scene.
		var marker := Marker3D.new()
		marker.name = "platform"
		marker.position = Vector3(-0.23449643, 0.9104481, -0.37026796)
		if ResourceLoader.exists("res://planets/planet1.tscn"):
			var previous := load("res://planets/planet1.tscn").instantiate() as Node3D
			var previous_marker := previous.get_node_or_null("platform") as Marker3D
			if previous_marker != null:
				marker.transform = previous_marker.transform
			previous.free()
		add_owned(root, marker)
		var platform := load("res://planets/launch_platform.tscn").instantiate() as Node3D
		marker.add_child(platform)
		platform.owner = root
		var ocean := MeshInstance3D.new()
		ocean.name = "Ocean"
		var ocean_mesh := SphereMesh.new()
		ocean_mesh.radius = 1.0
		ocean_mesh.height = 2.0
		ocean_mesh.radial_segments = 256
		ocean_mesh.rings = 128
		ocean.mesh = ocean_mesh
		ocean.material_override = load("res://planets/ocean_material.tres")
		add_owned(root, ocean)
		maximum_radius = maxf(maximum_radius, bake_forests(root))
	var occluder := OccluderInstance3D.new()
	occluder.name = "CoreOccluder"
	var sphere := SphereOccluder3D.new()
	sphere.radius = minimum_radius * 0.995
	occluder.occluder = sphere
	occluder.visible = false
	add_owned(root, occluder)
	root.set_meta("maximum_surface_radius", maximum_radius)
	root.set_meta("generation_seed", WORLD_SEED)
	var scene := PackedScene.new()
	check_error(scene.pack(root), "packing planet")
	check_error(ResourceSaver.save(scene, "res://planets/planet%d.tscn" % (kind + 1)), "saving planet")
	print("Planet %d: %d terrain triangles; radial extent %.4f" % [kind + 1, mesh_indices.size() / 3, maximum_radius])
	root.free()

func make_collider(_kind: int) -> StaticBody3D:
	# Geometry is generated from the current terrain and ocean when the scene loads.
	var body := StaticBody3D.new()
	body.name = "SurfaceCollider"
	body.set_script(load("res://planets/surface_collider.gd"))
	var collision := CollisionShape3D.new()
	collision.name = "Shape"
	body.add_child(collision)
	return body

func add_owned(root: Node, child: Node) -> void:
	root.add_child(child)
	child.owner = root

func save_resource(resource: Resource, path: String) -> void:
	check_error(ResourceSaver.save(resource, path), path)
	resource.take_over_path(path)

func check_error(error: Error, operation: String) -> void:
	if error != OK:
		push_error("%s: %s" % [operation, error_string(error)])
		quit(1)

func tree_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.0008
	trunk.bottom_radius = 0.0011
	trunk.height = 0.006
	trunk.radial_segments = 5
	trunk.rings = 1
	append_tinted(surface, trunk, Transform3D(Basis.IDENTITY, Vector3(0, 0.003, 0)), Color(0.23, 0.12, 0.045))
	for tier in range(3):
		var crown := CylinderMesh.new()
		crown.top_radius = 0.0
		crown.bottom_radius = 0.006 - tier * 0.0012
		crown.height = 0.01 - tier * 0.0015
		crown.radial_segments = 6
		crown.rings = 1
		append_tinted(surface, crown, Transform3D(Basis.IDENTITY, Vector3(0, 0.009 + tier * 0.0035, 0)), Color(0.055 + tier * 0.012, 0.2 + tier * 0.035, 0.065))
	surface.index()
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	return mesh

func bake_forests(root: Node3D) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED + 10
	var mesh := tree_mesh()
	save_resource(mesh, "res://planets/tree.res")
	var patches: Array = []
	for index in range(FOREST_PATCHES):
		patches.append([])
	var maximum_radius := 1.0
	var total := 0
	for index in range(TREE_CANDIDATES):
		var p := random_direction(rng)
		var height := elevation(p, 0)
		if height < 0.01 or height > 0.037 or forest.get_noise_3dv(p) < -0.05:
			continue
		var yaw := rng.randf_range(0.0, TAU)
		var size := rng.randf_range(0.7, 1.2)
		var basis := Basis(Quaternion(Vector3.UP, p)).rotated(p, yaw).scaled(Vector3.ONE * size)
		var transform := Transform3D(basis, p * (1.0 + height - 0.0005))
		var longitude := fposmod(atan2(p.z, p.x), TAU)
		var column := mini(int(longitude / TAU * 8.0), 7)
		var row := mini(int((p.y + 1.0) * 0.5 * 8.0), 7)
		patches[row * 8 + column].append(transform)
		maximum_radius = maxf(maximum_radius, 1.0 + height + 0.021 * size)
		total += 1
	var forests := Node3D.new()
	forests.name = "Forests"
	add_owned(root, forests)
	for index in range(patches.size()):
		if patches[index].is_empty():
			continue
		# The headless dummy renderer discards MultiMesh buffers. Serialize the
		# matrix rows and colors explicitly so baking does not require a GPU.
		var values := PackedStringArray()
		for transform: Transform3D in patches[index]:
			var tint := rng.randf_range(0.8, 1.15)
			var b := transform.basis
			var o := transform.origin
			for value in [b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z, tint, tint, tint, 1.0]:
				values.append(String.num(value, 8))
		var path := "res://planets/forest_patch_%02d.tres" % index
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string('[gd_resource type="MultiMesh" load_steps=2 format=3]\n\n[ext_resource type="ArrayMesh" path="res://planets/tree.res" id="1_tree"]\n\n[resource]\ntransform_format = 1\nuse_colors = true\ninstance_count = %d\nmesh = ExtResource("1_tree")\nbuffer = PackedFloat32Array(%s)\n' % [patches[index].size(), ", ".join(values)])
		file.close()
		var multimesh := load(path) as MultiMesh
		var patch := MultiMeshInstance3D.new()
		patch.name = "Patch%02d" % index
		patch.multimesh = multimesh
		forests.add_child(patch)
		patch.owner = root
	print("Forest: %d trees in spatial batches" % total)
	return maximum_radius

func append_tinted(surface: SurfaceTool, mesh: PrimitiveMesh, transform: Transform3D, tint: Color) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var triangles: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in triangles:
		surface.set_color(tint)
		surface.set_normal(transform.basis * normals[index])
		surface.add_vertex(transform * positions[index])
