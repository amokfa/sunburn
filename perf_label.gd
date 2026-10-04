extends Label

const BYTES_PER_MIB := 1024.0 * 1024.0
const UPDATE_INTERVAL := 0.25

var viewport_rid: RID
var elapsed: float = 0.0
@onready var overlay: CanvasLayer = get_parent()
@onready var ship: Node3D = overlay.get_parent().get_node("Ship")
@onready var sun: Node3D = overlay.get_parent().get_node("Sun")


func _ready() -> void:
	viewport_rid = get_viewport().get_viewport_rid()
	overlay.hide()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, false)
	set_process(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		overlay.visible = not overlay.visible
		RenderingServer.viewport_set_measure_render_time(viewport_rid, overlay.visible)
		set_process(overlay.visible)
		elapsed = 0.0
		if overlay.visible:
			_update_text()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= UPDATE_INTERVAL:
		elapsed = fmod(elapsed, UPDATE_INTERVAL)
		_update_text()


func _update_text() -> void:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var render_cpu_ms := (
		RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
		+ RenderingServer.get_frame_setup_time_cpu()
	)
	var render_gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	var sun_radius := sun.global_basis.x.length()
	var sun_dist := ship.global_position.distance_to(sun.global_position) - sun_radius

	text = """FPS: %d
Frame total: %.2f ms
Render CPU: %.2f ms
Render GPU: %.2f ms
Physics CPU: %.2f ms
Navigation CPU: %.2f ms
Draw calls: %d
Primitives: %d
Objects: %d
Nodes: %d
VRAM used: %.2f MB
sun_dist: %.1f m
sun_radius: %.1f m""" % [
		fps,
		1000.0 / max(fps, 1.0),
		render_cpu_ms,
		render_gpu_ms,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / BYTES_PER_MIB,
		sun_dist,
		sun_radius,
	]
