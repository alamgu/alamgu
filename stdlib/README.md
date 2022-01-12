# Updating the standard library

Unfortunately, the is quite manual at this time.

1. Edit `cargo.py`, changing the exact version pin of `compiler_builtins`,
   which is needed because Cargo would otherwise gladly pick the latest
   version, as the tight coupling with rustc is not recorded anywhere in its
   `Cargo.tom`

2. `./update-lockfile.sh` to update the `Cargo.lock`

3. `crate2nix generate "--nixpkgs-path=throw \"pass in nixpkgs\""` to
   regenerate `Cargo.nix`

3. `sed -E -i -f fix-nix-store-paths.sed Cargo.nix` to make store paths baked
   in the `Cargo.toml` properly absolute.
