{pkgs ? import <nixpkgs> {
    inherit system;
}, system ? builtins.currentSystem}:

let
  nodePackages = import ./composed.nix {
    inherit pkgs system;
  };
    postInstallFixup = ''
      # Fixup for checkouts from git.
        echo "POST INSTALL FIXUP RUNNING"
        for pkg in hw-app-obsidian-common
        do
        if [ -d node_modules/$pkg ]
        then pushd node_modules/$pkg; npm run prepare; popd;
        fi
        done
  '';
in
nodePackages // {
  shell = (nodePackages.shell.override (old: {
    buildInputs = old.buildInputs ++ [ pkgs.pkg-config pkgs.libusb ];
    preFixup = ''
      pushd $out/lib/
      ${postInstallFixup}
      popd
    '';
      })).overrideAttrs (attrs: {
          shellHook = attrs.shellHook + ''
          export TS_NODE_COMPILER_OPTIONS="{\"baseUrl\": \"$NODE_PATH\"}"
          '';
      });
  package = nodePackages.package.override (old: {
    buildInputs = old.buildInputs ++ [ pkgs.pkg-config pkgs.libusb ];
      preRebuild = ''
        ${pkgs.jq}/bin/jq ".baseUrl |= \"$NODE_PATH\"" < tsconfig.json > tsconfig_temp.json
        cat tsconfig_temp.json
        mv tsconfig_temp.json tsconfig.json
        ${postInstallFixup}
        npm run prepare
      '';
  });

  generateCmd = pkgs.writeShellScriptBin "run-node2nix" ''
    ${pkgs.nodePackages.node2nix}/bin/node2nix --supplement-input supplement.json --composition composed.nix
  '';
}
