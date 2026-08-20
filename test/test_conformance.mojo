from heat_url import (
    DEFAULT_MAX_INPUT_CODEPOINTS,
    parse_uri,
    parse_url,
)
from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)


def _ascii_of_length(n: Int, fill: UInt8) -> String:
    var bytes = List[UInt8]()
    var i = 0
    while i < n:
        bytes.append(fill)
        i += 1
    return String(unsafe_from_utf8=bytes)


def test_default_max_input_length_plus_one_fails() raises:
    var s = _ascii_of_length(DEFAULT_MAX_INPUT_CODEPOINTS + 1, UInt8(0x61))
    with assert_raises(contains="input_too_long"):
        _ = parse_url(s)
    with assert_raises(contains="input_too_long"):
        _ = parse_uri(s)


def test_rfc3987_iri_examples() raises:
    var iri = parse_uri("http://www.example.org/Dürst")
    assert_equal(iri.path, "/Dürst")
    assert_equal(iri.host().value().serialize(), "www.example.org")
    var pct = parse_uri("http://www.example.org/D%C3%BCrst")
    assert_equal(pct.path, "/D%C3%BCrst")
    var jp = parse_uri("http://xn--99zt52a.example.org/resumé")
    assert_equal(jp.host().value().serialize(), "xn--99zt52a.example.org")
    assert_equal(jp.path, "/resumé")


def test_oversize_error_omits_secret() raises:
    var prefix = String("https://user:secret@host/")
    var n = DEFAULT_MAX_INPUT_CODEPOINTS + 1
    var pad_n = n - prefix.byte_length()
    var s = prefix + _ascii_of_length(pad_n, UInt8(0x61))
    var raised = False
    try:
        _ = parse_url(s)
    except e:
        raised = True
        var text = String(e)
        assert_false("secret" in text)
        assert_true("input_too_long" in text)
    assert_true(raised)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
