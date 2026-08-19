# Implementation phases

Agents implement **heat-url** one phase at a time. Specs in [`specs/`](../specs/README.md) are normative. These files are the **execution plan**.

## How to pick up work

1. Read [`AGENTS.md`](../AGENTS.md) and this file.
2. Open [`STATUS.md`](STATUS.md). Take the first phase whose status is `todo`.
3. Read that phase file completely. Read every spec it lists.
4. Implement **only** that phase. Do not start the next parser, IDNA tables, or WPT runner “while you are here”.
5. Run `pixi run test` and any extra commands in the phase. All existing tests must stay green.
6. Run `pixi run fmt` on edited `.mojo` files.
7. Set the phase to `done` in `STATUS.md`. Add a one-line note if you deferred a listed item (must still meet the phase’s **Acceptance**).
8. Commit. Stop unless the user asked you to continue to the next phase.

If the user names a phase (`implement phase 4`), do that phase only, after confirming earlier phases are `done`.

If the user says “implement the library” with no phase, walk the `todo` list in order, committing after each phase.

## Rules that apply to every phase

- No Python in `src/heat_url` (table *generators* under `tools/` are allowed).
- No `parse_magic` / profile guessing.
- No `fn` keyword (Mojo 1.0: `def` only).
- Tests: `test/test_*.mojo` + `TestSuite.discover_tests[__functions_in_module()]().run()`. Never `mojo test`.
- Import the package with `mojo run -I src`.
- Public functions: comment states the spec clause they implement.
- If code must diverge from `specs/`, edit the spec in the same change.

## Phase map

| Phase | Builds on | Ships |
| --- | --- | --- |
| [00 Bootstrap](00-bootstrap.md) | — | Package, errors, options, test runner |
| [01 Percent-encoding](01-percent-encoding.md) | 00 | `heat_url.percent` |
| [02 Query parameters](02-query-parameters.md) | 01 | `heat_url.query` |
| [03 Punycode](03-punycode.md) | 00 | `heat_url.punycode` |
| [04 IDNA / UTS #46](04-idna.md) | 03 | `heat_url.idna` + mapping tables |
| [05 Hosts](05-hosts.md) | 01, 04 | `heat_url.host` |
| [06 RFC 3986 URI](06-rfc3986.md) | 01, 05 | `heat_url.rfc3986` |
| [07 WHATWG URL](07-whatwg.md) | 01, 02, 05 | `heat_url.whatwg` |
| [08 Public API](08-public-api.md) | 06, 07 | `parse_url` / `parse_uri` re-exports |
| [09 Conformance](09-conformance.md) | 08 | Vendored WPT / IDNATestV2 / skip lists |

Dependency graph (do not invert):

```text
00 → 01 → 02 ──────────────┐
00 → 03 → 04 → 05 → 06 ──→ 08 → 09
                 └→ 07 ──┘
```

Phases 02 and 03 may run in parallel after 01 and 00 respectively, but a single agent should still finish one file before starting another unless the user asked for parallel work.
