{
  description = "Logos Design System - Qt/QML design system (themes, colors, typography)";

  inputs = {
    logos-nix.url = "github:logos-co/logos-nix";
    nixpkgs.follows = "logos-nix/nixpkgs";

    # Bundlers used to produce redistributable artifacts (AppImage / .app).
    # Same three tools basecamp uses (see logos-basecamp/flake.nix).
    # Every bundler's transitive nixpkgs / logos-nix / nix-bundle-dir follows
    # ours so the whole graph evaluates against one dependency set (avoids
    # `logos-nix_*` / `nixpkgs_*` clones in flake.lock).
    nix-bundle-dir = {
      url = "github:logos-co/nix-bundle-dir";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-nix.follows = "logos-nix";
    };
    nix-bundle-appimage = {
      url = "github:logos-co/nix-bundle-appimage";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
    };
    nix-bundle-macos-app = {
      url = "github:logos-co/nix-bundle-macos-app";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.logos-nix.follows = "logos-nix";
      inputs.nix-bundle-dir.follows = "nix-bundle-dir";
    };
  };

  outputs = { self, logos-nix, nixpkgs, nix-bundle-dir, nix-bundle-appimage, nix-bundle-macos-app }:
    let
      # nix-bundle-dir RUNS on the builder, so on a cross target it comes from
      # the build system. It is also ELF/Mach-O only (its bundle.sh branches
      # `file -b` -> Mach-O | ELF with no PE case), so a Windows bundle must not
      # be produced through it -- see the guard on `storybook-bundle` below.
      buildSystemFor = target:
        if target == "x86_64-windows" then "x86_64-linux" else target;

      # Adds the "x86_64-windows" pseudo-system. A cross derivation's `system`
      # attr is its BUILD platform, so these evaluate anywhere and realise on
      # x86_64-linux.
      forAllSystems = f: logos-nix.lib.forAllTargets ({ system, pkgs }:
        f { inherit system pkgs; });
    in
    {
      packages = forAllSystems ({ pkgs, system, ... }:
        let
          common = import ./nix/common.nix { inherit pkgs; };
          storybookDrv = import ./nix/storybook.nix { inherit pkgs common; };
          dirBundler = nix-bundle-dir.bundlers.${buildSystemFor system}.qtApp;
        in
        rec {
          default = import ./nix/library.nix { inherit pkgs common; };
          storybook = storybookDrv;
          tests = import ./nix/tests.nix { inherit pkgs common; };

          # Self-contained tree: Qt libs + QML modules copied next to the
          # binary, RPATHs rewritten so nothing references /nix/store at
          # runtime. Base for the platform-specific bundles below.
          bin-bundle-dir = dirBundler storybookDrv;
        }
        # THE WEB CONTAINER'S COPY. Same static QML modules, compiled for
        # wasm32-emscripten so they can be linked into the bundled Qt-wasm QML
        # runtime ADR 0004 describes. Not on the Windows pseudo-system: a wasm
        # artifact is produced by an ordinary NATIVE derivation (logos-nix
        # README, "Wasm target"), so it belongs to the real systems only.
        // pkgs.lib.optionalAttrs (system != "x86_64-windows") (
          let qtWasm = logos-nix.lib.qtWasmFor system; in
          rec {
            wasm = import ./nix/wasm.nix { inherit pkgs common qtWasm; };

            # A consumer of that artifact, because "the archives installed" and
            # "a wasm image gets the Logos types" are different claims.
            wasm-smoke = import ./nix/wasm-smoke.nix {
              inherit pkgs common qtWasm;
              designSystemWasm = wasm;
            };
          }
        )
        // pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          # Single-file .AppImage — click-to-run on any modern Linux with no
          # Nix installed. Consumed by CI (uploaded as build artifact).
          bin-appimage = nix-bundle-appimage.lib.${system}.mkAppImage {
            drv = storybookDrv;
            name = "logos-storybook";
            bundle = dirBundler storybookDrv;
            desktopFile = ./assets/logos-storybook.desktop;
            icon = ./assets/logos-storybook.png;
          };
        } // pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
          # .app bundle — the macOS equivalent, produced only on Darwin.
          bin-macos-app = nix-bundle-macos-app.lib.${system}.mkMacOSApp {
            drv = storybookDrv;
            name = "LogosStorybook";
            bundle = dirBundler storybookDrv;
            icon = ./assets/macos/logos-storybook.icns;
            infoPlist = ./assets/macos/Info.plist.in;
            entitlements = ./assets/macos/LogosStorybook.entitlements;
          };
        });

      apps = forAllSystems ({ system, ... }: rec {
        storybook = {
          type = "app";
          program = "${self.packages.${system}.storybook}/bin/LogosStorybook";
        };
        tests = {
          type = "app";
          program = "${self.packages.${system}.tests}/bin/LogosDesignSystemTests";
        };
        default = storybook;
      });

      checks = forAllSystems ({ system, pkgs, ... }: {
        tests = self.packages.${system}.tests;
      }
      # Not on Windows (no wasm there) and not in a default `nix flake check`
      # on a Mac: the wasm Qt it links against is built from source. x86_64-linux
      # is where CI may pay for it, the same placement logos-nix gives its own
      # Qt-wasm probe.
      // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
        wasm-smoke = self.packages.${system}.wasm-smoke;
      });

      devShells = forAllSystems ({ pkgs, ... }: {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.cmake
            pkgs.ninja
          ];
          buildInputs = [
            pkgs.qt6.qtbase
            pkgs.qt6.qtdeclarative
          ];
          shellHook = ''
            echo "Logos Design System development shell"
            echo "Run: cmake -B build -GNinja && cmake --build build"
          '';
        };
      });
    };
}
