from heat_url import to_ascii, to_unicode
from std.testing import assert_true, TestSuite


def _read_file(path: String) raises -> String:
    var f = open(path, "r")
    var content = f.read()
    f.close()
    return content^


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


def _hex_nibble(ch: Int) -> Int:
    if ch >= 0x30 and ch <= 0x39:
        return ch - 0x30
    if ch >= 0x41 and ch <= 0x46:
        return ch - 0x41 + 10
    if ch >= 0x61 and ch <= 0x66:
        return ch - 0x61 + 10
    return -1


def _append_cp(mut out: List[UInt8], cp: Int):
    if cp < 0x80:
        out.append(UInt8(cp))
    elif cp < 0x800:
        out.append(UInt8(0xC0 | (cp >> 6)))
        out.append(UInt8(0x80 | (cp & 0x3F)))
    elif cp < 0x10000:
        out.append(UInt8(0xE0 | (cp >> 12)))
        out.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
        out.append(UInt8(0x80 | (cp & 0x3F)))
    else:
        out.append(UInt8(0xF0 | (cp >> 18)))
        out.append(UInt8(0x80 | ((cp >> 12) & 0x3F)))
        out.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
        out.append(UInt8(0x80 | (cp & 0x3F)))


def _unescape(s: String) raises -> Optional[String]:
    var b = s.as_bytes()
    var out = List[UInt8]()
    var i = 0
    var n = len(b)
    while i < n:
        var c = Int(b[i])
        if c == 0x5C and i + 1 < n:
            var nxt = Int(b[i + 1])
            if nxt == 0x75 and i + 6 <= n:
                var cp = 0
                var k = 0
                var ok = True
                while k < 4:
                    var nib = _hex_nibble(Int(b[i + 2 + k]))
                    if nib < 0:
                        ok = False
                        break
                    cp = (cp << 4) + nib
                    k += 1
                if ok:
                    if cp >= 0xD800 and cp <= 0xDFFF:
                        return Optional[String](None)
                    _append_cp(out, cp)
                    i += 6
                    continue
            if nxt == 0x78 and i + 3 < n and Int(b[i + 2]) == 0x7B:
                var j = i + 3
                var cp2 = 0
                var digits = 0
                while j < n and Int(b[j]) != 0x7D:
                    var nib2 = _hex_nibble(Int(b[j]))
                    if nib2 < 0:
                        break
                    cp2 = (cp2 << 4) + nib2
                    digits += 1
                    j += 1
                if digits > 0 and j < n and Int(b[j]) == 0x7D:
                    if cp2 >= 0xD800 and cp2 <= 0xDFFF:
                        return Optional[String](None)
                    _append_cp(out, cp2)
                    i = j + 1
                    continue
        out.append(UInt8(c))
        i += 1
    return Optional(String(unsafe_from_utf8=out))


def _split_semi(s: String) -> List[String]:
    var out = List[String]()
    var b = s.as_bytes()
    var start = 0
    var i = 0
    while i < len(b):
        if Int(b[i]) == 0x3B:
            out.append(String(s[byte=start:i]))
            start = i + 1
        i += 1
    out.append(String(s[byte = start : len(b)]))
    return out^


def _strip_hash_comment(s: String) -> String:
    var b = s.as_bytes()
    var i = 0
    while i < len(b):
        if Int(b[i]) == 0x23:
            if i == 0:
                return String("")
            var prev = Int(b[i - 1])
            if prev == 0x20 or prev == 0x09 or prev == 0x3B:
                return String(s[byte=0:i])
        i += 1
    return s


def _field_value(raw: String, inherit: String) raises -> Optional[String]:
    var t = _trim(raw)
    if t.byte_length() == 0:
        return Optional(inherit.copy())
    if t == '""':
        return Optional(String(""))
    return _unescape(t)


def _parse_status(raw: String) -> List[String]:
    var t = _trim(raw)
    var out = List[String]()
    if t.byte_length() == 0 or t == "[]":
        return out^
    if Int(t.as_bytes()[0]) != 0x5B:
        return out^
    var inner = _trim(String(t[byte = 1 : t.byte_length() - 1]))
    if inner.byte_length() == 0:
        return out^
    var b = inner.as_bytes()
    var start = 0
    var i = 0
    while i <= len(b):
        if i == len(b) or Int(b[i]) == 0x2C:
            var tok = _trim(String(inner[byte=start:i]))
            if tok.byte_length() > 0:
                out.append(tok^)
            start = i + 1
        i += 1
    return out^


def _status_active(
    codes: List[String], *, whatwg_unicode: Bool
) -> List[String]:
    var out = List[String]()
    var i = 0
    while i < len(codes):
        var c = codes[i]
        var drop = False
        if whatwg_unicode:
            # WHATWG ToUnicode: STD3/hyphens off; VerifyDnsLength is not used
            # (UTS #46: ignore U1, V2, V3, A4_1, A4_2; X4_2 is the toUnicode
            # empty-label code that replaced A4_2).
            if (
                c == "U1"
                or c == "V2"
                or c == "V3"
                or c == "A4_1"
                or c == "A4_2"
                or c == "X4_2"
            ):
                drop = True
        if not drop:
            out.append(c.copy())
        i += 1
    return out^


def test_idna_test_v2_non_transitional() raises:
    var text = _read_file("test/data/IDNATestV2.txt")
    var lines = _split_lines(text)
    var failures = List[String]()
    var ran = 0
    var skipped = 0
    var i = 0
    while i < len(lines):
        var raw_line = lines[i]
        i += 1
        var stripped = _trim(_strip_hash_comment(raw_line))
        if stripped.byte_length() == 0:
            continue
        var cols = _split_semi(stripped)
        if len(cols) < 5:
            continue
        var source_opt = _field_value(cols[0], String(""))
        if source_opt is None:
            skipped += 1
            continue
        var source = source_opt.value()
        var uni_opt = _field_value(cols[1], source)
        if uni_opt is None:
            skipped += 1
            continue
        var expected_unicode = uni_opt.value()
        var uni_status = _status_active(
            _parse_status(cols[2]), whatwg_unicode=True
        )
        var ascii_inherit = expected_unicode.copy()
        var ascii_opt = _field_value(cols[3], ascii_inherit)
        if ascii_opt is None:
            skipped += 1
            continue
        var expected_ascii = ascii_opt.value()
        var ascii_status_raw = _parse_status(cols[4])
        if _trim(cols[4]).byte_length() == 0:
            ascii_status_raw = _parse_status(cols[2])
        var ascii_status = _status_active(
            ascii_status_raw, whatwg_unicode=False
        )
        ran += 1

        var uni_err = False
        var uni_got = String("")
        try:
            uni_got = to_unicode(source)
        except _:
            uni_err = True
        if len(uni_status) == 0:
            if uni_err:
                failures.append("to_unicode unexpected error source=" + source)
            elif uni_got != expected_unicode:
                failures.append(
                    "to_unicode source="
                    + source
                    + " got="
                    + uni_got
                    + " expected="
                    + expected_unicode
                )
        else:
            if not uni_err:
                failures.append(
                    "to_unicode unexpected success source=" + source
                )

        var ascii_err = False
        var ascii_got = String("")
        try:
            ascii_got = to_ascii(source, be_strict=True)
        except _:
            ascii_err = True
        if len(ascii_status) == 0:
            if ascii_err:
                failures.append("to_ascii unexpected error source=" + source)
            elif ascii_got != expected_ascii:
                failures.append(
                    "to_ascii source="
                    + source
                    + " got="
                    + ascii_got
                    + " expected="
                    + expected_ascii
                )
        else:
            if not ascii_err:
                failures.append("to_ascii unexpected success source=" + source)

    var msg = (
        "IDNATestV2 ran="
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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
