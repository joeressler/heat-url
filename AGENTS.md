# AGENTS.md

Instructions for coding agents working on **heat-url** (`github.com/joeressler/heat-url`).

## What this repository is

A **Mojo 1.0 library** of standardized, robust URI/URL utilities: parse/serialize, percent-encoding, query parameters, and **native** IDNA (UTS #46 + Punycode in Mojo, not Python).

Two parse profiles are mandatory and must never be mixed in one call:

| Profile | When to use | Spec |
| --- | --- | --- |
| `whatwg` | Web / HTTP user input / HTML forms | [WHATWG URL Standard](https://url.spec.whatwg.org/) |
| `rfc3986` | Generic URI / IRI / protocol identifiers | [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986) + [RFC 3987](https://www.rfc-editor.org/rfc/rfc3987) |

**Normative behavior:** [`specs/README.md`](specs/README.md).  
**How to implement:** [`phases/README.md`](phases/README.md) and [`phases/STATUS.md`](phases/STATUS.md).

Do not invent URL behavior from `urllib`, Go `net/url`, or “common sense”.

## Start here (implementation)

1. Read this file and [`phases/README.md`](phases/README.md).
2. Open [`phases/STATUS.md`](phases/STATUS.md). Implement the first phase with status `todo`.
3. Read that phase file fully and every spec it lists.
4. Change only what that phase allows. Keep `pixi run test` green.
5. `pixi run fmt` on edited `.mojo` files.
6. Mark the phase `done` in `STATUS.md`. Commit. Stop unless the user asked you to continue.

Phase 00 (bootstrap) is **done**. Next is **phase 01** (percent-encoding).

If the user names a phase, do that phase only after its dependencies are `done`. If they say “implement the library” with no phase, walk `todo` rows in order, one commit per phase.

## Toolchain

- Package manager: **Pixi** (not Magic).
- Channel: **stable** Modular (`https://conda.modular.com/max`) + `conda-forge`.
- Compiler: `mojo` 1.0.x. Linker: `gcc` (or equivalent) on Linux.

```bash
pixi install
pixi run mojo-version
pixi run test
pixi run fmt
```

Never pin a mismatched MAX/Mojo pair. This repo is Mojo-only. Do not hand-edit `pixi.lock`.

## Layout

```text
pixi.toml
src/heat_url/           # import path heat_url
test/test_*.mojo        # TestSuite files
test/data/              # golden fixtures (phase 09)
phases/                 # guided implementation plan
specs/                  # normative behavior
scripts/run-tests.sh
AGENTS.md
README.md
```

Run a single file: `pixi run mojo run -I src test/test_percent.mojo`.

Each test module:

```mojo
from std.testing import assert_equal, TestSuite

def test_example() raises:
    assert_equal(1, 1)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
```

Do **not** use `mojo test` (removed).

## Mojo syntax (1.0)

Use Modular [`mojo-syntax`](https://github.com/modular/skills/tree/main/mojo-syntax) (`npx skills add modular/skills`). Highlights:

- **No `fn`:** use `def` only.
- Imports: `from std.testing import …` — not `from testing import`.
- `raises` before `->`: `def parse(s: String) raises -> Url:`.
- Compile-time: `comptime`, not `alias`.
- Origins: `out` / `mut` / `var` / `ref` / `deinit`.
- Struct parameters: `Self.T`, not bare `T`.
- Non-`ImplicitlyCopyable`: `.copy()` or `^`.
- Lists: `[1, 2, 3]`, not `List[Int](1, 2, 3)`.
- Strings: `s[byte=i]` / `s[byte=start:end]`; `s.find`, `"x" in s`.
- Interpolation: `t"x={x}"`.

## Implementation rules

1. **Specs first.** API and errors: `specs/09-api.md`, `specs/08-error-handling.md`. Language rules: RFC or WHATWG for the active profile.
2. **Native IDNA.** Punycode + UTS #46 in Mojo. No `from std.python import Python` in `src/heat_url`. Generators may live under `tools/`.
3. **No profile guessing.** `parse_url` → WHATWG; `parse_uri` → RFC 3986.
4. **Robustness.** No panics on untrusted input. Enforce size limits. Linear-time parsers. Error text must not include userinfo/passwords (`redact_userinfo` already exists).
5. **WHATWG validation errors ≠ failure** unless `strict_whatwg`.
6. **No urllib oracle.** Use WPT, RFC examples, IDNATestV2 (`specs/10-conformance.md`).
7. **Keep specs true.** Divergences update `specs/` in the same change.
8. **No extra scope.** No HTTP client, DNS, HTML parser, URI templates, or required PSL.

## Commands

| Task | Command |
| --- | --- |
| Install env | `pixi install` |
| Compiler version | `pixi run mojo-version` |
| All tests | `pixi run test` |
| Format | `pixi run fmt` |
| Run one file | `pixi run mojo run -I src path/to/file.mojo` |

## Docs map

| Path | Audience |
| --- | --- |
| [`README.md`](README.md) | Humans: what/why/status |
| [`specs/`](specs/README.md) | Normative library behavior |
| [`phases/`](phases/README.md) | Ordered implementation work |
| [`AGENTS.md`](AGENTS.md) | Agents: how to work in this repo |
| [`pixi.toml`](pixi.toml) | Dependencies and tasks |

## Upstream references

- WHATWG URL (living standard; re-read at implement time)
- RFC 3986, 3987, 3492, 5890–5894, 6874, 5952
- UTS #46
- Modular: [Get started](https://docs.modular.com/mojo/manual/get-started/), [Testing](https://docs.modular.com/mojo/tools/testing/), [Packaging](https://docs.modular.com/mojo/tools/packaging/), [skills](https://github.com/modular/skills)
