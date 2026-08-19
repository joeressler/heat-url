# AGENTS.md

Instructions for coding agents working on **heat-url** (`github.com/joeressler/heat-url`).

## What this repository is

A **Mojo 1.0 library** of standardized, robust URI/URL utilities: parse/serialize, percent-encoding, query parameters, and **native** IDNA (UTS #46 + Punycode in Mojo, not Python).

Two parse profiles are mandatory and must never be mixed in one call:

| Profile | When to use | Spec |
| --- | --- | --- |
| `whatwg` | Web / HTTP user input / HTML forms | [WHATWG URL Standard](https://url.spec.whatwg.org/) |
| `rfc3986` | Generic URI / IRI / protocol identifiers | [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986) + [RFC 3987](https://www.rfc-editor.org/rfc/rfc3987) |

**Normative project documents:** [`specs/README.md`](specs/README.md) and the numbered files in `specs/`. Implement those documents. Do not invent URL behavior from `urllib`, Go `net/url`, or “common sense”.

## Current freeze

This revision is **specification-only**. The Pixi project and Mojo toolchain are initialized. **Do not add `.mojo` sources, tests, or sample programs unless the user explicitly asks to implement the library.** Do not “helpfully” scaffold `src/heat_url` or a hello-world `main`.

When implementation is requested, follow `specs/` and the layout in `specs/00-overview.md`. Cite the spec section in public doc comments.

## Toolchain

- Package manager: **Pixi** (not Magic; Magic is unsupported).
- Channel: **stable** Modular (`https://conda.modular.com/max`) + `conda-forge`.
- Compiler: `mojo` from the `mojo` conda package (workspace uses Mojo 1.0.x).
- Linker: a C toolchain (`gcc` on Linux) is required to compile Mojo.

```bash
pixi install
pixi run mojo-version          # → mojo --version
pixi run mojo --help
```

Never pin a mismatched MAX/Mojo pair. This repo is Mojo-only (`pixi add mojo`); do not add `max` unless the user asks.

After changing `pixi.toml`, let Pixi refresh `pixi.lock`. Do not hand-edit the lockfile.

## Intended layout (implementation phase)

```text
pixi.toml
pixi.lock
src/heat_url/           # import path heat_url; __init__.mojo required
test/                   # TestSuite files, plus test/data/ fixtures
specs/                  # already present; keep in sync with code
AGENTS.md
README.md
```

Match Modular packaging: sources under `src/<package>/` with `__init__.mojo` so `mojo precompile` can emit `$PREFIX/lib/mojo/heat_url.mojoc` later.

Run tests (once they exist):

```bash
pixi run mojo run -I src test/test_percent.mojo
```

Each test module needs `test_*` functions and:

```mojo
from std.testing import TestSuite

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
```

Do **not** use `mojo test` (removed). Assertions: `std.testing` (`assert_equal`, `assert_true`, `assert_raises`, …).

## Mojo syntax (1.0) — avoid pretrained mistakes

Install/use Modular skills when writing Mojo: [`mojo-syntax`](https://github.com/modular/skills/tree/main/mojo-syntax) (`npx skills add modular/skills`). Highlights:

- Imports: `from std.testing import …`, `import std.random` — not `from testing import`.
- `raises` goes **before** `->`: `def parse(s: String) raises -> Url:`.
- Compile-time: `comptime`, not `alias`.
- Origins: `out` / `mut` / `var` / `ref` / `deinit`. Copy ctor is `__init__(out self, *, copy: Self)`; move is `__init__(out self, *, deinit move: Self)`.
- Struct parameters: use `Self.T`, not bare `T`.
- Non-`ImplicitlyCopyable` values: `.copy()` or `^` transfer — no implicit copy.
- Lists: `[1, 2, 3]`, not `List[Int](1, 2, 3)`.
- Strings: `s[byte=i]`, not `s[i]`; iterate `s.codepoint_slices()` / `s.codepoints()`.
- Interpolation: `t"x={x}"`.
- Functions that fail: `raises`; `main` usually `raises`.

## Implementation rules (when unfrozen)

1. **Read `specs/` first.** API names and error policy live in `specs/09-api.md` and `specs/08-error-handling.md`. Language rules live in the cited RFC/WHATWG for the active profile.
2. **Native IDNA.** Punycode (RFC 3492) + UTS #46 tables in Mojo. No `from std.python import Python` in core parse/IDNA. A Python *generator* for Unicode tables is OK; runtime is not.
3. **No profile guessing.** No `parse_magic`. `parse_url` → WHATWG; `parse_uri` → RFC 3986.
4. **Robustness.** No panics on untrusted input. Enforce size limits. Linear-time parsers. Error messages must not include userinfo/passwords.
5. **WHATWG validation errors ≠ failure.** Record them; only spec “Failure” rows abort. Optional `strict_whatwg` may promote them.
6. **Do not use Python urllib as an oracle.** Use WPT `urltestdata.json`, RFC examples, Unicode IDNATestV2 (`specs/10-conformance.md`).
7. **Keep specs true.** If code must diverge (Mojo limitation), update `specs/` in the same change and document the deviation. Do not silently diverge.
8. **No extra product scope.** No HTTP client, DNS, HTML parser, URI templates, or PSL requirement in v1.

## Commands agents should prefer

| Task | Command |
| --- | --- |
| Install env | `pixi install` |
| Compiler version | `pixi run mojo-version` |
| Run a file | `pixi run mojo run path/to/file.mojo` |
| Build a binary | `pixi run mojo build path/to/file.mojo` |
| Format (if available) | `pixi run mojo format` on edited `.mojo` files |

## Docs map

| Path | Audience |
| --- | --- |
| [`README.md`](README.md) | Humans: what/why/status |
| [`specs/`](specs/README.md) | Normative library behavior |
| [`AGENTS.md`](AGENTS.md) | Agents: how to work in this repo |
| [`pixi.toml`](pixi.toml) | Dependencies and tasks |

## Upstream references (pinned in specs)

- WHATWG URL (living standard; re-read at implement time)
- RFC 3986, 3987, 3492, 5890–5894, 6874, 5952
- UTS #46
- Modular: [Get started](https://docs.modular.com/mojo/manual/get-started/), [Testing](https://docs.modular.com/mojo/tools/testing/), [Packaging](https://docs.modular.com/mojo/tools/packaging/), [skills](https://github.com/modular/skills)
