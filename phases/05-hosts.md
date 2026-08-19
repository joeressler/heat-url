# Phase 05 — Hosts

**Depends on:** 01, 04  
**Unlocks:** 06, 07

## Goal

Parse and serialize hosts for both profiles: IPv4, IPv6, `reg-name` / domain / opaque / empty. IDNA is used for WHATWG **domains** (`is_opaque=false`), not as a silent RFC parse side effect.

## Specs to read

- [`specs/02-data-model.md`](../specs/02-data-model.md) — `RfcHost`, `WhatwgHost`
- [`specs/06-host-and-idna.md`](../specs/06-host-and-idna.md) (entire file)
- [`specs/03-parsing.md`](../specs/03-parsing.md) — host-related forbidden recoveries
- WHATWG URL Standard §3 (hosts)
- RFC 3986 Appendix A (`IP-literal`, `IPv4address`, `reg-name`)
- RFC 6874 (zone IDs, RFC profile only)
- RFC 5952 (RFC IPv6 text)

## Create

```text
src/heat_url/host.mojo
test/test_host.mojo
```

## Implement

Types: `RfcHost` and `WhatwgHost` variants from spec 02.

```text
parse_host_rfc3986(input, *, allow_zone_id=True) raises ParseError -> RfcHost
parse_host_whatwg(input, *, is_opaque=False) raises ParseError -> WhatwgHost
serialize_host(...) -> String
```

RFC IPv4: four decimal `dec-octet`s only. WHATWG IPv4: full host parser (hex, octal, 1–4 parts, ends-in-a-number).  
RFC IPv6: ABNF + optional zone ID. WHATWG IPv6: spec algorithm, **no** zone ID.  
WHATWG opaque host: C0 percent-encode, forbidden host code points.  
WHATWG domain: UTS #46 via `idna.to_ascii` with the WHATWG domain-parser fork (ASCII lowercase even when strict ToASCII failed, when `beStrict` is false — implement that fork **here** as specified).

Forbidden host/domain code points: spec 06.

## Tests (minimum)

- RFC: `127.0.0.1` IPv4; `127.0.0x1` is **not** IPv4 (reg-name or fail per ABNF)
- WHATWG: `0x7f.0.0.1` IPv4
- `[::1]` and `[2001:db8::1]` round-trip both profiles
- Zone ID accepted only in RFC with `allow_zone_id`
- `faß.example` as WHATWG domain → ASCII `xn--fa-hia.example`; as opaque → percent-encoded, not Punycode (WHATWG host table)
- `git://` opaque vs special-scheme domain is a **URL** concern; here test `parse_host_whatwg(..., is_opaque=True|False)` directly

## Acceptance

- `pixi run test` green
- Public suffix / registrable domain **not** implemented (spec non-goal)

## Out of scope

Full URL parser, path, query.
