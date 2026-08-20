# heat-url

Mojo library for parsing URIs and URLs. Use `parse_url` when you want the
[WHATWG URL Standard](https://url.spec.whatwg.org/) (browsers, HTML forms, HTTP
user input). Use `parse_uri` when you want [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986)
(and [RFC 3987](https://www.rfc-editor.org/rfc/rfc3987) if you turn IRI on).

The two profiles are separate on purpose. They disagree on inputs like
`https:example.org`, so the library will not guess which one you meant.

Percent-encoding, query lists, and IDNA (UTS #46 plus Punycode, Unicode 17.0.0)
are implemented in Mojo. The `heat_url` package does not import Python.

## Install

From this repo:

```bash
pixi install
pixi run test
pixi run mojo run -I src examples/basic.mojo
```

`conda.recipe/` is a [rattler-build](https://docs.modular.com/mojo/tools/packaging/)
recipe. It precompiles `src/heat_url` to `lib/mojo/heat_url.mojoc`. To publish
on [modular-community](https://prefix.dev/channels/modular-community), copy that
recipe into a PR there and point `source` at a git commit SHA. After it is on
the channel:

```toml
[workspace]
channels = [
    "https://conda.modular.com/max",
    "conda-forge",
    "https://repo.prefix.dev/modular-community",
]

[dependencies]
mojo = ">=1.0.0,<2"
heat-url = ">=1.0.0,<2"
```

Then `from heat_url import parse_url` with no extra `-I`.

## Usage

```mojo
from heat_url import parse_url, parse_uri, try_parse_url, to_ascii

def main() raises:
    # WHATWG recovers https:example.org into an https origin.
    var url = parse_url("https:example.org")
    print(url.serialize())  # https://example.org/

    var page = parse_url("/search?q=1", "https://example.org/old")
    print(page.serialize())  # https://example.org/search?q=1

    # RFC 3986 keeps a scheme-only relative-ish split.
    var uri = parse_uri("https:example.org")
    print(uri.serialize())  # https:example.org

    if try_parse_url("https://ex ample.org/") is None:
        print("invalid")

    print(to_ascii("faß.example"))  # xn--fa-hia.example
```

`parse_url` / `parse_uri` raise `ParseError` on failure. The `try_*` helpers
return an empty `Optional` instead. WHATWG validation errors (for example
`invalid-credentials`) do not fail the parse unless you set
`ParseOptions.strict_whatwg`. Call `parse_url_detailed` if you need that list.

Error text is stripped of userinfo so a password in the input does not show up
in the message.

## What 1.0 covers

| Area | Entry points |
| --- | --- |
| WHATWG parse / serialize | `parse_url`, `try_parse_url`, `parse_url_detailed`, `Url` |
| RFC 3986 URI-reference | `parse_uri`, `try_parse_uri`, `Uri` (relative resolution in RFC §5) |
| Either profile | `parse(input, ParseOptions)` |
| Percent-encoding | `encode`, `decode_*`, `EncodeSet` |
| Query | `QueryList` (form-urlencoded or raw `&` / `=` split) |
| Hosts | `parse_host_whatwg`, `parse_host_rfc3986`, `serialize_host` |
| IDNA | `to_ascii`, `to_unicode`, `punycode_encode`, `punycode_decode` |

Not in 1.0: WHATWG setters, `origin()`, an HTTP client, DNS, an HTML parser,
URI templates, or the Public Suffix List.

Behavior is specified in [`specs/`](specs/README.md). Tests include WPT
`urltestdata.json` (href and getters, not `origin` or setters) and Unicode
IDNATestV2 non-transitional columns. Fixture sources are recorded in
[`test/data/README.md`](test/data/README.md).

## Development

Needs [Pixi](https://pixi.sh/) and a C linker (`gcc` on Linux).

```bash
pixi install
pixi run mojo --version
pixi run test
pixi run fmt
pixi run mojo run -I src test/test_percent.mojo
```

Do not use `mojo test`; it was removed. Each file under `test/test_*.mojo` is a
`TestSuite`. EmberJson is a **test** dependency for the WPT JSON fixtures. Keep
it out of `src/heat_url`.

IDNA mapping tables come from Unicode 17.0.0. To regenerate them:

```bash
python3 tools/generate_idna_tables.py
```

More contributor notes: [`CONTRIBUTING.md`](CONTRIBUTING.md). Coding agents:
[`AGENTS.md`](AGENTS.md).

## License

Apache License 2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
