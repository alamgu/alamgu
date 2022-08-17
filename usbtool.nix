{ pkgs ? import ./dep/nixpkgs {}, thunkSource }:

pkgs.stdenv.mkDerivation {
  name = "usbtool";
  src = thunkSource ./dep/v-usb;
  preBuild = ''
    cd examples/usbtool
    ./make-files.sh
  '';
  makeFlags = [ "CC=${pkgs.stdenv.cc.targetPrefix}cc" ];
  nativeBuildInputs = with pkgs.buildPackages; [ pkg-config ];
  buildInputs = with pkgs; [ libusb1 ];
  installPhase = ''
    install -D usbtool $out/bin/usbtool
    install -D Readme.txt $out/share/doc/usbtool/Readme.txt
  '';
}
