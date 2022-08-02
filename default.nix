{ localSystem ? { system = builtins.currentSystem; }
, pkgsSrc ? import ./dep/nixpkgs/thunk.nix
, pkgsFunc ? import pkgsSrc
}:

rec {
  overlays = [
    (self: super: {
      rustPackages_1_61 = self.rust_1_61.packages.stable;
      cargo_1_61 = self.rustPackages_1_61.cargo;
      clippy_1_61 = self.rustPackages_1_61.clippy;
      rustc_1_61 = self.rustPackages_1_61.rustc;
      rustPlatform_1_61 = self.rustPackages_1_61.rustPlatform;
    })
    (self: super: {
      rustcBuilt = self.rustc_1_61.overrideAttrs (attrs: {
        configureFlags = (builtins.tail attrs.configureFlags) ++ [
          "--release-channel=nightly"
          "--disable-docs"
          "--disable-compiler-docs"
        ];
      });

      rustcSrc = self.runCommand "rustc-source" {} ''
        install -d $out/lib/rustlib/src/rust
        tar -C $out/lib/rustlib/src/rust -xvf ${self.rustcBuilt.src} --strip-components=1
      '';

      # TODO upstream this stuff back to nixpkgs after bumping to latest
      # stable.
      stdlibSrc = self.callPackage ./stdlib/src.nix {
        rustPlatform = self.rustPlatform_1_61;
        originalCargoToml = null;
      };

      ropiAllLlvmPass = self.stdenv.mkDerivation {
        name = "LedgerROPI";
        src = ./llvm-pass;
        nativeBuildInputs = [
          self.buildPackages.cmake
        ];
        buildInputs = [
          self.llvmPackages_14.libllvm
        ];
      };

      rustcRopi = self.runCommand "rustc-ledger" {} ''
        install -d $out/
        ${self.buildPackages.xorg.lndir}/bin/lndir -silent ${self.rustcBuilt} $out
        ${self.buildPackages.xorg.lndir}/bin/lndir -silent ${self.rustcSrc} $out
        rm $out/bin/rustc
        ${self.buildPackages.patchelf}/bin/patchelf --add-needed ${self.ropiAllLlvmPass}/lib/libLedgerROPI.so ${self.rustcBuilt}/bin/rustc --output $out/bin/rustc
      '';
    })
    (self: super: {
      lldClangStdenv = self.llvmPackages_14.stdenv.override (old: {
        cc = old.cc.override (old: {
          # This is needed to get armv6m-unknown-none-eabi-clang to do linking
          # using armv6m-unknown-none-eabi-ld
          inherit (ledgerPkgs.buildPackages.llvmPackages_14) bintools;
        });
      });
    })
    (self: super: {
      protobuf = self.callPackage (pkgsSrc + "/pkgs/development/libraries/protobuf/generic-v3.nix") {
        version = "3.20.1";
        sha256 = "sha256-pAMacD0UQetqysZHszu5slPqp0iREtDmHFv1cgcUBJA=";
      };
    })
  ];

  pkgs = pkgsFunc {
    config = {};
    inherit localSystem overlays;
  };

  inherit (pkgs) lib;

  # Have rustc spit out unstable target config json so we can do a minimum of
  # hard-coding.
  stockThumbTarget = pkgs.runCommand "stock-target.json" {
    nativeBuildInputs = [ pkgs.buildPackages.rustcBuilt ];
  } ''
    rustc -Z unstable-options --print target-spec-json --target thumbv6m-none-eabi > $out
  '';

  ledgerPkgs = pkgsFunc {
    config.allowUnsupportedSystem = true;
    crossSystem = {
      isStatic = true;
      config = "armv6m-unknown-none-eabi";
      gcc = {
        arch = "armv6s-m";
      };
      rustc = {
        config = "thumbv6m-none-eabi";
        platform = builtins.fromJSON (builtins.readFile stockThumbTarget) // {
          # Shoudn't be needed, but what rustc prints out by default is
          # evidently wrong!
          atomic-cas = true;
          os = "nanos";
        };
      };
    };
    inherit localSystem overlays;
    crossOverlays = [
      (self: super: {
        newlibCross = super.newlibCross.override {
          nanoizeNewlib = true;
        };
      })
    ];
  };

  # TODO: Replace this with `thunkSource` from nix-thunk for added safety
  # checking once CI stuff is separated.
  thunkSource = p:
    if builtins.pathExists (p + /thunk.nix)
      then (import (p + /thunk.nix))
    else p;

  usbtool = import ./usbtool.nix { };

  gitignoreNix = import (thunkSource ./dep/gitignore.nix) { inherit lib; };

  inherit (gitignoreNix) gitignoreSource;

  speculos = pkgs.callPackage ./dep/speculos {
    inherit pkgsFunc pkgs localSystem;
  };

  crate2nix = import ./dep/crate2nix { inherit pkgs; };

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
    inherit (ledgerPkgs.rustPlatform_1_61) rustLibSrc;
    nativeBuildInputs = [
      # emu
      speculos.speculos ledgerPkgs.buildPackages.gdb

      # loading on real hardware
      cargo-ledger ledgerctl

      # just plain useful for rust dev
      stack-sizes
      cargo-watch

      # Testing stuff against nodejs modules
      pkgs.nodejs_latest
    ];
    # buildInputs = [ stableRustPackages.rust-std ];
    verifyCargoDeps = true;
    target = "thumbv6m-none-eabi";

    # Cargo hash must be updated when Cargo.lock file changes.
    cargoSha256 = "1kdg77ijbq0y1cwrivsrnb9mm4y5vlj7hxn39fq1dqlrppr6fdrr";

    # It is more reliable to trick a stable rustc into doing unstable features
    # than use an unstable nightly rustc. Just because we want unstable
    # langauge features doesn't mean we want a less tested implementation!
    RUSTC_BOOTSTRAP = 1;

    meta = {
      platforms = lib.platforms.all;
    };
  };

  # Use right Rust; use Clang.
  buildRustCrateForPkgsLedger = pkgs: let
    isLedger = (pkgs.stdenv.hostPlatform.rustc.platform.os or "") == "nanos";
    platform = if isLedger then ledgerRustPlatform else rustPlatform;
  in pkgs.buildRustCrate.override rec {
    stdenv = if isLedger then pkgs.lldClangStdenv else pkgs.stdenv;
    inherit (platform.rust) rustc cargo;
  };

  stableRustPackages = pkgs.rust_1_61.packages.stable;

  rustPlatform = pkgs.makeRustPlatform {
    inherit (stableRustPackages) cargo rustcSrc;
    rustc = pkgs.buildPackages.rustcRopi;
  };

  ledgerRustPlatform = ledgerPkgs.makeRustPlatform {
    inherit (stableRustPackages) cargo;
    rustcSrc = ledgerPkgs.buildPackages.rustcBuilt.src;
    rustc = ledgerPkgs.buildPackages.rustcRopi;
  };

  ledgerctl = with pkgs.python3Packages; buildPythonPackage {
    pname = "ledgerctl";
    version = "master";
    src = thunkSource ./dep/ledgerctl;
    propagatedBuildInputs = [
      click
      construct
      cryptography
      ecdsa
      hidapi
      intelhex
      pillow
      protobuf
      requests
      tabulate
    ];
  };

  buildRustCrateForPkgsWrapper = pkgs: fun: let
    isLedger = (pkgs.stdenv.hostPlatform.rustc.platform.os or "") == "nanos";
  in args: fun (args // lib.optionalAttrs isLedger {
      RUSTC_BOOTSTRAP = true;
      extraRustcOpts = [
        "-C" "relocation-model=ropi"
        "-C" "passes=ledger-ropi"
        "-C" "opt-level=3"
        "-C" "codegen-units=1"
        "-C" "embed-bitcode"
        "-C" "lto"
        "-Z" "emit-stack-sizes"
        "--emit=link,dep-info,obj"
      ] ++ args.extraRustcOpts or [];
      # separateDebugInfo = true;
      dontStrip = isLedger;
    });

  generic-cli = (import ./node/cli {
    inherit pkgs;
  }).package;

  ledgerStdlib = import ./stdlib/Cargo.nix {
    pkgs = ledgerPkgs;
    buildRustCrateForPkgs = pkgs: buildRustCrateForPkgsWrapper
      pkgs
      ((buildRustCrateForPkgsLedger pkgs).override {
        defaultCrateOverrides = pkgs.defaultCrateOverrides // {
          core = attrs: {
            src = ledgerPkgs.rustPlatform_1_61.rustLibSrc + "/core";
            postUnpack = ''
              cp -r ${ledgerPkgs.rustPlatform_1_61.rustLibSrc}/stdarch $sourceRoot/..
            '';
          };
          alloc = attrs: { src = ledgerPkgs.rustPlatform_1_61.rustLibSrc + "/alloc"; };
          rustc-std-workspace-core = attrs: { src = ledgerPkgs.rustPlatform_1_61.rustLibSrc + "/rustc-std-workspace-core"; };
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

  utils = import ./utils/Cargo.nix { inherit pkgs; };

  cargo-ledger = utils.workspaceMembers.cargo-ledger.build;

  cargo-watch = utils.workspaceMembers.cargo-watch.build;

  stack-sizes = utils.workspaceMembers.stack-sizes.build;
}
