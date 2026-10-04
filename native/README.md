# Native combat simulation

`SunburnSimulation` advances the existing 200–230 ship fleet in one C++ call per
frame. It ports pursuit/circling, altitude spacing, separation, weighted target
selection, one-second velocity histories, orbital interception, damped yaw and
attitude stabilization, 120 Hz thrust integration, swept missile collisions,
ground impacts, and missile lifetime handling. It keeps the existing ship and
missile scenes; scene creation, hit/death callbacks, audio, HUD and plot stay in
GDScript. No population, damage, movement, or firing settings are reduced.

The battle manager uses C++ when the extension class is registered and retains
the original GDScript path for comparison and platforms without a native binary.
Linux and single-threaded wasm32 binaries are built here. The Windows export
continues using GDScript until a Windows extension DLL is built and added to the
manifest; the Windows preset deliberately excludes the extension.

## Build

Bindings are pinned to godot-cpp commit
`507ed9d840c01a3c5b2a39af8bb4000bfac30bf5` (Godot API 4.7). CMake, a C++17 compiler,
and Python are needed. Downloaded bindings and build directories are ignored.

```sh
./native/build.sh linux
EMSDK_DIR=/path/to/emsdk ./native/build.sh web
```

Use Emscripten 4.0.20 for both engine and extension. The SDK used during this
session is `/tmp/sunburn-emsdk`; re-create it if `/tmp` has been cleaned.

The matching engine template is built from `../engine`:

```sh
source /path/to/emsdk/emsdk_env.sh
scons platform=web target=template_release threads=no dlink_enabled=yes -j8
```

The Web export preset enables extension support and points at
`godot.web.template_release.wasm32.nothreads.dlink.zip`. Keep the generated
`index.side.wasm` and `sunburn_sim.wasm` beside `index.html`, `index.js`,
`index.wasm`, `index.pck`, and the other exported files when hosting.

Do not remove `-fvisibility=hidden` from the extension's compile options: exposing
inline godot-cpp helper symbols can collide with engine symbols and cause a WASM
`function signature mismatch` at startup. The entry function is explicitly
exported.

## Verification

```sh
../engine/bin/godot.linuxbsd.editor.x86_64 --headless --path . --script tests/native_sim_test.gd
../engine/bin/godot.linuxbsd.editor.x86_64 --headless --path . --script tests/missile_impulse_test.gd
```

`Web benchmark` is a separate export preset using the `web_bench` feature to
start `tests/native_web_bench.tscn`. It preserves the same seeded fleet and
rendering while disabling damage so population stays constant. It warms up for
30 seconds and reports 10 seconds of FPS and simulation CPU measurements.
Append `?native=0` to compare GDScript and `?native=1` for C++. Normal Web exports
start the normal game; benchmark scenes are excluded from them.
