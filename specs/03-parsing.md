# 03 — Parsing

## Shared requirements

- Input is a scalar value string (Mojo `String`) or a byte sequence interpreted as UTF-8. Invalid UTF-8 in a byte API **MUST** fail before URL parsing.
- Parsers **MUST** be iterative (no unbounded recursion on path `..` or nested encodings).
- Parsers **MUST** bound work by input length (see [08-error-handling.md](08-error-handling.md)).
- A **base URL** is optional. WHATWG uses it per the basic URL parser. RFC 3986 uses §5 relative resolution only when the input is a relative-ref **and** a base is provided; absolute URIs ignore base except for documented merge helpers.

## `rfc3986` profile

### Algorithm

1. If IRI mode is enabled (default **on** for public `parse_uri` when non-ASCII is present): apply RFC 3987 — scheme must still match `ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )`; other components may contain UCS characters excluding those forbidden by RFC 3987. Optionally convert to URI by UTF-8 percent-encoding non-ASCII (RFC 3987 §3.1) when the caller asks for a URI-only record.
2. Split using the RFC 3986 Appendix B component scan (the five-component regular structure), implemented as a **state machine / pointer scan**, not as an actual regular-expression engine requirement:
   - scheme, authority, path, query, fragment
3. If authority is present, parse `userinfo`, `host`, `port`:
   - Host: `IP-literal` / `IPv4address` / `reg-name` per Appendix A.
   - IPv4 **MUST** match `dec-octet` (no octal/hex IPv4 in this profile).
   - IPv6 **MUST** match `IPv6address`; zone ID **MAY** be accepted per RFC 6874 (`%25` + `ZoneID`).
4. Reject inputs that do not match the ABNF. Do not “fix” `https:example.org` into `https://example.org/`.
5. If the input is a relative-ref and a base `Uri` is provided, resolve per RFC 3986 §5.2.
6. Lowercase the scheme. Do not lowercase `reg-name` unless a normalization option is set (syntax-based normalization **SHOULD** be a separate `normalize` operation, RFC 3986 §6.2.2).

### Strictness flags

| Flag | Default | Effect |
| --- | --- | --- |
| `iri` | true | Allow RFC 3987 characters; if false, non-ASCII outside percent-encoding fails |
| `allow_ipv6_zone_id` | true | RFC 6874 zone IDs |
| `normalize_syntax` | false | If true, apply §6.2.2 (case of scheme/host, percent-encoding case, decode unreserved) after parse |

### Forbidden silent recoveries

The RFC parser **MUST NOT**:

- Treat `\` as `/`.
- Insert missing `//` after special schemes.
- Parse IPv4 with `0x` or leading-zero octal.
- Drop a port that is non-numeric.
- IDNA-encode the host as part of parse.

## `whatwg` profile

Implement the **basic URL parser** in WHATWG URL Standard §4.4, including all states (scheme start, no scheme, special authority slashes, authority, host, port, file, path, opaque path, query, fragment, etc.).

### Required WHATWG behaviors (non-exhaustive, all mandatory)

- Record **validation errors** from the table in WHATWG §1.1; only rows marked **Failure** abort parse.
- Special scheme table and default ports as in [02-data-model.md](02-data-model.md).
- For special URLs, `\` is a path separator (validation error `invalid-reverse-solidus`).
- `file:` Windows drive letters, `localhost` shrinking to empty host, and drive-letter quirks as specified.
- Host parsing via the WHATWG host parser (`isOpaque` depends on whether the URL is special). See [06-host-and-idna.md](06-host-and-idna.md).
- Port is a 16-bit unsigned integer; `port-out-of-range` and `port-invalid` are failures when the spec says so.
- Path: single-dot and double-dot segment compression including `%2e` variants.
- Query encoding: UTF-8 percent-encode with query or special-query encode set (`'` extra for special URLs).
- Idempotence: parse → serialize → parse **MUST** yield an equivalent URL record for non-failure results.

### Base URL

Follow WHATWG: a missing scheme with no usable base is failure (`missing-scheme-non-relative-URL`). Relative resolution is **not** RFC 3986 §5; it is the parser’s no-scheme / scheme-state logic.

### Constructor vs parse

| Operation | Failure behavior |
| --- | --- |
| `parse_url` / `Url.parse` | Returns failure (`ParseError` / `Optional.empty`) — analogue of `URL.parse` |
| `Url()` raising constructor | **MUST** raise `ParseError` — analogue of `new URL()` |

Both **MUST** run the same parser.

## Choosing a parser

| Caller intent | API |
| --- | --- |
| Browser-like / HTML forms / HTTP(S) user input | `whatwg` |
| Protocol identifiers, RDF, strict validators, IETF URI | `rfc3986` |
| Unknown mixed input | **MUST NOT** guess; the caller chooses |

## Encoding of implementation

Pseudocode in WHATWG is the spec. Mojo code **MUST** implement those steps, not a “simplified” parser that only handles `http` URLs. RFC 3986 **MUST** accept any scheme matching the ABNF, including `urn:`, `mailto:`, `tag:`, and `git+https:`.
