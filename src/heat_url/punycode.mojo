from heat_url.error import IdnaError
from heat_url.limits import DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS


comptime _BASE: Int = 36
comptime _TMIN: Int = 1
comptime _TMAX: Int = 26
comptime _SKEW: Int = 38
comptime _DAMP: Int = 700
comptime _INITIAL_BIAS: Int = 72
comptime _INITIAL_N: Int = 0x80
comptime _DELIMITER: Int = 0x2D
comptime _MAXINT: Int = 0x7FFFFFFFFFFFFFFF


# RFC 3492 bootstring encode of a single label. ASCII payload without `xn--`.
def punycode_encode(label: String) raises IdnaError -> String:
    var cps = _codepoints(label)
    var input_len = len(cps)
    if input_len > DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS:
        raise IdnaError.punycode_too_long(
            input_len, DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS
        )

    var n = _INITIAL_N
    var delta = 0
    var bias = _INITIAL_BIAS
    var out = List[UInt8]()
    var j = 0
    while j < input_len:
        var c = cps[j]
        if c <= 0x7F:
            out.append(UInt8(c))
        j += 1
    var b = len(out)
    var h = b
    if b > 0:
        out.append(UInt8(_DELIMITER))

    while h < input_len:
        var m = _MAXINT
        j = 0
        while j < input_len:
            var c = cps[j]
            if c >= n and c < m:
                m = c
            j += 1
        delta = _add(delta, _mul(m - n, h + 1))
        n = m
        j = 0
        while j < input_len:
            var c = cps[j]
            if c < n:
                delta = _add(delta, 1)
            if c == n:
                var q = delta
                var k = _BASE
                while True:
                    var t = _threshold(k, bias)
                    if q < t:
                        break
                    out.append(_encode_digit(t + ((q - t) % (_BASE - t))))
                    q = (q - t) // (_BASE - t)
                    k += _BASE
                out.append(_encode_digit(q))
                bias = _adapt(delta, h + 1, h == b)
                delta = 0
                h += 1
            j += 1
        delta += 1
        n += 1

    return String(unsafe_from_utf8=out)


# RFC 3492 bootstring decode of a single label. Input is the payload without `xn--`.
def punycode_decode(ascii_label: String) raises IdnaError -> String:
    var cps = _codepoints(ascii_label)
    var in_len = len(cps)
    var n = _INITIAL_N
    var i = 0
    var bias = _INITIAL_BIAS
    var output = List[Int]()

    var last_delim = -1
    var p = 0
    while p < in_len:
        if cps[p] == _DELIMITER:
            last_delim = p
        p += 1

    var in_idx = 0
    if last_delim >= 0:
        p = 0
        while p < last_delim:
            if cps[p] > 0x7F:
                raise IdnaError.punycode_bad_input(
                    "non-basic code point before delimiter"
                )
            output.append(cps[p])
            p += 1
        in_idx = last_delim + 1

    if len(output) > DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS:
        raise IdnaError.punycode_too_long(
            len(output), DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS
        )

    while in_idx < in_len:
        var oldi = i
        var w = 1
        var k = _BASE
        while True:
            if in_idx >= in_len:
                raise IdnaError.punycode_bad_input("truncated punycode")
            var digit = _digit_value(cps[in_idx])
            in_idx += 1
            if digit < 0:
                raise IdnaError.punycode_bad_input("invalid punycode digit")
            i = _add(i, _mul(digit, w))
            var t = _threshold(k, bias)
            if digit < t:
                break
            w = _mul(w, _BASE - t)
            k += _BASE
        var out_len = len(output)
        bias = _adapt(i - oldi, out_len + 1, oldi == 0)
        n = _add(n, i // (out_len + 1))
        i = i % (out_len + 1)
        if out_len >= DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS:
            raise IdnaError.punycode_too_long(
                out_len + 1, DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS
            )
        _insert(output, i, n)
        i += 1

    return _string_from_codepoints(output)


def _threshold(k: Int, bias: Int) -> Int:
    if k <= bias:
        return _TMIN
    if k >= bias + _TMAX:
        return _TMAX
    return k - bias


def _adapt(delta: Int, numpoints: Int, firsttime: Bool) -> Int:
    var d = delta
    if firsttime:
        d = d // _DAMP
    else:
        d = d // 2
    d = d + d // numpoints
    var k = 0
    while d > ((_BASE - _TMIN) * _TMAX) // 2:
        d = d // (_BASE - _TMIN)
        k += _BASE
    return k + ((_BASE - _TMIN + 1) * d) // (d + _SKEW)


def _encode_digit(d: Int) -> UInt8:
    if d < 26:
        return UInt8(0x61 + d)
    return UInt8(0x30 + d - 26)


def _digit_value(cp: Int) -> Int:
    if cp >= 0x41 and cp <= 0x5A:
        return cp - 0x41
    if cp >= 0x61 and cp <= 0x7A:
        return cp - 0x61
    if cp >= 0x30 and cp <= 0x39:
        return cp - 0x30 + 26
    return -1


def _add(a: Int, b: Int) raises IdnaError -> Int:
    if b > 0 and a > _MAXINT - b:
        raise IdnaError.punycode_overflow()
    return a + b


def _mul(a: Int, b: Int) raises IdnaError -> Int:
    if a > 0 and b > _MAXINT // a:
        raise IdnaError.punycode_overflow()
    return a * b


def _codepoints(s: String) -> List[Int]:
    var out = List[Int]()
    for cp in s.codepoints():
        out.append(Int(cp))
    return out^


def _insert(mut out: List[Int], index: Int, cp: Int):
    var n = List[Int](capacity=len(out) + 1)
    var i = 0
    while i < index:
        n.append(out[i])
        i += 1
    n.append(cp)
    while i < len(out):
        n.append(out[i])
        i += 1
    out = n^


def _string_from_codepoints(cps: List[Int]) -> String:
    var out = List[UInt8]()
    var i = 0
    while i < len(cps):
        _utf8_append(out, cps[i])
        i += 1
    return String(unsafe_from_utf8=out)


def _utf8_append(mut out: List[UInt8], cp: Int):
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
