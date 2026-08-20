# Changelog

## 1.0.0

First release of `heat_url`.

- WHATWG basic URL parser and serializer (`parse_url`, `try_parse_url`,
  `parse_url_detailed`)
- RFC 3986 URI-reference parse, serialize, and §5 resolution (`parse_uri`)
- Percent-encoding sets, `QueryList`, host parsers, Punycode, UTS #46 IDNA
  (Unicode 17.0.0)
- WPT `urltestdata.json` and IDNATestV2 in `pixi run test`
- No WHATWG setters or `origin()` yet (planned for 1.1)
