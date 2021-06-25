{ pkgsFunc ? import ./dep/nixpkgs
}:

rec {
  pkgs = pkgsFunc {
    config = {};
    overlays = [
      (import "${thunkSource ./dep/nixpkgs-mozilla}/rust-overlay.nix")
    ];
  };

  ledgerPkgs = pkgsFunc {
    crossSystem = {
      config = "armv6l-unknown-none-eabi";
      #useLLVM = true;
      gcc = {
        arch = "armv6t2";
        fpu = "vfpv2";
      };
      rustc = {
        arch = "thumbv6m";
        config = "thumbv6m-none-eabi";
      };
    };
    overlays = [
      (import "${thunkSource ./dep/nixpkgs-mozilla}/rust-overlay.nix")
    ];
  };

  # TODO: Replace this with `thunkSource` from nix-thunk for added safety
  # checking once CI stuff is separated.
  thunkSource = p:
    if builtins.pathExists (p + /thunk.nix)
      then (import (p + /thunk.nix))
    else p;

  usbtool = import ./usbtool.nix { };

  gitignoreNix = import (thunkSource ./dep/gitignore.nix) { inherit (pkgs) lib; };

  inherit (gitignoreNix) gitignoreSource;

  gitIgnoredSrc = gitignoreSource ./.;

  speculos = pkgs.callPackage ./dep/speculos { };

  speculosItself = speculos.speculos;

  buildRustPackageClang = ledgerRustPlatform.buildRustPackage.override {
    stdenv = ledgerPkgs.clangStdenv;
  };

  rustShell = buildRustPackageClang {
    stdenv = ledgerPkgs.clangStdenv;
    name = "rust-app";
    src = null;
    # We just want dev shell
    unpackPhase = ''
      echo got in shell > $out
      exit 0;
    '';
    cargoVendorDir = "pretend-exists";
    depsBuildBuild = [ ledgerPkgs.buildPackages.stdenv.cc ];
    nativeBuildInputs = [ ];
    buildInputs = [ rustPackages.rust-std ];
    verifyCargoDeps = true;
    target = "thumbv6m-none-eabi";

    # Cargo hash must be updated when Cargo.lock file changes.
    cargoSha256 = "1kdg77ijbq0y1cwrivsrnb9mm4y5vlj7hxn39fq1dqlrppr6fdrr";

    # It is more reliable to trick a stable rustc into doing unstable features
    # than use an unstable nightly rustc. Just because we want unstable
    # langauge features doesn't mean we want a less tested implementation!
    RUSTC_BOOTSTRAP = 1;

    meta = {
      platforms = pkgs.lib.platforms.all;
    };
  };

  rustPackages = pkgs.rustChannelOf {
    channel = "1.53.0";
    sha256 = "1p4vxwv28v7qmrblnvp6qv8dgcrj8ka5c7dw2g2cr3vis7xhflaa";
  };

  rustc = rustPackages.rust.override {
    targets = [
      "thumbv6m-none-eabi"
    ];
  };

  rustPlatform = pkgs.makeRustPlatform {
    inherit (rustPackages) cargo;
    inherit rustc;
  };

  ledgerRustPlatform = ledgerPkgs.makeRustPlatform {
    inherit (rustPackages) cargo;
    inherit rustc;
  };
}
