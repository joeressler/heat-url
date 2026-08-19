from heat_url import (
    EncodeSet,
    decode_lenient,
    decode_strict,
    decode_utf8_lenient,
    decode_utf8_strict,
    encode,
)
from std.testing import (
    assert_equal,
    assert_raises,
    assert_true,
    TestSuite,
)


def _assert_bytes(got: List[UInt8], expected: List[UInt8]) raises:
    assert_equal(len(got), len(expected))
    var i = 0
    while i < len(got):
        assert_equal(Int(got[i]), Int(expected[i]))
        i += 1


def test_encode_space_path_vs_form() raises:
    assert_equal(encode("a b", EncodeSet.Path), "a%20b")
    assert_equal(
        encode("a b", EncodeSet.FormUrlencoded, space_as_plus=True), "a+b"
    )


def test_encode_hex_is_uppercase() raises:
    assert_equal(encode("{", EncodeSet.Path), "%7B")
    assert_equal(encode("\x0a", EncodeSet.C0Control), "%0A")


def test_decode_lenient_copies_stray_percent() raises:
    _assert_bytes(decode_lenient("%"), [UInt8(0x25)])


def test_decode_strict_rejects_stray_percent() raises:
    with assert_raises(contains="invalid_percent_encoding"):
        _ = decode_strict("%")
    with assert_raises(contains="invalid_percent_encoding"):
        _ = decode_strict("%2")
    with assert_raises(contains="invalid_percent_encoding"):
        _ = decode_strict("%2G")


def test_tilde_form_vs_rfc_unreserved() raises:
    assert_equal(encode("~", EncodeSet.FormUrlencoded), "%7E")
    assert_equal(encode("~", EncodeSet.RfcUnreserved), "~")


def test_utf8_round_trip_component() raises:
    var original = "é日本語😀"
    var encoded = encode(original, EncodeSet.Component)
    assert_equal(decode_utf8_strict(encoded), original)
    assert_equal(decode_utf8_lenient(encoded), original)


def test_decode_lenient_null_byte() raises:
    _assert_bytes(decode_lenient("%00"), [UInt8(0)])


def test_rfc_unreserved_ascii_unchanged() raises:
    var unreserved = (
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )
    assert_equal(encode(unreserved, EncodeSet.RfcUnreserved), unreserved)


def test_plus_is_not_space_in_generic_decode() raises:
    _assert_bytes(decode_lenient("+"), [UInt8(0x2B)])
    _assert_bytes(decode_strict("+"), [UInt8(0x2B)])


def test_decode_hex_is_case_insensitive() raises:
    _assert_bytes(decode_lenient("%2f"), [UInt8(0x2F)])
    _assert_bytes(decode_strict("%2F"), [UInt8(0x2F)])


def test_component_encodes_percent_path_does_not() raises:
    assert_equal(encode("%", EncodeSet.Component), "%25")
    assert_equal(encode("%", EncodeSet.Path), "%")
    assert_equal(encode("%", EncodeSet.FormUrlencoded), "%25")


def test_whatwg_userinfo_examples() raises:
    assert_equal(encode("≡", EncodeSet.Userinfo), "%E2%89%A1")
    assert_equal(encode("Say what‽", EncodeSet.Userinfo), "Say%20what%E2%80%BD")


def test_query_vs_fragment_hash() raises:
    assert_equal(encode("#", EncodeSet.Query), "%23")
    assert_equal(encode("#", EncodeSet.Fragment), "#")


def test_special_query_encodes_apostrophe() raises:
    assert_equal(encode("'", EncodeSet.Query), "'")
    assert_equal(encode("'", EncodeSet.SpecialQuery), "%27")


def test_c0_leaves_printable_ascii() raises:
    assert_equal(encode("~", EncodeSet.C0Control), "~")
    assert_equal(encode(" ", EncodeSet.C0Control), " ")


def test_rfc_path_allows_pchar() raises:
    assert_equal(encode(":@", EncodeSet.RfcPath), ":@")
    assert_equal(encode("/", EncodeSet.RfcPath), "%2F")
    assert_equal(encode("?", EncodeSet.RfcQuery), "?")
    assert_equal(encode("/", EncodeSet.RfcQuery), "/")
    assert_equal(encode("?", EncodeSet.RfcFragment), "?")


def test_form_leaves_star_dash_dot_underscore() raises:
    assert_equal(encode("*-._", EncodeSet.FormUrlencoded), "*-._")
    assert_equal(encode("!", EncodeSet.FormUrlencoded), "%21")


def test_decode_utf8_rejects_invalid_bytes() raises:
    with assert_raises(contains="invalid_utf8"):
        _ = decode_utf8_lenient("%FF")
    with assert_raises(contains="invalid_utf8"):
        _ = decode_utf8_strict("%FF")


def test_encode_set_names_are_distinct() raises:
    assert_true(EncodeSet.Path != EncodeSet.Query)
    assert_equal(String(EncodeSet.FormUrlencoded), "FormUrlencoded")


def test_incomplete_percent_lenient_copies() raises:
    _assert_bytes(decode_lenient("%2"), [UInt8(0x25), UInt8(0x32)])
    _assert_bytes(decode_lenient("a%"), [UInt8(0x61), UInt8(0x25)])


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
