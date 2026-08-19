# Phase 08 — Public API

**Depends on:** 06, 07  
**Unlocks:** 09

## Goal

A single import surface matching [`specs/09-api.md`](../specs/09-api.md): `parse_url` / `try_parse_url` / `parse_uri` / `try_parse_uri` / `parse(options)`. Wire `Url.query_list()` to phase 02. No profile guessing.

## Specs to read

- [`specs/09-api.md`](../specs/09-api.md) (entire file)
- [`specs/00-overview.md`](../specs/00-overview.md) — convenience defaults
- [`specs/08-error-handling.md`](../specs/08-error-handling.md) — try vs raise

## Modify

```text
src/heat_url/__init__.mojo    # re-exports
src/heat_url/parse.mojo       # thin wrappers (new)
test/test_api.mojo            # new
```

## Implement

| Function | Profile | Failure |
| --- | --- | --- |
| `parse_url` / `Url` constructor analogue | whatwg | raises `ParseError` |
| `try_parse_url` | whatwg | `Optional[Url]` empty |
| `parse_uri` | rfc3986 | raises `ParseError` |
| `try_parse_uri` | rfc3986 | `Optional[Uri]` empty |
| `parse(input, options)` | `options.profile` | raises; variant `Url` or `Uri` |

`parse_url` should still expose validation errors: either a side channel on `Url` (`var validation_errors: List[ValidationError]`) or `parse_url_detailed` returning `UrlParseResult`. Pick one, document it in `specs/09-api.md` if you add a name, keep `try_parse_url` as success/failure only.

`Url.serialize(exclude_fragment=False)` and `Uri.serialize()` call the profile serializers.

`Url.query_list()` parses opaque query with `QueryList.parse(form=True)`; missing query → empty list.

WHATWG setters (`protocol`, `pathname`, …) are **optional** (spec: may defer to v1.1). If skipped, note in `STATUS.md`. Parse/serialize/query/IDNA remain required.

Do **not** add `parse_magic`.

## Tests (minimum)

- Same input `https:example.org` differs between `parse_url` and `parse_uri`
- `try_parse_url` on failure returns empty, does not raise
- `parse(..., ParseOptions.rfc3986())` vs `.whatwg()`
- `query_list()` on `https://example.test/?a=b&a=c`
- Error path for `https://user:secret@x/` WHATWG success does not include `secret` in `ParseError.message` / printed `ValidationError` (credentials are valid-but-flagged)

## Acceptance

- `from heat_url import parse_url, parse_uri, percent, query, host, idna` works (submodules may be the packages/files)
- `pixi run test` green
- Doc comments on public functions cite the spec clause

## Out of scope

WPT vendor, packaging to conda, HTTP client.
