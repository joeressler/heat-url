# 10 — Conformance

A future implementation is **not** complete until the following pass. Phases 01–08 add unit tests; **phase 09** vendors golden files.

## Tooling

- Run tests with `pixi run test` (`scripts/run-tests.sh` runs each `test/test_*.mojo`).
- Each test file: `test_*` functions + `main()` calling `TestSuite.discover_tests[__functions_in_module()]().run()`.
- `mojo test` **MUST NOT** be used (removed from Mojo).

## Golden sources (import as data, do not retype by hand)

| Source | Profile | Use |
| --- | --- | --- |
| [wpt `urltestdata.json`](https://github.com/web-platform-tests/wpt/blob/master/url/resources/urltestdata.json) | `whatwg` | Parse + serialize (skip JavaScript-only base quirks if any; document skips) |
| [wpt `setters_tests.json`](https://github.com/web-platform-tests/wpt/blob/master/url/resources/setters_tests.json) | `whatwg` | Setters, if implemented |
| [wpt `percent-encoding.json`](https://github.com/web-platform-tests/wpt/blob/master/url/resources/percent-encoding.json) | shared | Encode sets |
| [Unicode IDNATestV2](https://www.unicode.org/Public/idna/) | IDNA | ToASCII / ToUnicode |
| RFC 3986 examples (§1.1.2, §5.4, Appendix B) | `rfc3986` | Split and relative resolution |
| RFC 3987 examples | `rfc3986` + IRI | Non-ASCII components |
| RFC 3492 §7.1 samples | Punycode | `xn--` round-trip |

Vendored JSON/text fixtures **SHOULD** live under `test/data/` when implementation starts, with source URL and revision recorded.

Phase 09 notes:

- `urltestdata.json` is parsed with [ehsanmok/json](https://github.com/ehsanmok/json) v0.3.0 (`from json.cpu import parse_cpu_native_tape`; CPU target only).
- WPT **`origin` is not asserted** (WHATWG `origin()` deferred to v1.1). Setters and `urltestdata-javascript-only.json` are not run.
- Empty query/fragment still serialize as `?`/`#` on `href`; the URL **search**/**hash** getters treat null *or empty* as `""` (URL Standard).
- `percent-encoding.json`: utf-8 rows only (`EncodeSet.SpecialQuery`). Other encodings are out of scope (no encoding argument).
- IDNATestV2 columns 6–7 (transitional ToASCII) are ignored. Transitional processing stays false. WHATWG `to_unicode` ignores UTS #46 codes for flags it does not set (`U1`, `V2`, `V3`, `A4_1`, `A4_2`, `X4_2`).

## Required unit clusters

### Percent-encoding

- Uppercase hex on encode.
- Lenient vs strict decode of stray `%`.
- `+` is space **only** in form-urlencoded parse.
- Unreserved RFC characters not encoded by `RfcUnreserved`.
- `~` encoded in form-urlencoded, not in RFC unreserved.
- Round-trip of UTF-8 (`é`, `日本語`, emoji).
- `%00` preserved in byte decode.

### Query

- `a=b&a=c` → two tuples; `get` returns `b`; `get_all` returns both.
- `=v`, `k=`, `k`, empty segments.
- `%26` and `%3D` not treated as separators.
- `sort` UTF-16 code unit order vs a documented pair of names that would differ in UTF-8.
- Tuple cap failure.

### IDNA / hosts

- `faß.example` → `xn--fa-hia.example` (WHATWG domain, non-opaque).
- `☕.example` → `xn--53h.example`.
- Punycode RFC 3492 Japanese/Arabic samples.
- WHATWG IPv4 `0x7f.0.0.1` vs RFC rejection.
- IPv6 compression round-trip `[::1]`, `[2001:db8::1]`.
- Zone ID accepted only in RFC profile.

### RFC 3986

- Appendix B split of `http://www.ics.uci.edu/pub/ietf/uri/#Related`.
- Relative resolution examples in §5.4.
- `urn:isbn:0451450523` opaque path / no authority.
- Strict rejection of `https:example.org` without `//`.
- Scheme case folding.

### WHATWG

- Table in URL Standard §4 (https:example.org, backslashes, file drive letters, spaces, credentials validation errors).
- Validation error recorded but parse succeeds for `https://user:password@example.org/` (invalid-credentials is non-fatal).
- Failure for `https://ex ample.org/` and `https://example.com:demo`.
- Special vs non-special host (opaque `git://`).

### Security / robustness

- Input at `max_input_length + 1` fails.
- Error message for `https://user:secret@host/` does not contain `secret`.
- No stack overflow on a long `a/../../../../...` path.

## Acceptance for “v1 done”

1. All clusters above have tests.
2. WPT `urltestdata.json` expected failures are listed in `test/data/WHATWG_SKIP.md` with reasons; unexplained failures are bugs.
3. IDNATestV2: document ignored columns (e.g. transitional) — transitional **MUST** be false.
4. No Python import in `src/heat_url`.
5. `pixi run mojo --version` still works; `pixi run test` runs the suite.

## Adding tests later

Prefer table-driven tests. Do not assert against Python `urllib.parse` as an oracle for WHATWG or RFC 3986 (it matches neither fully).
