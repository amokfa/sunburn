extends Node3D
## Straight tracer with swept hit detection; no rigid-body simulation.
var _velocity := Vector3.ZERO
var _remaining: float = 0.0
var _damage: float = 10.0

func launch(origin: Vector3, direction: Vector3, speed: float, lifetime: float, damage: float) -> void:
	global_position = origin
	_velocity = direction.normalized() * speed
	_remaining = lifetime
	_damage = damage
	var up := Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP
	look_at(origin + direction, up)

func _process(delta: float) -> void:
	var destination := global_position + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, destination)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		if hit.collider.has_method("take_damage"):
			hit.collider.take_damage(_damage)
		queue_free()
		return
	global_position = destination
	_remaining -= delta
	if _remaining <= 0.0:
		queue_free()
