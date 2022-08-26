# Updating the standard library

Most things are handled automatically, but the lockfile needs to be
regenerated manually.

1. Edit `cargo.py`, changing the exact version pin of `compiler_builtins`,
   which is needed because Cargo would otherwise gladly pick the latest
   version, as the tight coupling with rustc is not recorded anywhere in its
   `Cargo.tom`

2. `./update-lockfile.sh` to update the `Cargo.lock`
