# Phase status

Update the **Status** column when a phase is finished (`todo` → `done`). Do not mark `done` if `pixi run test` fails.

| ID | Phase | Status | Notes |
| --- | --- | --- | --- |
| 00 | [Bootstrap](00-bootstrap.md) | done | Package, ParseProfile, ParseError, ParseOptions (including `base`), `pixi run test` |
| 01 | [Percent-encoding](01-percent-encoding.md) | done | `heat_url.percent` encode/decode sets |
| 02 | [Query parameters](02-query-parameters.md) | done | `heat_url.query.QueryList` form-urlencoded + RFC-style split |
| 03 | [Punycode](03-punycode.md) | done | RFC 3492 payload without `xn--` |
| 04 | [IDNA / UTS #46](04-idna.md) | done | Unicode 17.0.0 tables; `to_ascii` / `to_unicode` non-transitional |
| 05 | [Hosts](05-hosts.md) | todo | |
| 06 | [RFC 3986 URI](06-rfc3986.md) | todo | |
| 07 | [WHATWG URL](07-whatwg.md) | todo | |
| 08 | [Public API](08-public-api.md) | todo | |
| 09 | [Conformance fixtures](09-conformance.md) | todo | |
