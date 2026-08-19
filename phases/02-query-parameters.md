# Phase 02 — Query parameters

**Depends on:** 01  
**Unlocks:** 07, 08

## Goal

Ship `heat_url.query.QueryList`: ordered name/value tuples with WHATWG `application/x-www-form-urlencoded` parse/serialize, plus an RFC-style split that does not treat `+` as space.

## Specs to read

- [`specs/05-query-parameters.md`](../specs/05-query-parameters.md) (entire file)
- [`specs/09-api.md`](../specs/09-api.md) — Query module
- WHATWG URL Standard §5 and §6.2 (`URLSearchParams` list operations)
- [`specs/08-error-handling.md`](../specs/08-error-handling.md) — query tuple cap (`DEFAULT_MAX_QUERY_TUPLES`)

## Create

```text
src/heat_url/query.mojo
test/test_query.mojo
```

Use `heat_url.percent` for percent-decode and form-urlencoded encode. Split on `&` **before** percent-decode so `%26` / `%3D` stay data.

## Implement

```text
struct QueryList:
    parse(input, *, form=True, max_tuples=DEFAULT_MAX_QUERY_TUPLES) raises
    serialize(self) -> String
    get / get_all / has / append / set / delete / sort / __len__
```

- `form=True`: WHATWG §5.1 (`+` → space, UTF-8 decode without BOM)
- `form=False`: split `&` / first `=`, no plus-decoding
- Do **not** split on `;` unless you add an explicit off-by-default flag as in the spec
- `set`: replace first matching name, drop later matches, append if none
- `sort`: **UTF-16 code unit** order (web-platform-tests). Document a pair of names that would differ in UTF-8 if you add a comment in the test file
- Exceeding `max_tuples` → `ParseError` kind `too_many_query_tuples` (do not truncate)

Empty query / missing `=` / empty name (`=v`) per spec 05.

## Tests (minimum)

- `a=b&a=c`: `get` → `b`, `get_all` → `[b, c]`, `len` → 2
- `=v`, `k=`, `k`, skipped empty `&` segments
- `%26` and `%3D` are not extra separators
- serialize uses `+` for spaces and the form-urlencoded encode set
- tuple cap failure
- `form=False` keeps `+` as plus

## Acceptance

- `pixi run test` green
- Query serialize vs URL serializer encode-set mismatch is **not** “fixed”; it is specified (spec 05)

## Out of scope

`Url.searchParams` write-through (phase 07/08). Host/IDNA. RFC 3986 URI parser.
