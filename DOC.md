Game jam theme is "everything is temporary". Duration is 3 days, 2.5 days are left. The game idea is way too ambitious. We gotta work hard and cut scope aggressively if we hope to finish it in time. Keep that in mind. We must not add too much details and do things as cheaply as possible. We'll use godot as the engine.

The game will look and feel sort of like outer wilds. We start on a planet, in our ship. Our ship will have an AI assistant that'll inform the player about the plot as it progresses. When the game begins, some anomaly in the sun causes it to turn into a red giant. It'll soon swallow starting planet. The goal on this planet is to gather enough fuel and resources to leave the planet to the next planet in the solar system before current planet gets swallowed by the expanding sun. Again, the look and feel will be like outer wilds. The sun will be a giant sphere that expands.

In the second planet we'll meet other ships that managed to escape the first planet in time. The sun is still expanding. On this planet the goal is to engage in gunfights with other ships, steal their resources, and jump to a third planet. There just enough fuel on the second planet for one ship to jump to the third planet.

On the third planet the ship runs out of energy shortly after arrival. The assistant analyzes the barren wasteland but finds nothing that can help us. We watch the expanding sun approach, until it suddenly collapses into a blue dwarf. For a moment it looks like we survived, but the dwarf is too weak to provide useful light, heat, or energy. The planet falls into everlasting darkness, with only the starry sky for light. We have one final conversation with the assistant before his backup power dies too, and the game ends.


The player will not get 6 degrees of freedom like outer wilds. It'll make things too complicated for 2.5 days. The ship will always stay upright relative to the planet it's on. There'll be upper and lower limits on the altitude of the ship, so it can't leave the atmosphere or collide with ground stuff. When travelling from the next planet we will have a cutscene sort of thing. It'll be seamless but we'll take control from the player and move the ship to the next planet, where he'll get the control back. On planet controls will be q: upward thrust, e: downward thrust, w/s: forward/backward thrust, a/d: turn the ship. Camera will be in third person. Move mouse to tilt the camera.

The AI assistant chat ui will be a terminal in the bottom right. It'll have a chatgpt like interface with player character text on the right and assistant responses on the left. Sort of like whatsapp where the player character is chatting with the assistant.

To avoid hitting the f32 large world problem, we'll use a geostationary world model. Current planet will be at the center, and other planets and sun will have positions relative to it. When moving from one planet to other, we'll keep the ship stationary and move the planets relative to the ship.

First planet will have oceans and forests. Fuel cells will be gta like artificial looking pickups that we collect. All celestial bodies will be visible from all the other. When we're on the first planet, we'll see rocket streaks of other ships leaving for the second planet. We'll also see other ships rummaging around to collect fuel, but only from very far away. The game logic will ensure we never get close to those ships.

Second planet will be a barren wasteland modelled after mars. Not much else on this planet except some mountains and valleys

Third planet will be a simple barren sphere. The travel cutscene deposits the ship on its sun-facing side, with the sun clearly above the horizon. The player can fly briefly within a small area around arrival. When power fails, the ship stops and stays suspended above the surface, but the player keeps camera control to watch the finale. The planet does not rotate during this sequence, keeping the sun visible. The sun's collapse is scripted relative to arrival and happens before it reaches the ship, regardless of how quickly the player escaped the previous planets. Keep the finale short rather than making the player wait for several minutes.

Sky will be a simple skybox but we'll use a custom shader anyways because I feel we'll have to add more details.


The game will boot into a black screen. The main menu will slowly fade in. It'll work like spec ops/half life/outer wilds where the background of the main menu will be a scene from the game, in this case it'll be the starting scene of the game with the ship and a rising sun visible. Starting a new game will move from that scenic angle to the third person. The character will chat with the assitant for a while, this is where the initial world building will happen. That's when something anomolous will happen in the sun. The assistant will do research and inform the character about the situation. The planet is about to die and the character needs to gather fuel and leave for second planet. There'll be another chat between the character and assistant when he reaches the second planet. First we'll see ships fighting each other, then the assistant will research and explain the situation on this planet, the weapons will be enabled and gameplay of second planet will begin. Arrival on the third planet begins the final sequence: the ship loses power, the sun collapses, and the last conversation ends when the assistant's backup power dies. The AI chat will be scripted. It's just a plot element.


The sun is the central threat and must look impressive and scary, with visible waves on its surface when it gets close. We could use a giant icosphere with a vertex shader to animate surface waves. First we need to settle the planet radii and their orbit radii, then visually test the expanding sun at that scale on the development machine to decide how much its mesh needs to be subdivided. Leave subdivision levels and wave parameters undecided until that visual test.

===========================================================

Implementation details

This document is the sole handoff to the development machine and a new chat. Development happens there; this laptop is only used to update this document. Keep the high-level description above the separator unchanged unless the user edits it. Append implementation decisions below. Prioritize a finished jam game and keep implementation cheap.

First planet: procedural generation

- Generate the entire planet once before gameplay with a fixed seed. No terrain streaming or changing terrain resolution during on-planet play.
- Start with a subdivided sphere. Sample seeded 3D noise using each vertex's unit direction, then displace the vertex radially. A broad noise layer produces continents and islands; a weaker layer produces hills. Keep elevation changes modest and terrain features broad.
- Add a separate smooth ocean sphere at a fixed sea level. Terrain below it is hidden, giving coastlines naturally. Keep water shading simple; a little animated surface detail is enough.
- Color the terrain according to elevation: sandy near sea level, green above the beach, rocky at the highest elevations.
- Scatter a few reusable, super low-poly tree models on land above the beach. Use a separate noise field to cluster trees into forests. Orient trees radially, away from the planet center. The player sees them from fairly high up, so detailed models and tree LOD are unnecessary initially.
- Place fuel pickups independently of decorative terrain generation, at reachable heights within the flight band. Put an accessible starter cluster near spawn, then spread more across a few clusters. Provide more fuel than the escape requires so the player does not need every pickup.
- Keep the lower altitude limit above the highest terrain and trees, avoiding terrain and tree collision work. Account for the ship's size when choosing clearance.
- Tune planet size, ship speed, pickup spacing, required fuel, and the sun countdown together. The planet must be small enough to visit several pickup clusters before destruction. Numeric values remain to be tuned on the development machine.

Planet LOD and travel

- Use exactly two representations per planet: full detail when active, and a simple sphere with just a surface texture when distant. The distant texture should match the generated planet's broad land/ocean colors and patterns; use the same seed and terrain sampling rules so the representations agree.
- Fade between these representations during the controlled travel sequence. Trees and other surface decorations belong only to the full-detail representation.
- Use one fixed terrain mesh resolution for the full-detail planet, chosen to look acceptable at the lowest allowed flight height. No terrain chunk LOD, seam stitching, or continuous resolution changes initially.
- Test performance early on the development machine. Adjust terrain resolution and tree density first; add complexity only if measurements justify it.

Planet occlusion and tree batching (Godot 4)

- Enable Rendering > Occlusion Culling > Use Occlusion Culling in Project Settings (enable the Advanced toggle to find it).
- Add an OccluderInstance3D at the active planet's center with a SphereOccluder3D resource and set its radius. This manually supplied primitive does not require baking.
- Keep the occluder entirely inside the opaque planet surface. Use a conservative radius that does not protrude through terrain depressions. Some hidden geometry remaining visible to the renderer near the horizon is preferable to incorrectly culling visible trees.
- Godot tests an object's whole axis-aligned bounding box for occlusion. MultiMesh instances are not culled individually, so do not put all trees on the planet into one MultiMesh.
- Divide forests into local patches, each using its own MultiMeshInstance3D with tight bounds. This lets Godot cull whole patches behind the planet or outside the camera view, while instancing keeps draw calls manageable. If multiple tree meshes are used, create separate batches within each patch.
- If needed, use distance visibility limits for tree patches. Add a short fade only if popping is noticeable; start with the simplest setup.
- Keep the active planet's occluder stationary during on-planet play. Hide occluders during travel while moving the planets, then show the destination occluder once it is stationary. Continuously moving occluders rebuilds Godot's spatial acceleration structure.
- Compare performance with occlusion enabled and disabled. Use the editor's Occlusion Culling Buffer debug view to inspect coverage, especially near the horizon.

Godot reference links for the development handoff:
- Sphere occluder: https://docs.godotengine.org/en/stable/classes/class_sphereoccluder3d.html
- Occlusion setup, bounding-box tests, debug view, and moving occluders: https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html
- MultiMesh batching and culling limitations: https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
