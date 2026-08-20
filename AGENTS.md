# AGENTS.md

How to work on **heat-url** (`github.com/joeressler/heat-url`).

This is a Mojo 1.0 library. Import path: `heat_url`. Package name: `heat-url`.
v1 parse and serialize are implemented. Specs in [`specs/`](specs/README.md)
are normative. [`phases/`](phases/README.md) is the original build plan; every
phase is `done`.

Two parse profiles. Never mix them in one call:

| Profile | When to use | Spec |
| --- | --- | --- |
| `whatwg` | Web / HTTP user input / HTML forms | [WHATWG URL Standard](https://url.spec.whatwg.org/) |
| `rfc3986` | Generic URI / IRI / protocol identifiers | [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986) + [RFC 3987](https://www.rfc-editor.org/rfc/rfc3987) |

Do not invent URL behavior from `urllib`, Go `net/url`, or "common sense".

## Toolchain

- Package manager: Pixi (not Magic).
- Channels: stable Modular (`https://conda.modular.com/max`), conda-forge, and
  `https://repo.prefix.dev/modular-community` (EmberJson for tests).
- Compiler: `mojo` 1.0.x. Linker: `gcc` (or equivalent) on Linux.

```bash
pixi install
pixi run mojo --version
pixi run test
pixi run fmt
```

Never pin a mismatched MAX/Mojo pair. This repo is Mojo-only. Do not hand-edit
`pixi.lock`.

## Layout

```text
pixi.toml
src/heat_url/        # import path heat_url
test/test_*.mojo     # TestSuite files
test/data/           # WPT / IDNATestV2 fixtures
examples/
conda.recipe/        # rattler-build package
phases/              # completed implementation plan
specs/               # normative behavior
scripts/run-tests.sh
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

Use Modular [`mojo-syntax`](https://github.com/modular/skills/tree/main/mojo-syntax)
(`npx skills add modular/skills`). Highlights:

- **No `fn`:** use `def` only.
- Imports: `from std.testing import …`, not `from testing import`.
- `raises` before `->`: `def parse(s: String) raises -> Url:`.
- Compile-time: `comptime`, not `alias`.
- Origins: `out` / `mut` / `var` / `ref` / `deinit`.
- Struct parameters: `Self.T`, not bare `T`.
- Non-`ImplicitlyCopyable`: `.copy()` or `^`.
- Lists: `[1, 2, 3]`, not `List[Int](1, 2, 3)`.
- Strings: `s[byte=i]` / `s[byte=start:end]`; `s.find`, `"x" in s`.
- Interpolation: `t"x={x}"`.

## Implementation rules

1. **Specs first.** API and errors: `specs/09-api.md`, `specs/08-error-handling.md`.
   Language rules: RFC or WHATWG for the active profile.
2. **Native IDNA.** Punycode + UTS #46 in Mojo. No `from std.python import Python`
   in `src/heat_url`. Generators may live under `tools/`.
3. **No profile guessing.** `parse_url` is WHATWG; `parse_uri` is RFC 3986.
4. **Robustness.** No panics on untrusted input. Enforce size limits.
   Linear-time parsers. Error text must not include userinfo/passwords
   (`redact_userinfo` already exists).
5. **WHATWG validation errors ≠ failure** unless `strict_whatwg`.
6. **No urllib oracle.** Use WPT, RFC examples, IDNATestV2
   (`specs/10-conformance.md`).
7. **Keep specs true.** Divergences update `specs/` in the same change.
8. **No extra scope.** No HTTP client, DNS, HTML parser, URI templates, or
   required PSL. Setters and `origin()` are 1.1.

EmberJson (`from emberjson import parse`) is tests-only. Do not import it from
`src/heat_url`. The conda package must not depend on it.

## Commands

| Task | Command |
| --- | --- |
| Install env | `pixi install` |
| Compiler version | `pixi run mojo --version` |
| All tests | `pixi run test` |
| Format | `pixi run fmt` |
| Run one file | `pixi run mojo run -I src path/to/file.mojo` |
| Example | `pixi run mojo run -I src examples/basic.mojo` |

## Docs map

| Path | Audience |
| --- | --- |
| [`README.md`](README.md) | Humans: install, usage, status |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Humans: how to patch this repo |
| [`specs/`](specs/README.md) | Normative library behavior |
| [`phases/`](phases/README.md) | Historical implementation plan |
| [`AGENTS.md`](AGENTS.md) | Agents: how to work in this repo |
| [`pixi.toml`](pixi.toml) | Dependencies and tasks |
| [`conda.recipe/`](conda.recipe/) | conda / modular-community package |

## Upstream references

- WHATWG URL (living standard; re-read at implement time)
- RFC 3986, 3987, 3492, 5890–5894, 6874, 5952
- UTS #46
- Modular: [Get started](https://docs.modular.com/mojo/manual/get-started/),
  [Testing](https://docs.modular.com/mojo/tools/testing/),
  [Packaging](https://docs.modular.com/mojo/tools/packaging/),
  [skills](https://github.com/modular/skills)
