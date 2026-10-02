# Generated planets

Open `planet1.tscn`, `planet2.tscn`, or `planet3.tscn` to inspect the baked scenes. They are instanced in `scale_prototype.tscn`. Mesh coordinates use a unit planet radius; the prototype root's `planet_radii` controls their world scale.

- Planet 1: seeded continents, elevation colors, opaque animated ocean, and 3,414 low-poly conifers in local MultiMesh patches. Water adapts wanderer's four drifting noise normal samples and Fresnel shading, with seamless spherical mapping, subdued waves, mipmaps, and distance fading for aerial views. Shore tint uses a baked seabed-depth texture from the same elevation field as the land; no transparency or screen/depth sampling is needed.
- Planet 2: mostly flat red dusty terrain, gentle undulations, and two isolated mountains (roughly 15 m and 12 m tall at the default radius).
- Planet 3: a simple grey sphere for the finale.

Generation settings live near the top of `tools/generate_planets.gd`. Rebuild after changing the seed, terrain formulas, or tree distribution:

```sh
godot --headless --path . --script tools/generate_planets.gd
```

The generator uses the baked unit icosphere at `sun/icosphere.res`. Its geometry and forest buffers are saved to disk, so gameplay does not regenerate terrain. Forest buffers are written explicitly because Godot's headless dummy renderer does not retain MultiMesh instance data.

Terrain triangle edges are now half their original length: planets 1 and 2 have 327,680 triangles each, and planet 3 has 81,920. Ocean segments and rings are also doubled. Mountain directions, heights, and footprint width are configurable at the top of the generator.

Tune water colors, `wave_tile_size`, `wave_speed`, `wave_strength`, `shallow_depth`, and detail fade distances in `ocean_material.tres`'s shader parameters. The shared material survives planet rebuilds; the generator rebakes `seabed_depth_image.res` alongside the terrain.

The prototype derives its flight floor from each planet's maximum terrain/tree extent. A conservative sphere occluder is enabled only on the current planet and disabled during travel. Planet surfaces ignore received shadows, preserving the rule that planets do not shadow each other; they still cast shadows on the ship.
