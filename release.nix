let
  pkgsSrc = import ./dep/nixpkgs/thunk.nix;
  lib = import (pkgsSrc + "/lib");

  x86_64-linux = import ./. rec {
    inherit pkgsSrc;
    localSystem = { system = "x86_64-linux"; };
  };
  x86_64-darwin = builtins.removeAttrs (import ./. rec {
    inherit pkgsSrc;
    localSystem = { system = "x86_64-darwin"; };
  }) [
    "stableRustPackages"
    "buildRustCrateForPkgsLedger"
    "buildRustCrateForPkgsWrapper"
    "buildRustPackageClang"
    "cargo-ledger"
    "cargo-watch"
    "cargoLedgerPreHook"
    "crate2nix"
    #"gccLibsPreHook"
    "generic-cli"
    #"gitignoreNix"
    #"gitignoreSource"
    "ledgerCore"
    "ledgerCompilerBuiltins"
    #"ledgerPkgs"
    "ledgerRustPlatform"
    "ledgerStdlib"
    "ledgerStdlib-nix"
    "ledgerStdlibCI"
    #"ledgerctl"
    #"lib"
    #"overlays"
    #"pkgs"
    "rustPlatform"
    "rustShell"
    #"speculos"
    "stack-sizes"
    "util-stack-sizes"
    "stack-sizes-nix"
    "stockThumbTarget"
    "thunkSource"
    "usbtool"
    "utils"
    "utils-nix"
  ];
in {
  inherit x86_64-linux x86_64-darwin;
}
  # Hack until CI will traverse contents
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--" + n)) x86_64-linux
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--nanos--" + n)) x86_64-linux.perDevice.nanos
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--nanox--" + n)) x86_64-linux.perDevice.nanox
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--nanosplus--" + n)) x86_64-linux.perDevice.nanosplus
  // lib.mapAttrs' (n: lib.nameValuePair ("macos--" + n)) x86_64-darwin
