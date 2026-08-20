# Contributing

Thanks for looking at heat-url. Specs in [`specs/`](specs/README.md) are the
contract. If code and a spec disagree, fix them together in the same change.
Do not copy Python `urllib`, Go `net/url`, or "whatever browsers seem to do"
when a profile already cites WHATWG or RFC 3986.

## Setup

```bash
pixi install
pixi run mojo --version
pixi run test
pixi run fmt
```

Run one file:

```bash
pixi run mojo run -I src test/test_percent.mojo
```

`pixi run test` walks `test/test_*.mojo`. Do not use `mojo test`.

## Rules that tend to matter

- `parse_url` is WHATWG. `parse_uri` is RFC 3986. No `parse_magic`.
- No `from std.python import Python` under `src/heat_url`. Table generators
  can live in `tools/`.
- Public functions should name the spec clause they implement.
- Untrusted input must not abort the process. Size caps live in
  `heat_url.limits`. Error strings must not include passwords
  (`redact_userinfo`).
- WHATWG validation errors are not parse failures unless `strict_whatwg` is
  on.
- Mojo 1.0: `def` only (no `fn`), `comptime` not `alias`,
  `from std.testing import ...`.

WPT skips belong in `test/data/WHATWG_SKIP.md` with a reason. An unexplained
fixture failure is a parser bug.

Refresh golden files with `bash tools/fetch_fixtures.sh` (network). Committed
copies are what tests use.

## Packaging

[`conda.recipe/recipe.yaml`](conda.recipe/recipe.yaml) builds a conda package
with `mojo precompile`. Local builds use `source.path`. A
[modular-community](https://github.com/modular/modular-community) listing needs
the git URL and a full commit SHA instead.

```bash
rattler-build build \
  --recipe conda.recipe/recipe.yaml \
  -c conda-forge \
  -c https://conda.modular.com/max
```

The published package must not depend on EmberJson. That crate is tests-only.

## License

Contributions land under Apache License 2.0.
