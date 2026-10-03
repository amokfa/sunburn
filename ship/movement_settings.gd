class_name ShipMovementSettings
extends Resource

@export var mass: float = 1000.0
@export var horizontal_thrust_force: float = 32000.0
@export var vertical_thrust_force: float = 40000.0
@export var horizontal_damping: float = 0.8
@export var vertical_damping: float = 1.2
@export var yaw_inertia: float = 100.0
@export var view_turn_torque: float = 1200.0
@export var yaw_damping: float = 700.0
@export var impact_angular_inertia: float = 10000.0
@export var attitude_stabilization_frequency: float = 4.0
@export_group("Planet boundaries")
@export_range(0.0, 100.0, 0.1, "or_greater") var surface_clearance: float = 0.0
@export var boundary_spring_stiffness: float = 5000.0
@export var boundary_spring_damping: float = 9000.0
@export var maximum_altitude_ratio: float = 0.5
