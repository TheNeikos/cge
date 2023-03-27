{
  description = "The Card Game Engine project";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-22.11";
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = { self, nixpkgs, crane, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ (import rust-overlay) ];
        };

        rustTarget = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        craneLib = (crane.mkLib pkgs).overrideToolchain rustTarget;

        src = craneLib.cleanCargoSource ./.;

        cargoArtifacts = craneLib.buildDepsOnly {
          inherit src;
          cargoExtraArgs = "--all-features --all";
        };

        cge = craneLib.buildPackage {
          inherit cargoArtifacts src;
          cargoExtraArgs = "--all-features --all";
        };

      in
      rec {
        checks = {
          inherit cge;

          cge-clippy = craneLib.cargoClippy {
            inherit cargoArtifacts src;
            cargoExtraArgs = "--all --all-features";
            cargoClippyExtraArgs = "-- --deny warnings";
          };

          cge-fmt = craneLib.cargoFmt {
            inherit src;
          };
        };

        devShells.default = devShells.cge;
        devShells.cge = pkgs.mkShell {
          buildInputs = [ ];

          nativeBuildInputs = [
            rustTarget

            pkgs.cargo-msrv
            pkgs.cargo-deny
            pkgs.cargo-expand
            pkgs.cargo-bloat
            pkgs.cargo-fuzz

            pkgs.gitlint
          ];
        };
      }
    );
}
