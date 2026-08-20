# Phase 09 — Conformance fixtures

**Depends on:** 08  
**Unlocks:** v1 acceptance in [`specs/10-conformance.md`](../specs/10-conformance.md)

## Goal

Vendor external golden files, run them, and document skips. This phase proves interoperability; it should not redesign the parser. Failures without a skip rationale are bugs — fix them in the relevant module, do not weaken tests.

## Specs to read

- [`specs/10-conformance.md`](../specs/10-conformance.md) (entire file)

## Create

```text
test/data/README.md              # source URLs, revisions, licenses
test/data/urltestdata.json       # WPT (or a dated snapshot)
test/data/percent-encoding.json  # optional if useful beyond phase 01
test/data/IDNATestV2.txt         # Unicode
test/data/WHATWG_SKIP.md         # unexplained failures are forbidden
test/test_wpt_url.mojo           # or a small driver + JSON subset loader
test/test_idna_unidata.mojo
tools/fetch_fixtures.sh          # optional; record exact URLs
```

Mojo JSON: tests parse WPT JSON with [EmberJson](https://github.com/bgreni/EmberJson) (`from emberjson import parse`). Do not import EmberJson from `src/heat_url`. Do not write a homemade JSON parser.

## Implement

- Load WPT `urltestdata.json` (WHATWG parse + serialize). Skip entries listed in `WHATWG_SKIP.md` with a **reason** (e.g. blob URLs out of scope)
- IDNATestV2: non-transitional columns only; document ignored columns
- RFC 3986 §5.4 already in phase 06 — keep those tests; add any missing RFC examples
- Security cluster from spec 10: oversize input, password not in errors, long `..` paths

## Tests / commands

```bash
pixi run test
```

Every `test/test_*.mojo` file must pass. Add a pixi task `test-wpt` only if the WPT run is too slow for the default task; default `test` must still run unit tests including a **representative** WPT sample.

## Acceptance (v1 done)

Checklist from spec 10:

1. All unit clusters in spec 10 have tests
2. WPT skips are listed with reasons
3. IDNATestV2 transitional ignored; processing stays non-transitional
4. No Python import in `src/heat_url`
5. `pixi run mojo --version` and `pixi run test` succeed

## Out of scope

New features, PSL, URI templates, shipping a conda recipe (unless the user asks).
