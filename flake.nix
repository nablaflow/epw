{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    crane.url = "github:ipetkov/crane";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    crane,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;

        overlays = [
          (final: prev: {
            craneLib = crane.mkLib prev;
            beamPackages = prev.beam_minimal.packagesWith prev.beam_minimal.interpreters.erlang_27;
          })
        ];
      };

      rustWs = pkgs.callPackage ./nix/rust-ws.nix {};
      epwPy = pkgs.python3Packages.callPackage ./nix/python.nix {};
    in {
      checks = rustWs.checks // epwPy.checks;

      packages = rustWs.packages // epwPy.packages;

      devShells.default = pkgs.mkShell {
        inputsFrom = builtins.attrValues self.checks.${system};

        packages = with pkgs; [
          beamPackages.elixir
          beamPackages.erlang
          beamPackages.hex
          beamPackages.rebar3
          cargo-insta
          cargo-outdated
          poetry
          maturin
          ruff
        ];
      };

      formatter = pkgs.alejandra;
    });
}
