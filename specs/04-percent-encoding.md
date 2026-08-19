# 04 — Percent-encoding

Percent-encoding is a **standalone module**. URL parse/serialize **MUST** call it rather than duplicating encode tables.

## Byte grammar

A percent-encoded byte is `%` followed by two ASCII hex digits (`0-9A-Fa-f`).

**Encode:** given a byte, emit `%` plus two **uppercase** hex digits (WHATWG §1.3; RFC 3986 §2.1 allows either case and prefers uppercase in normalization).

**Decode (WHATWG byte sequence):**

- Copy bytes other than `0x25`.
- If `0x25` is not followed by two hex digits, copy `0x25` unchanged (do not fail).
- Otherwise append the decoded byte and skip the two digits.

**Decode (RFC strict mode):** `%` not followed by two hex digits **MUST** fail. This is the default for `rfc3986` component validation. A `lenient` decode API **MAY** match WHATWG’s “leave stray `%`” rule.

## UTF-8

- **Percent-encode a scalar value string:** UTF-8 encode, then percent-encode each byte that is in the given encode set (and, when specified, space-as-plus).
- **Percent-decode to string:** percent-decode to bytes, then UTF-8 decode without BOM. Invalid UTF-8 **MUST** fail in strict APIs. WHATWG form-urlencoded uses UTF-8 decode without BOM (Replacement is **not** used in the URL Standard’s form parser description — implement “UTF-8 decode without BOM” as in the Encoding Standard; if that operation fails, fail the decode API. For WHATWG URL parser internals, follow the URL Standard’s own percent-decode + isomorphic decode steps exactly).

Never use a locale encoding. UTF-8 is the only default.

## Named percent-encode sets (WHATWG §1.3)

Implement these sets exactly. Each is a set of code points that **are** encoded. All non-ASCII code points are encoded for these sets (they include the C0 control set which already covers > U+007E).

| Name | Contents (additive) |
| --- | --- |
| `c0_control` | C0 controls and code points > U+007E |
| `fragment` | C0 + SPACE `"` `<` `>` `` ` `` |
| `query` | C0 + SPACE `"` `#` `<` `>` |
| `special_query` | query + `'` |
| `path` | query + `?` `^` `` ` `` `{` `}` |
| `userinfo` | path + `/` `:` `;` `=` `@` `[` `\` `]` `\|` |
| `component` | userinfo + `$` `&` `+` `,` (HTML `encodeURIComponent` equivalent with UTF-8) |
| `application_x_www_form_urlencoded` | component + `!` `'` `(` `)` `~` — i.e. encode everything except `ALPHA / DIGIT / * / - / . / _` |

RFC 3986 **unreserved** is `ALPHA / DIGIT / "-" / "." / "_" / "~"`. Encoding “all except unreserved” is **not** the same as the form-urlencoded set (`~` is unreserved in RFC 3986 but encoded in form-urlencoded).

## RFC 3986 encode helpers

Provide sets aligned to RFC 3986 components (encode everything that is not allowed in that ABNF production):

| Name | Allowed unencoded |
| --- | --- |
| `rfc_unreserved` | unreserved only |
| `rfc_userinfo` | unreserved / sub-delims / `:` |
| `rfc_reg_name` | unreserved / sub-delims |
| `rfc_path` | `pchar` |
| `rfc_query` | `pchar` / `/` / `?` |
| `rfc_fragment` | `pchar` / `/` / `?` |

`pct-encoded` already in the input **MUST NOT** be double-encoded by parse. Dedicated `encode` functions **MUST** encode `%` when the set includes it (component and form-urlencoded sets do; several URL-parser sets do **not**, matching WHATWG’s warning about round-tripping).

## Space-as-plus

Only the `application/x-www-form-urlencoded` encode path maps U+0020 to `+`. Path, userinfo, fragment, and RFC component encoding **MUST** use `%20` for space.

Decode of query form data maps `+` to space **after** splitting on `&`, as in WHATWG §5.1. Generic percent-decode **MUST NOT** treat `+` as space.

## Robustness

- Incomplete `%` at end of input: strict RFC fails; WHATWG decode copies `%`.
- `%00` **MUST** be representable in decoded **bytes**. String APIs **MUST** document whether NUL is allowed (Mojo `String` can hold it; higher-level “C string” exports **MUST NOT** silently truncate).
- Encode/decode **MUST** run in linear time and allocate O(n).
- Do not interpret `%0a` / `%0d` as syntax delimiters after the first split into components; they belong to the component body as encoded data.

## Public operations (see also [09-api.md](09-api.md))

- `percent_encode(input, set, space_as_plus=false) -> String`
- `percent_decode_lenient(input) -> List[Byte]` (WHATWG)
- `percent_decode_strict(input) -> List[Byte] | error` (RFC)
- `percent_decode_utf8(...)` wrappers
