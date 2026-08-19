# Phase 04 — IDNA / UTS #46

**Depends on:** 03  
**Unlocks:** 05

## Goal

`heat_url.idna.to_ascii` / `to_unicode` using Unicode IDNA Compatibility Processing (UTS #46), **non-transitional**, matching WHATWG §3.3 parameter table.

## Specs to read

- [`specs/06-host-and-idna.md`](../specs/06-host-and-idna.md) — Domain names and IDNA
- UTS #46 (ToASCII / ToUnicode, mapping table)
- WHATWG URL Standard §3.3 (exact flag table for `beStrict`)
- [`specs/09-api.md`](../specs/09-api.md) — IDNA functions
- [`specs/10-conformance.md`](../specs/10-conformance.md) — IDNATestV2 (full vendor is phase 09; use a **small** hand-picked subset here)

## Create

```text
src/heat_url/idna.mojo
src/heat_url/idna_data.mojo   # generated mapping tables, or idna_data/*.mojo
tools/generate_idna_tables.py # optional generator; runtime stays Mojo
test/test_idna.mojo
```

Document the Unicode version in a comment at the top of the data module.

## Implement

`to_ascii(domain, *, be_strict=False) raises IdnaError -> String`  
`to_unicode(domain) raises IdnaError -> String`

Flags from spec 06 / WHATWG:

| Option | `be_strict=true` | `be_strict=false` |
| --- | --- | --- |
| CheckHyphens | true | false |
| CheckBidi | true | true |
| CheckJoiners | true | true |
| UseSTD3ASCIIRules | true | false |
| Transitional_Processing | **false** | **false** |
| VerifyDnsLength | true | false |
| IgnoreInvalidPunycode | false | false |

Split on U+002E. NFC as UTS #46 requires. Punycode via phase 03. `xn--` prefix on non-ASCII labels for ToASCII.

WHATWG host parser’s “ASCII domain lowercased even if strict ToASCII failed” belongs in **phase 05**, not here. This module is the UTS #46 primitives.

Empty labels / trailing dots: follow UTS #46. Label count cap: `DEFAULT_MAX_IDNA_LABELS`. DNS length 63/253 when `VerifyDnsLength`.

**No** `from std.python import Python` in `src/`.

## Tests (minimum)

- `faß.example` → `xn--fa-hia.example`
- `☕.example` → `xn--53h.example`
- ASCII `EXAMPLE.COM` → `example.com` (ToASCII)
- Invalid Punycode label fails
- `be_strict=True` rejects at least one STD3 / hyphen case that non-strict accepts (pick from UTS #46 / IDNATestV2)

## Acceptance

- `pixi run test` green
- Transitional processing never enabled
- Unicode version recorded

## Out of scope

IPv4/IPv6 parsers, WHATWG opaque hosts, full IDNATestV2 dump (phase 09).
