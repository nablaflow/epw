{
  epw-py-cdylib,
  stdenv,
  lib,
  python3Packages,
}: {
  checks = {
    epw-py-test = stdenv.mkDerivation {
      pname = "epw-py-test";
      version = "dev";

      src = lib.fileset.toSource {
        root = ../crates/epw-py;

        fileset = lib.fileset.unions [
          ../crates/epw-py/tests
        ];
      };

      nativeBuildInputs = with python3Packages; [
        polars
        pytest
        ruff
      ];

      doCheck = true;

      checkPhase = ''
        export PYTHONPATH="${epw-py-cdylib}/lib:$PYTHONPATH"

        pytest .
      '';

      installPhase = "touch $out";
    };
  };
}
