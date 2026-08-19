from heat_url.error import IdnaError
from heat_url.idna_data import (
    BIDI_RANGES_HEX,
    CCC_RANGES_HEX,
    COMPOSE_HEX,
    DECOMP_HEX,
    DECOMP_SEQ_HEX,
    JOIN_RANGES_HEX,
    MAP_RANGES_HEX,
    MAP_REPL_HEX,
    MARK_RANGES_HEX,
)
from heat_url.limits import (
    DEFAULT_MAX_IDNA_LABELS,
    DEFAULT_MAX_INPUT_CODEPOINTS,
    DNS_MAX_DOMAIN_OCTETS,
    DNS_MAX_LABEL_OCTETS,
)
from heat_url.punycode import punycode_decode, punycode_encode


comptime STATUS_VALID: Int = 0
comptime STATUS_IGNORED: Int = 1
comptime STATUS_MAPPED: Int = 2
comptime STATUS_DEVIATION: Int = 3
comptime STATUS_DISALLOWED: Int = 4

comptime BIDI_L: Int = 0
comptime BIDI_R: Int = 1
comptime BIDI_AL: Int = 2
comptime BIDI_AN: Int = 3
comptime BIDI_EN: Int = 4
comptime BIDI_ES: Int = 5
comptime BIDI_CS: Int = 6
comptime BIDI_ET: Int = 7
comptime BIDI_ON: Int = 8
comptime BIDI_BN: Int = 9
comptime BIDI_NSM: Int = 10

comptime JOIN_U: Int = 0
comptime JOIN_L: Int = 1
comptime JOIN_D: Int = 2
comptime JOIN_R: Int = 3
comptime JOIN_T: Int = 4

comptime _SBASE: Int = 0xAC00
comptime _LBASE: Int = 0x1100
comptime _VBASE: Int = 0x1161
comptime _TBASE: Int = 0x11A7
comptime _LCOUNT: Int = 19
comptime _VCOUNT: Int = 21
comptime _TCOUNT: Int = 28
comptime _NCOUNT: Int = 588
comptime _SCOUNT: Int = 11172


# UTS #46 ToASCII with WHATWG §3.3 flags (non-transitional always).
def to_ascii(
    domain: String, *, be_strict: Bool = False
) raises IdnaError -> String:
    var tables = _Tables.load()
    var labels = _process(
        domain,
        tables,
        check_hyphens=be_strict,
        check_bidi=True,
        check_joiners=True,
        use_std3=be_strict,
    )
    var i = 0
    while i < len(labels):
        if not _all_ascii(labels[i]):
            var unicode_label = _string_from_codepoints(labels[i])
            var puny = punycode_encode(unicode_label)
            labels[i] = _ascii_cps("xn--" + puny)
        i += 1
    if be_strict:
        _verify_dns_length(labels)
    return _join_labels(labels)


# UTS #46 ToUnicode with WHATWG domain-to-Unicode flags. Raises on recorded errors.
def to_unicode(domain: String) raises IdnaError -> String:
    var tables = _Tables.load()
    var labels = _process(
        domain,
        tables,
        check_hyphens=False,
        check_bidi=True,
        check_joiners=True,
        use_std3=False,
    )
    return _join_labels(labels)


@fieldwise_init
struct _Tables(Copyable, Movable):
    var map_ranges: List[UInt32]
    var map_repl: List[UInt32]
    var decomp: List[UInt32]
    var decomp_seq: List[UInt32]
    var compose: List[UInt32]
    var ccc_ranges: List[UInt32]
    var mark_ranges: List[UInt32]
    var bidi_ranges: List[UInt32]
    var join_ranges: List[UInt32]

    @staticmethod
    def load() -> Self:
        return _Tables(
            _decode_hex_u32(MAP_RANGES_HEX),
            _decode_hex_u32(MAP_REPL_HEX),
            _decode_hex_u32(DECOMP_HEX),
            _decode_hex_u32(DECOMP_SEQ_HEX),
            _decode_hex_u32(COMPOSE_HEX),
            _decode_hex_u32(CCC_RANGES_HEX),
            _decode_hex_u32(MARK_RANGES_HEX),
            _decode_hex_u32(BIDI_RANGES_HEX),
            _decode_hex_u32(JOIN_RANGES_HEX),
        )

    def status(self, cp: Int) -> Int:
        var idx = _find_range(self.map_ranges, 3, cp)
        if idx < 0:
            return STATUS_DISALLOWED
        var packed = Int(self.map_ranges[idx * 3 + 2])
        return packed & 0xFF

    def map_into(self, cp: Int, mut out: List[Int]):
        var idx = _find_range(self.map_ranges, 3, cp)
        if idx < 0:
            out.append(cp)
            return
        var packed = Int(self.map_ranges[idx * 3 + 2])
        var st = packed & 0xFF
        if st == STATUS_IGNORED:
            return
        if st == STATUS_MAPPED:
            var ln = (packed >> 8) & 0xFF
            var off = packed >> 16
            var j = 0
            while j < ln:
                out.append(Int(self.map_repl[off + j]))
                j += 1
            return
        out.append(cp)

    def ccc(self, cp: Int) -> Int:
        var idx = _find_range(self.ccc_ranges, 3, cp)
        if idx < 0:
            return 0
        return Int(self.ccc_ranges[idx * 3 + 2])

    def is_mark(self, cp: Int) -> Bool:
        return _find_range(self.mark_ranges, 2, cp) >= 0

    def bidi(self, cp: Int) -> Int:
        var idx = _find_range(self.bidi_ranges, 3, cp)
        if idx < 0:
            return BIDI_L
        return Int(self.bidi_ranges[idx * 3 + 2])

    def join(self, cp: Int) -> Int:
        var idx = _find_range(self.join_ranges, 3, cp)
        if idx < 0:
            return JOIN_U
        return Int(self.join_ranges[idx * 3 + 2])

    def nfc(self, cps: List[Int]) -> List[Int]:
        var nfd = List[Int]()
        var i = 0
        while i < len(cps):
            self._decomp_append(cps[i], nfd)
            i += 1
        self._canonical_reorder(nfd)
        return self._compose(nfd^)

    def _decomp_append(self, cp: Int, mut out: List[Int]):
        if _hangul_decomp_append(cp, out):
            return
        var idx = _find_exact(self.decomp, 2, cp)
        if idx < 0:
            out.append(cp)
            return
        var packed = Int(self.decomp[idx * 2 + 1])
        var ln = packed >> 16
        var off = packed & 0xFFFF
        var j = 0
        while j < ln:
            out.append(Int(self.decomp_seq[off + j]))
            j += 1

    def _canonical_reorder(self, mut cps: List[Int]):
        var n = len(cps)
        var i = 1
        while i < n:
            var cc = self.ccc(cps[i])
            if cc != 0:
                var j = i
                while j > 0:
                    var prev = self.ccc(cps[j - 1])
                    if prev == 0 or prev <= cc:
                        break
                    var tmp = cps[j]
                    cps[j] = cps[j - 1]
                    cps[j - 1] = tmp
                    j -= 1
            i += 1

    def _compose(self, nfd: List[Int]) -> List[Int]:
        var n = len(nfd)
        if n == 0:
            return List[Int]()
        var out = List[Int]()
        out.append(nfd[0])
        var starter_idx = 0
        var last_cc = self.ccc(nfd[0])
        if last_cc != 0:
            starter_idx = -1
        var i = 1
        while i < n:
            var ch = nfd[i]
            var cc = self.ccc(ch)
            var combined = -1
            if starter_idx >= 0 and (last_cc < cc or last_cc == 0):
                combined = self._combine(out[starter_idx], ch)
            if combined >= 0:
                out[starter_idx] = combined
                if starter_idx == len(out) - 1:
                    last_cc = 0
            else:
                out.append(ch)
                if cc == 0:
                    starter_idx = len(out) - 1
                    last_cc = 0
                else:
                    last_cc = cc
            i += 1
        return out^

    def _combine(self, a: Int, b: Int) -> Int:
        var hangul = _hangul_compose(a, b)
        if hangul >= 0:
            return hangul
        var n = len(self.compose) // 3
        var lo = 0
        var hi = n - 1
        var ua = UInt32(a)
        var ub = UInt32(b)
        while lo <= hi:
            var mid = lo + (hi - lo) // 2
            var base = mid * 3
            var aa = self.compose[base]
            var bb = self.compose[base + 1]
            if ua < aa or (ua == aa and ub < bb):
                hi = mid - 1
            elif ua > aa or (ua == aa and ub > bb):
                lo = mid + 1
            else:
                return Int(self.compose[base + 2])
        return -1


def _process(
    domain: String,
    ref tables: _Tables,
    *,
    check_hyphens: Bool,
    check_bidi: Bool,
    check_joiners: Bool,
    use_std3: Bool,
) raises IdnaError -> List[List[Int]]:
    var n_cp = domain.count_codepoints()
    if n_cp > DEFAULT_MAX_INPUT_CODEPOINTS:
        raise IdnaError.input_too_long(n_cp, DEFAULT_MAX_INPUT_CODEPOINTS)

    var mapped = List[Int]()
    for cp in domain.codepoints():
        tables.map_into(Int(cp), mapped)
    if len(mapped) > DEFAULT_MAX_INPUT_CODEPOINTS:
        raise IdnaError.input_too_long(
            len(mapped), DEFAULT_MAX_INPUT_CODEPOINTS
        )

    var normalized = tables.nfc(mapped^)
    var labels = _split_dots(normalized^)
    if len(labels) > DEFAULT_MAX_IDNA_LABELS:
        raise IdnaError.too_many_labels(len(labels), DEFAULT_MAX_IDNA_LABELS)

    var converted = List[List[Int]]()
    var i = 0
    while i < len(labels):
        converted.append(_convert_ace(labels[i].copy()))
        i += 1

    var is_bidi = False
    if check_bidi:
        is_bidi = _domain_is_bidi(tables, converted)

    i = 0
    while i < len(converted):
        _validate(
            tables,
            converted[i],
            check_hyphens=check_hyphens,
            check_bidi=check_bidi and is_bidi,
            check_joiners=check_joiners,
            use_std3=use_std3,
        )
        i += 1
    return converted^


def _convert_ace(var label: List[Int]) raises IdnaError -> List[Int]:
    if not _starts_with_xn(label):
        return label^
    var i = 0
    while i < len(label):
        if label[i] > 0x7F:
            raise IdnaError.invalid_ace()
        i += 1
    var rest = _string_from_codepoints_from(label, 4)
    var decoded = punycode_decode(rest)
    var dcps = _codepoints(decoded)
    if len(dcps) == 0 or _all_ascii(dcps):
        raise IdnaError.invalid_ace()
    return dcps^


def _validate(
    ref tables: _Tables,
    ref label: List[Int],
    *,
    check_hyphens: Bool,
    check_bidi: Bool,
    check_joiners: Bool,
    use_std3: Bool,
) raises IdnaError:
    var n = len(label)
    if n == 0:
        return
    var nfc_form = tables.nfc(_copy_cps(label))
    if not _same_cps(nfc_form, label):
        raise IdnaError.not_nfc()
    if check_hyphens:
        if n >= 4 and label[2] == 0x2D and label[3] == 0x2D:
            raise IdnaError.check_hyphens()
        if label[0] == 0x2D or label[n - 1] == 0x2D:
            raise IdnaError.check_hyphens()
    else:
        if _starts_with_xn(label):
            raise IdnaError.invalid_ace()
    var i = 0
    while i < n:
        if label[i] == 0x2E:
            raise IdnaError.disallowed()
        i += 1
    if tables.is_mark(label[0]):
        raise IdnaError.leading_combining_mark()
    i = 0
    while i < n:
        var cp = label[i]
        var st = tables.status(cp)
        if st != STATUS_VALID and st != STATUS_DEVIATION:
            raise IdnaError.disallowed()
        if use_std3 and cp <= 0x7F:
            var ldh = (
                (cp >= 0x61 and cp <= 0x7A)
                or (cp >= 0x30 and cp <= 0x39)
                or cp == 0x2D
            )
            if not ldh:
                raise IdnaError.std3()
        i += 1
    if check_joiners:
        _check_joiners(tables, label)
    if check_bidi:
        _check_bidi_label(tables, label)


def _check_joiners(ref tables: _Tables, ref label: List[Int]) raises IdnaError:
    var n = len(label)
    var i = 0
    while i < n:
        var cp = label[i]
        if cp == 0x200C:
            var ok = False
            if i > 0 and tables.ccc(label[i - 1]) == 9:
                ok = True
            else:
                var left = i - 1
                while left >= 0 and tables.join(label[left]) == JOIN_T:
                    left -= 1
                var right = i + 1
                while right < n and tables.join(label[right]) == JOIN_T:
                    right += 1
                if left >= 0 and right < n:
                    var jl = tables.join(label[left])
                    var jr = tables.join(label[right])
                    if (jl == JOIN_L or jl == JOIN_D) and (
                        jr == JOIN_R or jr == JOIN_D
                    ):
                        ok = True
            if not ok:
                raise IdnaError.check_joiners()
        elif cp == 0x200D:
            if not (i > 0 and tables.ccc(label[i - 1]) == 9):
                raise IdnaError.check_joiners()
        i += 1


def _check_bidi_label(
    ref tables: _Tables, ref label: List[Int]
) raises IdnaError:
    var first = tables.bidi(label[0])
    var rtl = first == BIDI_R or first == BIDI_AL
    if not (first == BIDI_L or rtl):
        raise IdnaError.check_bidi()
    var n = len(label)
    var saw_en = False
    var saw_an = False
    var i = 0
    while i < n:
        var bc = tables.bidi(label[i])
        if rtl:
            if not _bidi_ok_rtl(bc):
                raise IdnaError.check_bidi()
            if bc == BIDI_EN:
                saw_en = True
            if bc == BIDI_AN:
                saw_an = True
        else:
            if not _bidi_ok_ltr(bc):
                raise IdnaError.check_bidi()
        i += 1
    if rtl and saw_en and saw_an:
        raise IdnaError.check_bidi()
    var last = _last_non_nsm(tables, label)
    if last < 0:
        raise IdnaError.check_bidi()
    var end_bc = tables.bidi(label[last])
    if rtl:
        if not (
            end_bc == BIDI_R
            or end_bc == BIDI_AL
            or end_bc == BIDI_EN
            or end_bc == BIDI_AN
        ):
            raise IdnaError.check_bidi()
    else:
        if not (end_bc == BIDI_L or end_bc == BIDI_EN):
            raise IdnaError.check_bidi()


def _bidi_ok_rtl(bc: Int) -> Bool:
    return (
        bc == BIDI_R
        or bc == BIDI_AL
        or bc == BIDI_AN
        or bc == BIDI_EN
        or bc == BIDI_ES
        or bc == BIDI_CS
        or bc == BIDI_ET
        or bc == BIDI_ON
        or bc == BIDI_BN
        or bc == BIDI_NSM
    )


def _bidi_ok_ltr(bc: Int) -> Bool:
    return (
        bc == BIDI_L
        or bc == BIDI_EN
        or bc == BIDI_ES
        or bc == BIDI_CS
        or bc == BIDI_ET
        or bc == BIDI_ON
        or bc == BIDI_BN
        or bc == BIDI_NSM
    )


def _last_non_nsm(ref tables: _Tables, ref label: List[Int]) -> Int:
    var i = len(label) - 1
    while i >= 0:
        if tables.bidi(label[i]) != BIDI_NSM:
            return i
        i -= 1
    return -1


def _domain_is_bidi(ref tables: _Tables, ref labels: List[List[Int]]) -> Bool:
    var i = 0
    while i < len(labels):
        var j = 0
        var n = len(labels[i])
        while j < n:
            var bc = tables.bidi(labels[i][j])
            if bc == BIDI_R or bc == BIDI_AL or bc == BIDI_AN:
                return True
            j += 1
        i += 1
    return False


def _verify_dns_length(ref labels: List[List[Int]]) raises IdnaError:
    var n = len(labels)
    var end = n
    if n > 0 and len(labels[n - 1]) == 0:
        raise IdnaError.dns_length()
    var total = 0
    var i = 0
    while i < end:
        var lab_len = len(labels[i])
        if lab_len < 1 or lab_len > DNS_MAX_LABEL_OCTETS:
            raise IdnaError.dns_length()
        if i > 0:
            total += 1
        total += lab_len
        i += 1
    if total < 1 or total > DNS_MAX_DOMAIN_OCTETS:
        raise IdnaError.dns_length()


def _split_dots(cps: List[Int]) -> List[List[Int]]:
    var labels = List[List[Int]]()
    var cur = List[Int]()
    var i = 0
    while i < len(cps):
        if cps[i] == 0x2E:
            labels.append(cur^)
            cur = List[Int]()
        else:
            cur.append(cps[i])
        i += 1
    labels.append(cur^)
    return labels^


def _join_labels(ref labels: List[List[Int]]) -> String:
    var out = List[Int]()
    var i = 0
    while i < len(labels):
        if i > 0:
            out.append(0x2E)
        var j = 0
        var n = len(labels[i])
        while j < n:
            out.append(labels[i][j])
            j += 1
        i += 1
    return _string_from_codepoints(out)


def _starts_with_xn(ref label: List[Int]) -> Bool:
    return (
        len(label) >= 4
        and label[0] == 0x78
        and label[1] == 0x6E
        and label[2] == 0x2D
        and label[3] == 0x2D
    )


def _all_ascii(ref label: List[Int]) -> Bool:
    var i = 0
    while i < len(label):
        if label[i] > 0x7F:
            return False
        i += 1
    return True


def _same_cps(ref a: List[Int], ref b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    var i = 0
    while i < len(a):
        if a[i] != b[i]:
            return False
        i += 1
    return True


def _copy_cps(ref cps: List[Int]) -> List[Int]:
    var out = List[Int]()
    var i = 0
    while i < len(cps):
        out.append(cps[i])
        i += 1
    return out^


def _codepoints(s: String) -> List[Int]:
    var out = List[Int]()
    for cp in s.codepoints():
        out.append(Int(cp))
    return out^


def _ascii_cps(s: String) -> List[Int]:
    var out = List[Int]()
    var src = s.as_bytes()
    var i = 0
    while i < len(src):
        out.append(Int(src[i]))
        i += 1
    return out^


def _string_from_codepoints(ref cps: List[Int]) -> String:
    var out = List[UInt8]()
    var i = 0
    while i < len(cps):
        _utf8_append(out, cps[i])
        i += 1
    return String(unsafe_from_utf8=out)


def _string_from_codepoints_from(ref cps: List[Int], start: Int) -> String:
    var out = List[UInt8]()
    var i = start
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


def _decode_hex_u32(hex: String) -> List[UInt32]:
    var src = hex.as_bytes()
    var n = len(src)
    var out = List[UInt32](capacity=n // 8)
    var i = 0
    while i + 8 <= n:
        var v = 0
        var k = 0
        while k < 8:
            var x = Int(src[i + k])
            var d: Int
            if x >= 48 and x <= 57:
                d = x - 48
            elif x >= 97 and x <= 102:
                d = x - 87
            else:
                d = x - 55
            v = (v << 4) + d
            k += 1
        out.append(UInt32(v))
        i += 8
    return out^


def _find_range(ref data: List[UInt32], stride: Int, cp: Int) -> Int:
    var n = len(data) // stride
    if n == 0:
        return -1
    var lo = 0
    var hi = n - 1
    var c = UInt32(cp)
    while lo <= hi:
        var mid = lo + (hi - lo) // 2
        var base = mid * stride
        if c < data[base]:
            hi = mid - 1
        elif c > data[base + 1]:
            lo = mid + 1
        else:
            return mid
    return -1


def _find_exact(ref data: List[UInt32], stride: Int, cp: Int) -> Int:
    var n = len(data) // stride
    if n == 0:
        return -1
    var lo = 0
    var hi = n - 1
    var c = UInt32(cp)
    while lo <= hi:
        var mid = lo + (hi - lo) // 2
        var key = data[mid * stride]
        if c < key:
            hi = mid - 1
        elif c > key:
            lo = mid + 1
        else:
            return mid
    return -1


def _hangul_decomp_append(cp: Int, mut out: List[Int]) -> Bool:
    var sindex = cp - _SBASE
    if sindex < 0 or sindex >= _SCOUNT:
        return False
    out.append(_LBASE + sindex // _NCOUNT)
    out.append(_VBASE + (sindex % _NCOUNT) // _TCOUNT)
    var t = sindex % _TCOUNT
    if t != 0:
        out.append(_TBASE + t)
    return True


def _hangul_compose(a: Int, b: Int) -> Int:
    if a >= _LBASE and a < _LBASE + _LCOUNT:
        if b >= _VBASE and b < _VBASE + _VCOUNT:
            return _SBASE + (a - _LBASE) * _NCOUNT + (b - _VBASE) * _TCOUNT
    var sindex = a - _SBASE
    if sindex >= 0 and sindex < _SCOUNT and sindex % _TCOUNT == 0:
        if b > _TBASE and b < _TBASE + _TCOUNT:
            return a + (b - _TBASE)
    return -1
