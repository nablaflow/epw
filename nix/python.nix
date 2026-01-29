{
  buildPythonPackage,
  lib,
  polars,
  pytestCheckHook,
  rustPlatform,
  setuptools,
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

    pyproject = true;
    build-system = [setuptools];

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit pname version src;
      hash = "sha256-/7Fjq3GInAI8TXAk1qOc0c5g5gxcJLCV/6SIv0dkyLI=";
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
