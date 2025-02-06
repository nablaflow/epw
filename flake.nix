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

      fs = pkgs.lib.fileset;
      src = fs.toSource {
        root = ./.;
        fileset = fs.unions [
          ./Cargo.toml
          ./Cargo.lock
          (fs.fileFilter (file: builtins.any file.hasExt ["rs" "toml" "snap" "epw"]) ./crates)
        ];
      };

      commonArgs = {
        inherit src;

        pname = "epw-rust-workspace";
        version = "master";

        strictDeps = true;
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs;
    in {
      checks = {
        rust-ws-clippy = craneLib.cargoClippy (commonArgs
          // {
            inherit cargoArtifacts;

            cargoClippyExtraArgs = "--all-targets -- --deny warnings -W clippy::pedantic";
          });

        rust-ws-fmt = craneLib.cargoFmt commonArgs;

        rust-ws-nextest = craneLib.cargoNextest (commonArgs
          // {
            inherit cargoArtifacts;

            partitions = 1;
            partitionType = "count";
          });
      };

      # packages.default = nablaflow-cli.app;

      devShells.default = pkgs.mkShell {
        # inputsFrom = builtins.attrValues self.checks.${system};

        packages = with pkgs; [
          cargo-insta
          cargo-outdated
          rustToolchain
        ];
      };

      # apps.default = flake-utils.lib.mkApp {
      #   drv = nablaflow-cli.app;
      # };

      formatter = pkgs.alejandra;
    });
}
