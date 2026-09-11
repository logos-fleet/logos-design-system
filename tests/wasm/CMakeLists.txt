# WASM SMOKE: does a consumer linking Logos::DesignSystem still get the static
# QML plugins under a STATIC Qt-for-wasm?
#
# A SEPARATE PROJECT, not a target in the main build, and that is the point: it
# consumes the INSTALLED package through `find_package(LogosDesignSystem CONFIG)`,
# which is the path where the umbrella's WHOLE_ARCHIVE genexpr has to survive
# install(EXPORT)'s target-name rewrite. The spike that gated ADR 0004 reported
# the umbrella colliding with Qt's in-tree static-plugin auto-import and linked
# the backing libs plainly instead; this is where that claim gets re-tested
# against a nix-built wasm Qt rather than worked around.
cmake_minimum_required(VERSION 3.24)
project(LogosDesignSystemWasmSmoke LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Svg)
find_package(LogosDesignSystem CONFIG REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(logos_ds_wasm_smoke main.cpp)

qt_add_qml_module(logos_ds_wasm_smoke
    URI LogosDesignSystemWasmSmoke
    VERSION 1.0
    QML_FILES Main.qml
)

target_link_libraries(logos_ds_wasm_smoke PRIVATE
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Svg
    Logos::DesignSystem
)

# Static Qt: qt_add_executable's finalizer links the design system's QML plugins
# plainly while the umbrella links them WHOLE_ARCHIVE, and CMake refuses both.
# The design system's package config ships the one-line resolution.
logos_design_system_resolve_static_plugins(logos_ds_wasm_smoke)
