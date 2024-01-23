{ pkgs, crate2nix-tools, thunkSource }:

rec {
  utils-srcs = pkgs.runCommand "utils-srcs" {} ''
    mkdir -p "$out"
    cd "$out"
    ln -s ${pkgs.runCommand "crate2nix-sources" {} ''
      mkdir -p "$out"
      cd "$out"
      ln -s "${thunkSource ./dep/cargo-watch}" cargo-watch
      ln -s "${thunkSource ./dep/ledger-device-rust-sdk}/cargo-ledger" cargo-ledger
    ''} crate2nix-sources
    cat <<EOF >"crate2nix.json"
      {
        "sources": {
          "cargo-watch": {
            "type": "LocalDirectory",
            "path": "${thunkSource ./dep/cargo-watch}"
          },
          "cargo-ledger": {
            "type": "LocalDirectory",
            "path": "${thunkSource ./dep/ledger-device-rust-sdk}/cargo-ledger"
          }
        }
      }
    EOF
  '';
  utils-nix = crate2nix-tools.generatedCargoNix {
    name = "utils";
    src = utils-srcs;
  };

  utils = pkgs.callPackage utils-nix {
    inherit pkgs;
    defaultCrateOverrides = pkgs.defaultCrateOverrides // {
      cargo-watch = attrs: {
        buildInputs = (attrs.buildInputs or []) ++
        pkgs.lib.optionals (pkgs.stdenv.isDarwin) [
          pkgs.darwin.apple_sdk.frameworks.CoreServices
        ];
      };
    };
  };

  # stack-sizes is separate from cargo-ledger as crate2nix output fails to build
  # the serde
  stack-sizes-nix = crate2nix-tools.generatedCargoNix {
    name = "stack-sizes-nix";
    src = pkgs.runCommand "stack-sizes-src" {} ''
      mkdir -p "$out"
      cd "$out"
      ln -s ${pkgs.runCommand "crate2nix-sources" {} ''
        mkdir -p "$out"
        cd "$out"
        ln -s "${thunkSource ./dep/stack-sizes}" stack-sizes
      ''} crate2nix-sources
      cat <<EOF >"crate2nix.json"
        {
          "sources": {
            "stack-sizes": {
              "type": "LocalDirectory",
              "path": "${thunkSource ./dep/stack-sizes}"
            }
          }
        }
      EOF
    '';
  };

  util-stack-sizes = pkgs.callPackage stack-sizes-nix {
    inherit pkgs;
    defaultCrateOverrides = pkgs.defaultCrateOverrides // {
      llvm-sys = attrs: {
        LLVM_SYS_120_FFI_WORKAROUND=1;
        LLVM_SYS_130_FFI_WORKAROUND=1;
        LLVM_SYS_140_FFI_WORKAROUND=1;
        LLVM_SYS_150_FFI_WORKAROUND=1;
        buildInputs = (attrs.buildInputs or [ ]) ++ [pkgs.llvmPackages_15.libllvm pkgs.zlib pkgs.ncurses pkgs.xml2 pkgs.libffi];
      };
      stack-sizes = attrs: {
        # For #![feature(exit_status_error)]
        RUSTC_BOOTSTRAP = true;
        buildInputs = (attrs.buildInputs or []) ++ [pkgs.llvmPackages_15.libllvm pkgs.zlib pkgs.ncurses pkgs.libxml2 pkgs.libffi];
      };
    };
  };
}
