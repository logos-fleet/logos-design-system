{ pkgs, common, qtWasm, designSystemWasm }:

# DOES A CONSUMER OF THE WASM DESIGN SYSTEM GET ITS TYPES? See tests/wasm for
# what is built and why it is a separate cmake project.
#
# "It linked" is the weak half of this check. The strong half is reading the
# REGISTRATION SYMBOLS back off the image: `Logos::DesignSystem` is an INTERFACE
# target whose plugin halves are wrapped in `$<LINK_LIBRARY:WHOLE_ARCHIVE,...>`,
# and if that genexpr does not survive install(EXPORT)'s target-name rewrite —
# or if a static Qt's own plugin-import machinery swallows it — the link still
# SUCCEEDS and the image simply has no Logos types in it. The first symptom would
# be `module "Logos.Controls" is not installed` inside a webview, with the build
# long since green.
pkgs.stdenv.mkDerivation {
  pname = "logos-design-system-wasm-smoke";
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

  buildPhase = ''
    runHook preBuild
    ${pkgs.logosEmscriptenSetup}

    # CMAKE_FIND_ROOT_PATH as well as CMAKE_PREFIX_PATH: the Emscripten
    # toolchain sets CMAKE_FIND_ROOT_PATH_MODE_PACKAGE to ONLY, so a prefix
    # named only in CMAKE_PREFIX_PATH is never searched.
    cmake -S tests/wasm -B build-wasm-smoke -GNinja \
      ${pkgs.lib.escapeShellArgs qtWasm.cmakeFlags} \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_PREFIX_PATH="${qtWasm.prefix};${designSystemWasm}" \
      -DCMAKE_FIND_ROOT_PATH="${qtWasm.prefix};${designSystemWasm}"
    cmake --build build-wasm-smoke --parallel $NIX_BUILD_CORES

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    image=build-wasm-smoke/logos_ds_wasm_smoke.wasm
    [ -f "$image" ] || { echo "the wasm link produced no image" >&2; exit 1; }

    # WHAT THE IMAGE MUST CONTAIN, read as bytes rather than as symbols: a
    # Release wasm link runs wasm-opt, which leaves 19 names in the symbol
    # table, so `llvm-nm` can say nothing about what got linked.
    #
    # `Logos_<Mod>Plugin` is the RTTI name of each module's
    # QQmlEngineExtensionPlugin, and it lives in the `<mod>_qmlplugin` archive —
    # the one whose static constructor REGISTERS the module, and the one a
    # linker drops unless it is linked WHOLE_ARCHIVE. That is the claim this
    # check exists to make; the link succeeding says nothing about it.
    #
    # NOT the qrc prefix: `:/qt/qml/Logos/Theme/` and `.../Icons/` appear in the
    # image but `.../Controls/` does not, while Controls' own type data
    # (`LogosButton.Variant.Primary`) plainly does — the string table does not
    # carry one prefix literal per module, so a per-module prefix grep would be
    # asserting something about string dedup, not about linkage. A type name
    # from the biggest module is the honest second marker.
    for mod in Theme Icons Controls; do
      grep -a -q "Logos_''${mod}Plugin" "$image" || {
        echo "the image carries no Logos_''${mod}Plugin: the static QML plugin was" >&2
        echo "  dropped by the linker (the WHOLE_ARCHIVE resolution regressed)." >&2
        exit 1
      }
    done
    grep -a -q "LogosButton" "$image" || {
      echo "the image carries no LogosButton: Logos.Controls' compiled QML is" >&2
      echo "  not in it, whatever its plugin says." >&2
      exit 1
    }

    mkdir -p $out/www
    cp build-wasm-smoke/logos_ds_wasm_smoke.wasm \
       build-wasm-smoke/logos_ds_wasm_smoke.js \
       build-wasm-smoke/logos_ds_wasm_smoke.html \
       build-wasm-smoke/qtloader.js $out/www/

    raw=$(wc -c < $out/www/logos_ds_wasm_smoke.wasm)
    echo "logos-ds-wasm-smoke: Qt ${qtWasm.version}, Logos.Theme/.Icons/.Controls registered"
    echo "  raw $raw B"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "A wasm image linking Logos::DesignSystem, with its QML registrations asserted";
    platforms = platforms.unix;
  };
}
