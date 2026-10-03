@tool
extends Node3D
## Geometry uses metres even though its marker belongs to a unit-radius planet.
@export var deck_half_width := 4.0
@export var height_offset := 2.0

func _ready() -> void:
	align_to_planet()
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	align_to_planet()

func align_to_planet() -> void:
	if get_parent() == null or get_parent().get_parent() == null:
		return
	var planet := get_parent().get_parent() as Node3D
	if planet == null:
		return
	var marker := get_parent() as Node3D
	var up := (marker.global_position - planet.global_position).normalized()
	var forward := Vector3.LEFT - up * Vector3.LEFT.dot(up)
	if forward.length_squared() < 0.000001:
		forward = up.cross(Vector3.FORWARD)
	# The standalone planet scene has unit radius; show metre-sized geometry there too.
	var unit_scale := planet.global_basis.x.length() / 300.0 if Engine.is_editor_hint() else 1.0
	global_transform = Transform3D(Basis.looking_at(forward.normalized(), up).scaled(Vector3.ONE * unit_scale), marker.global_position + up * height_offset * unit_scale)

func contains_ship(position: Vector3, clearance: float) -> bool:
	var local := to_local(position)
	return absf(local.x) <= deck_half_width and absf(local.z) <= deck_half_width and local.y >= 0.0 and local.y <= clearance + 0.75
