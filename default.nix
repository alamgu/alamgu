{ localSystem ? { system = builtins.currentSystem; }
, pkgsSrc ? import ./dep/nixpkgs/thunk.nix
, pkgsFunc ? import pkgsSrc
}:

rec {
  overlays = [
    (self: super: {
      # Alias so we use the same version everywhere
      alamguRustPackages = self.rustPackages_1_61;

      rustcBuilt = self.alamguRustPackages.rustc.overrideAttrs (attrs: {
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
        inherit (self.alamguRustPackages) rustPlatform;
        originalCargoToml = null;
      };

      ropiAllLlvmPass = self.stdenv.mkDerivation {
        name = "LedgerROPI";
        src = thunkSource ./dep/llvm-ledger-ropi;
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
        ln -s ${self.rustcBuilt.llvmPackages.lld}/bin/lld $out/bin/rust-lld
        ${self.buildPackages.patchelf}/bin/patchelf --add-needed ${self.ropiAllLlvmPass}/lib/libLedgerROPI.so ${self.rustcBuilt}/bin/rustc --output $out/bin/rustc
      '';
    })
    (self: super: {
      lldClangStdenv = self.llvmPackages_14.stdenv.override (old: {
        cc = old.cc.override (old: {
          # This is needed to get armv6m-unknown-none-eabi-clang to do linking
          # using armv6m-unknown-none-eabi-l
          inherit (self.buildPackages.llvmPackages_14) bintools;
        });
      });
    })
  ];

  pkgs = pkgsFunc {
    config = {};
    inherit localSystem overlays;
  };

  inherit (pkgs) lib;

  # Have rustc spit out unstable target config json so we can do a minimum of
  # hard-coding.
  stockThumbTargets = lib.genAttrs
    [ "thumbv6m-none-eabi" "thumbv8m.main-none-eabi" ]
    (target-name:
      pkgs.runCommand "stock-target.json" {
        nativeBuildInputs = [ pkgs.buildPackages.rustcRopi ];
      } ''
        rustc -Z unstable-options --print target-spec-json --target ${target-name} > $out
      '');

  perDevice = let
    f = crossSystem: import ./per-device.nix {
      inherit
        pkgs
        rustPlatform
        cargo-ledger
        cargo-watch
        ledgerctl
        speculos
        stack-sizes
        ;
      ledgerPkgs = pkgsFunc {
        config.allowUnsupportedSystem = true;
        inherit crossSystem;
        inherit localSystem overlays;
      };
    };
  in {
    nanos = f {
      isStatic = true;
      config = "armv6m-unknown-none-eabi";
      libc = "newlib-nano";
      gcc = {
        arch = "armv6s-m";
      };
      rustc = rec {
        config = "thumbv6m-none-eabi";
        platform = builtins.fromJSON (builtins.readFile stockThumbTargets.${config}) // {
          is-builtin = false;

          atomic-cas = false;
          os = "nanos";
          target-family = [ "bolos" ];

          relocation-model = "ropi";
        };
      };
    };
    nanox = f {
      isStatic = true;
      config = "armv6m-unknown-none-eabi";
      libc = "newlib-nano";
      gcc = {
        arch = "armv6s-m";
      };
      rustc = rec {
        config = "thumbv6m-none-eabi";
        platform = builtins.removeAttrs (builtins.fromJSON (builtins.readFile stockThumbTargets.${config})) ["features"] // {
          is-builtin = false;

          atomic-cas = false;
          os = "nanox";
          target-family = [ "bolos" ];

          relocation-model = "ropi-rwpi";
        };
      };
    };
    nanosplus = f {
      isStatic = true;
      config = "armv8m-unknown-none-eabi";
      libc = "newlib-nano";
      gcc = {
        arch = "armv8-m.main";
      };
      rustc = rec {
        config = "thumbv8m.main-none-eabi";
        platform = builtins.fromJSON (builtins.readFile stockThumbTargets.${config}) // {
          is-builtin = false;

          max-atomic-width = 32;
          os = "nanosplus";
          target-family = [ "bolos" ];

          relocation-model = "ropi-rwpi";
        };
      };
    };
  };

  # TODO: Replace this with `thunkSource` from nix-thunk for added safety
  # checking once CI stuff is separated.
  thunkSource = p:
    if builtins.pathExists (p + /thunk.nix)
      then (import (p + /thunk.nix))
    else p;

  usbtool = import ./usbtool.nix { inherit pkgs thunkSource; };

  gitignoreNix = import (thunkSource ./dep/gitignore.nix) { inherit lib; };

  inherit (gitignoreNix) gitignoreSource;

  speculos = pkgs.callPackage ./dep/speculos {
    inherit pkgsFunc pkgs localSystem;
  };

  crate2nix = import ./dep/crate2nix { inherit pkgs; };

  crate2nix-tools = import (import ./dep/crate2nix/thunk.nix + "/tools.nix") {
    inherit pkgs;
  };

  rustPlatform = pkgs.makeRustPlatform {
    inherit (pkgs.alamguRustPackages) cargo;
    # Go back one stage too far back (`buildPackages.buildPackages` not
    # `buildPackages`) so we just use native compiler. Since we are building
    # stdlib from scratch we don't need a "cross compiler" --- rustc itself is
    # actually always multi-target.
    rustc = pkgs.buildPackages.buildPackages.rustcRopi;
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

  generic-cli = (import ./node/cli {
    inherit pkgs;
  }).package;

  inherit (import ./utils.nix { inherit pkgs crate2nix-tools; })
    utils-srcs utils-nix utils;

  cargo-ledger = utils.workspaceMembers.cargo-ledger.build;

  cargo-watch = utils.workspaceMembers.cargo-watch.build;

  stack-sizes = utils.workspaceMembers.stack-sizes.build;

  # COMPAT
  stockThumbTarget = stockThumbTargets.thumbv6m-none-eabi;
  inherit (perDevice.nanos)
    buildRustCrateForPkgsLedger
    buildRustCrateForPkgsWrapper
    buildRustPackageClang
    cargoLedgerPreHook
    gccLibsPreHook
    ledgerCompilerBuiltins
    ledgerCore
    ledgerPkgs
    ledgerRustPlatform
    ledgerStdlib
    ledgerStdlibCI
    rustShell
    ;
}
