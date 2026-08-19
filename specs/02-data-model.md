# 02 — Data model

Types below are specification types. Mojo structs **MUST** preserve the fields and optionality. Names **MAY** use Mojo conventions (`Url`, `Uri`, `Host`) as in [09-api.md](09-api.md).

## Common string rules

- A **scalar value string** is a sequence of Unicode scalar values (no surrogates), matching WHATWG Infra and Mojo `String` contents.
- An **ASCII string** is a scalar value string whose code points are all ≤ U+007F.
- Internal URL/URI component strings in the WHATWG profile are ASCII (percent-encoded as needed). The RFC profile may hold IRI components as Unicode until converted to URI.

## `Uri` record (`rfc3986` profile)

A `Uri` is a parsed URI-reference. Components are stored as **raw parsed text** (percent-encoded sequences preserved) unless an operation documents decoding.

| Field | Type | Notes |
| --- | --- | --- |
| `scheme` | optional ASCII string | Case stored lowercase after parse (RFC 3986 §3.1 scheme is case-insensitive; syntax-based normalization lowercases it) |
| `userinfo` | optional string | Includes `:` inside userinfo; **MUST NOT** split user/password unless a dedicated accessor is used |
| `host` | optional `RfcHost` | Absent when no authority |
| `port` | optional string of DIGIT, plus optional parsed `UInt16` | RFC 3986 allows any `*DIGIT`; values > 65535 **MUST** be representable as text and **MUST** fail if coerced to a 16-bit port |
| `path` | string | Path as parsed; may be empty. Path types (abempty, absolute, noscheme, rootless, empty) **SHOULD** be recoverable |
| `query` | optional string | Without leading `?` |
| `fragment` | optional string | Without leading `#` |
| `has_authority` | bool | Distinguishes `foo:/bar` from `foo://bar` and empty-authority `file:///x` |
| `is_relative` | bool | True for relative-ref (no scheme) |

### `RfcHost`

| Variant | Payload |
| --- | --- |
| `Ipv4` | 32-bit unsigned integer |
| `Ipv6` | 128-bit address as eight 16-bit pieces; optional zone ID string (RFC 6874) |
| `IpvFuture` | version nibble string + remainder (RFC 3986 `IPvFuture`) |
| `RegName` | string, percent-encodings preserved; not IDNA-converted by default |

## `Url` record (`whatwg` profile)

Matches the WHATWG **URL record**:

| Field | Type | Initial |
| --- | --- | --- |
| `scheme` | ASCII string | `""` |
| `username` | ASCII string | `""` |
| `password` | ASCII string | `""` |
| `host` | optional `WhatwgHost` | null |
| `port` | optional `UInt16` | null |
| `path` | opaque path **or** list of ASCII path segments | empty list |
| `query` | optional ASCII string | null |
| `fragment` | optional ASCII string | null |

`blob URL entry` is **out of scope** for v1 (always null).

Special schemes and default ports **MUST** match WHATWG:

| Scheme | Default port |
| --- | --- |
| `ftp` | 21 |
| `file` | null |
| `http` | 80 |
| `https` | 443 |
| `ws` | 80 |
| `wss` | 443 |

A URL is **special** iff its scheme is a special scheme. Special URLs **MUST NOT** have an opaque path.

Allowed scheme/host combinations **MUST** match WHATWG §4.1 (special excluding `file` require a domain or IP; `file` allows domain, IP, or empty host; non-special allow IPv6, opaque host, empty host, or null).

### `WhatwgHost`

| Variant | Payload |
| --- | --- |
| `Domain` | non-empty ASCII domain (IDNA output) |
| `Ipv4` | 32-bit unsigned integer |
| `Ipv6` | 128-bit address as eight 16-bit pieces (**no** zone ID) |
| `OpaqueHost` | non-empty ASCII string |
| `EmptyHost` | empty string |

## Query list

A **query list** is an ordered list of `(name, value)` tuples of scalar value strings. Order **MUST** be preserved. Duplicate names **MUST** be allowed. This is the WHATWG `application/x-www-form-urlencoded` data model and the WHATWG `URLSearchParams` list.

The RFC profile **MAY** attach a query list by parsing `Uri.query` with the form-urlencoded parser; that is an application-layer view, not RFC 3986 syntax.

## Percent-encode set

A named set of code points that **must** be percent-encoded. Built-in sets are listed in [04-percent-encoding.md](04-percent-encoding.md).

## Parse result

Every parse operation returns one of:

- **Success** with a record and, for `whatwg`, a (possibly empty) list of **validation errors**.
- **Failure** with a `ParseError` (see [08-error-handling.md](08-error-handling.md)).

RFC 3986 has no “validation error but success” channel: input either matches the grammar (optionally after a documented lenient flag) or fails.

## Equality

- `whatwg`: URL equivalence as WHATWG §4.6 (serialize without fragment by default for equality helpers unless `include_fragment` is set).
- `rfc3986`: comparison as RFC 3986 §6. Two URIs **MUST NOT** be reported equal solely because their WHATWG serializations match.

Host equivalence follows the profile’s host serializer, not Unicode “looks the same”.
