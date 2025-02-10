{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    crane.url = "github:ipetkov/crane";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = inputs @ {
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

        overlays = [
          (import rust-overlay)

          (final: prev: {
            poetry2nix = inputs.poetry2nix.lib.mkPoetry2Nix {pkgs = prev;};
            beamPackages = prev.beam_minimal.packagesWith prev.beam_minimal.interpreters.erlang_27;
          })
        ];
      };

      rustToolchain = pkgs.rust-bin.stable.latest.default;

      rustWs = pkgs.callPackage ./nix/rust-ws.nix {inherit crane rustToolchain;};
      epwPy = pkgs.callPackage ./nix/python.nix {inherit (rustWs.packages) epw-py-cdylib;};
    in {
      checks = rustWs.checks // epwPy.checks;

      packages = rustWs.packages;

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
        ];
      };

      formatter = pkgs.alejandra;
    });
}
