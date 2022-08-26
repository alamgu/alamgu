{ pkgs, crate2nix-tools }:

rec {
  utils-srcs = pkgs.runCommand "utils-srcs" {} ''
    mkdir -p "$out"
    cd "$out"
    ln -s ${pkgs.runCommand "crate2nix-sources" {} ''
      mkdir -p "$out"
      cd "$out"
      ln -s "${import ./dep/cargo-watch/thunk.nix}" cargo-watch
      ln -s "${import ./dep/cargo-ledger/thunk.nix}" cargo-ledger
      ln -s "${import ./dep/stack-sizes/thunk.nix}" stack-sizes
    ''} crate2nix-sources
    cat <<EOF >"crate2nix.json"
      {
        "sources": {
          "cargo-watch": {
            "type": "LocalDirectory",
            "path": "${import ./dep/cargo-watch/thunk.nix}"
          },
          "cargo-ledger": {
            "type": "LocalDirectory",
            "path": "${import ./dep/cargo-ledger/thunk.nix}"
          },
          "stack-sizes": {
            "type": "LocalDirectory",
            "path": "${import ./dep/stack-sizes/thunk.nix}"
          }
        }
      }
    EOF
  '';
  utils-nix = crate2nix-tools.generatedCargoNix {
    name = "utils";
    src = utils-srcs;
  };

  utils = pkgs.callPackage utils-nix {};
}
