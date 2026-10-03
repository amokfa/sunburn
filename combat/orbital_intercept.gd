extends RefCounted
## Predict steady surface flight, including radial motion, around the planet center.
const LAUNCH_OFFSET := 1.5
const MAX_LEAD_SECONDS := 8.0

static func predicted_position(position: Vector3, tangent_direction: Vector3, tangent_speed: float, radial_speed: float, time: float) -> Vector3:
	var radius := position.length()
	var future_radius := maxf(radius + radial_speed * time, 0.001)
	var angle := tangent_speed * time / maxf(radius, 0.001)
	if absf(radial_speed) > 0.001:
		angle = tangent_speed / radial_speed * log(future_radius / maxf(radius, 0.001))
	var up := position.normalized()
	return (up * cos(angle) + tangent_direction * sin(angle)) * future_radius

static func direction(origin: Vector3, position: Vector3, tangent_direction: Vector3, tangent_speed: float, radial_speed: float, missile_speed: float, lifetime: float) -> Vector3:
	# Lead only when interception is within eight seconds and the missile lifetime.
	var horizon := minf(lifetime, MAX_LEAD_SECONDS)
	var low := 0.0
	var high := 0.0
	while high < horizon:
		high = minf(high + 0.125, horizon)
		var future := predicted_position(position, tangent_direction, tangent_speed, radial_speed, high)
		if origin.distance_to(future) <= LAUNCH_OFFSET + missile_speed * high:
			for iteration in range(18):
				var middle := (low + high) * 0.5
				future = predicted_position(position, tangent_direction, tangent_speed, radial_speed, middle)
				if origin.distance_to(future) > LAUNCH_OFFSET + missile_speed * middle:
					low = middle
				else:
					high = middle
			return (predicted_position(position, tangent_direction, tangent_speed, radial_speed, high) - origin).normalized()
		low = high
	# A later or unreachable intercept falls back to the target's current position.
	return (position - origin).normalized()
