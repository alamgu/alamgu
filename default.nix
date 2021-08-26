{ pkgsFunc ? import ./dep/nixpkgs
}:

rec {
  overlays = [
    (import "${thunkSource ./dep/nixpkgs-mozilla}/rust-overlay.nix")
    (self: super: {
      rust_1_53 = pkgs.callPackage ./1_53.nix {
          nixpkgs_src = self.path;
          inherit (pkgs.darwin.apple_sdk.frameworks) CoreFoundation Security;
          llvm_12 = pkgs.llvmPackages_12.libllvm;
      };
      rustPackages_1_53 = self.rust_1_53.packages.stable;
      cargo_1_53 = self.rustPackages_1_53.cargo;
      clippy_1_53 = self.rustPackages_1_53.clippy;
      rustc_1_53 = self.rustPackages_1_53.rustc;
      rustPlatform_1_53 = self.rustPackages_1_53.rustPlatform;
    })
    (self: super: {
      lldClangStdenv = self.clangStdenv.override (old: {
        cc = old.cc.override (old: {
          # Default version of 11 segfaulted
          inherit (ledgerPkgs.buildPackages.llvmPackages_12) bintools;
        });
      });
    })
  ];

  pkgs = pkgsFunc {
    config = {};
    inherit overlays;
  };

  inherit (pkgs) lib;

  ledgerPkgs = pkgsFunc {
    crossSystem = {
      isStatic = true;
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
    inherit overlays;
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

  speculos = pkgs.callPackage ./dep/speculos { inherit pkgsFunc pkgs; };

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

  rustShell = buildRustPackageClang {
    stdenv = ledgerPkgs.lldClangStdenv;
    name = "rust-app";
    src = null;
    preHook = gccLibsPreHook;
    # We just want dev shell
    unpackPhase = ''
      echo got in shell > $out
      exit 0;
    '';
    cargoVendorDir = "pretend-exists";
    depsBuildBuild = [ ledgerPkgs.buildPackages.stdenv.cc ];
    inherit (ledgerPkgs.rustPlatform_1_53) rustLibSrc;
    nativeBuildInputs = [
      # emu
      speculos.speculos ledgerPkgs.buildPackages.gdb

      # loading on real hardware
      cargo-ledger ledgerctl

      # just plain useful for rust dev
      cargo-watch
    ];
    # buildInputs = [ binaryRustPackages.rust-std ];
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
    isLedger = pkgs.stdenv.hostPlatform.parsed.kernel.name == "none";
    platform = if isLedger then ledgerRustPlatform else rustPlatform;
  in pkgs.buildRustCrate.override rec {
    stdenv = if isLedger then pkgs.lldClangStdenv else pkgs.stdenv;
    inherit (platform.rust) rustc cargo;
  };

  binaryRustPackages = pkgs.rustChannelOf {
    channel = "1.53.0";
    sha256 = "1p4vxwv28v7qmrblnvp6qv8dgcrj8ka5c7dw2g2cr3vis7xhflaa";
  };

  binaryRustC = binaryRustPackages.rust.override {
    targets = [
      "thumbv6m-none-eabi"
    ];
  };

  rustcBuilt = ledgerPkgs.buildPackages.rustc_1_53.overrideAttrs (attrs: {
    configureFlags = (builtins.tail attrs.configureFlags) ++ [
      "--release-channel=nightly"
      "--disable-docs"
      "--disable-compiler-docs"
    ];
  });

  rustcSrc = pkgs.runCommand "rustc-source" {} ''
    install -d $out/lib/rustlib/src/rust
    tar -C $out/lib/rustlib/src/rust -xvf ${rustcBuilt.src} --strip-components=1
  '';

  llvmPass = pkgs.stdenv.mkDerivation {
    name = "LedgerROPI";
    src = ./llvm-pass;
    buildInputs = [
      pkgs.llvmPackages_12.libllvm
      pkgs.cmake
    ];
  };

  rustc = pkgs.runCommand "rustc-ledger" {} ''
    install -d $out/
    ${pkgs.xorg.lndir}/bin/lndir -silent ${rustcBuilt} $out
    ${pkgs.xorg.lndir}/bin/lndir -silent ${rustcSrc} $out
    rm $out/bin/rustc
    ${pkgs.patchelf}/bin/patchelf --add-needed ${llvmPass}/lib/libLedgerROPI.so ${rustcBuilt}/bin/rustc --output $out/bin/rustc
  '';

  rustPlatform = pkgs.makeRustPlatform {
    inherit (binaryRustPackages) cargo rustcSrc;
    inherit rustc;
  };

  ledgerRustPlatform = ledgerPkgs.makeRustPlatform {
    inherit (binaryRustPackages) cargo rustcSrc;
    inherit rustc;
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

  utils = import ./Cargo.nix { inherit pkgs; };

  cargo-ledger = utils.workspaceMembers.cargo-ledger.build;

  cargo-watch = utils.workspaceMembers.cargo-watch.build;
}
