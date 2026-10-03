extends Node3D
const LIFETIME_SECONDS := 8.0
var velocity := Vector3.ZERO
var launcher: Node3D
var remaining: float = LIFETIME_SECONDS

func _ready() -> void:
	var material := $Body.material_override as ShaderMaterial
	material.set_shader_parameter("pulse_phase", randf_range(0.0, TAU))

func launch(origin: Vector3, direction: Vector3, speed: float, owner_ship: Node3D, up: Vector3) -> void:
	position = origin
	velocity = direction * speed
	launcher = owner_ship
	var safe_up := up if absf(direction.dot(up)) < 0.99 else Vector3.RIGHT
	if absf(direction.dot(safe_up)) > 0.99:
		safe_up = Vector3.FORWARD
	basis = Basis.looking_at(direction, safe_up)
