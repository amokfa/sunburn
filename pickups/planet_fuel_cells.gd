extends Node3D
## Ten reachable fuel cells; swept collection catches fast passes without physics bodies.
signal all_collected
const PickupScene := preload("res://pickups/fuel_cell.tscn")
const ShipController := preload("res://ship/ship.gd")
@export var cell_count := 10
@export var collection_radius := 5.0
@export var spawn_cone_degrees := 65.0
@export var minimum_spacing := 25.0
var _cells: Array[Node3D] = []
var _planet: Node3D
var _ship: ShipController
var _collecting := false
var _collected := 0
var _previous_ship_position := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
@onready var _counter: Label = $HUD/Counter
@onready var _pickup_sound: AudioStreamPlayer = $PickupSound


func _ready() -> void:
	_rng.randomize()
	_counter.hide()


func begin(planet: Node3D, player: ShipController) -> void:
	clear(true)
	_planet = planet
	_ship = player
	global_position = planet.global_position
	var radius: float = planet.global_basis.x.length()
	var up: Vector3 = (player.global_position - planet.global_position).normalized()
	var tangent := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var bitangent := up.cross(tangent)
	var terrain: MeshInstance3D = planet.get_node("Terrain")
	var triangles := TriangleMesh.new()
	triangles.create_from_faces(terrain.mesh.get_faces())
	var ocean := planet.get_node_or_null("Ocean") as MeshInstance3D
	var water_radius := (ocean.mesh as SphereMesh).radius * ocean.global_basis.x.length() if ocean != null else 0.0
	var ceiling: float = radius * player.maximum_altitude_ratio - 10.0
	for attempt in range(1000):
		if _cells.size() == cell_count:
			break
		var cosine := _rng.randf_range(cos(deg_to_rad(spawn_cone_degrees)), 1.0)
		var angle := _rng.randf_range(0.0, TAU)
		var direction := up * cosine + (tangent * cos(angle) + bitangent * sin(angle)) * sqrt(1.0 - cosine * cosine)
		# Remove the planet's scale from the ray length. Tiny local-space rays
		# fall below the triangle intersection tolerance on the detailed mesh.
		var local_ray := (terrain.global_basis.inverse() * direction).normalized()
		var hit := triangles.intersect_ray(terrain.to_local(planet.global_position), local_ray)
		if hit.is_empty():
			continue
		var ground_radius := terrain.to_global(hit.position).distance_to(planet.global_position)
		var floor_height: float = maxf(ground_radius, water_radius) - radius + player.surface_clearance + 8.0
		var low := maxf(25.0, floor_height)
		if low > ceiling:
			continue
		var altitude := _rng.randf_range(low, maxf(low, minf(90.0, ceiling)))
		var candidate := direction * (radius + altitude)
		var separated := true
		for cell in _cells:
			if cell.position.distance_to(candidate) < minimum_spacing:
				separated = false
				break
		if not separated:
			continue
		var cell := PickupScene.instantiate() as Node3D
		add_child(cell)
		cell.position = candidate
		_cells.append(cell)
	if _cells.size() != cell_count:
		push_error("Could not place all fuel cells within the flight boundaries")
		clear()
		return
	_previous_ship_position = player.global_position
	_collecting = true
	_counter.text = "FUEL CELLS  0 / %d" % cell_count
	_counter.show()


func _process(_delta: float) -> void:
	if not _collecting or not is_instance_valid(_ship) or not _ship.can_fight:
		return
	global_position = _planet.global_position
	var current: Vector3 = _ship.global_position
	for index in range(_cells.size() - 1, -1, -1):
		var cell := _cells[index]
		var nearest := Geometry3D.get_closest_point_to_segment(cell.global_position, _previous_ship_position, current)
		if nearest.distance_squared_to(cell.global_position) > collection_radius * collection_radius:
			continue
		_cells.remove_at(index)
		_collected += 1
		_pickup_sound.play()
		_counter.text = "FUEL CELLS  %d / %d" % [_collected, cell_count]
		cell.set_process(false)
		var animation := create_tween().bind_node(cell)
		animation.tween_property(cell, "scale", Vector3.ONE * 0.01, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		animation.tween_callback(cell.queue_free)
	_previous_ship_position = current
	if _cells.is_empty():
		_collecting = false
		all_collected.emit()


func stop() -> void:
	_collecting = false
	_counter.hide()


func clear(stop_audio := false) -> void:
	stop()
	if stop_audio:
		_pickup_sound.stop()
	_collected = 0
	_cells.clear()
	for child in get_children():
		if child is Node3D:
			remove_child(child)
			child.queue_free()
