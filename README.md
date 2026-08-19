# heat-url

A Mojo library of standardized, robust URI/URL parsing utilities. It is specified to handle percent-encoding, query parameters, and internationalized domain names natively.

This repository is **specification-first**. The Pixi/Mojo project is initialized; library source is not present yet. Implement against the documents in [`specs/`](specs/), not against ad-hoc URL folklore.

## Status

| Item | State |
| --- | --- |
| Pixi workspace + Mojo 1.0 toolchain | Ready |
| Specifications | Ready (`specs/`) |
| Agent instructions | Ready (`AGENTS.md`) |
| Library implementation | Not started (intentionally) |

## Specifications

Start at [`specs/README.md`](specs/README.md). The library defines two parse profiles:

- **RFC 3986 / RFC 3987** — strict URI/IRI for protocols, validators, and generic identifiers
- **WHATWG URL Standard** — web-interoperable parsing, serialization, and form-urlencoded queries

Internationalized domain names are first-class: Unicode IDNA Compatibility Processing ([UTS #46](https://www.unicode.org/reports/tr46/)) with Punycode ([RFC 3492](https://www.rfc-editor.org/rfc/rfc3492)), implemented in Mojo rather than delegated to Python or the OS.

## Development environment

Requires [Pixi](https://pixi.sh/) and a C linker (`gcc` on Linux).

```bash
pixi install
pixi run mojo-version
```

See [`AGENTS.md`](AGENTS.md) for project conventions, intended package layout, and how to implement from the specs.
