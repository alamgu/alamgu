{ pkgsFunc ? import ./dep/nixpkgs
}:

rec {
  pkgs = pkgsFunc {
    config = {};
    overlays = [
    ];
  };

  speculos = pkgs.callPackage ./dep/speculos { };
}
