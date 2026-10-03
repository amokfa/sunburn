# Force simulation CPU breakdown

Measured on the development PC (Ryzen 9 5950X, Radeon RX 6650 XT), Godot 4.7 custom build. Two separate rendered runs, 200 enemies, stationary player/camera on planet 2, ordinary 1200×792 window. VSync disabled, no FPS cap. Each run had 30 seconds of real-time warmup followed by 30 seconds of measurement. No combat settings or production scripts were changed by this benchmark. The editor remained open; no other game process was running.

Instrumentation uses GDScript subclasses and microsecond timers. It adds some overhead, so FPS is diagnostic rather than an uninstrumented capacity claim. The fixed player does not integrate its own flight controls; enemies use the full force controller. Camera, sky, planets, lighting, thrusters, missiles and explosions render normally.

| Renderer | Average FPS | Frame p95 | Frame p99 | Render CPU | Render GPU | Peak missiles |
|---|---:|---:|---:|---:|---:|---:|
| gl_compatibility | 48.17 | 23.91ms | 25.63ms | 3.18ms | 2.73ms | 224 |
| forward_plus | 49.72 | 21.78ms | 22.86ms | 3.02ms | 4.42ms | 212 |

## Forward+ CPU costs per rendered frame

The rows below are disjoint within the instrumented combat/exhaust work. Parent totals are shown separately to avoid double counting.

| Work | Mean CPU time |
|---|---:|
| Force integration (includes terrain sampling) | 3.54ms |
| Thruster power selection | 2.44ms |
| Tilt and wobble | 0.46ms |
| Remaining flight/autopilot/pose work | 1.47ms |
| Spacing and neighbor-grid construction | 0.64ms |
| Pursuit/circling steering | 0.52ms |
| Missile simulation and collision | 0.76ms |
| Target selection | 0.01ms |
| Remaining battle bookkeeping and firing | 1.08ms |
| Exhaust smoothing/material/light updates | 2.11ms |

Battle update total: **10.92ms**. Exhaust updates outside that total: **2.11ms**. Combined measured combat CPU work: **13.04ms**.

All terrain-query calls together take 1.54ms, across approximately 640 queries per frame. This overlaps force integration and spacing, so it must not be added to the table total.

Render CPU/GPU timings are separate from the combat hooks. CPU and GPU can overlap; adding them does not produce total wall-clock frame time. The hooks do not fully attribute all engine, callback and presentation overhead.

## Before/after removing dodging

A matching CPU-only test used a fixed 1/30-second simulation step, 30 simulated seconds of warmup, and 10 simulated seconds of measurement. Battle update dropped from 21.25ms to 12.50ms; the removed dodge scan previously took 8.00ms. Exhaust updates took another 2.61ms after removal. These fixed-step headless numbers should not be compared directly to rendered FPS; rendered runs integrate a different number of 120Hz flight substeps per frame.

## Next optimization targets

Thruster power selection plus exhaust updates consume about 4.56ms per Forward+ frame, more than force integration. Precompute marker actuator directions, avoid updating disabled lights, and sleep exhaust scripts after power settles. Terrain sampling is another concrete target: skip exact queries only when safely above a maximum radius computed from the actual collider. Keep the force model and collision accuracy.
