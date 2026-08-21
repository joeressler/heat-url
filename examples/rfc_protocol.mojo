from heat_url import ParseOptions, Uri, parse_uri


def main() raises:
    # URN: no authority, rootless path (RFC 3986).
    var urn = parse_uri("urn:isbn:0451450523")
    print("urn scheme:", urn.scheme.value())
    print("urn has_authority:", urn.has_authority)
    print("urn path:", urn.path)
    print("urn serialize:", urn.serialize())

    # RFC 3986 §5.2 relative resolution against a base URI-reference.
    var rfc_base = "http://a/b/c/d;p?q"
    var relatives = ["g", "../g", "//g", "http:g"]
    var i = 0
    while i < len(relatives):
        var rel = relatives[i]
        var resolved = parse_uri(rel, rfc_base)
        print(rel + " -> " + resolved.serialize())
        i += 1

    # Default RFC parse keeps reg-name case; normalize_syntax lowercases host.
    var mixed = parse_uri("HTTP://Example.COM/foo")
    print("default host:", mixed.host().value().serialize())
    print("default serialize:", mixed.serialize())

    var norm_opts = ParseOptions.rfc3986()
    norm_opts.normalize_syntax = True
    var normalized = Uri.parse("HTTP://Example.COM/foo", norm_opts)
    print("normalized serialize:", normalized.serialize())

    # IRI keeps Unicode; idna_host Punycode-encodes the host only.
    var iri = parse_uri("http://éxample.test/café")
    print("iri serialize:", iri.serialize())

    var idna_opts = ParseOptions.rfc3986()
    idna_opts.idna_host = True
    var idna = Uri.parse("http://éxample.test/café", idna_opts)
    print("idna_host serialize:", idna.serialize())

    # IPv6 zone id round-trips; disabling zone ids rejects the input.
    var zoned = parse_uri("http://[::1%25eth0]/")
    print("zoned serialize:", zoned.serialize())

    var no_zone_opts = ParseOptions.rfc3986()
    no_zone_opts.allow_ipv6_zone_id = False
    try:
        _ = Uri.parse("http://[::1%25eth0]/", no_zone_opts)
        print("zone id disabled: unexpected success")
    except _:
        print("zone id disabled: rejected")
