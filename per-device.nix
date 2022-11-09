{ lib ? pkgs.lib

, pkgs
, ledgerPkgs

, rustPlatform
, crate2nix-tools

, cargo-ledger
, cargo-watch
, ledgerctl
, speculos
, stack-sizes
}:

rec {

  inherit ledgerPkgs;

  buildRustPackageClang = ledgerRustPlatform.buildRustPackage.override {
    stdenv = ledgerPkgs.lldClangStdenv;
  };

  # TODO once we break up GCC to separate compiler vs runtime like we do with
  # Clang, we shouldn't need these hacks to get make the gcc runtime available.
  gccLibsPreHook = ''
    export NIX_LDFLAGS
    NIX_LDFLAGS+=' -L${ledgerPkgs.stdenv.cc.cc}/lib/gcc/${ledgerPkgs.stdenv.hostPlatform.config}/${ledgerPkgs.stdenv.cc.cc.version}'
  '';

  # Our tools are named differently than the Cargo defaults.
  cargoLedgerPreHook = ''
    export CARGO_TARGET_THUMBV6M_NONE_EABI_OBJCOPY=$OBJCOPY
    export CARGO_TARGET_THUMBV6M_NONE_EABI_SIZE=$SIZE
    export RUSTFLAGS='-Z llvm_plugins=${pkgs.ropiAllLlvmPass}/lib/libLedgerROPI.so'
  '';

  rustShell = buildRustPackageClang {
    stdenv = ledgerPkgs.lldClangStdenv;
    name = "rustShell";
    src = null;
    # We are just (ab)using buildRustPackage for a shell. When we actually build
    __internal_dontAddSysroot = true;
    preHook = gccLibsPreHook;
    shellHook = cargoLedgerPreHook;
    # We just want dev shell
    unpackPhase = ''
      echo got in shell > $out
      exit 0;
    '';
    cargoVendorDir = "pretend-exists";
    depsBuildBuild = [ ledgerPkgs.buildPackages.stdenv.cc ];
    inherit (ledgerPkgs.alamguRustPackages.rustPlatform) rustLibSrc;
    nativeBuildInputs = [
      # emu
      speculos.speculos ledgerPkgs.buildPackages.gdb

      # loading on real hardware
      cargo-ledger
      ledgerctl

      # just plain useful for rust dev
      stack-sizes
      cargo-watch

      # Testing stuff against nodejs modules
      pkgs.nodejs_latest
    ];
    verifyCargoDeps = true;
    target = "thumbv6m-none-eabi";

    # Cargo hash must be updated when Cargo.lock file changes.
    cargoSha261 = "1kdg77ijbq0y1cwrivsrnb9mm4y5vlj7hxn39fq1dqlrppr6fdrr";

    # It is more reliable to trick a stable rustc into doing unstable features
    # than use an unstable nightly rustc. Just because we want unstable
    # langauge features doesn't mean we want a less tested implementation!
    RUSTC_BOOTSTRAP = true;

    meta = {
      platforms = lib.platforms.all;
    };
  };

  # Use right Rust; use Clang.
  buildRustCrateForPkgsLedger = pkgs: let
    isLedger = lib.elem "bolos" (pkgs.stdenv.hostPlatform.rustc.platform.target-family or []) ;
    platform = if isLedger then ledgerRustPlatform else rustPlatform;
  in pkgs.buildRustCrate.override rec {
    stdenv = if isLedger then pkgs.lldClangStdenv else pkgs.stdenv;
    inherit (platform.rust) rustc cargo;
  };

  ledgerRustPlatform = ledgerPkgs.makeRustPlatform {
    inherit (pkgs.alamguRustPackages) cargo;
    rustcSrc = ledgerPkgs.buildPackages.alamguRustPackages.rustc.src;
    # Go back one stage too far back (`buildPackages.buildPackages` not
    # `buildPackages`) so we just use native compiler. Since we are building
    # stdlib from scratch we don't need a "cross compiler" --- rustc itself is
    # actually always multi-target.
    rustc = ledgerPkgs.buildPackages.buildPackages.alamguRustPackages.rustc;
  };

  buildRustCrateForPkgsWrapper = pkgs: fun: let
    isLedger = lib.elem "bolos" (pkgs.stdenv.hostPlatform.rustc.platform.target-family or []) ;
  in args: fun (args // lib.optionalAttrs isLedger {
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
      dontStrip = isLedger;
    });

  ledgerStdlib-nix = (crate2nix-tools.generatedCargoNix {
    name = "stdlib";
    src = ledgerPkgs.stdlibSrc;
  }).overrideAttrs (old: {
    buildPhase = old.buildPhase + ''
      sed -E -i $out/crate/Cargo-generated.nix -e \
        's_(/?\.\./?)*(${builtins.storeDir})_\2_'
    '';
  });

  ledgerStdlib = ledgerPkgs.callPackage ledgerStdlib-nix {
    # Hack to avoid a `.override` that doesn't work.
    defaultCrateOverrides = ledgerPkgs.defaultCrateOverrides;
    pkgs = ledgerPkgs;
    buildRustCrateForPkgs = pkgs: buildRustCrateForPkgsWrapper
      pkgs
      ((buildRustCrateForPkgsLedger pkgs).override {
        defaultCrateOverrides = pkgs.defaultCrateOverrides // {
          core = attrs: {
            src = ledgerPkgs.alamguRustPackages.rustPlatform.rustLibSrc + "/core";
            postUnpack = ''
              cp -r ${ledgerPkgs.alamguRustPackages.rustPlatform.rustLibSrc}/stdarch $sourceRoot/..
              cp -r ${ledgerPkgs.alamguRustPackages.rustPlatform.rustLibSrc}/portable-simd $sourceRoot/..
            '';
          };
          alloc = attrs: { src = ledgerPkgs.alamguRustPackages.rustPlatform.rustLibSrc + "/alloc"; };
          rustc-std-workspace-core = attrs: { src = ledgerPkgs.alamguRustPackages.rustPlatform.rustLibSrc + "/rustc-std-workspace-core"; };
        };
      });
  };

  ledgerCompilerBuiltins = lib.findFirst
    (p: lib.hasPrefix "rust_compiler_builtins" p.name)
    (builtins.throw "no compiler_builtins!")
    ledgerStdlib.rootCrate.build.dependencies;

  ledgerCore = lib.findFirst
    (p: lib.hasPrefix "rust_core" p.name)
    (builtins.throw "no core!")
    ledgerStdlib.rootCrate.build.dependencies;

  ledgerStdlibCI = ledgerStdlib.rootCrate.build;
}
