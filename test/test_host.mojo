from heat_url import (
    DEFAULT_MAX_AUTHORITY_LENGTH,
    RfcHost,
    WhatwgHost,
    parse_host_rfc3986,
    parse_host_whatwg,
    serialize_host,
)
from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)


def test_rfc_dotted_decimal_is_ipv4() raises:
    var h = parse_host_rfc3986("127.0.0.1")
    assert_true(h.is_ipv4())
    assert_equal(h.serialize(), "127.0.0.1")
    assert_equal(serialize_host(h.copy()), "127.0.0.1")
    assert_equal(Int(h.ipv4_address()), 0x7F000001)


def test_rfc_hex_looking_host_is_reg_name() raises:
    var mixed = parse_host_rfc3986("127.0.0x1")
    assert_true(mixed.is_reg_name())
    assert_false(mixed.is_ipv4())
    assert_equal(mixed.serialize(), "127.0.0x1")

    var hex_ipv4 = parse_host_rfc3986("0x7f.0.0.1")
    assert_true(hex_ipv4.is_reg_name())
    assert_equal(hex_ipv4.serialize(), "0x7f.0.0.1")

    var two_part = parse_host_rfc3986("1.1")
    assert_true(two_part.is_reg_name())
    assert_equal(two_part.serialize(), "1.1")


def test_whatwg_hex_ipv4_and_ends_in_a_number() raises:
    var hex_ipv4 = parse_host_whatwg("0x7f.0.0.1")
    assert_true(hex_ipv4.is_ipv4())
    assert_equal(hex_ipv4.serialize(), "127.0.0.1")
    assert_equal(Int(hex_ipv4.ipv4_address()), 0x7F000001)

    var two_part = parse_host_whatwg("1.1")
    assert_true(two_part.is_ipv4())
    assert_equal(two_part.serialize(), "1.0.0.1")

    var zero = parse_host_whatwg("0")
    assert_true(zero.is_ipv4())
    assert_equal(zero.serialize(), "0.0.0.0")

    var all_ones = parse_host_whatwg("0xffffffff")
    assert_true(all_ones.is_ipv4())
    assert_equal(all_ones.serialize(), "255.255.255.255")


def test_ipv6_loopback_and_db8_round_trip() raises:
    var web_loop = parse_host_whatwg("[::1]")
    assert_true(web_loop.is_ipv6())
    assert_equal(web_loop.serialize(), "[::1]")
    assert_equal(serialize_host(web_loop.copy()), "[::1]")

    var rfc_loop = parse_host_rfc3986("[::1]")
    assert_true(rfc_loop.is_ipv6())
    assert_equal(rfc_loop.serialize(), "[::1]")

    var web_db8 = parse_host_whatwg("[2001:db8::1]")
    assert_equal(web_db8.serialize(), "[2001:db8::1]")
    var rfc_db8 = parse_host_rfc3986("[2001:db8::1]")
    assert_equal(rfc_db8.serialize(), "[2001:db8::1]")


def test_ipv6_longest_zero_run_is_compressed() raises:
    var web = parse_host_whatwg("[2001:db8:0:0:0:0:0:1]")
    assert_equal(web.serialize(), "[2001:db8::1]")
    var rfc = parse_host_rfc3986("[2001:DB8:0:0:0:0:0:1]")
    assert_equal(rfc.serialize(), "[2001:db8::1]")
    var already = parse_host_whatwg("[0:0::1]")
    assert_equal(already.serialize(), "[::1]")


def test_ipv6_zone_id_is_rfc_only() raises:
    var zoned = parse_host_rfc3986("[::1%25eth0]")
    assert_true(zoned.is_ipv6())
    assert_equal(zoned.zone_id(), "eth0")
    assert_equal(zoned.serialize(), "[::1%25eth0]")

    with assert_raises(contains="zone"):
        _ = parse_host_rfc3986("[::1%25eth0]", allow_zone_id=False)

    with assert_raises(contains="IPv6"):
        _ = parse_host_whatwg("[::1%25eth0]")

    with assert_raises(contains="zone"):
        _ = parse_host_rfc3986("[::1%eth0]")


def test_whatwg_domain_vs_opaque_sharp_s() raises:
    var domain = parse_host_whatwg("faß.example")
    assert_true(domain.is_domain())
    assert_equal(domain.serialize(), "xn--fa-hia.example")

    var opaque = parse_host_whatwg("faß.example", is_opaque=True)
    assert_true(opaque.is_opaque())
    assert_equal(opaque.serialize(), "fa%C3%9F.example")
    assert_true("xn--" not in opaque.serialize())


def test_opaque_github_is_not_idna() raises:
    var h = parse_host_whatwg("github.com", is_opaque=True)
    assert_true(h.is_opaque())
    assert_equal(h.serialize(), "github.com")


def test_ipv6_wins_over_opaque_flag() raises:
    var h = parse_host_whatwg("[::1]", is_opaque=True)
    assert_true(h.is_ipv6())
    assert_equal(h.serialize(), "[::1]")


def test_ascii_idna_invalid_still_whatwg_domain() raises:
    var underscore = parse_host_whatwg("_foo.example")
    assert_true(underscore.is_domain())
    assert_equal(underscore.serialize(), "_foo.example")

    var hyphen = parse_host_whatwg("A-.example")
    assert_true(hyphen.is_domain())
    assert_equal(hyphen.serialize(), "a-.example")


def test_example_com_case_and_opaque_preserves_case() raises:
    var domain = parse_host_whatwg("EXAMPLE.COM")
    assert_true(domain.is_domain())
    assert_equal(domain.serialize(), "example.com")

    var opaque = parse_host_whatwg("EXAMPLE.COM", is_opaque=True)
    assert_true(opaque.is_opaque())
    assert_equal(opaque.serialize(), "EXAMPLE.COM")


def test_rfc_ipv_future_round_trip() raises:
    var h = parse_host_rfc3986("[v1.x]")
    assert_true(h.is_ipv_future())
    assert_equal(h.serialize(), "[v1.x]")

    var colon = parse_host_rfc3986("[v1.https:443]")
    assert_true(colon.is_ipv_future())
    assert_equal(colon.serialize(), "[v1.https:443]")


def test_empty_host_both_profiles() raises:
    var web = parse_host_whatwg("")
    assert_true(web.is_empty())
    assert_equal(web.serialize(), "")

    var rfc = parse_host_rfc3986("")
    assert_true(rfc.is_reg_name())
    assert_equal(rfc.serialize(), "")


def test_ipv4_in_ipv6_serializes_as_hex() raises:
    var web = parse_host_whatwg("[::ffff:192.0.2.1]")
    assert_true(web.is_ipv6())
    assert_equal(web.serialize(), "[::ffff:c000:201]")

    var rfc = parse_host_rfc3986("[::ffff:192.0.2.1]")
    assert_true(rfc.is_ipv6())
    assert_equal(rfc.serialize(), "[::ffff:c000:201]")


def test_whatwg_octal_nine_fails_decimal_opaque_ok() raises:
    with assert_raises():
        _ = parse_host_whatwg("09")
    var opaque = parse_host_whatwg("09", is_opaque=True)
    assert_true(opaque.is_opaque())
    assert_equal(opaque.serialize(), "09")


def test_forbidden_host_code_point_fails() raises:
    with assert_raises(contains="host_invalid_code_point"):
        _ = parse_host_whatwg("example^example", is_opaque=True)
    with assert_raises():
        _ = parse_host_whatwg("example^example")


def test_unclosed_ipv6_fails() raises:
    with assert_raises(contains="ipv6_unclosed"):
        _ = parse_host_whatwg("[::1")
    with assert_raises():
        _ = parse_host_rfc3986("[::1")


def test_percent_decoded_domain_and_ipv4() raises:
    var domain = parse_host_whatwg("example%2Ecom")
    assert_true(domain.is_domain())
    assert_equal(domain.serialize(), "example.com")

    var ipv4 = parse_host_whatwg("%30")
    assert_true(ipv4.is_ipv4())
    assert_equal(ipv4.serialize(), "0.0.0.0")


def test_coffee_symbol_domain() raises:
    var h = parse_host_whatwg("☕.example")
    assert_true(h.is_domain())
    assert_equal(h.serialize(), "xn--53h.example")


def test_authority_too_long_fails() raises:
    var out = List[UInt8](capacity=DEFAULT_MAX_AUTHORITY_LENGTH + 1)
    var i = 0
    while i < DEFAULT_MAX_AUTHORITY_LENGTH + 1:
        out.append(UInt8(0x61))
        i += 1
    var s = String(unsafe_from_utf8=out)
    with assert_raises(contains="authority_too_long"):
        _ = parse_host_whatwg(s)
    with assert_raises(contains="authority_too_long"):
        _ = parse_host_rfc3986(s.copy())


def test_rfc_reg_name_preserves_percent() raises:
    var h = parse_host_rfc3986("ex%61mple.com")
    assert_true(h.is_reg_name())
    assert_equal(h.serialize(), "ex%61mple.com")


def test_host_equality() raises:
    var a = parse_host_whatwg("127.0.0.1")
    var b = WhatwgHost.ipv4(UInt32(0x7F000001))
    assert_equal(a, b)
    var r = parse_host_rfc3986("127.0.0.1")
    assert_equal(r, RfcHost.ipv4(UInt32(0x7F000001)))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
