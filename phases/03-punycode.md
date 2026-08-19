# Phase 03 — Punycode

**Depends on:** 00  
**Unlocks:** 04

## Goal

Native RFC 3492 Punycode for a **single label** (no dots, no UTS #46 mapping). IDNA wrapping comes in phase 04.

## Specs to read

- RFC 3492 (especially decode/encode algorithms and §7.1 samples)
- [`specs/06-host-and-idna.md`](../specs/06-host-and-idna.md) — Punycode section
- [`specs/09-api.md`](../specs/09-api.md) — `punycode_encode` / `punycode_decode`
- [`specs/08-error-handling.md`](../specs/08-error-handling.md) — per-label size cap

## Create

```text
src/heat_url/punycode.mojo
test/test_punycode.mojo
```

Optional: re-export from `heat_url.idna` in phase 04; from `__init__.mojo` you may export `punycode_encode` / `punycode_decode` now or wait until 04. Prefer exporting now so tests import `heat_url.punycode`.

## Implement

- `punycode_encode(label) raises IdnaError -> String` — ASCII output **without** `xn--` prefix (caller of ToASCII adds the prefix). Document this in the function comment. If you instead include `xn--`, say so in STATUS notes and keep ToASCII in phase 04 consistent.
- `punycode_decode(ascii_label) raises IdnaError -> String` — inverse; reject invalid digits / overflow
- `IgnoreInvalidPunycode` is **false**: bad input fails
- Bound output by `DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS`
- No Python, no libc idn

**Recommended convention (match IDNA):** encode/decode the raw bootstring payload; `xn--` is applied in `idna.to_ascii`.

## Tests (minimum)

RFC 3492 §7.1 samples (Japanese, Chinese, Hebrew, etc. as listed in the RFC). Round-trip encode→decode. Invalid input raises `IdnaError`. Overflow / huge output hits the cap.

## Acceptance

- `pixi run test` green
- Linear time in label length; no unbounded recursion

## Out of scope

UTS #46 mapping, STD3, CheckBidi, splitting on `.`, IPv4.
