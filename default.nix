{ localSystem ? { system = builtins.currentSystem; }
, pkgsSrc ? import ./dep/nixpkgs/thunk.nix
, pkgsFunc ? import pkgsSrc
, backend ? "nixpkgs"
}:

rec {
  backendOverlays = {
    mozilla = [
      (import "${thunkSource ./dep/nixpkgs-mozilla}/rust-overlay.nix")
      (self: super: {
        alamguRustPackages = let
          pre = self.rustChannelOf {
            channel = "1.75.0";
          };
        in pre // rec {
          backend = "mozilla";
          clippy = pre.rust.override {
            extensions = [ "clippy-preview" ];
          };
          rustfmt = pre.rust.override {
            extensions = [ "rustfmt-preview" ];
          };
          rustc = pre.rust.override {
            extensions = [ "rust-std" ];
          };
          rustPlatform = pkgs.makeRustPlatform {
            inherit (pre) cargo;
            inherit rustc;
          } // {
            # src = pre.rust-src;
            # Hack around bad use of fetchurl
            # Get rid of symlinks
            rustLibSrc = let
              inherit (self.buildPackages.alamguRustPackages.rust-src) paths;
            in assert builtins.length paths == 1;
              "${builtins.head paths}/lib/rustlib/src/rust/library";
          };
        };
      })
    ];
    nixpkgs = [
      (self: super: rec {
        alamguRustPackages = self.rustPackages_1_75 // {
          backend = "nixpkgs";
          rust-src = self.runCommand "rustc-source" {} ''
            install -d $out
            tar -C $out -xvf ${self.rustPackages_1_75.rustc.src} --strip-components=1
          '';
        };
      })
    ];
  };

  inherit backend;
  overlays = backendOverlays."${backend}" ++ [
    (self: super: rec {
      # TODO upstream this stuff back to nixpkgs after bumping to latest
      # stable.
      stdlibSrc = self.callPackage ./stdlib/src.nix {
        inherit (self.alamguRustPackages) rustPlatform;
        originalCargoToml = null;
      };

      # Deprecated
      rustcRopi = self.alamguRustPackages.rustc;
      rustcBuilt = self.alamguRustPackages.rustc;
    })
    (self: super: {
      lldClangStdenv = self.llvmPackages_17.stdenv.override (old: {
        cc = old.cc.override (old: {
          # This is needed to get armv6m-unknown-none-eabi-clang to do linking
          # using armv6m-unknown-none-eabi-l
          inherit (self.buildPackages.llvmPackages_17) bintools;
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
        nativeBuildInputs = [ pkgs.buildPackages.alamguRustPackages.rustc ];
        RUSTC_BOOTSTRAP = true;
      } ''
        rustc -Z unstable-options --print target-spec-json --target ${target-name} > $out
      '');

  perDevice = let
    f = crossSystem: import ./per-device.nix {
      inherit
        pkgs
        rustPlatform
        crate2nix-tools
        alamguLib
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
          features = "+atomics-32"; # For newer rustc
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
    speculosPkgs = pkgsFunc {
      inherit localSystem;
      crossSystem = {
        #isStatic = true;
        config = "armv6l-unknown-linux-gnueabihf";
      };
      config = {
        permittedInsecurePackages = [
          # Required for speculos, till https://github.com/LedgerHQ/speculos/issues/447 is fixed upstream
          "openssl-1.1.1w"
        ];
      };
    };
  };

  crate2nix = import ./dep/crate2nix { inherit pkgs; };

  crate2nix-tools = import (import ./dep/crate2nix/thunk.nix + "/tools.nix") {
    inherit pkgs;
  };

  inherit (pkgs.alamguRustPackages) rustPlatform;

  alamguLib = import ./lib { inherit lib; };

  ledgerctl = pkgs.python3Packages.buildPythonPackage {
    pname = "ledgerctl";
    version = "0.1.4";
    src = thunkSource ./dep/ledgerctl;
    format = "pyproject";
    nativeBuildInputs = with pkgs.buildPackages.python3Packages; [
      flit-core
      setuptools
      setuptools-scm
    ];
    propagatedBuildInputs = with pkgs.python3Packages; [
      click
      construct
      cryptography
      ecdsa
      hidapi
      intelhex
      pillow
      protobuf3
      requests
      tabulate
      toml
    ];
    env.SETUPTOOLS_SCM_PRETEND_VERSION = "0.1.4";
  };

  generic-cli = (import (thunkSource ./dep/alamgu-generic-cli) {
    inherit pkgs;
  }).package;

  inherit (import ./utils.nix { inherit pkgs crate2nix-tools thunkSource; })
    utils utils-nix
    util-stack-sizes stack-sizes-nix
    ;

  cargo-ledger = utils.workspaceMembers.cargo-ledger.build;

  cargo-watch = utils.workspaceMembers.cargo-watch.build;

  stack-sizes = util-stack-sizes.workspaceMembers.stack-sizes.build;

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
