# Phase status

Update the **Status** column when a phase is finished (`todo` → `done`). Do not mark `done` if `pixi run test` fails.

| ID | Phase | Status | Notes |
| --- | --- | --- | --- |
| 00 | [Bootstrap](00-bootstrap.md) | done | Package, ParseProfile, ParseError, ParseOptions (including `base`), `pixi run test` |
| 01 | [Percent-encoding](01-percent-encoding.md) | done | `heat_url.percent` encode/decode sets |
| 02 | [Query parameters](02-query-parameters.md) | done | `heat_url.query.QueryList` form-urlencoded + RFC-style split |
| 03 | [Punycode](03-punycode.md) | done | RFC 3492 payload without `xn--` |
| 04 | [IDNA / UTS #46](04-idna.md) | done | Unicode 17.0.0 tables; `to_ascii` / `to_unicode` non-transitional |
| 05 | [Hosts](05-hosts.md) | done | WHATWG host parser + RFC 3986 IP-literal / IPv4 / reg-name |
| 06 | [RFC 3986 URI](06-rfc3986.md) | done | URI-reference parse/serialize/§5 resolve; IRI via `ParseOptions.iri` |
| 07 | [WHATWG URL](07-whatwg.md) | done | `heat_url.whatwg` basic URL parser/serializer + validation errors; origin/setters deferred |
| 08 | [Public API](08-public-api.md) | done | `parse_url` / `try_parse_url` / `parse_url_detailed` / `parse`; setters and `origin()` deferred to v1.1 |
| 09 | [Conformance fixtures](09-conformance.md) | done | WPT urltestdata + Unicode 17.0.0 IDNATestV2; setters/origin/JS-only WPT and transitional IDNA not run |
