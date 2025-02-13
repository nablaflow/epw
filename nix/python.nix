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
      hash = "sha256-CeMoe3iL/8Zv0OIaqv8lYZE61JG0hM/TPk8yE4DQxz8=";
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
