# C++ / WASM simulation comparison

Chromium 153 (Playwright, visible window), 1280×720, custom Godot 4.7 build
`afddf6e25`, single-threaded Emscripten 4.0.20 template with dynamic linking.
Same seeded 214-ship fleet, settings, scenes and camera. Each run warmed up for
30 seconds, then measured 10 seconds. Damage was disabled only in the benchmark
to keep the population constant. Results are local measurements, not a promise
for other hardware/browser combinations.

| Backend | FPS | Simulation CPU per frame | Peak active missiles |
|---|---:|---:|---:|
| GDScript | 50.98 | 13.16 ms | 267 |
| C++ / WASM | 91.48 | 4.97 ms | 271 |

FPS rose about 79%; measured simulation CPU per frame fell about 62%. Simulation
keeps the original maximum 1/120-second integration steps; the different frame
rates naturally change the number of substeps performed per frame. The fixed
step native/GDScript parity check found less than 1 mm of position/velocity
error after three simulated seconds. Missile counts differ slightly because
real-time frame sampling and firing timings differ.

A separate headless force/steering comparison measured roughly 3.34 ms native
versus 6.85 ms GDScript for the same fixed-step fleet. These figures should not
be compared directly against browser FPS.

The startup signature mismatch was reproduced and resolved by hiding extension
helper symbols (`-fvisibility=hidden`). The normal browser game reaches the main
menu with the extension loaded. Browser fullscreen/audio warnings in the
unattended benchmark came from starting without a user gesture; they were not
simulation failures.
