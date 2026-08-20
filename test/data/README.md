# Test fixtures

Golden files for [phase 09](../../phases/09-conformance.md) / [specs/10-conformance.md](../../specs/10-conformance.md). Tests read these from the repo root (see `scripts/run-tests.sh`). Do not treat Python `urllib.parse` as an oracle.

Refresh with `bash tools/fetch_fixtures.sh` (network). Committed copies are authoritative.

## Vendored files

| File | Source | Revision | License |
| --- | --- | --- | --- |
| `urltestdata.json` | [WPT `url/resources/urltestdata.json`](https://github.com/web-platform-tests/wpt/blob/181476aa16e8b28a07698bef3a0275fa53dd22e5/url/resources/urltestdata.json) | git `181476aa16e8b28a07698bef3a0275fa53dd22e5` (2026-08-20) | [WPT 3-clause BSD](https://github.com/web-platform-tests/wpt/blob/master/LICENSE.md) |
| `percent-encoding.json` | [WPT `url/resources/percent-encoding.json`](https://github.com/web-platform-tests/wpt/blob/181476aa16e8b28a07698bef3a0275fa53dd22e5/url/resources/percent-encoding.json) | same SHA | same |
| `IDNATestV2.txt` | [Unicode 17.0.0 IdnaTestV2](https://www.unicode.org/Public/17.0.0/idna/IdnaTestV2.txt) | Unicode 17.0.0 (file date 2025-05-01) | [Unicode Terms of Use](https://www.unicode.org/terms_of_use.html) |
| `WHATWG_SKIP.md` | this repo | | Apache-2.0 (heat-url) |

JSON fixtures are parsed with [EmberJson](https://github.com/bgreni/EmberJson) 0.3.4 (`from emberjson import parse`; pixi package, tests only).

## Not vendored

| File | Why |
| --- | --- |
| WPT `setters_tests.json` | WHATWG setters deferred to v1.1 |
| WPT `urltestdata-javascript-only.json` | non-scalar JS string quirks (spec 10) |
| WPT `toascii.json` | covered by IDNATestV2 + unit hosts tests |

## Driver rules

- `urltestdata.json`: `parse_url` vs `href` and derived getters. **`origin` is not asserted** (deferred). `relativeTo` extra bases are not synthesized. `blob:` / `data:` / `javascript:` run as generic URLs (no blob store).
- `percent-encoding.json`: **utf-8** outputs only, `EncodeSet.SpecialQuery`, `space_as_plus=false`. Other encodings skipped (no encoding argument in v1).
- `IDNATestV2.txt`: columns 1–5 only. Columns 6–7 (transitional ToASCII) **ignored**. `to_ascii(..., be_strict=True)` vs toAsciiN; `to_unicode` (WHATWG flags) vs toUnicode after dropping `U1` / `V2` / `V3`. Unpaired-surrogate (`A3`) lines skipped if Mojo `String` cannot hold them.

## Spec 10 unit clusters (already in `test/test_*.mojo`)

| Cluster | Tests |
| --- | --- |
| Percent-encoding | `test/test_percent.mojo` |
| Query | `test/test_query.mojo` |
| IDNA / hosts | `test/test_idna.mojo`, `test/test_host.mojo`, `test/test_punycode.mojo` |
| RFC 3986 | `test/test_rfc3986.mojo` |
| WHATWG | `test/test_whatwg.mojo`, `test/test_api.mojo` |
| Security / robustness | `test/test_whatwg.mojo`, `test/test_api.mojo`, `test/test_conformance.mojo` |
