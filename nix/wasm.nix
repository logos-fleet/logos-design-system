{ pkgs, common, qtWasm }:

# THE DESIGN SYSTEM FOR WEBASSEMBLY — the same static QML modules as
# ./library.nix, compiled against Qt-for-wasm (logos-nix `nix/wasm/qt.nix`).
#
# WHY IT EXISTS. ADR 0004's Web container renders a Downloaded module's UI as QML
# on ONE bundled Qt-wasm runtime, and "with the Logos look" means the runtime
# binary carries the type set: `Logos.Theme`, `Logos.Icons` and `Logos.Controls`
# are linked into the runtime, and a module ships QML/JS text that imports them
# (the Canonic model the spike validated). So the runtime needs this artifact,
# and nothing about the design system's own sources changes to produce it.
#
# WHAT IS DIFFERENT FROM ./library.nix, and it is only the toolchain:
#
#   * no `qt6.wrapQtAppsHook` and no native Qt in the inputs — a wasm build that
#     can see the build platform's Qt is a build that can link the wrong one;
#   * the configure is hand-rolled, because cmake's nix hook injects the build
#     platform's compiler and sysroot and the whole point here is the toolchain
#     file qtWasm.cmakeFlags names;
#   * nothing to strip or fix up: a wasm archive is neither ELF nor Mach-O.
#
# The install tree is the ordinary one (`lib/`, `lib/cmake/LogosDesignSystem`,
# `lib/objects`), so a consumer reaches it exactly as on desktop:
# `find_package(LogosDesignSystem CONFIG)` and `Logos::DesignSystem`.
pkgs.stdenv.mkDerivation {
  pname = "logos-design-system-wasm";
  version = "1.0.0";

  inherit (common) src;

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.ninja
  ];

  dontUseCmakeConfigure = true;
  dontWrapQtApps = true;
  dontStrip = true;
  dontFixup = true;

  configurePhase = ''
    runHook preConfigure
    ${pkgs.logosEmscriptenSetup}
    cmake -S . -B build -GNinja \
      ${pkgs.lib.escapeShellArgs qtWasm.cmakeFlags} \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=$out
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    ${pkgs.logosEmscriptenSetup}
    cmake --build build --parallel $NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    ${pkgs.logosEmscriptenSetup}
    cmake --install build

    # A wasm archive is not inspectable by the ordinary tools and "it installed"
    # is not the same claim as "it is wasm": llvm-ar reads the member names off
    # each archive and the \0asm magic says what the members ARE. Without this,
    # a toolchain-file regression that quietly built native objects would ship
    # an artifact that only fails when the runtime tries to link it.
    for a in $out/lib/*.a; do
      member=$(${pkgs.logosEmscriptenLlvm}/bin/llvm-ar t "$a" | head -1)
      ${pkgs.logosEmscriptenLlvm}/bin/llvm-ar p "$a" "$member" > member.o
      head -c 4 member.o | od -An -c | grep -q '\\0   a   s   m' || {
        echo "$a member $member is not a wasm object" >&2
        head -c 16 member.o | od -An -c >&2
        exit 1
      }
    done
    echo "logos-design-system-wasm: $(ls $out/lib/*.a | wc -l | tr -d ' ') wasm archives"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Logos Design System as static QML modules for wasm32-emscripten";
    platforms = platforms.unix;
  };
}
