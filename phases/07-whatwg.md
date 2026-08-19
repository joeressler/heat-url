# Phase 07 — WHATWG URL

**Depends on:** 01, 02, 05  
**Unlocks:** 08

## Goal

Implement the WHATWG **basic URL parser** and **serializer**, plus validation-error recording. This is the web profile. Do not call RFC 3986 §5.

## Specs to read

- [`specs/02-data-model.md`](../specs/02-data-model.md) — `Url` record, special schemes
- [`specs/03-parsing.md`](../specs/03-parsing.md) — `whatwg` profile
- [`specs/07-serialization-and-resolution.md`](../specs/07-serialization-and-resolution.md) — WHATWG serializer, origin optional
- [`specs/08-error-handling.md`](../specs/08-error-handling.md) — validation errors vs failure
- WHATWG URL Standard §4.4 (parser states), §4.5 (serialize), §1.1 (validation error table)
- Percent-encode sets from phase 01; query list from phase 02 for `query_list()` helper on `Url` if convenient (write-through can wait for phase 08)

## Create

```text
src/heat_url/whatwg.mojo
test/test_whatwg.mojo
```

Define `Url` here (or `src/heat_url/url.mojo`). Return type for parse: `Url` plus `List[ValidationError]`. Suggested:

```text
struct UrlParseResult:
    var url: Url
    var validation_errors: List[ValidationError]
```

`strict_whatwg` on `ParseOptions`: any validation error → `ParseError`. Default off.

## Implement

Walk the spec states. Required behaviors from spec 03 (all mandatory): special schemes and default ports; `\` as separator on special URLs; `file:` drive-letter / localhost quirks; host parser via phase 05; 16-bit port; `.` / `..` / `%2e` path compression; query encode set vs special-query (`'` extra); parse→serialize→parse identity.

Failure vs validation error: only table rows marked Failure abort.

Path segment count cap. Input length cap. Redact userinfo in error **messages** (invalid-credentials still **succeeds** as a validation error).

`blob URL entry` stays null (out of scope).

## Tests (minimum)

Use the examples table in WHATWG §4 / spec 02–03:

- `https:example.org` → `https://example.org/` (no base)
- backslash paths on `https`
- `file:///C|/demo` → `file:///C:/demo`
- `https://user:password@example.org/` succeeds; records `invalid-credentials`; serialized message tests must not contain the password
- `https://ex ample.org/` failure
- `https://example.com:demo` failure
- `git://github.com/whatwg/url.git` opaque host
- `https://EXAMPLE.com/../x` → `https://example.com/x`
- long `a/../` chain does not stack-overflow

Hand-translate a **small** subset of `urltestdata.json`; do not vendor the full file until phase 09.

## Acceptance

- `pixi run test` green
- Serializer omits default ports for special schemes
- No RFC 3986 relative-resolution function used on WHATWG records

## Out of scope

Full WPT dump, URL setters (optional v1.1 per spec 09), Public Suffix List.
