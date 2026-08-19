# Phase 00 — Bootstrap

**Status:** done.

## Goal

Make the repo implementable: a compilable `heat_url` package, shared error/profile/options types, and a test runner. Later phases add parsers; they do not redo project layout.

## Specs

- [`specs/00-overview.md`](../specs/00-overview.md) — package name, layout
- [`specs/08-error-handling.md`](../specs/08-error-handling.md) — error types, limits, password redaction
- [`specs/09-api.md`](../specs/09-api.md) — `ParseProfile`, `ParseOptions`, error structs

## Landed in this phase

```text
src/heat_url/__init__.mojo
src/heat_url/profile.mojo      # ParseProfile.rfc3986 | .whatwg
src/heat_url/limits.mojo       # comptime caps
src/heat_url/options.mojo      # ParseOptions.rfc3986() / .whatwg()
src/heat_url/error.mojo        # ParseError, ValidationError, IdnaError,
                               # check_input_length, redact_userinfo
test/test_package.mojo
scripts/run-tests.sh
pixi.toml tasks: test, fmt
```

## Commands

```bash
pixi install
pixi run test
pixi run fmt
```

## Do not redo

Do not replace `ParseProfile` / `ParseError` / `ParseOptions` with a parallel set of types. Extend them if a later spec field is missing.
