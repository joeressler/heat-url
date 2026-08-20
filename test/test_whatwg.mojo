from heat_url import (
    ParseError,
    ParseOptions,
    Url,
    UrlParseResult,
    parse_uri,
)
from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)


def _opts(base: Optional[String] = None, strict: Bool = False) -> ParseOptions:
    var options = ParseOptions.whatwg()
    options.base = base
    options.strict_whatwg = strict
    return options^


def _parse(
    input: String, base: Optional[String] = None
) raises -> UrlParseResult:
    return Url.parse(input, _opts(base))


def _ser(input: String, base: Optional[String] = None) raises -> String:
    return _parse(input, base).url.serialize()


def test_https_colon_example_org_without_base() raises:
    assert_equal(_ser("https:example.org"), "https://example.org/")


def test_https_colon_example_org_with_http_base_is_relative() raises:
    assert_equal(
        _ser("https:example.org", Optional("https://example.com/")),
        "https://example.com/example.org",
    )
    var rfc = parse_uri("https:example.org")
    assert_equal(rfc.serialize(), "https:example.org")


def test_backslash_paths_on_https() raises:
    var r = _parse("https://example.org\\path\\to\\file")
    assert_equal(r.url.serialize(), "https://example.org/path/to/file")
    assert_true(r.has_error("invalid-reverse-solidus"))


def test_file_pipe_drive_letter() raises:
    assert_equal(_ser("file:///C|/demo"), "file:///C:/demo")


def test_file_localhost_shrinks() raises:
    assert_equal(_ser("file://localhost/"), "file:///")


def test_file_dotdot_keeps_drive() raises:
    assert_equal(_ser("..", Optional("file:///C:/demo")), "file:///C:/")


def test_credentials_succeed_and_record_invalid_credentials() raises:
    var r = _parse("https://user:password@example.org/")
    assert_equal(r.url.serialize(), "https://user:password@example.org/")
    assert_true(r.has_error("invalid-credentials"))
    var i = 0
    while i < len(r.validation_errors):
        var text = String(r.validation_errors[i])
        assert_false("password" in text)
        i += 1


def test_strict_whatwg_credentials_fail_without_leaking_password() raises:
    var raised = False
    try:
        _ = Url.parse("https://user:secret@example.org/", _opts(strict=True))
    except e:
        raised = True
        var text = String(e)
        assert_false("secret" in text)
        assert_true("invalid-credentials" in text or "validation_error" in text)
    assert_true(raised)


def test_space_in_host_fails() raises:
    with assert_raises():
        _ = _parse("https://ex ample.org/")


def test_non_numeric_port_fails() raises:
    with assert_raises(contains="port_invalid"):
        _ = _parse("https://example.com:demo")


def test_missing_scheme_without_base_fails() raises:
    with assert_raises(contains="missing_scheme"):
        _ = _parse("example")


def test_git_opaque_host() raises:
    var r = _parse("git://github.com/whatwg/url.git")
    assert_equal(r.url.serialize(), "git://github.com/whatwg/url.git")
    var h = r.url.host()
    assert_true(h is not None)
    assert_true(h.value().is_opaque())
    assert_false(h.value().is_domain())


def test_https_example_dotdot_and_case() raises:
    assert_equal(_ser("https://EXAMPLE.com/../x"), "https://example.com/x")


def test_default_https_port_omitted() raises:
    assert_equal(_ser("https://example.com:443/"), "https://example.com/")
    assert_equal(_ser("http://example.com:80/foo"), "http://example.com/foo")
    assert_equal(_ser("http://example.com:8080/"), "http://example.com:8080/")


def test_special_query_encodes_apostrophe() raises:
    assert_equal(_ser("https://example.com/?q='"), "https://example.com/?q=%27")
    assert_equal(_ser("foo://example.com/?q='"), "foo://example.com/?q='")


def test_parse_serialize_parse_identity() raises:
    var samples = [
        "https://example.com/",
        "https://example.com/foo",
        "https://example.org//",
        "https://example.com/[]?[]#[]",
        "https://example/%25?%25#%25",
        "https://user:password@example.org/",
        "file:///C:/demo",
        "file:///",
        "git://github.com/whatwg/url.git",
        "urn:isbn:9780307476463",
        "hello:world",
        "https://example.org/foo%20bar",
        "web+demo:/.//not-a-host/",
    ]
    var i = 0
    while i < len(samples):
        var first = _parse(samples[i])
        var serialized = first.url.serialize()
        var second = _parse(serialized)
        assert_true(first.url.equals(second.url, include_fragment=True))
        assert_equal(second.url.serialize(), serialized)
        i += 1


def test_whatwg_section_4_examples() raises:
    assert_equal(_ser("https:example.org"), "https://example.org/")
    assert_equal(_ser("https://////example.com///"), "https://example.com///")
    assert_equal(_ser("https://example.com/././foo"), "https://example.com/foo")
    assert_equal(
        _ser("hello:world", Optional("https://example.com/")), "hello:world"
    )
    assert_equal(
        _ser("\\example\\..\\demo/.\\", Optional("https://example.com/")),
        "https://example.com/demo/",
    )
    assert_equal(
        _ser("example", Optional("https://example.com/demo")),
        "https://example.com/example",
    )
    assert_equal(_ser("file://loc%61lhost/"), "file:///")
    assert_equal(
        _ser("https://example.org/foo bar"), "https://example.org/foo%20bar"
    )
    with assert_raises():
        _ = _parse("http://[www.example.com]/")
    assert_equal(_ser("https://example.org//"), "https://example.org//")
    assert_equal(_ser("https://example/%?%#%"), "https://example/%?%#%")


def test_relative_query_and_fragment_against_base() raises:
    assert_equal(
        _ser("?y", Optional("https://example.com/a/b")),
        "https://example.com/a/b?y",
    )
    assert_equal(
        _ser("#s", Optional("https://example.com/a/b?q")),
        "https://example.com/a/b?q#s",
    )


def test_long_dotdot_chain_does_not_overflow() raises:
    var s = String("https://example.com/")
    var i = 0
    while i < 4000:
        s += "a/../"
        i += 1
    assert_equal(_ser(s), "https://example.com/")


def test_too_many_path_segments_fails() raises:
    var s = String("https://example.com")
    var i = 0
    while i < 8193:
        s += "/a"
        i += 1
    with assert_raises(contains="too_many_path_segments"):
        _ = _parse(s)


def test_input_too_long_fails() raises:
    var options = ParseOptions.whatwg()
    options.max_input_length = 3
    with assert_raises(contains="input_too_long"):
        _ = Url.parse("abcd", options)


def test_failure_host_missing() raises:
    with assert_raises(contains="host_missing"):
        _ = _parse("https://#fragment")
    with assert_raises(contains="host_missing"):
        _ = _parse("https://:443")


def test_failure_port_out_of_range() raises:
    with assert_raises(contains="port_out_of_range"):
        _ = _parse("https://example.org:70000")


def test_failure_ipv6_unclosed() raises:
    with assert_raises(contains="ipv6_unclosed"):
        _ = _parse("https://[::1")


def test_failure_ipv6_invalid_compression() raises:
    with assert_raises(contains="ipv6_invalid_compression"):
        _ = _parse("https://[:1]")


def test_failure_ipv6_too_many_pieces() raises:
    with assert_raises(contains="ipv6_too_many_pieces"):
        _ = _parse("https://[1:2:3:4:5:6:7:8:9]")


def test_failure_ipv6_multiple_compression() raises:
    with assert_raises(contains="ipv6_multiple_compression"):
        _ = _parse("https://[1::1::1]")


def test_failure_ipv6_invalid_code_point() raises:
    with assert_raises(contains="ipv6_invalid_code_point"):
        _ = _parse("https://[1:2:3!:4]")


def test_failure_ipv6_too_few_pieces() raises:
    with assert_raises(contains="ipv6_too_few_pieces"):
        _ = _parse("https://[1:2:3]")


def test_failure_ipv4_too_many_parts() raises:
    with assert_raises(contains="ipv4_too_many_parts"):
        _ = _parse("https://1.2.3.4.5/")


def test_failure_ipv4_non_numeric_part() raises:
    with assert_raises(contains="ipv4_non_numeric_part"):
        _ = _parse("https://test.42")


def test_failure_ipv4_out_of_range() raises:
    with assert_raises(contains="ipv4_out_of_range_part"):
        _ = _parse("https://255.255.255.256")


def test_failure_ipv4_in_ipv6() raises:
    with assert_raises(contains="ipv4_in_ipv6_too_many_pieces"):
        _ = _parse("https://[1:1:1:1:1:1:1:127.0.0.1]")
    with assert_raises(contains="ipv4_in_ipv6_invalid_code_point"):
        _ = _parse("https://[ffff::.0.0.1]")
    with assert_raises(contains="ipv4_in_ipv6_out_of_range_part"):
        _ = _parse("https://[ffff::127.0.0.4000]")
    with assert_raises(contains="ipv4_in_ipv6_too_few_parts"):
        _ = _parse("https://[ffff::127.0.0]")


def test_failure_host_invalid_code_point() raises:
    with assert_raises(contains="host_invalid_code_point"):
        _ = _parse("foo://exa[mple.org")


def test_failure_domain_to_ascii() raises:
    with assert_raises(contains="domain_to_ascii"):
        _ = _parse("https://exa%23mple.org")


def test_nonfatal_host_validation_errors() raises:
    var empty_part = _parse("https://127.0.0.1./")
    assert_equal(empty_part.url.serialize(), "https://127.0.0.1/")
    assert_true(empty_part.has_error("IPv4-empty-part"))

    var few = _parse("https://1.2.3/")
    assert_true(few.has_error("IPv4-too-few-parts"))

    var octal = _parse("https://127.0.0x0.1")
    assert_true(octal.has_error("IPv4-non-decimal-part"))

    var percent = _parse("https://exam%70le.org/")
    assert_equal(percent.url.serialize(), "https://example.org/")
    assert_true(percent.has_error("domain-percent-encoded"))

    var leading = _parse("https://[::01]")
    assert_true(leading.has_error("IPv6-piece-leading-zero"))


def test_equals_excludes_fragment_by_default() raises:
    var a = _parse("https://example.com/x#one")
    var b = _parse("https://example.com/x#two")
    assert_true(a.url.equals(b.url))
    assert_false(a.url.equals(b.url, include_fragment=True))


def test_query_list_from_url() raises:
    var r = _parse("https://example.test/?a=b&a=c")
    var q = r.url.query_list()
    assert_equal(q.get("a").value(), "b")
    assert_equal(len(q.get_all("a")), 2)
    var empty = _parse("https://example.test/")
    assert_equal(len(empty.url.query_list()), 0)


def test_exclude_fragment_serialize() raises:
    var r = _parse("https://example.com/x#frag")
    assert_equal(
        r.url.serialize(exclude_fragment=True), "https://example.com/x"
    )


def test_opaque_path_urn() raises:
    var r = _parse("urn:isbn:9780307476463")
    assert_true(r.url.has_opaque_path())
    assert_equal(r.url.opaque_path(), "isbn:9780307476463")
    assert_true(r.url.host() is None)


def test_file_invalid_windows_drive_letter_host() raises:
    var r = _parse("file://c:")
    assert_true(r.has_error("file-invalid-Windows-drive-letter-host"))


def test_special_scheme_missing_following_solidus() raises:
    var r = _parse("https:example.org")
    assert_true(r.has_error("special-scheme-missing-following-solidus"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
