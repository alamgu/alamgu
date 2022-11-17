{ lib }:

rec {
  platformIsBolos = platform:
    lib.elem "bolos" (platform.rustc.platform.target-family or []);

  combineWrappers = funs: pkgs: args:
    lib.foldr (f: a: f a) args (builtins.map (f: f pkgs) funs);

  extraArgsForAllCrates = pkgs: let
    isBolos = platformIsBolos pkgs.stdenv.hostPlatform;
  in args: args // lib.optionalAttrs isBolos {
      RUSTC_BOOTSTRAP = true;
      extraRustcOpts = [
        "-C" "passes=ledger-ropi"
        "-C" "opt-level=3"
        "-C" "codegen-units=1"
        "-C" "embed-bitcode"
        "-Z" "emit-stack-sizes"
        "-Z" "llvm_plugins=${pkgs.buildPackages.buildPackages.ropiAllLlvmPass}/lib/libLedgerROPI.so"
        "--emit=link,dep-info,obj"
      ] ++ args.extraRustcOpts or [];
      # separateDebugInfo = true;
      dontStrip = isBolos;
    };
}
