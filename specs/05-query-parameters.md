# 05 — Query parameters

A URL query is **not** inherently a map. RFC 3986 treats `query` as an opaque `*( pchar / "/" / "?" )` string. HTML and the web platform treat many queries as `application/x-www-form-urlencoded`. `heat-url` supports both and **MUST** keep them separate.

## Opaque query

On both `Uri` and `Url`:

- `query` is optional text **without** the leading `?`.
- Setting `query` to the empty string is distinct from `null` / absent when the profile has that distinction (WHATWG: empty query vs missing query serializes differently — follow the serializer: `?` is emitted if query is non-null).
- No interpretation of `&`, `=`, or `+` in opaque accessors.

## `application/x-www-form-urlencoded`

Implement WHATWG URL Standard §5 **exactly**, UTF-8 only for v1 (legacy `_charset_` / non-UTF-8 decoders are non-goals).

### Parse (byte sequence)

1. Split on `0x26` (`&`). **Do not** split on `;`. Semicolon-as-separator is a **non-default** optional flag (`separator_semicolon=true`) for legacy HTML4; it is **off** for WHATWG conformance.
2. Skip empty sequences.
3. If a tuple contains `0x3D` (`=`), split on the **first** `=` into name / value (either side may be empty). If no `=`, value is empty.
4. Replace `0x2B` (`+`) with `0x20` in name and value.
5. Percent-decode (WHATWG lenient) each side.
6. UTF-8 decode without BOM each side into scalar value strings.
7. Append `(name, value)` in order.

The string parser UTF-8-encodes the scalar value string first, then runs the byte parser.

### Serialize

For each tuple, percent-encode after encoding with UTF-8 and the form-urlencoded encode set (spaces become `+`). Join with `&`. Each tuple is `name=value` even if value is empty. Empty name is allowed (`=x`).

### List operations (URLSearchParams semantics)

Operate on the ordered list of tuples. Names are matched as exact scalar value string equality (no case folding).

| Operation | Behavior |
| --- | --- |
| `get(name)` | First value whose name matches, or absent |
| `get_all(name)` | All values in order |
| `has(name)` / `has(name, value)` | Existence |
| `set(name, value)` | Replace first matching name’s value; remove later matches; append if none |
| `append(name, value)` | Append tuple |
| `delete(name)` / `delete(name, value)` | Remove matches |
| `sort()` | Stable sort by name (UTF-16 code unit order is WHATWG’s JS order; in Mojo sort by Unicode code point / UTF-8 bytes **MUST** be documented). **SHOULD** sort by UTF-8 byte order and record that as a Mojo deviation in tests, **or** implement UTF-16 code unit order for bit-for-bit JS compatibility. v1 **MUST** pick UTF-16 code unit order when a pair would disagree, to match web-platform-tests. |
| `size` | Number of tuples |
| iteration | Insertion order |

Updating a `Url`’s query object **MUST** write through to `Url.query` using the form-urlencoded serializer (WHATWG `URLSearchParams` update algorithm).

### Differences vs URL serializer

Serializing `Url.query` via the URL serializer uses the **query** / **special-query** encode set and does **not** use `+` for spaces. Serializing via the query-list serializer **does**. This mismatch is specified by WHATWG and **MUST** be preserved (see WHATWG §6.2 note). Callers that need one or the other must choose the API.

## RFC 3986 query views

`parse_query(uri.query, syntax=form_urlencoded)` is allowed as a helper. It does not make the URI parser validate `application/x-www-form-urlencoded`. An additional `syntax=rfc3986_ampersand` **MAY** split on `&` and `=` **without** `+` → space, for non-HTML protocols.

## Robustness

- Maximum number of tuples **MUST** be configurable (default: 4096). Exceeding the limit **MUST** fail; it **MUST NOT** truncate silently.
- Maximum name/value length **MUST** share the global input cap.
- Nested encodings (`%26`, `%3D`) **MUST** remain data, not extra separators, because split happens before percent-decode.
