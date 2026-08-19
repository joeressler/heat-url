# Phase 01 — Percent-encoding

**Depends on:** 00  
**Unlocks:** 02, 05–07

## Goal

Ship `heat_url.percent`: encode/decode with named sets. All later parsers **must call this module** instead of copying hex tables.

## Specs to read

- [`specs/04-percent-encoding.md`](../specs/04-percent-encoding.md) (entire file)
- [`specs/09-api.md`](../specs/09-api.md) — Percent module
- WHATWG URL Standard §1.3 (percent-encoded bytes and encode sets)
- RFC 3986 §2

## Create

```text
src/heat_url/percent.mojo
test/test_percent.mojo
```

Re-export `EncodeSet` and the encode/decode functions from `src/heat_url/__init__.mojo`.

## Implement

`EncodeSet` variants from the spec: `C0Control`, `Fragment`, `Query`, `SpecialQuery`, `Path`, `Userinfo`, `Component`, `FormUrlencoded`, plus RFC sets `RfcUnreserved`, `RfcUserinfo`, `RfcRegName`, `RfcPath`, `RfcQuery`, `RfcFragment`.

| Function | Behavior |
| --- | --- |
| `encode(input, set, space_as_plus=False)` | UTF-8 encode, then `%` + **uppercase** hex for bytes whose code point is in the set. `space_as_plus` only for form-urlencoded (U+0020 → `+`) |
| `decode_lenient(input)` | WHATWG: stray `%` copied through; returns `List[UInt8]` |
| `decode_strict(input)` | RFC: `%` not followed by two hex digits → `ParseError` (kind `invalid_percent_encoding`) |
| `decode_utf8_strict` / `decode_utf8_lenient` | decode bytes then UTF-8; invalid UTF-8 fails |

`+` is **not** space in generic decode. `%00` is a real 0x00 byte.

## Tests (minimum)

- Encode space in path → `%20`; form-urlencoded with `space_as_plus=True` → `+`
- Hex digits on encode are `A–F` not `a–f`
- `decode_lenient("%")` → `[0x25]`; `decode_strict("%")` raises
- `~` encoded in `FormUrlencoded`, not in `RfcUnreserved`
- UTF-8 round-trip: `é`, `日本語`, emoji via encode `Component` then decode_utf8
- `%00` survives `decode_lenient` as a zero byte
- Unreserved RFC characters (`A-Z a-z 0-9 -._~`) unchanged by `RfcUnreserved`

## Acceptance

- `pixi run test` includes `test/test_percent.mojo` and passes
- No Python
- Encode sets match the additive table in spec 04 (do not invent a “safe” set)

## Out of scope

Query list parsing, URL parse, IDNA.
