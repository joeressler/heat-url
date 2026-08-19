# heat-url specifications

These documents are the **normative product specification** for `heat-url`. Future implementation must follow them. Where this tree and a referenced external standard disagree on library *shape* (API names, error types, profiles), this tree wins. Where they disagree on *URL/URI language rules*, the cited external standard for the active **parse profile** wins.

## Reading order

| # | Document | Purpose |
| --- | --- | --- |
| 00 | [Overview and principles](00-overview.md) | Goals, non-goals, profiles, package identity |
| 01 | [Normative references](01-normative-references.md) | RFCs, WHATWG, Unicode; precedence |
| 02 | [Data model](02-data-model.md) | In-memory URI/URL records and host types |
| 03 | [Parsing](03-parsing.md) | RFC 3986 splitter vs WHATWG basic URL parser |
| 04 | [Percent-encoding](04-percent-encoding.md) | Encode/decode sets, UTF-8, robustness |
| 05 | [Query parameters](05-query-parameters.md) | Opaque query vs `application/x-www-form-urlencoded` |
| 06 | [Hosts and IDNA](06-host-and-idna.md) | Domains, IPv4/IPv6, Punycode, UTS #46 |
| 07 | [Serialization and resolution](07-serialization-and-resolution.md) | Recomposition, relative refs, normalization |
| 08 | [Errors and robustness](08-error-handling.md) | Failure vs validation error, limits, security |
| 09 | [Public API](09-api.md) | Required modules, types, and operations |
| 10 | [Conformance](10-conformance.md) | Test vectors, golden files, acceptance |

Implementation order for agents is **not** this reading order. Follow [`phases/README.md`](../phases/README.md).

## Keywords

The words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, **MAY**, and **OPTIONAL** are interpreted as in [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119).
