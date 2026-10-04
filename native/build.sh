#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
GODOT_CPP_COMMIT=507ed9d840c01a3c5b2a39af8bb4000bfac30bf5
if [ ! -d vendor/godot-cpp/.git ]; then
    mkdir -p vendor
    git clone https://github.com/godotengine/godot-cpp.git vendor/godot-cpp
fi
git -C vendor/godot-cpp checkout "$GODOT_CPP_COMMIT"
case "${1:-linux}" in
linux)
    cmake -S . -B build-sim -DCMAKE_BUILD_TYPE=Release -DGODOTCPP_TARGET=template_release
    cmake --build build-sim --parallel "${BUILD_JOBS:-8}"
    ;;
web)
    : "${EMSDK_DIR:?Set EMSDK_DIR to an Emscripten 4.0.20 SDK directory}"
    source "$EMSDK_DIR/emsdk_env.sh"
    emcmake cmake -S . -B build-web -DCMAKE_BUILD_TYPE=Release -DGODOTCPP_TARGET=template_release -DGODOTCPP_THREADS=OFF
    cmake --build build-web --parallel "${BUILD_JOBS:-8}"
    ;;
*) echo "Usage: $0 [linux|web]" >&2; exit 1 ;;
esac
