from heat_url.error import ParseError
from heat_url.profile import ParseProfile


# Named percent-encode set. Membership is the set of code points that are encoded
# (WHATWG URL Standard §1.3; RFC 3986 §2 component helpers).
@fieldwise_init
struct EncodeSet(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    var _variant: Int

    comptime C0Control = Self(_variant=0)
    comptime Fragment = Self(_variant=1)
    comptime Query = Self(_variant=2)
    comptime SpecialQuery = Self(_variant=3)
    comptime Path = Self(_variant=4)
    comptime Userinfo = Self(_variant=5)
    comptime Component = Self(_variant=6)
    comptime FormUrlencoded = Self(_variant=7)
    comptime RfcUnreserved = Self(_variant=8)
    comptime RfcUserinfo = Self(_variant=9)
    comptime RfcRegName = Self(_variant=10)
    comptime RfcPath = Self(_variant=11)
    comptime RfcQuery = Self(_variant=12)
    comptime RfcFragment = Self(_variant=13)

    def __eq__(self, other: Self) -> Bool:
        return self._variant == other._variant

    def name(self) -> StaticString:
        if self._variant == 0:
            return "C0Control"
        if self._variant == 1:
            return "Fragment"
        if self._variant == 2:
            return "Query"
        if self._variant == 3:
            return "SpecialQuery"
        if self._variant == 4:
            return "Path"
        if self._variant == 5:
            return "Userinfo"
        if self._variant == 6:
            return "Component"
        if self._variant == 7:
            return "FormUrlencoded"
        if self._variant == 8:
            return "RfcUnreserved"
        if self._variant == 9:
            return "RfcUserinfo"
        if self._variant == 10:
            return "RfcRegName"
        if self._variant == 11:
            return "RfcPath"
        if self._variant == 12:
            return "RfcQuery"
        return "RfcFragment"

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.name())

    # True when this UTF-8 byte's isomorphic code point is in the encode set.
    def encodes(self, byte: UInt8) -> Bool:
        if byte <= 0x1F or byte >= 0x7F:
            return True
        var v = self._variant
        if v == 0:
            return False
        if v == 1:
            return _in_fragment_extra(byte)
        if v == 2:
            return _in_query_extra(byte)
        if v == 3:
            return _in_query_extra(byte) or byte == 0x27
        if v == 4:
            return _in_path_extra(byte)
        if v == 5:
            return _in_userinfo_extra(byte)
        if v == 6:
            return _in_component_extra(byte)
        if v == 7:
            return _in_form_extra(byte)
        if v == 8:
            return not _is_unreserved(byte)
        if v == 9:
            return not (
                _is_unreserved(byte) or _is_sub_delim(byte) or byte == 0x3A
            )
        if v == 10:
            return not (_is_unreserved(byte) or _is_sub_delim(byte))
        if v == 11:
            return not _is_pchar(byte)
        return not (_is_pchar(byte) or byte == 0x2F or byte == 0x3F)


# UTF-8 percent-encode (WHATWG §1.3; RFC 3986 §2.1 uppercase hex).
def encode(
    input: String, set: EncodeSet, space_as_plus: Bool = False
) -> String:
    var src = input.as_bytes()
    var n = len(src)
    var out = List[UInt8](capacity=n * 3)
    var i = 0
    while i < n:
        var b = src[i]
        if space_as_plus and b == 0x20:
            out.append(UInt8(0x2B))
        elif not set.encodes(b):
            out.append(b)
        else:
            out.append(UInt8(0x25))
            out.append(_hex_upper(Int(b >> 4)))
            out.append(_hex_upper(Int(b & 0xF)))
        i += 1
    return String(unsafe_from_utf8=out)


# WHATWG percent-decode: stray `%` is copied through (URL Standard §1.3).
def decode_lenient(input: String) -> List[UInt8]:
    var src = input.as_bytes()
    var n = len(src)
    var out = List[UInt8](capacity=n)
    var i = 0
    while i < n:
        var b = src[i]
        if b == 0x25 and i + 2 < n:
            var hi = _hex_nibble(src[i + 1])
            var lo = _hex_nibble(src[i + 2])
            if hi >= 0 and lo >= 0:
                out.append(UInt8((hi << 4) | lo))
                i += 3
                continue
        out.append(b)
        i += 1
    return out^


# RFC 3986 §2.1: `%` not followed by two HEXDIG is a parse failure.
def decode_strict(input: String) raises ParseError -> List[UInt8]:
    var src = input.as_bytes()
    var n = len(src)
    var out = List[UInt8](capacity=n)
    var i = 0
    while i < n:
        var b = src[i]
        if b == 0x25:
            if i + 2 >= n:
                raise ParseError.invalid_percent_encoding(
                    _codepoint_index(input, i)
                )
            var hi = _hex_nibble(src[i + 1])
            var lo = _hex_nibble(src[i + 2])
            if hi < 0 or lo < 0:
                raise ParseError.invalid_percent_encoding(
                    _codepoint_index(input, i)
                )
            out.append(UInt8((hi << 4) | lo))
            i += 3
            continue
        out.append(b)
        i += 1
    return out^


# WHATWG percent-decode then UTF-8 decode without BOM (fails on invalid UTF-8).
def decode_utf8_lenient(input: String) raises ParseError -> String:
    return _utf8_from_bytes(decode_lenient(input), ParseProfile.whatwg)


# RFC percent-decode then UTF-8 decode without BOM (fails on invalid UTF-8).
def decode_utf8_strict(input: String) raises ParseError -> String:
    return _utf8_from_bytes(decode_strict(input), ParseProfile.rfc3986)


def _utf8_from_bytes(
    bytes: List[UInt8], profile: ParseProfile
) raises ParseError -> String:
    try:
        return String(from_utf8=bytes)
    except _:
        raise ParseError.invalid_utf8(profile)


def _codepoint_index(input: String, byte_index: Int) -> Int:
    return String(input[byte=0:byte_index]).count_codepoints()


def _hex_upper(nibble: Int) -> UInt8:
    if nibble < 10:
        return UInt8(0x30 + nibble)
    return UInt8(0x41 + nibble - 10)


def _hex_nibble(b: UInt8) -> Int:
    if b >= 0x30 and b <= 0x39:
        return Int(b) - 0x30
    if b >= 0x41 and b <= 0x46:
        return Int(b) - 0x41 + 10
    if b >= 0x61 and b <= 0x66:
        return Int(b) - 0x61 + 10
    return -1


def _in_fragment_extra(b: UInt8) -> Bool:
    return b == 0x20 or b == 0x22 or b == 0x3C or b == 0x3E or b == 0x60


def _in_query_extra(b: UInt8) -> Bool:
    return b == 0x20 or b == 0x22 or b == 0x23 or b == 0x3C or b == 0x3E


def _in_path_extra(b: UInt8) -> Bool:
    return (
        _in_query_extra(b)
        or b == 0x3F
        or b == 0x5E
        or b == 0x60
        or b == 0x7B
        or b == 0x7D
    )


def _in_userinfo_extra(b: UInt8) -> Bool:
    return (
        _in_path_extra(b)
        or b == 0x2F
        or b == 0x3A
        or b == 0x3B
        or b == 0x3D
        or b == 0x40
        or b == 0x5B
        or b == 0x5C
        or b == 0x5D
        or b == 0x7C
    )


def _in_component_extra(b: UInt8) -> Bool:
    return (
        _in_userinfo_extra(b)
        or b == 0x24
        or b == 0x25
        or b == 0x26
        or b == 0x2B
        or b == 0x2C
    )


def _in_form_extra(b: UInt8) -> Bool:
    return (
        _in_component_extra(b)
        or b == 0x21
        or b == 0x27
        or b == 0x28
        or b == 0x29
        or b == 0x7E
    )


def _is_alpha(b: UInt8) -> Bool:
    return (b >= 0x41 and b <= 0x5A) or (b >= 0x61 and b <= 0x7A)


def _is_digit(b: UInt8) -> Bool:
    return b >= 0x30 and b <= 0x39


def _is_unreserved(b: UInt8) -> Bool:
    return (
        _is_alpha(b)
        or _is_digit(b)
        or b == 0x2D
        or b == 0x2E
        or b == 0x5F
        or b == 0x7E
    )


def _is_sub_delim(b: UInt8) -> Bool:
    return (
        b == 0x21
        or b == 0x24
        or b == 0x26
        or b == 0x27
        or b == 0x28
        or b == 0x29
        or b == 0x2A
        or b == 0x2B
        or b == 0x2C
        or b == 0x3B
        or b == 0x3D
    )


def _is_pchar(b: UInt8) -> Bool:
    return _is_unreserved(b) or _is_sub_delim(b) or b == 0x3A or b == 0x40
