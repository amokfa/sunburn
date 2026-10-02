extends "res://tools/generate_planets.gd"
## Only rebake collision resources; preserve existing visual planet scenes.
func generate() -> void:
	broad = noise_source(WORLD_SEED, 1.8, 3)
	detail = noise_source(WORLD_SEED + 1, 12.0, 3)
	for kind in range(3):
		var body := make_collider(kind)
		body.free()
	print("Baked three coarse planet colliders.")
	quit()
