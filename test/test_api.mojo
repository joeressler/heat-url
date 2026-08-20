from heat_url import (
    EncodeSet,
    ParseOptions,
    parse,
    parse_uri,
    parse_url,
    parse_url_detailed,
    try_parse_uri,
    try_parse_url,
)
from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)


def test_https_colon_example_org_differs_by_profile() raises:
    var web = parse_url("https:example.org")
    assert_equal(web.serialize(), "https://example.org/")
    var rfc = parse_uri("https:example.org")
    assert_equal(rfc.serialize(), "https:example.org")


def test_try_parse_url_failure_is_empty() raises:
    var got = try_parse_url("https://ex ample.org/")
    assert_true(got is None)


def test_try_parse_uri_failure_is_empty() raises:
    var got = try_parse_uri("https://example.com:demo")
    assert_true(got is None)


def test_parse_dispatches_on_profile() raises:
    var input = "https:example.org"
    var web = parse(input, ParseOptions.whatwg())
    assert_true(web.is_url())
    assert_false(web.is_uri())
    assert_true(web.url() is not None)
    assert_true(web.uri() is None)
    assert_equal(web.serialize(), "https://example.org/")

    var rfc = parse(input, ParseOptions.rfc3986())
    assert_true(rfc.is_uri())
    assert_false(rfc.is_url())
    assert_true(rfc.uri() is not None)
    assert_true(rfc.url() is None)
    assert_equal(rfc.serialize(), "https:example.org")


def test_query_list_from_parse_url() raises:
    var url = parse_url("https://example.test/?a=b&a=c")
    var q = url.query_list()
    assert_equal(q.get("a").value(), "b")
    assert_equal(len(q.get_all("a")), 2)


def test_credentials_succeed_without_leaking_secret() raises:
    var url = parse_url("https://user:secret@x/")
    assert_equal(url.serialize(), "https://user:secret@x/")
    var detailed = parse_url_detailed("https://user:secret@x/")
    assert_true(detailed.has_error("invalid-credentials"))
    var i = 0
    while i < len(detailed.validation_errors):
        assert_false("secret" in String(detailed.validation_errors[i]))
        i += 1


def test_try_parse_url_success() raises:
    var got = try_parse_url("https://example.com/")
    assert_true(got is not None)
    assert_equal(got.value().serialize(), "https://example.com/")


def test_package_acceptance_imports() raises:
    from heat_url import host, idna, parse_uri, parse_url, percent, query
    from heat_url.host import parse_host_whatwg
    from heat_url.idna import to_ascii
    from heat_url.percent import encode
    from heat_url.query import QueryList

    _ = parse_url
    _ = parse_uri
    _ = percent
    _ = query
    _ = host
    _ = idna
    assert_equal(encode(" ", EncodeSet.Path), "%20")
    _ = QueryList.parse("a=b")
    var h = parse_host_whatwg("example.com")
    assert_true(h.is_domain())
    assert_equal(to_ascii("EXAMPLE.COM"), "example.com")


def test_parse_url_failure_raises() raises:
    with assert_raises():
        _ = parse_url("https://ex ample.org/")


def test_strict_whatwg_parse_error_omits_secret() raises:
    var options = ParseOptions.whatwg()
    options.strict_whatwg = True
    var raised = False
    try:
        _ = parse("https://user:secret@x/", options)
    except e:
        raised = True
        assert_false("secret" in String(e))
    assert_true(raised)


def test_acceptance_import_parse_url_parse_uri() raises:
    from heat_url import parse_uri as parse_uri_name
    from heat_url import parse_url as parse_url_name

    assert_equal(
        parse_url_name("https:example.org").serialize(), "https://example.org/"
    )
    assert_equal(
        parse_uri_name("https:example.org").serialize(), "https:example.org"
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
