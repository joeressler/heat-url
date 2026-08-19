from heat_url import (
    ParseOptions,
    PathKind,
    Uri,
    parse_host_rfc3986,
    parse_uri,
)
from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)


def _resolve(relative: String) raises -> String:
    return parse_uri(relative, Optional("http://a/b/c/d;p?q")).serialize()


def test_appendix_b_component_split() raises:
    var u = parse_uri("http://www.ics.uci.edu/pub/ietf/uri/#Related")
    assert_true(u.scheme is not None)
    assert_equal(u.scheme.value(), "http")
    assert_true(u.has_authority)
    assert_false(u.is_relative)
    var h = u.host()
    assert_true(h is not None)
    assert_true(h.value().is_reg_name())
    assert_equal(h.value().serialize(), "www.ics.uci.edu")
    assert_equal(u.path, "/pub/ietf/uri/")
    assert_true(u.query is None)
    assert_true(u.fragment is not None)
    assert_equal(u.fragment.value(), "Related")
    assert_equal(u.path_kind, PathKind.abempty)


def test_rfc3986_section_5_4_normal_examples() raises:
    assert_equal(_resolve("g:h"), "g:h")
    assert_equal(_resolve("g"), "http://a/b/c/g")
    assert_equal(_resolve("./g"), "http://a/b/c/g")
    assert_equal(_resolve("g/"), "http://a/b/c/g/")
    assert_equal(_resolve("/g"), "http://a/g")
    assert_equal(_resolve("//g"), "http://g")
    assert_equal(_resolve("?y"), "http://a/b/c/d;p?y")
    assert_equal(_resolve("g?y"), "http://a/b/c/g?y")
    assert_equal(_resolve("#s"), "http://a/b/c/d;p?q#s")
    assert_equal(_resolve("g#s"), "http://a/b/c/g#s")
    assert_equal(_resolve("g?y#s"), "http://a/b/c/g?y#s")
    assert_equal(_resolve(";x"), "http://a/b/c/;x")
    assert_equal(_resolve("g;x"), "http://a/b/c/g;x")
    assert_equal(_resolve("g;x?y#s"), "http://a/b/c/g;x?y#s")
    assert_equal(_resolve(""), "http://a/b/c/d;p?q")
    assert_equal(_resolve("."), "http://a/b/c/")
    assert_equal(_resolve("./"), "http://a/b/c/")
    assert_equal(_resolve(".."), "http://a/b/")
    assert_equal(_resolve("../"), "http://a/b/")
    assert_equal(_resolve("../g"), "http://a/b/g")
    assert_equal(_resolve("../.."), "http://a/")
    assert_equal(_resolve("../../"), "http://a/")
    assert_equal(_resolve("../../g"), "http://a/g")


def test_rfc3986_section_5_4_abnormal_examples() raises:
    assert_equal(_resolve("../../../g"), "http://a/g")
    assert_equal(_resolve("../../../../g"), "http://a/g")
    assert_equal(_resolve("/./g"), "http://a/g")
    assert_equal(_resolve("/../g"), "http://a/g")
    assert_equal(_resolve("g."), "http://a/b/c/g.")
    assert_equal(_resolve(".g"), "http://a/b/c/.g")
    assert_equal(_resolve("g.."), "http://a/b/c/g..")
    assert_equal(_resolve("..g"), "http://a/b/c/..g")
    assert_equal(_resolve("./../g"), "http://a/b/g")
    assert_equal(_resolve("./g/."), "http://a/b/c/g/")
    assert_equal(_resolve("g/./h"), "http://a/b/c/g/h")
    assert_equal(_resolve("g/../h"), "http://a/b/c/h")
    assert_equal(_resolve("g;x=1/./y"), "http://a/b/c/g;x=1/y")
    assert_equal(_resolve("g;x=1/../y"), "http://a/b/c/y")
    assert_equal(_resolve("g?y/./x"), "http://a/b/c/g?y/./x")
    assert_equal(_resolve("g?y/../x"), "http://a/b/c/g?y/../x")
    assert_equal(_resolve("g#s/./x"), "http://a/b/c/g#s/./x")
    assert_equal(_resolve("g#s/../x"), "http://a/b/c/g#s/../x")
    assert_equal(_resolve("http:g"), "http:g")


def test_urn_has_no_authority_rootless_path() raises:
    var u = parse_uri("urn:isbn:0451450523")
    assert_equal(u.scheme.value(), "urn")
    assert_false(u.has_authority)
    assert_true(u.host() is None)
    assert_equal(u.path, "isbn:0451450523")
    assert_equal(u.path_kind, PathKind.rootless)
    assert_equal(u.serialize(), "urn:isbn:0451450523")


def test_scheme_lowercased_host_case_preserved_unless_normalize() raises:
    var u = parse_uri("HTTP://Example.COM/foo")
    assert_equal(u.scheme.value(), "http")
    assert_equal(u.host().value().serialize(), "Example.COM")
    assert_equal(u.serialize(), "http://Example.COM/foo")

    var opt = ParseOptions.rfc3986()
    opt.normalize_syntax = True
    var n = Uri.parse("HTTP://Example.COM/foo", opt)
    assert_equal(n.scheme.value(), "http")
    assert_equal(n.host().value().serialize(), "example.com")
    assert_equal(n.serialize(), "http://example.com/foo")


def test_https_colon_example_org_is_not_special_scheme_recovery() raises:
    var u = parse_uri("https:example.org")
    assert_equal(u.scheme.value(), "https")
    assert_false(u.has_authority)
    assert_equal(u.path, "example.org")
    assert_equal(u.path_kind, PathKind.rootless)
    assert_equal(u.serialize(), "https:example.org")
    assert_true("https://example.org" not in u.serialize())


def test_ipv6_and_zone_id_round_trip() raises:
    var loop = parse_uri("http://[::1]/")
    assert_true(loop.host().value().is_ipv6())
    assert_equal(loop.serialize(), "http://[::1]/")

    var zoned = parse_uri("http://[::1%25eth0]/")
    assert_true(zoned.host().value().is_ipv6())
    assert_equal(zoned.host().value().zone_id(), "eth0")
    assert_equal(zoned.serialize(), "http://[::1%25eth0]/")

    var opt = ParseOptions.rfc3986()
    opt.allow_ipv6_zone_id = False
    with assert_raises(contains="zone"):
        _ = Uri.parse("http://[::1%25eth0]/", opt)


def test_port_text_and_u16_coerce() raises:
    var ok = parse_uri("http://h:8080/")
    assert_equal(ok.port_text().value(), "8080")
    assert_equal(Int(ok.port_as_u16()), 8080)

    var big = parse_uri("http://h:99999/")
    assert_equal(big.port_text().value(), "99999")
    with assert_raises(contains="invalid_port"):
        _ = big.port_as_u16()

    with assert_raises(contains="invalid_port"):
        _ = parse_uri("http://h:80a/")


def test_has_authority_slash_count() raises:
    var no_auth = parse_uri("foo:/bar")
    assert_false(no_auth.has_authority)
    assert_equal(no_auth.path, "/bar")
    assert_equal(no_auth.path_kind, PathKind.absolute)
    assert_equal(no_auth.serialize(), "foo:/bar")

    var auth = parse_uri("foo://bar")
    assert_true(auth.has_authority)
    assert_equal(auth.host().value().serialize(), "bar")
    assert_equal(auth.path, "")
    assert_equal(auth.serialize(), "foo://bar")


def test_file_empty_host_with_authority() raises:
    var u = parse_uri("file:///x")
    assert_true(u.has_authority)
    assert_equal(u.host().value().serialize(), "")
    assert_equal(u.path, "/x")
    assert_equal(u.serialize(), "file:///x")


def test_backslash_is_not_rewritten_to_slash() raises:
    with assert_raises(contains="invalid_path"):
        _ = parse_uri("http://example.com/foo\\bar")
    var encoded = parse_uri("http://example.com/foo%5Cbar")
    assert_equal(encoded.serialize(), "http://example.com/foo%5Cbar")
    assert_true("foo/bar" not in encoded.serialize())


def test_iri_flag_and_idna_host_option() raises:
    var iri = parse_uri("http://éxample.test/café")
    assert_true(iri.host().value().is_reg_name())
    assert_equal(iri.host().value().serialize(), "éxample.test")
    assert_equal(iri.path, "/café")
    assert_true("xn--" not in iri.serialize())

    var no_iri = ParseOptions.rfc3986()
    no_iri.iri = False
    with assert_raises():
        _ = Uri.parse("http://éxample.test/café", no_iri)

    var idna = ParseOptions.rfc3986()
    idna.idna_host = True
    var converted = Uri.parse("http://éxample.test/café", idna)
    var ascii_host = converted.host().value().serialize()
    assert_true("xn--" in ascii_host)
    assert_equal(converted.path, "/café")


def test_empty_query_and_fragment_round_trip() raises:
    var u = parse_uri("http://example.com/path?#")
    assert_true(u.query is not None)
    assert_equal(u.query.value(), "")
    assert_true(u.fragment is not None)
    assert_equal(u.fragment.value(), "")
    assert_equal(u.serialize(), "http://example.com/path?#")
    var no_frag = u.serialize(exclude_fragment=True)
    assert_equal(no_frag, "http://example.com/path?")


def _caught_parse_error(s: String) -> String:
    try:
        _ = parse_uri(s)
        return String("NO_ERROR")
    except err:
        return String(err)


def test_error_does_not_include_password() raises:
    var text = _caught_parse_error("https://user:secret@x:zz/")
    assert_true("invalid_port" in text)
    assert_true("secret" not in text)


def test_relative_without_base_is_relative_ref() raises:
    var u = parse_uri("/abs")
    assert_true(u.is_relative)
    assert_equal(u.path, "/abs")
    assert_equal(u.serialize(), "/abs")


def test_query_list_from_uri() raises:
    var u = parse_uri("http://example.test/?a=b&a=c")
    var q = u.query_list()
    assert_equal(len(q), 2)
    assert_equal(q.get("a").value(), "b")


def test_parse_host_rfc3986_iri_reg_name() raises:
    var h = parse_host_rfc3986("éxample.test", iri=True)
    assert_true(h.is_reg_name())
    assert_equal(h.serialize(), "éxample.test")
    with assert_raises():
        _ = parse_host_rfc3986("éxample.test", iri=False)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
