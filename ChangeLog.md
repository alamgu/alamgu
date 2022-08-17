## Unreleased

* Bump Nixpkgs: 21.05 -> 21.11

* Bump Rust: 1.53 -> 1.56

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
