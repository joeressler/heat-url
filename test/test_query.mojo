from heat_url import (
    EncodeSet,
    QueryList,
    encode,
)
from std.testing import (
    assert_equal,
    assert_false,
    assert_raises,
    assert_true,
    TestSuite,
)


def test_duplicate_names_get_and_get_all() raises:
    var q = QueryList.parse("a=b&a=c")
    assert_equal(len(q), 2)
    var first = q.get("a")
    assert_true(first is not None)
    assert_equal(first.value(), "b")
    var all = q.get_all("a")
    assert_equal(len(all), 2)
    assert_equal(all[0], "b")
    assert_equal(all[1], "c")


def test_empty_name_value_and_missing_equals() raises:
    var empty_name = QueryList.parse("=v")
    assert_equal(len(empty_name), 1)
    var n = empty_name.get("")
    assert_true(n is not None)
    assert_equal(n.value(), "v")

    var empty_value = QueryList.parse("k=")
    var ev = empty_value.get("k")
    assert_true(ev is not None)
    assert_equal(ev.value(), "")

    var no_eq = QueryList.parse("k")
    var nv = no_eq.get("k")
    assert_true(nv is not None)
    assert_equal(nv.value(), "")


def test_skips_empty_ampersand_segments() raises:
    var q = QueryList.parse("a=1&&b=2&")
    assert_equal(len(q), 2)
    assert_equal(q.get("a").value(), "1")
    assert_equal(q.get("b").value(), "2")


def test_percent_encoded_separators_are_data() raises:
    var q = QueryList.parse("a%26b=c%3Dd")
    assert_equal(len(q), 1)
    assert_equal(q.get("a&b").value(), "c=d")


def test_serialize_uses_plus_and_form_set() raises:
    var q = QueryList.parse("a=b c")
    assert_equal(q.serialize(), "a=b+c")
    var with_tilde = QueryList.parse("")
    with_tilde.append("x", "b ~")
    assert_equal(with_tilde.serialize(), "x=b+%7E")


def test_query_list_serialize_differs_from_url_query_set() raises:
    # Specified WHATWG mismatch (spec 05 / §6.2): query-list uses form-urlencoded
    # (`+`, encode `~`); URL serializer uses query/special-query (`%20`, raw `~`).
    var list_out = encode("b ~", EncodeSet.FormUrlencoded, space_as_plus=True)
    var url_out = encode("b ~", EncodeSet.Query)
    assert_equal(list_out, "b+%7E")
    assert_equal(url_out, "b%20~")


def test_tuple_cap_fails_without_truncating() raises:
    with assert_raises(contains="too_many_query_tuples"):
        _ = QueryList.parse("a=1&b=2", max_tuples=1)


def test_form_false_keeps_plus() raises:
    var q = QueryList.parse("a+b=c+d", form=False)
    assert_equal(len(q), 1)
    assert_equal(q.get("a+b").value(), "c+d")


def test_form_true_plus_is_space() raises:
    var q = QueryList.parse("a+b=c+d")
    assert_equal(q.get("a b").value(), "c d")


def test_semicolon_is_not_a_separator() raises:
    var q = QueryList.parse("a=1;b=2")
    assert_equal(len(q), 1)
    assert_equal(q.get("a").value(), "1;b=2")


def test_set_replaces_first_and_drops_later() raises:
    var q = QueryList.parse("a=1&b=2&a=3")
    q.set("a", "x")
    assert_equal(len(q), 2)
    assert_equal(q.get("a").value(), "x")
    assert_equal(len(q.get_all("a")), 1)
    assert_equal(q.get("b").value(), "2")
    q.set("c", "3")
    assert_equal(len(q), 3)
    assert_equal(q.get("c").value(), "3")


def test_has_and_delete_with_optional_value() raises:
    var q = QueryList.parse("a=1&a=2&b=1")
    assert_true(q.has("a"))
    assert_true(q.has("a", Optional("1")))
    assert_false(q.has("a", Optional("9")))
    assert_false(q.has("z"))
    q.delete("a", Optional("1"))
    assert_equal(len(q), 2)
    assert_equal(q.get("a").value(), "2")
    q.delete("a")
    assert_false(q.has("a"))
    assert_equal(len(q), 1)


def test_sort_utf16_code_unit_order() raises:
    # UTF-16: U+1F600 (😀) is D83D DE00, which is less than U+FFFF.
    # UTF-8 disagrees: U+FFFF is EF BF BF, 😀 is F0 9F 98 80 (EF < F0).
    var bytes = List[UInt8](capacity=3)
    bytes.append(UInt8(0xEF))
    bytes.append(UInt8(0xBF))
    bytes.append(UInt8(0xBF))
    var ffff = String(from_utf8=bytes)
    var q = QueryList.parse("")
    q.append(ffff.copy(), "bmp")
    q.append("😀", "emoji")
    q.append("a", "ascii")
    q.sort()
    var serialized = q.serialize()
    var ascii_at = serialized.find("a=ascii")
    var emoji_at = serialized.find("%F0%9F%98%80")
    var ffff_at = serialized.find("%EF%BF%BF")
    assert_true(ascii_at >= 0)
    assert_true(emoji_at >= 0)
    assert_true(ffff_at >= 0)
    assert_true(ascii_at < emoji_at)
    assert_true(emoji_at < ffff_at)


def test_empty_query_serializes_empty() raises:
    var q = QueryList.parse("")
    assert_equal(len(q), 0)
    assert_equal(q.serialize(), "")


def test_does_not_strip_leading_question_mark() raises:
    var q = QueryList.parse("?a=b")
    assert_true(q.has("?a"))
    assert_equal(q.get("?a").value(), "b")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
