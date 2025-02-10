{
  crane,
  rustToolchain,
  pkgs,
  lib,
  cargo-hakari,
  python3,
}: let
  craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchain;

  src = lib.fileset.toSource {
    root = ../.;

    fileset = lib.fileset.unions [
      ../Cargo.toml
      ../Cargo.lock
      ../deny.toml
      ../rustfmt.toml
      ../taplo.toml
      ../.config
      (craneLib.fileset.commonCargoSources ../crates)
      (lib.fileset.fileFilter (file: builtins.any file.hasExt ["rs" "toml" "snap" "epw"]) ../crates)
    ];
  };

  commonArgs = {
    inherit src;

    strictDeps = true;
    doCheck = false;

    nativeBuildInputs = [
      python3
    ];
  };

  cargoArtifacts = craneLib.buildDepsOnly commonArgs;

  epw = craneLib.buildPackage (commonArgs
    // {
      pname = "epw";
      cargoExtraArgs = "-p epw --features polars";
      inherit cargoArtifacts;
    });

  epw-py = craneLib.buildPackage (commonArgs
    // {
      pname = "epw-py";
      cargoExtraArgs = "-p epw-py";
      inherit cargoArtifacts;

      installPhaseCommand = ''
        mkdir -p $out/lib
        cp target/release/libepw_py.so $out/lib/epw.so
      '';
    });

  epw-ex = craneLib.buildPackage (commonArgs
    // {
      pname = "epw-ex";
      cargoExtraArgs = "-p epw-ex";
      inherit cargoArtifacts;
    });
in {
  checks = {
    inherit epw epw-py;

    epw-clippy = craneLib.cargoClippy (commonArgs
      // {
        inherit cargoArtifacts;

        pname = "epw-clippy";
        cargoClippyExtraArgs = "-p epw -- --deny warnings -W clippy::pedantic";
      });

    epw-py-clippy = craneLib.cargoClippy (commonArgs
      // {
        inherit cargoArtifacts;

        pname = "epw-py-clippy";
        cargoClippyExtraArgs = "-p epw-py -- --deny warnings -W clippy::pedantic";
      });

    epw-ex-clippy = craneLib.cargoClippy (commonArgs
      // {
        inherit cargoArtifacts;

        pname = "epw-ex-clippy";
        cargoClippyExtraArgs = "-p epw_ex -- --deny warnings -W clippy::pedantic";
      });

    ws-fmt = craneLib.cargoFmt {inherit src;};

    ws-toml-fmt = craneLib.taploFmt {
      src = lib.sources.sourceFilesBySuffices src [".toml"];
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

      nativeBuildInputs = [
        cargo-hakari
      ];
    };
  };

  packages = {
    epw-py-cdylib = epw-py;
  };
}
