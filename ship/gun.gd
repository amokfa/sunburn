extends Node3D
signal fired(projectile: Node3D)
const PROJECTILE := preload("res://ship/projectile.tscn")
@export var rounds_per_second: float = 8.0
@export var projectile_speed: float = 450.0
@export var projectile_lifetime: float = 3.0
@export var damage: float = 10.0
@export var aim_distance: float = 1000.0
@onready var muzzle: Marker3D = $Muzzle
@onready var shots: Node3D = $Shots
var enabled: bool = false:
	set(value):
		enabled = value
		visible = value
		set_process(value)
		if not value:
			_cooldown = 0.0
			clear_shots()
var _aim_target := Vector3.ZERO
var _cooldown: float = 0.0

func _ready() -> void:
	enabled = enabled

func aim_at(target: Vector3, up: Vector3) -> void:
	_aim_target = target
	if global_position.distance_squared_to(target) > 0.000001:
		var direction := (target - global_position).normalized()
		var safe_up := global_basis.x if absf(direction.dot(up)) > 0.99 else up
		look_at(target, safe_up)

func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		try_fire()

func try_fire() -> bool:
	if not enabled or _cooldown > 0.0:
		return false
	var direction := (_aim_target - muzzle.global_position).normalized()
	if direction.length_squared() < 0.000001:
		direction = -global_basis.z
	var projectile = PROJECTILE.instantiate()
	shots.add_child(projectile)
	projectile.launch(muzzle.global_position, direction, projectile_speed, projectile_lifetime, damage)
	_cooldown = 1.0 / maxf(rounds_per_second, 0.01)
	fired.emit(projectile)
	return true

func clear_shots() -> void:
	if not is_instance_valid(shots):
		return
	for projectile in shots.get_children():
		projectile.free()
