from heat_url import (
    ParseError,
    ParseOptions,
    ParseProfile,
    VERSION,
    DEFAULT_MAX_INPUT_CODEPOINTS,
    check_input_length,
    redact_userinfo,
)
from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)


def test_package_version() raises:
    assert_equal(String(VERSION), "0.1.0")


def test_parse_profiles_are_distinct() raises:
    assert_equal(String(ParseProfile.rfc3986), "rfc3986")
    assert_equal(String(ParseProfile.whatwg), "whatwg")
    assert_true(ParseProfile.rfc3986 != ParseProfile.whatwg)


def test_parse_options_defaults() raises:
    var rfc = ParseOptions.rfc3986()
    assert_equal(rfc.profile, ParseProfile.rfc3986)
    assert_true(rfc.iri)
    assert_true(rfc.allow_ipv6_zone_id)
    assert_false(rfc.normalize_syntax)
    assert_false(rfc.idna_host)
    assert_false(rfc.strict_whatwg)
    assert_equal(rfc.max_input_length, DEFAULT_MAX_INPUT_CODEPOINTS)

    var web = ParseOptions.whatwg()
    assert_equal(web.profile, ParseProfile.whatwg)
    assert_equal(web.max_input_length, DEFAULT_MAX_INPUT_CODEPOINTS)


def test_redact_userinfo_strips_password() raises:
    var raw = "https://user:secret@example.org/path"
    var redacted = redact_userinfo(raw)
    assert_true(String("secret") not in redacted)
    assert_true("REDACTED@" in redacted)
    assert_true("example.org/path" in redacted)


def test_redact_userinfo_leaves_urls_without_userinfo() raises:
    var raw = "https://example.org/path"
    assert_equal(redact_userinfo(raw), raw)


def test_parse_error_writable_omits_payload_by_default() raises:
    var err = ParseError.input_too_long(ParseProfile.whatwg, 10, 5)
    assert_equal(err.kind, "input_too_long")
    var text = String(err)
    assert_true("ParseError" in text)
    assert_true("input_too_long" in text)


def test_check_input_length_accepts_within_cap() raises:
    var options = ParseOptions.whatwg()
    options.max_input_length = 4
    check_input_length("abcd", options)


def test_check_input_length_rejects_over_cap() raises:
    var options = ParseOptions.rfc3986()
    options.max_input_length = 3
    with assert_raises(contains="input_too_long"):
        check_input_length("abcd", options)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
