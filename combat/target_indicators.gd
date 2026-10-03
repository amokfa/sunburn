extends Control
## One canvas draw for all enemy reticles; no extra ship meshes or AI updates.
const TICK_DIRECTIONS = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
@export var radius: float = 4.0
@export var line_width: float = 0.75
@export var targeting_player_color := Color(1.0, 0.12, 0.08, 1.0)
@onready var battle = get_parent().get_parent()


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	queue_redraw()


func _indicator_color(ship: Node3D) -> Color:
	if not ship.can_fight or ship.target != battle.player:
		return Color.TRANSPARENT
	return targeting_player_color


func _draw() -> void:
	if not battle.active or not battle.targeting_hud_enabled:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var inverse_frame: Transform3D = battle.global_transform.affine_inverse()
	var camera_position: Vector3 = inverse_frame * camera.global_position
	var occluder: OccluderInstance3D = battle.planet.get_node("CoreOccluder")
	var planet_radius: float = occluder.occluder.radius * battle.planet.global_basis.x.length()
	var planet_radius_squared := planet_radius * planet_radius
	for ship in battle.ships:
		var color := _indicator_color(ship)
		if color.a == 0.0:
			continue
		var world_position: Vector3 = ship.global_position
		if not camera.is_position_in_frustum(world_position):
			continue
		# The planet's existing occlusion sphere hides far-side reticles too.
		var offset: Vector3 = ship.position - camera_position
		var t := clampf(
			-camera_position.dot(offset) / maxf(offset.length_squared(), 0.001), 0.0, 1.0
		)
		if (camera_position + offset * t).length_squared() < planet_radius_squared:
			continue
		var point := camera.unproject_position(world_position)
		draw_arc(point, radius, 0.0, TAU, 32, color, line_width, true)
		for direction in TICK_DIRECTIONS:
			draw_line(
				point + direction * (radius * 1.2),
				point + direction * (radius * 1.6),
				color,
				line_width,
				true
			)
