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
        "-C" "opt-level=3"
        "-C" "codegen-units=1"
        "-C" "embed-bitcode"
        "-C" "lto"
        "-Z" "emit-stack-sizes"
        "--emit=link,dep-info,obj,llvm-bc,llvm-ir"
      ] ++ args.extraRustcOpts or [];
      # separateDebugInfo = true;
      dontStrip = isBolos;
    };
}
