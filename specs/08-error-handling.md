# 08 — Errors and robustness

## Error taxonomy

### `ParseError` (fatal)

Raised or returned when the profile’s parser **fails**. Fields:

| Field | Meaning |
| --- | --- |
| `profile` | `rfc3986` or `whatwg` |
| `kind` | Stable snake_case identifier |
| `message` | Human-readable, ASCII preferred |
| `index` | Optional code-point offset into the original input |
| `whatwg_name` | Optional WHATWG failure name (`host-missing`, `port-out-of-range`, …) |

`kind` values **MUST** be stable across minor versions. WHATWG failure kinds **SHOULD** use the spec’s kebab-case names in `whatwg_name`.

The parser **MUST NOT** panic, abort, or throw an untyped runtime crash on any finite input that fits the size limit.

### `ValidationError` (WHATWG, non-fatal)

Each WHATWG validation error:

| Field | Meaning |
| --- | --- |
| `name` | Spec name (`invalid-URL-unit`, `domain-to-ASCII`, …) |
| `index` | Optional offset |
| `fatal` | Always false for this type; fatal cases are `ParseError` |

`parse_url` success **MUST** be able to return the URL plus the list (possibly empty). A `strict_whatwg` flag **MAY** convert any validation error into failure; default **off** (browser-compatible).

### IDNA errors

Surface UTS #46 CheckHyphens / CheckBidi / CheckJoiners / STD3 / length / Punycode failures as `IdnaError` with a `code` enum. WHATWG host parse maps these to `domain-to-ASCII` as specified.

## Input limits (DoS)

Defaults **MUST** be enforced. Callers **MAY** raise them.

| Limit | Default | On exceed |
| --- | --- | --- |
| Input code points | 1 MiB (`2^20`) | `ParseError` `input_too_long` |
| Authority length | 32 KiB | fail |
| Path segment count (WHATWG list) | 8192 | fail |
| Query tuple count | 4096 | fail |
| IDNA label count | 128 | fail |
| Punycode decode output per label | 63 ASCII LDH octets after ToASCII when `VerifyDnsLength`; otherwise 256 Unicode code points per label | fail |

No compression-bomb path: percent-decode expansion is at most linear (each `%xx` becomes one byte).

## Memory and time

- O(n) time for parse/encode/decode except IDNA mapping (still O(n) with table lookup).
- No backtracking regex over the full URL.
- IPv6 / IPv4 parsers **MUST** be bounded by literal length.

## Security properties

1. **No credential leakage in errors.** `ParseError.message` **MUST NOT** include userinfo (username/password). Truncate host in messages if needed.
2. **Homograph awareness.** ToUnicode is for display; security decisions **SHOULD** use ASCII/ToASCII or WHATWG origin. v1 **MUST NOT** claim confusable-character detection (UTS #39 is out of scope).
3. **NUL and control bytes.** Do not truncate at NUL. Document that embedding decoded URLs in C APIs is the caller’s problem.
4. **CRLF.** `%0d` / `%0a` in components stay in components; serializers **MUST** percent-encode C0 in WHATWG encode sets so raw CR/LF are not reintroduced into HTTP request-target lines when using WHATWG serialize. RFC serialize **SHOULD** offer `encode_c0=true` for the same reason when emitting wire URIs.
5. **Open redirects / backslash.** Only the WHATWG profile treats `\` as `/` on special URLs. RFC profile keeps `\`. Callers **MUST** pick a profile deliberately for security-sensitive redirects.
6. **IPv4 confusion.** WHATWG `http://1.1` style hosts **MUST** parse as IPv4 per WHATWG; RFC profile **MUST NOT**. Document this in API docs.

## Thread safety and purity

Parse, serialize, encode, and IDNA **MUST** be pure functions of their arguments plus immutable Unicode tables. No global mutable parser state.

## Testing errors

Every WHATWG failure name used in the spec table **MUST** have at least one unit test. RFC ABNF failures **MUST** cover missing scheme colon (for URI, not relative-ref), bad IPv6, non-decimal port, and illegal characters in `reg-name`.
