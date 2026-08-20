from heat_url import (
    EncodeSet,
    Url,
    encode,
    parse_url,
    serialize_host,
)
from json.cpu import parse_cpu_native_tape
from json.value import Value
from std.testing import assert_equal, assert_true, TestSuite


@fieldwise_init
struct _Skip(Copyable, Movable):
    var input: String
    var base: Optional[String]
    var reason: String


def _read_file(path: String) raises -> String:
    var f = open(path, "r")
    var content = f.read()
    f.close()
    return content^


def _load_json(path: String) raises -> Value:
    return parse_cpu_native_tape(_read_file(path))


def _has(obj: Value, key: String) -> Bool:
    var keys = obj.object_keys()
    var i = 0
    while i < len(keys):
        if keys[i] == key:
            return True
        i += 1
    return False


def _opt_base(obj: Value) raises -> Optional[String]:
    if not _has(obj, "base"):
        return Optional[String](None)
    var b = obj["base"]
    if b.is_null():
        return Optional[String](None)
    return Optional(b.string_value())


def _bases_equal(a: Optional[String], b: Optional[String]) -> Bool:
    if a is None and b is None:
        return True
    if a is None or b is None:
        return False
    return a.value() == b.value()


def _load_skips() raises -> List[_Skip]:
    var text = _read_file("test/data/WHATWG_SKIP.md")
    var lines = _split_lines(text)
    var out = List[_Skip]()
    var i = 0
    while i < len(lines):
        var line = _trim(lines[i])
        if line.byte_length() > 0 and Int(line.as_bytes()[0]) == 0x7B:
            var obj = parse_cpu_native_tape(line)
            out.append(
                _Skip(
                    obj["input"].string_value(),
                    _opt_base(obj),
                    obj["reason"].string_value(),
                )
            )
        i += 1
    return out^


def _is_skipped(
    skips: List[_Skip], input: String, base: Optional[String]
) -> Bool:
    var i = 0
    while i < len(skips):
        if skips[i].input == input and _bases_equal(skips[i].base, base):
            return True
        i += 1
    return False


def _split_lines(s: String) -> List[String]:
    var out = List[String]()
    var b = s.as_bytes()
    var start = 0
    var i = 0
    while i < len(b):
        if Int(b[i]) == 0x0A:
            var end = i
            if end > start and Int(b[end - 1]) == 0x0D:
                end -= 1
            out.append(String(s[byte=start:end]))
            start = i + 1
        i += 1
    if start < len(b):
        var end2 = len(b)
        if end2 > start and Int(b[end2 - 1]) == 0x0D:
            end2 -= 1
        out.append(String(s[byte=start:end2]))
    return out^


def _trim(s: String) -> String:
    var b = s.as_bytes()
    var lo = 0
    var hi = len(b)
    while lo < hi:
        var c = Int(b[lo])
        if c != 0x20 and c != 0x09:
            break
        lo += 1
    while hi > lo:
        var c2 = Int(b[hi - 1])
        if c2 != 0x20 and c2 != 0x09:
            break
        hi -= 1
    return String(s[byte=lo:hi])


def _hostname(url: Url) -> String:
    var h = url.host()
    if h is None:
        return String("")
    return serialize_host(h.value())


def _port_text(url: Url) -> String:
    if url.port is None:
        return String("")
    return String(Int(url.port.value()))


def _host_text(url: Url) -> String:
    var name = _hostname(url)
    if url.port is None:
        return name^
    return name + ":" + _port_text(url)


def _pathname(url: Url) -> String:
    if url.has_opaque_path():
        return url.opaque_path()
    var segs = url.path_segments()
    var out = String("")
    var i = 0
    while i < len(segs):
        out += "/"
        out += segs[i]
        i += 1
    return out^


def _search(url: Url) -> String:
    # URL Standard hash/search getters: null or empty → "".
    if url.query is None or url.query.value().byte_length() == 0:
        return String("")
    return "?" + url.query.value()


def _hash(url: Url) -> String:
    if url.fragment is None or url.fragment.value().byte_length() == 0:
        return String("")
    return "#" + url.fragment.value()


def _case_label(input: String, base: Optional[String]) -> String:
    if base is None:
        return "input=" + input + " base=null"
    return "input=" + input + " base=" + base.value()


def _mismatch(
    mut failures: List[String],
    label: String,
    field: String,
    got: String,
    exp: String,
):
    if got != exp:
        failures.append(
            label + " " + field + " got=" + got + " expected=" + exp
        )


def test_wpt_urltestdata() raises:
    var root = _load_json("test/data/urltestdata.json")
    assert_true(root.is_array())
    var skips = _load_skips()
    var failures = List[String]()
    var ran = 0
    var skipped = 0
    var n = root.array_count()
    var i = 0
    while i < n:
        var item = root[i]
        i += 1
        if item.is_string():
            continue
        if not item.is_object():
            continue
        if not _has(item, "input"):
            continue
        var input = item["input"].string_value()
        var base = _opt_base(item)
        if _is_skipped(skips, input, base):
            skipped += 1
            continue
        ran += 1
        var label = _case_label(input, base)
        var expect_fail = _has(item, "failure") and item["failure"].bool_value()
        var parsed = Optional[Url](None)
        var did_fail = False
        try:
            parsed = Optional(parse_url(input, base))
        except _:
            did_fail = True
        if expect_fail:
            if not did_fail:
                failures.append(label + " unexpected success")
            continue
        if did_fail:
            failures.append(label + " unexpected failure")
            continue
        var url = parsed.value().copy()
        _mismatch(
            failures,
            label,
            "href",
            url.serialize(),
            item["href"].string_value(),
        )
        _mismatch(
            failures,
            label,
            "protocol",
            url.scheme + ":",
            item["protocol"].string_value(),
        )
        _mismatch(
            failures,
            label,
            "username",
            url.username,
            item["username"].string_value(),
        )
        _mismatch(
            failures,
            label,
            "password",
            url.password,
            item["password"].string_value(),
        )
        _mismatch(
            failures,
            label,
            "host",
            _host_text(url),
            item["host"].string_value(),
        )
        _mismatch(
            failures,
            label,
            "hostname",
            _hostname(url),
            item["hostname"].string_value(),
        )
        _mismatch(
            failures,
            label,
            "port",
            _port_text(url),
            item["port"].string_value(),
        )
        _mismatch(
            failures,
            label,
            "pathname",
            _pathname(url),
            item["pathname"].string_value(),
        )
        _mismatch(
            failures,
            label,
            "search",
            _search(url),
            item["search"].string_value(),
        )
        _mismatch(
            failures, label, "hash", _hash(url), item["hash"].string_value()
        )

    var msg = (
        "wpt urltestdata ran="
        + String(ran)
        + " skipped="
        + String(skipped)
        + " failures="
        + String(len(failures))
    )
    if len(failures) > 0:
        var shown = 0
        while shown < len(failures) and shown < 25:
            msg += "\n"
            msg += failures[shown]
            shown += 1
        raise Error(msg)
    assert_true(ran > 100)
    assert_equal(len(failures), 0)


def test_wpt_percent_encoding_utf8() raises:
    var root = _load_json("test/data/percent-encoding.json")
    assert_true(root.is_array())
    var n = root.array_count()
    var i = 0
    while i < n:
        var item = root[i]
        i += 1
        if not item.is_object():
            continue
        var input = item["input"].string_value()
        var out = item["output"]
        if not _has(out, "utf-8"):
            continue
        var expected = out["utf-8"].string_value()
        var got = encode(input, EncodeSet.SpecialQuery)
        assert_equal(got, expected)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
