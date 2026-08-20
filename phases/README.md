# Implementation phases

These files are the original execution plan for **heat-url**. Specs in
[`specs/`](../specs/README.md) stay normative. Every phase in [`STATUS.md`](STATUS.md)
is `done`. Do not re-run the plan from scratch; change the library against the
specs instead.

## How this was built

1. Read [`AGENTS.md`](../AGENTS.md) and this file.
2. Open [`STATUS.md`](STATUS.md). Take the first phase whose status is `todo`.
3. Read that phase file completely. Read every spec it lists.
4. Implement **only** that phase.
5. Run `pixi run test` and any extra commands in the phase.
6. Run `pixi run fmt` on edited `.mojo` files.
7. Set the phase to `done` in `STATUS.md`.
8. Commit. Stop unless asked to continue.

That sequence is historical. Keep it here so later readers can see how the
tree was assembled.

## Rules that still apply

- No Python in `src/heat_url` (table *generators* under `tools/` are allowed).
- No `parse_magic` / profile guessing.
- No `fn` keyword (Mojo 1.0: `def` only).
- Tests: `test/test_*.mojo` + `TestSuite.discover_tests[__functions_in_module()]().run()`.
  Never `mojo test`.
- Import the package with `mojo run -I src` (or from the installed `.mojoc`).
- Public functions: comment states the spec clause they implement.
- If code must diverge from `specs/`, edit the spec in the same change.

## Phase map

| Phase | Builds on | Ships |
| --- | --- | --- |
| [00 Bootstrap](00-bootstrap.md) | | Package, errors, options, test runner |
| [01 Percent-encoding](01-percent-encoding.md) | 00 | `heat_url.percent` |
| [02 Query parameters](02-query-parameters.md) | 01 | `heat_url.query` |
| [03 Punycode](03-punycode.md) | 00 | `heat_url.punycode` |
| [04 IDNA / UTS #46](04-idna.md) | 03 | `heat_url.idna` + mapping tables |
| [05 Hosts](05-hosts.md) | 01, 04 | `heat_url.host` |
| [06 RFC 3986 URI](06-rfc3986.md) | 01, 05 | `heat_url.rfc3986` |
| [07 WHATWG URL](07-whatwg.md) | 01, 02, 05 | `heat_url.whatwg` |
| [08 Public API](08-public-api.md) | 06, 07 | `parse_url` / `parse_uri` re-exports |
| [09 Conformance](09-conformance.md) | 08 | Vendored WPT / IDNATestV2 / skip lists |

```text
00 → 01 → 02 ──────────────┐
00 → 03 → 04 → 05 → 06 ──→ 08 → 09
                 └→ 07 ──┘
```
