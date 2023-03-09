let
  pkgsSrc = import ./dep/nixpkgs/thunk.nix;
  lib = import (pkgsSrc + "/lib");

  ci = lib.genAttrs [ "nixpkgs" "mozilla" ] (a: {
    inherit a;
  } // lib.genAttrs [ "x86_64-linux" "x86_64-darwin" ] (system: import ./. rec {
    inherit pkgsSrc;
    localSystem = { inherit system; };
    backend = a;
  }));
in ci // {
  recurseForDerivations = true;
} // lib.genAttrs
  [ "nixpkgs" "mozilla" ]
  (a: {
    recurseForDerivations = true;
  }
  # Hack until CI will traverse contents
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--" + n)) (ci."${a}".x86_64-linux)
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--nanos--" + n)) (ci."${a}".x86_64-linux.perDevice.nanos)
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--nanox--" + n)) (ci."${a}".x86_64-linux.perDevice.nanox)
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--nanosplus--" + n)) (ci."${a}".x86_64-linux.perDevice.nanosplus)
  // lib.mapAttrs' (n: lib.nameValuePair ("macos--" + n)) (ci."${a}".x86_64-darwin)
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--nanos--" + n)) (ci."${a}".x86_64-linux.perDevice.nanos)
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--nanox--" + n)) (ci."${a}".x86_64-linux.perDevice.nanox)
  // lib.mapAttrs' (n: lib.nameValuePair ("linux--nanosplus--" + n)) (ci."${a}".x86_64-linux.perDevice.nanosplus))
