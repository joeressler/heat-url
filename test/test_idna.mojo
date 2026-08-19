from heat_url import UNICODE_VERSION, to_ascii, to_unicode
from std.testing import (
    assert_equal,
    assert_raises,
    assert_true,
    TestSuite,
)


def test_unicode_version_is_documented() raises:
    assert_equal(String(UNICODE_VERSION), "17.0.0")


def test_sharp_s_is_non_transitional() raises:
    assert_equal(to_ascii("faß.example"), "xn--fa-hia.example")
    assert_true(to_ascii("faß.example") != "fass.example")


def test_coffee_symbol_to_ascii() raises:
    assert_equal(to_ascii("☕.example"), "xn--53h.example")


def test_ascii_domain_is_lowercased() raises:
    assert_equal(to_ascii("EXAMPLE.COM"), "example.com")


def test_to_unicode_round_trip_sharp_s() raises:
    assert_equal(to_unicode("xn--fa-hia.example"), "faß.example")
    assert_equal(to_unicode("faß.example"), "faß.example")


def test_invalid_punycode_fails() raises:
    with assert_raises(contains="punycode"):
        _ = to_ascii("xn--0.pt")
    with assert_raises():
        _ = to_ascii("xn--em*.example")


def test_strict_rejects_std3_underscore() raises:
    assert_equal(to_ascii("_foo.example"), "_foo.example")
    with assert_raises(contains="std3"):
        _ = to_ascii("_foo.example", be_strict=True)


def test_strict_rejects_trailing_hyphen() raises:
    assert_equal(to_ascii("a-.example"), "a-.example")
    with assert_raises(contains="check_hyphens"):
        _ = to_ascii("a-.example", be_strict=True)


def test_ideographic_full_stop_and_fullwidth() raises:
    assert_equal(to_ascii("日本語。ＪＰ"), "xn--wgv71a119e.jp")
    assert_equal(to_unicode("xn--wgv71a119e.jp"), "日本語.jp")


def test_capital_sharp_s_maps_to_small() raises:
    assert_equal(to_ascii("BLOẞ.de"), to_ascii("bloß.de"))
    assert_equal(to_unicode("xn--blo-7ka.de"), "bloß.de")


def test_punycode_not_nfc_fails() raises:
    with assert_raises(contains="not_nfc"):
        _ = to_unicode("xn--u-ccb.com")


def test_trailing_dot_strict_vs_lenient() raises:
    assert_equal(to_ascii("example.com."), "example.com.")
    with assert_raises(contains="dns_length"):
        _ = to_ascii("example.com.", be_strict=True)


def test_too_many_labels_fails() raises:
    var s = String("a")
    var i = 1
    while i < 129:
        s += ".a"
        i += 1
    with assert_raises(contains="too_many_labels"):
        _ = to_ascii(s)


def test_empty_input_strict_fails() raises:
    with assert_raises(contains="dns_length"):
        _ = to_ascii("", be_strict=True)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
