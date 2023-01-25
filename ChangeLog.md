## 0.5

* Remove the LLVM plugin to insert PIC fix-ups.

  Instead, we have modified the SDK (pinned in downstream projects) to relocate address in memory on app start (as needed, the relocation is persistent).

* Re-enable LTO.

  It is needed for the stack check.

* Tidy up how `buildRustCrate` overriding works.

  There is a new `alamguLib` to assist with this.

* Bump speculos slightly

  Changes from upstream, and also a slight change to the loading to accommodate our more complicated linker script.
  That is https://github.com/LedgerHQ/speculos/pull/327

* Bump `crate2nix`

  Get ready to support newer Nixpkgs.

* Update `cargo-ledger`

  Note that the `package.metadata.nanos` has changed with this.
  `path` and `curve` are now lists of strings, not strings.

## 0.4.2

* Add Clippy and rustfmt to the development shell

## 0.4.1

* Do not force LTO in the ledger app build, some apps were not working with it.

* Instead of baking in our PIC LLVM pass to rustc, instruct it to load from the SO using the new LLVM pass manager.

  This change allows us to simplify things, deprecating `rustcBuild` and `rustcRopi` in package sets

* Bump `crate2nix`

  * Supports newer Nix.

  * Supports improved `target-family` support now upstreamed into Nixpkgs.

* Bump Nixpkgs to newer 22.05

* Use `thunkSource` for util dependencies.

  This makes modifying them easier.

## 0.4.0

* Bump Nixpkgs: 21.11 -> 22.05

* Bump Rust: 1.56 -> 1.61

* Suppport package sets for all three Ledger devices:

  * Nano S
  * Nano X
  * Nano S+

## 0.3.0

* Bump Nixpkgs: 21.05 -> 21.11

* Bump Rust: 1.53 -> 1.56

## 0.2.1

Compute all `Cargo.nix` that are needed on the fly instead of vendoring impurely pre-generated copies.

## 0.2.0

- Extend target spec so the OS "family" is "bolos".

  This prepares us for supporting more devices without `cfg` in Rust having to enumarate each of them.

## 0.1.1

- Switch back to upstream `crate2nix`.

  Our PRs improving cross support have been merged.

## 0.1.0

- Removed `rust/`.

  These libraries now have their own homes:

   - `rust/ledger-log` -> [`alamgu/ledger-log`](https://github.com/alamgu/ledger-log)

   - `rust/prompts-ui` -> [`alamgu/ledger-log`](https://github.com/alamgu/ledger-prompts-ui)

This is not technically a breaking change because these libraries are not used
in this repo. Downstream `Cargo.toml`s handle versioning separately than the
Nix infra this exposes.

## 0.0.1

- Rename project to Alamgu.

- Switch Nixpkgs to stock 21.05

  All patches have been upstreamed!

## 0.0.0

Initial release

We've been using this for a while now.
We're cutting release before making more invasive changes like bumping Nixpkgs.
