# 01 — Normative references

External documents are cited at a **pinned understanding** below. Implementers **MUST** re-read the living WHATWG spec when implementing; if WHATWG has changed, update this file in the same change set as code.

## Primary standards

| Document | Role in `heat-url` |
| --- | --- |
| [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986) — URI Generic Syntax | `rfc3986` profile grammar, component ABNF, relative resolution (§5), comparison/normalization (§6) |
| [RFC 3987](https://www.rfc-editor.org/rfc/rfc3987) — IRI | Unicode in non-scheme components; mapping IRI → URI via UTF-8 percent-encoding of non-ASCII |
| [WHATWG URL Standard](https://url.spec.whatwg.org/) | `whatwg` profile parser, serializer, host parser, percent-encode sets, `application/x-www-form-urlencoded` |
| [Unicode Technical Standard #46](https://www.unicode.org/reports/tr46/) — Unicode IDNA Compatibility Processing | Domain ToASCII / ToUnicode used by WHATWG and by explicit IDNA APIs |
| [RFC 3492](https://www.rfc-editor.org/rfc/rfc3492) — Punycode | ACE (`xn--`) encode/decode used by IDNA |
| [RFC 5890](https://www.rfc-editor.org/rfc/rfc5890)–[RFC 5894](https://www.rfc-editor.org/rfc/rfc5894) — IDNA2008 | Terminology and IDNA2008 validity; UTS #46 is the processing layer this library implements |
| [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) | Requirement keywords |

## Supporting standards

| Document | Role |
| --- | --- |
| [RFC 6874](https://www.rfc-editor.org/rfc/rfc6874) | IPv6 zone identifiers in URIs (`rfc3986` profile only) |
| [RFC 5952](https://www.rfc-editor.org/rfc/rfc5952) | Recommended IPv6 text representation for `rfc3986` serialization |
| [RFC 8089](https://www.rfc-editor.org/rfc/rfc8089) | `file:` URI informational rules for the RFC profile (WHATWG `file` rules remain WHATWG) |
| [RFC 1034](https://www.rfc-editor.org/rfc/rfc1034) / [RFC 1123](https://www.rfc-editor.org/rfc/rfc1123) | DNS name length and LDH vocabulary (applied when STD3 / `beStrict` is on) |
| [RFC 4291](https://www.rfc-editor.org/rfc/rfc4291) / [RFC 791](https://www.rfc-editor.org/rfc/rfc791) | IPv6 / IPv4 address sizes |
| [WHATWG Encoding Standard](https://encoding.spec.whatwg.org/) | UTF-8 decode without BOM; output encoding for form-urlencoded |
| [WHATWG Infra](https://infra.spec.whatwg.org/) | Scalar value strings, ASCII helpers used by the URL Standard |

## Informative (must not override a profile)

- Python `urllib.parse`, Node `whatwg-url`, Go `net/url`, Java `java.net.URI` — useful for *test ideas*, never for deciding WHATWG vs RFC behavior.
- [URL Living Standard tests](https://github.com/web-platform-tests/wpt/tree/master/url) (`urltestdata.json`, `setters_tests.json`, `percent-encoding.json`).
- [IDNATestV2](https://www.unicode.org/Public/idna/) from Unicode.

## Precedence

When implementing an operation tagged with a profile:

1. This `specs/` tree (API, errors, limits, native-IDNA requirement).
2. The profile’s primary standard (RFC 3986+3987 **or** WHATWG URL).
3. UTS #46 + RFC 3492 for IDNA primitives shared by both profiles.
4. Supporting RFCs only where the profile document is silent **and** this tree explicitly allows them (example: RFC 6874 zone IDs on `rfc3986` only).

**Conflict examples that are already resolved here:**

- WHATWG omits IPv6 `<zone_id>`. `whatwg` **MUST NOT** accept zone IDs. `rfc3986` **MAY** parse them per RFC 6874.
- WHATWG special-scheme hosts are IDNA-processed during parse. `rfc3986` parse **MUST NOT** rewrite `reg-name` to Punycode unless the caller uses the IDNA API or an explicit “host to ASCII” option.
- WHATWG percent-decodes then re-encodes with per-component encode sets. RFC 3986 permits leaving percent-encoded octets as-is (syntax-based normalization vs others). Each profile keeps its own encode/decode policy.

## Snapshot note

WHATWG URL Standard referenced while writing these specs: **Last Updated 18 August 2026**. Mojo toolchain for the workspace: **Mojo 1.0.0**.
