let
  pkgsSrc = import ./dep/nixpkgs/thunk.nix;
  lib = import (pkgsSrc + "/lib");

  ci = lib.genAttrs [ "nixpkgs" "mozilla" ] (a: rec {
    inherit a;
    x86_64-linux = import ./. rec {
      inherit pkgsSrc;
      localSystem = { system = "x86_64-linux"; };
      backend = a;
    };
    x86_64-darwin = builtins.removeAttrs (import ./. rec {
      inherit pkgsSrc;
      localSystem = { system = "x86_64-darwin"; };
      backend = a;
    }) [
         "stableRustPackages"
         "buildRustCrateForPkgsLedger"
         "buildRustCrateForPkgsWrapper"
         "buildRustPackageClang"
         "cargo-ledger"
         "cargo-watch"
         #"cargoLedgerPreHook"
         #"crate2nix"
         #"gccLibsPreHook"
         "generic-cli"
         #"gitignoreNix"
         #"gitignoreSource"
         "ledgerCore"
         "ledgerCompilerBuiltins"
         #"ledgerPkgs"
         "ledgerRustPlatform"
         "ledgerStdlib"
         #"ledgerStdlib-nix"
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
         #"stack-sizes-nix"
         "stockThumbTarget"
         #"thunkSource"
         #"usbtool"
         "utils"
         #"utils-nix"
      ];
  });
in {
  #inherit x86_64-linux x86_64-darwin;
  inherit ci;
  recurseForDerivations = true;
} // lib.genAttrs [ "nixpkgs" "mozilla" ] (a: {
      recurseForDerivations = true;
    } //
    # Hack until CI will traverse contents
    lib.mapAttrs' (n: lib.nameValuePair ("linux--" + n)) (ci."${a}".x86_64-linux) //
    lib.mapAttrs' (n: lib.nameValuePair ("linux--nanos--" + n)) (ci."${a}".x86_64-linux.perDevice.nanos) //
    lib.mapAttrs' (n: lib.nameValuePair ("linux--nanox--" + n)) (ci."${a}".x86_64-linux.perDevice.nanox) //
    lib.mapAttrs' (n: lib.nameValuePair ("linux--nanosplus--" + n)) (ci."${a}".x86_64-linux.perDevice.nanosplus) //
    lib.mapAttrs' (n: lib.nameValuePair ("macos--" + n)) (ci."${a}".x86_64-darwin)
)
