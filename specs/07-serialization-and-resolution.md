# 07 — Serialization and resolution

## WHATWG serializer

Implement URL Standard §4.5.

- Scheme, `://` vs `:`, credentials, host, port (omit default ports for special schemes), path, query, fragment.
- `exclude_fragment` flag as specified.
- File URLs and empty host: follow the spec (`file:///`, `file://localhost/` shrinking rules already applied at parse).
- Host serialization: domains as ASCII, IPv4 dotted decimal, IPv6 in `[]` with WHATWG compression, opaque host as stored.

Parse → serialize → parse **MUST** be identity on the URL record for successful parses (WHATWG goal). Serialize → parse **MUST** also be stable for serializer output.

## RFC 3986 recomposition

RFC 3986 §5.3 component recomposition:

```text
scheme ":" hier-part [ "?" query ] [ "#" fragment ]
```

- Emit `//` **only** when `has_authority` is true (including empty host).
- Userinfo followed by `@` when present.
- Port prefixed with `:` when present.
- Path: if authority is present and path is non-empty, path **MUST** start with `/` (RFC 3986 §3). The parser **SHOULD** reject or repair only via an explicit `fix_path` option; default is reject `http://example.comfoo`.
- Do not drop empty query (`?`) or empty fragment (`#`) if those components were present as empty strings.

IPv6 hosts serialize in `[]`. Zone IDs use `%25`.

## Relative resolution

### RFC 3986 §5

Implement transform references (5.2.2), merge paths (5.2.3), remove dot segments (5.2.4). Remove-dot-segments **MUST** match the RFC algorithm (not WHATWG’s `%2e` rules unless the input already decoded those segments).

### WHATWG

Relative references are handled **inside** the basic URL parser with a base URL. Do not run RFC 3986 §5 on WHATWG records.

A dedicated `resolve(ref, base, profile)` **MUST** dispatch to the correct algorithm.

## Normalization (`rfc3986`)

Expose explicit operations; do not hide them inside parse:

| Operation | RFC 3986 | Default |
| --- | --- | --- |
| Syntax-based | §6.2.2 — lowercase scheme and host, uppercase percent hex, decode unreserved percent-encodes | Off on parse |
| Scheme-based | §6.2.3 — default port removal, `http` path `/` when empty, etc. | Off; when on, only for schemes this library documents (`http`, `https`, `ftp`, `ws`, `wss`, `file`) |
| Protocol-based | §6.2.4 | Out of scope |

WHATWG canonicalization **is** the parser/serializer. Do not offer a separate “normalize” that undoes WHATWG recoveries.

## Origin

WHATWG origin (§4.7) **MAY** be implemented as a helper (`tuple` of scheme, host, port). Opaque origins for `file` and non-special URLs **MUST** follow the spec. Origin is **not** required for v1 parse conformance but **SHOULD** be included if HTTP clients will depend on this library.

## Path helpers

- Join path segments with `/` without collapsing empty segments unless the profile’s parser already did.
- For WHATWG special URLs, path is a list; serialize with leading `/` and `/` between segments (including empty segments that produce `//` in the path).
