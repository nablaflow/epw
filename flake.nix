{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    crane.url = "github:ipetkov/crane";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    flake-utils,
    rust-overlay,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;

        overlays = [(import rust-overlay)];
      };

      rustToolchain = pkgs.rust-bin.stable.latest.default;

      craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

      src = pkgs.lib.fileset.toSource {
        root = ./.;

        fileset = pkgs.lib.fileset.unions [
          ./Cargo.toml
          ./Cargo.lock
          ./deny.toml
          ./rustfmt.toml
          ./taplo.toml
          ./.config
          (craneLib.fileset.commonCargoSources ./crates)
          (pkgs.lib.fileset.fileFilter (file: builtins.any file.hasExt ["rs" "toml" "snap" "epw"]) ./crates)
        ];
      };

      commonArgs = {
        inherit src;

        strictDeps = true;

        nativeBuildInputs = with pkgs; [
          python3
        ];

        doCheck = false;
      };

      cargoArtifacts = craneLib.buildDepsOnly (commonArgs
        // {
          inherit (craneLib.crateNameFromCargoToml {inherit src;}) version;
          pname = "epw-workspace";
        });

      individualCrateArgs =
        commonArgs
        // {
          inherit cargoArtifacts;
          inherit (craneLib.crateNameFromCargoToml {inherit src;}) version;
        };

      epw = craneLib.buildPackage (individualCrateArgs
        // {
          pname = "epw";
          cargoExtraArgs = "-p epw --features polars";

          src = pkgs.lib.fileset.toSource {
            root = ./.;

            fileset = pkgs.lib.fileset.unions [
              ./Cargo.toml
              ./Cargo.lock
              (craneLib.fileset.commonCargoSources ./crates/epw)
              (craneLib.fileset.commonCargoSources ./crates/workspace-hack)
              (pkgs.lib.fileset.fileFilter (file: builtins.any file.hasExt ["snap" "epw"]) ./crates/epw)
            ];
          };
        });

      epw-py = craneLib.buildPackage (individualCrateArgs
        // {
          pname = "epw-py";
          cargoExtraArgs = "-p epw-py";

          src = pkgs.lib.fileset.toSource {
            root = ./.;

            fileset = pkgs.lib.fileset.unions [
              ./Cargo.toml
              ./Cargo.lock
              (craneLib.fileset.commonCargoSources ./crates/epw)
              (craneLib.fileset.commonCargoSources ./crates/workspace-hack)
              (craneLib.fileset.commonCargoSources ./crates/epw-py)
              (pkgs.lib.fileset.fileFilter (file: builtins.any file.hasExt ["pyi"]) ./crates/epw-py)
            ];
          };

          doCheck = true;

          postBuild = ''
            pushd crates/epw-py
            ${pkgs.lib.getExe pkgs.maturin} build --frozen --locked --offline --release --manylinux off --out dist >"$cargoBuildLog"
            popd
          '';

          nativeCheckInputs = with pkgs; [
            python3Packages.polars
          ];

          checkPhase = ''
            pushd crates/epw-py
            ${pkgs.python3Packages.pip}/bin/pip install dist/*.whl --no-dependencies --verbose --no-index --no-warn-script-location --prefix="$out" --no-cache
            popd

            export PYTHONPATH="$out/${pkgs.python3.sitePackages}:$PYTHONPATH"
            python3 -c 'import epw; epw.parse_into_dataframe(b"")'
          '';

          installPhase = ''
            pushd crates/epw-py
            ${pkgs.python3Packages.pip}/bin/pip install dist/*.whl --no-dependencies --verbose --no-index --no-warn-script-location --prefix="$out" --no-cache
            popd
          '';
        });
    in {
      checks = {
        inherit epw epw-py;

        ws-clippy = craneLib.cargoClippy (commonArgs
          // {
            inherit cargoArtifacts;

            cargoClippyExtraArgs = "--all-targets -- --deny warnings -W clippy::pedantic";
          });

        ws-fmt = craneLib.cargoFmt {inherit src;};

        ws-toml-fmt = craneLib.taploFmt {
          src = pkgs.lib.sources.sourceFilesBySuffices src [".toml"];
        };

        ws-deny = craneLib.cargoDeny {inherit src;};

        ws-nexttest = craneLib.cargoNextest (commonArgs
          // {
            inherit cargoArtifacts;
            doCheck = true;
            partitions = 1;
            partitionType = "count";
          });

        ws-hakari = craneLib.mkCargoDerivation {
          inherit src;

          pname = "ws-hakari";

          cargoArtifacts = null;
          doInstallCargoArtifacts = false;

          buildPhaseCargoCommand = ''
            cargo hakari generate --diff  # workspace-hack Cargo.toml is up-to-date
            cargo hakari manage-deps --dry-run  # all workspace crates depend on workspace-hack
            cargo hakari verify
          '';

          nativeBuildInputs = with pkgs; [
            cargo-hakari
          ];
        };
      };

      packages = {
        inherit epw epw-py;
      };

      devShells.default = pkgs.mkShell {
        inputsFrom = builtins.attrValues self.checks.${system};

        packages = with pkgs; [
          cargo-insta
          cargo-outdated
          (python3.withPackages (ps: with ps; [polars]))
          poetry
          maturin
        ];
      };

      formatter = pkgs.alejandra;
    });
}
