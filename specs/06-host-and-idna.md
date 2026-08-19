# 06 — Hosts and internationalized domain names

IDNA is a **native** subsystem: Punycode + UTS #46 tables compiled into the Mojo package. Core host parsing **MUST NOT** call Python, ICU via FFI (unless a future optional backend is explicitly gated), or libc `idn2`.

## Host kinds

See [02-data-model.md](02-data-model.md). Parsing dispatches on profile.

## IPv4

### `rfc3986`

- Exactly four `dec-octet` values `0–255` in decimal, no leading zeros except the value `0`.
- No hex, octal, or fewer-than-four-part dotted forms.
- `reg-name` that looks like IPv4 but fails `dec-octet` remains a `reg-name` only if it matches `reg-name` ABNF; otherwise failure.

### `whatwg`

Implement the WHATWG IPv4 parser (including hex/`0x`, octal leading zeros, 1–4 parts, and `ends in a number` checker). Validation errors such as `IPv4-non-decimal-part` are non-fatal unless the spec marks failure. Out-of-range rules follow the standard (failure conditions are not the same for every part).

## IPv6

### `whatwg`

Implement the IPv6 parser in WHATWG §3.5. **No zone IDs.** Unclosed brackets, multiple `::`, too many pieces, etc. fail as specified. Serialize compressed form per WHATWG host serializer (longest zero run).

### `rfc3986`

- Parse `IPv6address` ABNF.
- If `allow_ipv6_zone_id`, accept RFC 6874: zone delimiter in the URI is `%25` followed by `ZoneID = 1*( unreserved / pct-encoded )`.
- Serialize addresses per RFC 5952 (no leading zeros in pieces, compress the longest zero run, lowercase hex). Zone ID: emit `%25` + encoded zone.

`IPvFuture` **MUST** round-trip in the RFC profile (`v` + HEXDIG + `.` + remainder).

## Opaque hosts (`whatwg`)

Non-special URLs use the opaque-host parser: percent-encode C0, reject forbidden host code points. Example: `git://github.com/whatwg/url.git` has an opaque host `github.com` (not IDNA-processed as a special-scheme domain).

## Domain names and IDNA

### Processing layer

WHATWG §3.3: **Unicode IDNA Compatibility Processing (UTS #46)**, not “raw IDNA2008” alone. Example: `☕.example` → `xn--53h.example`, not failure.

**domain parser ToASCII** parameters (WHATWG):

| UTS #46 option | `beStrict = true` | `beStrict = false` |
| --- | --- | --- |
| CheckHyphens | true | false |
| CheckBidi | true | true |
| CheckJoiners | true | true |
| UseSTD3ASCIIRules | true | false |
| Transitional_Processing | false | false |
| VerifyDnsLength | true | false |
| IgnoreInvalidPunycode | false | false |

`beStrict` is true for WHATWG “valid domain” checks; the host parser’s non-strict path lowercases ASCII domains even if strict ToASCII failed (web compatibility). Implement that fork exactly.

**domain to Unicode:** UTS #46 ToUnicode with CheckHyphens false, CheckBidi true, CheckJoiners true, UseSTD3ASCIIRules false, Transitional_Processing false, IgnoreInvalidPunycode false. If errors were recorded, WHATWG returns the original ASCII domain; do the same.

### `rfc3986` default

Parse `reg-name` only. Provide explicit APIs:

- `idna.to_ascii(domain, be_strict: Bool) -> String | error`
- `idna.to_unicode(domain) -> String | error`

A URI option `idna_host=true` **MAY** run ToASCII on `RegName` after parse for callers who want a DNS-ready URI. Default **off**.

### Punycode

Implement RFC 3492 (bootstring) for `xn--` labels. Invalid Punycode **MUST** fail when `IgnoreInvalidPunycode` is false.

Label operations:

1. Split on U+002E (`.`).
2. Map/normalize per UTS #46 mapping table (non-transitional).
3. For each label, ToASCII: apply NFC as UTS #46 requires, then Punycode if non-ASCII, prefix `xn--`.
4. Rejoin with `.`.

Trailing-dot behavior **MUST** follow UTS #46 / WHATWG (VerifyDnsLength and empty labels).

### Unicode data

- Check in a generated mapping table derived from the Unicode IDNA mapping file matching a documented Unicode version.
- Generation script **MAY** be Python; **runtime MUST be Mojo**.
- Document the Unicode version in `src/heat_url/idna` (when created) and in release notes.

### Forbidden code points (`whatwg`)

- Forbidden **host** code points: NUL, TAB, LF, CR, SPACE, `# / : < > ? @ [ \ ] ^ |`
- Forbidden **domain** code points: those plus C0, `%`, DEL

Apply them where the host parser says to.

## Public suffix (optional, not v1-required)

WHATWG defines public suffix / registrable domain via the Public Suffix List. v1 **MAY** omit these helpers. If added later, they **MUST NOT** change parse results.

## Display vs DNS

- **ASCII / wire form:** ToASCII (Punycode labels).
- **Display form:** ToUnicode.
- Equality of special-scheme hosts uses the ASCII domain, not the display form, unless a documented Unicode-equals helper is used (NFC/UTS46; **MUST NOT** use visual confusable matching in v1).
