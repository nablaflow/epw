{
  craneLib,
  pkgs,
  lib,
  python3,
}: let
  src = lib.fileset.toSource {
    root = ../.;

    fileset = lib.fileset.unions [
      ../Cargo.toml
      ../Cargo.lock
      ../deny.toml
      ../rustfmt.toml
      ../taplo.toml
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
      inherit cargoArtifacts;

      pname = "epw";
      cargoExtraArgs = "-p epw";
    });

  epw-ex = craneLib.buildPackage (commonArgs
    // {
      inherit cargoArtifacts;

      pname = "epw-ex";
      cargoExtraArgs = "-p epw_ex";
    });
in {
  checks = {
    inherit epw epw-ex;

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
  };

  packages = {};
}
