# 00 — Overview and principles

## Product

`heat-url` is a **pure Mojo library** for parsing, serializing, normalizing, and mutating Uniform Resource Identifiers and URLs. Callers get:

1. Standards-accurate component access (scheme, userinfo, host, port, path, query, fragment).
2. Percent-encoding and percent-decoding with explicit encode sets.
3. Query-string utilities, including WHATWG `application/x-www-form-urlencoded`.
4. Native internationalized domain name (IDN) processing (Punycode + UTS #46), with no Python, libc IDN, or OS resolver dependency in the core crate.

The conda / Pixi package name is `heat-url`. The Mojo import package name is `heat_url`.

## Why two profiles

URI/URL “correctness” is not a single algorithm:

- [RFC 3986](https://www.rfc-editor.org/rfc/rfc3986) defines a generic syntax and a strict grammar. Many internet protocols (and validators) expect this.
- The [WHATWG URL Standard](https://url.spec.whatwg.org/) defines the algorithm browsers actually run. It recovers from many “illegal” inputs, lowercases special-scheme hosts, treats `\` as `/` on special URLs, maps `https:example.org` depending on a base URL, and so on.
- [RFC 3987](https://www.rfc-editor.org/rfc/rfc3987) defines IRIs (Unicode in components other than scheme). The web platform folded IRI handling into the WHATWG parser plus IDNA.

Shipping only one of these would make the library either unusable on the web or incorrect for protocol work. `heat-url` therefore exposes **named parse profiles**. Mixing rules from both in a single call is forbidden.

## Parse profiles

| Profile identifier | Default for | Grammar / algorithm | Unicode hosts |
| --- | --- | --- | --- |
| `rfc3986` | Generic URI APIs (`parse_uri`, `Uri`) | RFC 3986 ABNF; relative resolution §5; optional IRI input via RFC 3987 | IDNA applied **only** when the caller requests host conversion (ToASCII / ToUnicode), not as a silent parse side effect |
| `whatwg` | Web URL APIs (`parse_url`, `Url`) | WHATWG basic URL parser, serializer, host parser | IDNA via UTS #46 as specified by WHATWG §3.3 |

A call **MUST** select a profile. Convenience wrappers **MAY** default:

- `parse_uri` → `rfc3986`
- `parse_url` → `whatwg`

There is **no** implicit “best effort” profile that tries WHATWG after RFC failure.

## Design principles

1. **Spec over folklore.** Behavior comes from the cited standard for the active profile, not from Python `urllib`, Go `net/url`, or Java `URI` unless this specification explicitly aligns with them.
2. **Native.** Percent-encoding, query parsing, Punycode, and UTS #46 mapping **MUST** be implemented in Mojo (including generated Unicode tables checked into the repo). Core parse **MUST NOT** import Python.
3. **Robust.** Untrusted input **MUST NOT** abort the process, overflow buffers, or recurse without a bound. Failures are structured errors. WHATWG *validation errors* are observable without being fatal.
4. **Round-trip honesty.** Parse-then-serialize stability follows the active profile (WHATWG idempotence goal; RFC 3986 syntactic vs semantic normalization kept distinct).
5. **Bytes vs text are explicit.** Percent-decoding yields bytes. Decoding those bytes as UTF-8 is a separate step that can fail. Query form parsing uses UTF-8 decode without BOM, matching WHATWG.
6. **Small, composable surface.** Encoding sets, host parsers, and query lists are reusable without constructing a full URL.

## Non-goals (v1)

- Fetching resources, DNS lookup, or TLS.
- HTML parser integration, `javascript:` execution, or blob URL stores.
- Being a full WHATWG `URL` / `URLSearchParams` JavaScript binding (semantics are aligned; Web IDL is not required).
- URI templates ([RFC 6570](https://www.rfc-editor.org/rfc/rfc6570)), media type parsing, or mailto/data-URL specialized codecs beyond generic syntax.
- Public Suffix List registration as a *required* parse step. Optional PSL helpers **MAY** land later; they **MUST NOT** gate basic parse.

## Intended package layout (when code is added)

Follow Modular’s library layout so `mojo precompile` / pixi-build-mojo can discover the package:

```text
src/heat_url/__init__.mojo
src/heat_url/percent.mojo
src/heat_url/query.mojo
src/heat_url/host.mojo
src/heat_url/idna.mojo
src/heat_url/rfc3986.mojo
src/heat_url/whatwg.mojo
test/test_percent.mojo
test/test_query.mojo
test/test_host.mojo
test/test_rfc3986.mojo
test/test_whatwg.mojo
```

Do not add these files until an implementation change set. Tests use `std.testing.TestSuite` (`mojo test` was removed).

## Versioning

The library is `0.1.0` until the first implementation that passes the conformance suite in [10-conformance.md](10-conformance.md). After that, parse-profile behavior is semver-stable: silent changes to WHATWG or RFC interpretation require a major version **or** an explicit profile revision flag.
