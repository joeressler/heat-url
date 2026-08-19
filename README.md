# heat-url

A Mojo library of standardized, robust URI/URL parsing utilities. It handles percent-encoding, query parameters, and internationalized domain names natively.

Implement against [`specs/`](specs/), following the agent phases in [`phases/`](phases/README.md).

## Status

| Item | State |
| --- | --- |
| Pixi workspace + Mojo 1.0 toolchain | Ready |
| Specifications | Ready (`specs/`) |
| Implementation phases | Ready (`phases/`) |
| Bootstrap package (`ParseProfile`, errors, options) | Done (phase 00) |
| Percent / query / IDNA / parsers | Not started (phases 01–09) |

## Specifications

Start at [`specs/README.md`](specs/README.md). Two parse profiles:

- **RFC 3986 / RFC 3987** — strict URI/IRI for protocols, validators, and generic identifiers
- **WHATWG URL Standard** — web-interoperable parsing, serialization, and form-urlencoded queries

IDNA is first-class: UTS #46 + Punycode in Mojo (not Python or the OS).

## Development

Requires [Pixi](https://pixi.sh/) and a C linker (`gcc` on Linux).

```bash
pixi install
pixi run mojo-version
pixi run test
pixi run fmt
```

Agents: read [`AGENTS.md`](AGENTS.md), then take the next `todo` row in [`phases/STATUS.md`](phases/STATUS.md).
