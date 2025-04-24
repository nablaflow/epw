{
  buildPythonPackage,
  lib,
  rustPlatform,
  pytestCheckHook,
  polars,
}: let
  epw-py = buildPythonPackage rec {
    pname = "epw";
    version = "dev";

    src = lib.fileset.toSource {
      root = ../.;

      fileset = lib.fileset.unions [
        ../Cargo.toml
        ../Cargo.lock
        (lib.fileset.fileFilter (file: builtins.any file.hasExt ["rs" "toml" "py" "typed"]) ../crates)
      ];
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit pname version src;
      hash = "sha256-oGOl7+pra4X2n/ap+BuOzLIRX6V3fG+PUGZ/fJYwCPY=";
    };

    nativeBuildInputs = with rustPlatform; [
      cargoSetupHook
      maturinBuildHook
    ];

    dependencies = [
      polars
    ];

    nativeCheckInputs = [
      pytestCheckHook
    ];

    doCheck = true;

    buildAndTestSubdir = "crates/epw-py";
  };
in {
  checks = {
    inherit epw-py;
  };

  packages = {
    inherit epw-py;
  };
}
