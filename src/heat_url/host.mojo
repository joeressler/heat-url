from heat_url.error import ParseError
from heat_url.idna import to_ascii
from heat_url.limits import (
    DEFAULT_MAX_AUTHORITY_LENGTH,
    DEFAULT_MAX_INPUT_CODEPOINTS,
)
from heat_url.percent import EncodeSet, decode_utf8_lenient, encode
from heat_url.profile import ParseProfile


comptime _KIND_DOMAIN: Int = 0
comptime _KIND_IPV4: Int = 1
comptime _KIND_IPV6: Int = 2
comptime _KIND_OPAQUE: Int = 3
comptime _KIND_EMPTY: Int = 4
comptime _KIND_IPV_FUTURE: Int = 5
comptime _KIND_REG_NAME: Int = 6


# Eight 16-bit IPv6 pieces (WHATWG §3.1 / RFC 4291).
@fieldwise_init
struct Ipv6Pieces(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    var p0: UInt16
    var p1: UInt16
    var p2: UInt16
    var p3: UInt16
    var p4: UInt16
    var p5: UInt16
    var p6: UInt16
    var p7: UInt16

    @staticmethod
    def zero() -> Self:
        return Ipv6Pieces(
            UInt16(0),
            UInt16(0),
            UInt16(0),
            UInt16(0),
            UInt16(0),
            UInt16(0),
            UInt16(0),
            UInt16(0),
        )

    def __eq__(self, other: Self) -> Bool:
        return (
            self.p0 == other.p0
            and self.p1 == other.p1
            and self.p2 == other.p2
            and self.p3 == other.p3
            and self.p4 == other.p4
            and self.p5 == other.p5
            and self.p6 == other.p6
            and self.p7 == other.p7
        )

    def get(self, i: Int) -> UInt16:
        if i == 0:
            return self.p0
        if i == 1:
            return self.p1
        if i == 2:
            return self.p2
        if i == 3:
            return self.p3
        if i == 4:
            return self.p4
        if i == 5:
            return self.p5
        if i == 6:
            return self.p6
        return self.p7

    def set(mut self, i: Int, value: UInt16):
        if i == 0:
            self.p0 = value
        elif i == 1:
            self.p1 = value
        elif i == 2:
            self.p2 = value
        elif i == 3:
            self.p3 = value
        elif i == 4:
            self.p4 = value
        elif i == 5:
            self.p5 = value
        elif i == 6:
            self.p6 = value
        else:
            self.p7 = value

    def write_to(self, mut writer: Some[Writer]):
        writer.write(_serialize_ipv6(self))


# WHATWG URL Standard §3.1 host.
@fieldwise_init
struct WhatwgHost(Copyable, Equatable, Movable, Writable):
    var _kind: Int
    var _text: String
    var _ipv4: UInt32
    var _ipv6: Ipv6Pieces

    @staticmethod
    def domain(ascii_domain: String) -> Self:
        return WhatwgHost(
            _KIND_DOMAIN, ascii_domain.copy(), UInt32(0), Ipv6Pieces.zero()
        )

    @staticmethod
    def ipv4(addr: UInt32) -> Self:
        return WhatwgHost(_KIND_IPV4, String(""), addr, Ipv6Pieces.zero())

    @staticmethod
    def ipv6(pieces: Ipv6Pieces) -> Self:
        return WhatwgHost(_KIND_IPV6, String(""), UInt32(0), pieces)

    @staticmethod
    def opaque(ascii_host: String) -> Self:
        return WhatwgHost(
            _KIND_OPAQUE, ascii_host.copy(), UInt32(0), Ipv6Pieces.zero()
        )

    @staticmethod
    def empty() -> Self:
        return WhatwgHost(_KIND_EMPTY, String(""), UInt32(0), Ipv6Pieces.zero())

    def __eq__(self, other: Self) -> Bool:
        if self._kind != other._kind:
            return False
        if self._kind == _KIND_IPV4:
            return self._ipv4 == other._ipv4
        if self._kind == _KIND_IPV6:
            return self._ipv6 == other._ipv6
        return self._text == other._text

    def is_domain(self) -> Bool:
        return self._kind == _KIND_DOMAIN

    def is_ipv4(self) -> Bool:
        return self._kind == _KIND_IPV4

    def is_ipv6(self) -> Bool:
        return self._kind == _KIND_IPV6

    def is_opaque(self) -> Bool:
        return self._kind == _KIND_OPAQUE

    def is_empty(self) -> Bool:
        return self._kind == _KIND_EMPTY

    def ipv4_address(self) -> UInt32:
        return self._ipv4

    def ipv6_pieces(self) -> Ipv6Pieces:
        return self._ipv6

    def serialize(self) -> String:
        if self._kind == _KIND_IPV4:
            return _serialize_ipv4(self._ipv4)
        if self._kind == _KIND_IPV6:
            return "[" + _serialize_ipv6(self._ipv6) + "]"
        return self._text.copy()

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.serialize())


# RFC 3986 host: IP-literal / IPv4address / reg-name.
@fieldwise_init
struct RfcHost(Copyable, Equatable, Movable, Writable):
    var _kind: Int
    var _text: String
    var _ipv4: UInt32
    var _ipv6: Ipv6Pieces
    var _zone: String
    var _future_version: String
    var _future_rest: String

    @staticmethod
    def ipv4(addr: UInt32) -> Self:
        return RfcHost(
            _KIND_IPV4,
            String(""),
            addr,
            Ipv6Pieces.zero(),
            String(""),
            String(""),
            String(""),
        )

    @staticmethod
    def ipv6(pieces: Ipv6Pieces, zone: String) -> Self:
        return RfcHost(
            _KIND_IPV6,
            String(""),
            UInt32(0),
            pieces,
            zone.copy(),
            String(""),
            String(""),
        )

    @staticmethod
    def ipv_future(version: String, rest: String) -> Self:
        return RfcHost(
            _KIND_IPV_FUTURE,
            String(""),
            UInt32(0),
            Ipv6Pieces.zero(),
            String(""),
            version.copy(),
            rest.copy(),
        )

    @staticmethod
    def reg_name(name: String) -> Self:
        return RfcHost(
            _KIND_REG_NAME,
            name.copy(),
            UInt32(0),
            Ipv6Pieces.zero(),
            String(""),
            String(""),
            String(""),
        )

    def __eq__(self, other: Self) -> Bool:
        if self._kind != other._kind:
            return False
        if self._kind == _KIND_IPV4:
            return self._ipv4 == other._ipv4
        if self._kind == _KIND_IPV6:
            return self._ipv6 == other._ipv6 and self._zone == other._zone
        if self._kind == _KIND_IPV_FUTURE:
            return (
                self._future_version == other._future_version
                and self._future_rest == other._future_rest
            )
        return self._text == other._text

    def is_ipv4(self) -> Bool:
        return self._kind == _KIND_IPV4

    def is_ipv6(self) -> Bool:
        return self._kind == _KIND_IPV6

    def is_ipv_future(self) -> Bool:
        return self._kind == _KIND_IPV_FUTURE

    def is_reg_name(self) -> Bool:
        return self._kind == _KIND_REG_NAME

    def ipv4_address(self) -> UInt32:
        return self._ipv4

    def ipv6_pieces(self) -> Ipv6Pieces:
        return self._ipv6

    def zone_id(self) -> String:
        return self._zone.copy()

    def serialize(self) -> String:
        if self._kind == _KIND_IPV4:
            return _serialize_ipv4(self._ipv4)
        if self._kind == _KIND_IPV6:
            var inner = _serialize_ipv6(self._ipv6)
            if self._zone.byte_length() > 0:
                inner = inner + "%25" + self._zone
            return "[" + inner + "]"
        if self._kind == _KIND_IPV_FUTURE:
            return "[v" + self._future_version + "." + self._future_rest + "]"
        return self._text.copy()

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.serialize())


# WHATWG URL Standard §3.5 host parser (`isOpaque` selects opaque-host vs domain).
def parse_host_whatwg(
    input: String, *, is_opaque: Bool = False
) raises ParseError -> WhatwgHost:
    _check_host_length(input, ParseProfile.whatwg)
    if input.byte_length() == 0:
        return WhatwgHost.empty()
    if _byte_at(input, 0) == 0x5B:
        if _byte_at(input, input.byte_length() - 1) != 0x5D:
            raise _whatwg_fail(
                "ipv6_unclosed", "IPv6-unclosed", "IPv6 host is unclosed"
            )
        var n = input.byte_length()
        var inner = String(input[byte = 1 : n - 1])
        return WhatwgHost.ipv6(_parse_whatwg_ipv6(inner^))
    if is_opaque:
        return _parse_opaque_host(input)
    var domain = decode_utf8_lenient(input)
    var ascii_domain = _domain_parser(domain^)
    if _ends_in_a_number(ascii_domain.copy()):
        return WhatwgHost.ipv4(_parse_whatwg_ipv4(ascii_domain^))
    return WhatwgHost.domain(ascii_domain^)


# RFC 3986 Appendix A host: IP-literal / IPv4address / reg-name.
def parse_host_rfc3986(
    input: String, *, allow_zone_id: Bool = True
) raises ParseError -> RfcHost:
    _check_host_length(input, ParseProfile.rfc3986)
    if input.byte_length() == 0:
        return RfcHost.reg_name("")
    if _byte_at(input, 0) == 0x5B:
        return _parse_rfc_ip_literal(input, allow_zone_id)
    var ipv4 = _try_rfc_ipv4(input)
    if ipv4.ok:
        return RfcHost.ipv4(UInt32(ipv4.value))
    if _is_reg_name(input):
        return RfcHost.reg_name(input.copy())
    raise _rfc_fail(
        "invalid_host", "host is not IP-literal, IPv4address, or reg-name"
    )


# WHATWG URL Standard §3.6 host serializer.
def serialize_host(host: WhatwgHost) -> String:
    return host.serialize()


# RFC 3986 / RFC 5952 host serializer (IPv6 compressed form; zone as %25ZoneID).
def serialize_host(host: RfcHost) -> String:
    return host.serialize()


def _check_host_length(input: String, profile: ParseProfile) raises ParseError:
    var n_cp = input.count_codepoints()
    if n_cp > DEFAULT_MAX_INPUT_CODEPOINTS:
        raise ParseError.input_too_long(
            profile, n_cp, DEFAULT_MAX_INPUT_CODEPOINTS
        )
    var n_b = input.byte_length()
    if n_b > DEFAULT_MAX_AUTHORITY_LENGTH:
        raise ParseError.authority_too_long(
            profile, n_b, DEFAULT_MAX_AUTHORITY_LENGTH
        )


def _whatwg_fail(
    kind: String, whatwg_name: String, message: String
) -> ParseError:
    return ParseError.host_failure(
        ParseProfile.whatwg, kind, message, Optional(whatwg_name)
    )


def _rfc_fail(kind: String, message: String) -> ParseError:
    return ParseError.host_failure(
        ParseProfile.rfc3986, kind, message, Optional[String]()
    )


# WHATWG §3.3 domain parser with beStrict=false (ASCII lowercase fallback).
def _domain_parser(domain: String) raises ParseError -> String:
    try:
        _ = to_ascii(domain.copy(), be_strict=True)
    except _:
        pass

    var result: String
    if _is_ascii(domain):
        result = _ascii_lower(domain)
    else:
        try:
            result = to_ascii(domain.copy(), be_strict=False)
        except _:
            raise _whatwg_fail(
                "domain_to_ascii", "domain-to-ASCII", "domain ToASCII failed"
            )

    if result.byte_length() == 0:
        raise _whatwg_fail(
            "domain_to_ascii", "domain-to-ASCII", "domain ToASCII was empty"
        )
    if _contains_forbidden_domain(result):
        raise _whatwg_fail(
            "domain_to_ascii",
            "domain-to-ASCII",
            "ASCII domain contains a forbidden domain code point",
        )
    return result^


def _parse_opaque_host(input: String) raises ParseError -> WhatwgHost:
    if _contains_forbidden_host(input):
        raise _whatwg_fail(
            "host_invalid_code_point",
            "host-invalid-code-point",
            "opaque host contains a forbidden host code point",
        )
    var encoded = encode(input, EncodeSet.C0Control)
    if encoded.byte_length() == 0:
        return WhatwgHost.empty()
    return WhatwgHost.opaque(encoded^)


def _ends_in_a_number(input: String) raises ParseError -> Bool:
    var parts = _split_byte(input, 0x2E)
    if len(parts) == 0:
        return False
    if parts[len(parts) - 1].byte_length() == 0:
        _ = parts.pop()
    if len(parts) == 0:
        return False
    var last = parts[len(parts) - 1]
    if last.byte_length() > 0 and _only_ascii_digits(last):
        return True
    var parsed = _parse_ipv4_number(last)
    return parsed.ok


# WHATWG §3.5 IPv4 parser. Returns a 32-bit address or failure.
def _parse_whatwg_ipv4(input: String) raises ParseError -> UInt32:
    var parts = _split_byte(input, 0x2E)
    if len(parts) > 0 and parts[len(parts) - 1].byte_length() == 0:
        if len(parts) > 1:
            _ = parts.pop()
    if len(parts) > 4:
        raise _whatwg_fail(
            "ipv4_too_many_parts",
            "IPv4-too-many-parts",
            "IPv4 address has too many parts",
        )
    var numbers = List[Int]()
    var i = 0
    while i < len(parts):
        var parsed = _parse_ipv4_number(parts[i])
        if not parsed.ok:
            raise _whatwg_fail(
                "ipv4_non_numeric_part",
                "IPv4-non-numeric-part",
                "IPv4 part is not a number",
            )
        numbers.append(parsed.value)
        i += 1
    if len(numbers) == 0:
        raise _whatwg_fail(
            "ipv4_non_numeric_part",
            "IPv4-non-numeric-part",
            "IPv4 address has no parts",
        )
    var j = 0
    while j < len(numbers) - 1:
        if numbers[j] > 255:
            raise _whatwg_fail(
                "ipv4_out_of_range_part",
                "IPv4-out-of-range-part",
                "IPv4 part is out of range",
            )
        j += 1
    var limit = _pow256(5 - len(numbers))
    if numbers[len(numbers) - 1] >= limit:
        raise _whatwg_fail(
            "ipv4_out_of_range_part",
            "IPv4-out-of-range-part",
            "IPv4 last part is out of range",
        )
    var ipv4 = numbers[len(numbers) - 1]
    _ = numbers.pop()
    var counter = 0
    var k = 0
    while k < len(numbers):
        ipv4 += numbers[k] * _pow256(3 - counter)
        counter += 1
        k += 1
    return UInt32(ipv4)


@fieldwise_init
struct _Ipv4Number(Copyable, ImplicitlyCopyable, Movable):
    var value: Int
    var non_decimal: Bool
    var ok: Bool

    @staticmethod
    def fail() -> Self:
        return _Ipv4Number(0, False, False)

    @staticmethod
    def ok_val(value: Int, non_decimal: Bool) -> Self:
        return _Ipv4Number(value, non_decimal, True)


def _parse_ipv4_number(input: String) -> _Ipv4Number:
    var n = input.byte_length()
    if n == 0:
        return _Ipv4Number.fail()
    var src = input.as_bytes()
    var validation_error = False
    var radix = 10
    var start = 0
    if n >= 2 and src[0] == 0x30 and (src[1] == 0x78 or src[1] == 0x58):
        validation_error = True
        start = 2
        radix = 16
    elif n >= 2 and src[0] == 0x30:
        validation_error = True
        start = 1
        radix = 8
    if start == n:
        return _Ipv4Number.ok_val(0, True)
    var output = 0
    var i = start
    while i < n:
        var d = _digit_value(Int(src[i]), radix)
        if d < 0:
            return _Ipv4Number.fail()
        if output > (0x7FFFFFFFFFFFFFFF - d) // radix:
            return _Ipv4Number.ok_val(0x7FFFFFFFFFFFFFFF, True)
        output = output * radix + d
        i += 1
    return _Ipv4Number.ok_val(output, validation_error)


# WHATWG §3.5 IPv6 parser (pointer algorithm; no zone IDs).
def _parse_whatwg_ipv6(input: String) raises ParseError -> Ipv6Pieces:
    var cps = _codepoints(input)
    var address = List[Int](capacity=8)
    var a = 0
    while a < 8:
        address.append(0)
        a += 1
    var piece_index = 0
    var compress = -1
    var pointer = 0
    var n = len(cps)

    if _ipv6_c(cps, pointer, n) == 0x3A:
        if pointer + 1 >= n or cps[pointer + 1] != 0x3A:
            raise _whatwg_fail(
                "ipv6_invalid_compression",
                "IPv6-invalid-compression",
                "IPv6 compression is invalid",
            )
        pointer += 2
        piece_index += 1
        compress = piece_index

    while _ipv6_c(cps, pointer, n) >= 0:
        if piece_index == 8:
            raise _whatwg_fail(
                "ipv6_too_many_pieces",
                "IPv6-too-many-pieces",
                "IPv6 address has too many pieces",
            )
        if _ipv6_c(cps, pointer, n) == 0x3A:
            if compress >= 0:
                raise _whatwg_fail(
                    "ipv6_multiple_compression",
                    "IPv6-multiple-compression",
                    "IPv6 address has multiple compressions",
                )
            pointer += 1
            piece_index += 1
            compress = piece_index
            continue

        var value = 0
        var length = 0
        while length < 4 and _is_ascii_hex(_ipv6_c(cps, pointer, n)):
            value = value * 16 + _hex_value(_ipv6_c(cps, pointer, n))
            pointer += 1
            length += 1

        if _ipv6_c(cps, pointer, n) == 0x2E:
            if length == 0:
                raise _whatwg_fail(
                    "ipv4_in_ipv6_invalid_code_point",
                    "IPv4-in-IPv6-invalid-code-point",
                    "IPv4-in-IPv6 sequence is invalid",
                )
            pointer -= length
            if piece_index > 6:
                raise _whatwg_fail(
                    "ipv4_in_ipv6_too_many_pieces",
                    "IPv4-in-IPv6-too-many-pieces",
                    "IPv4-in-IPv6 address has too many pieces",
                )
            var numbers_seen = 0
            while _ipv6_c(cps, pointer, n) >= 0:
                var ipv4_piece = -1
                if numbers_seen > 0:
                    if _ipv6_c(cps, pointer, n) == 0x2E and numbers_seen < 4:
                        pointer += 1
                    else:
                        raise _whatwg_fail(
                            "ipv4_in_ipv6_invalid_code_point",
                            "IPv4-in-IPv6-invalid-code-point",
                            "IPv4-in-IPv6 sequence is invalid",
                        )
                if not _is_ascii_digit(_ipv6_c(cps, pointer, n)):
                    raise _whatwg_fail(
                        "ipv4_in_ipv6_invalid_code_point",
                        "IPv4-in-IPv6-invalid-code-point",
                        "IPv4-in-IPv6 sequence is invalid",
                    )
                while _is_ascii_digit(_ipv6_c(cps, pointer, n)):
                    var number = _ipv6_c(cps, pointer, n) - 0x30
                    if ipv4_piece < 0:
                        ipv4_piece = number
                    elif ipv4_piece == 0:
                        raise _whatwg_fail(
                            "ipv4_in_ipv6_invalid_code_point",
                            "IPv4-in-IPv6-invalid-code-point",
                            "IPv4-in-IPv6 sequence is invalid",
                        )
                    else:
                        ipv4_piece = ipv4_piece * 10 + number
                    if ipv4_piece > 255:
                        raise _whatwg_fail(
                            "ipv4_in_ipv6_out_of_range_part",
                            "IPv4-in-IPv6-out-of-range-part",
                            "IPv4-in-IPv6 part is out of range",
                        )
                    pointer += 1
                address[piece_index] = address[piece_index] * 0x100 + ipv4_piece
                numbers_seen += 1
                if numbers_seen == 2 or numbers_seen == 4:
                    piece_index += 1
            if numbers_seen != 4:
                raise _whatwg_fail(
                    "ipv4_in_ipv6_too_few_parts",
                    "IPv4-in-IPv6-too-few-parts",
                    "IPv4-in-IPv6 address has too few parts",
                )
            continue
        elif _ipv6_c(cps, pointer, n) == 0x3A:
            pointer += 1
            if _ipv6_c(cps, pointer, n) < 0:
                raise _whatwg_fail(
                    "ipv6_invalid_code_point",
                    "IPv6-invalid-code-point",
                    "IPv6 address has an invalid code point",
                )
        elif _ipv6_c(cps, pointer, n) >= 0:
            raise _whatwg_fail(
                "ipv6_invalid_code_point",
                "IPv6-invalid-code-point",
                "IPv6 address has an invalid code point",
            )

        address[piece_index] = value
        piece_index += 1

    if compress >= 0:
        var swaps = piece_index - compress
        piece_index = 7
        while piece_index != 0 and swaps > 0:
            var other = compress + swaps - 1
            var tmp = address[piece_index]
            address[piece_index] = address[other]
            address[other] = tmp
            piece_index -= 1
            swaps -= 1
    else:
        if piece_index != 8:
            raise _whatwg_fail(
                "ipv6_too_few_pieces",
                "IPv6-too-few-pieces",
                "IPv6 address has too few pieces",
            )

    return _ipv6_from_list(address)


def _ipv6_c(cps: List[Int], pointer: Int, n: Int) -> Int:
    if pointer < 0 or pointer >= n:
        return -1
    return cps[pointer]


def _parse_rfc_ip_literal(
    input: String, allow_zone_id: Bool
) raises ParseError -> RfcHost:
    var n = input.byte_length()
    if n < 2 or _byte_at(input, n - 1) != 0x5D:
        raise _rfc_fail("invalid_ip_literal", "IP-literal is not closed")
    var inner = String(input[byte = 1 : n - 1])
    if inner.byte_length() >= 2 and _byte_at(inner, 0) == 0x76:
        return _parse_rfc_ipv_future(inner)
    var zone = String("")
    var addr = inner
    var pct25 = inner.find("%25")
    if pct25 >= 0:
        if not allow_zone_id:
            raise _rfc_fail("invalid_ipv6_zone", "IPv6 zone ID is not allowed")
        if inner.find("%25", pct25 + 3) >= 0:
            raise _rfc_fail("invalid_ipv6_zone", "IPv6 zone ID is malformed")
        zone = String(inner[byte = pct25 + 3 : inner.byte_length()])
        if zone.byte_length() == 0 or not _is_zone_id(zone):
            raise _rfc_fail("invalid_ipv6_zone", "IPv6 zone ID is invalid")
        addr = String(inner[byte=0:pct25])
    elif inner.find("%") >= 0:
        raise _rfc_fail("invalid_ipv6_zone", "IPv6 zone delimiter must be %25")
    var pieces = _parse_rfc_ipv6(addr)
    return RfcHost.ipv6(pieces, zone^)


def _parse_rfc_ipv_future(inner: String) raises ParseError -> RfcHost:
    # inner starts with 'v'
    var src = inner.as_bytes()
    var n = len(src)
    if n < 4 or src[0] != 0x76:
        raise _rfc_fail("invalid_ipv_future", "IPvFuture is invalid")
    var i = 1
    while i < n and _is_ascii_hex(Int(src[i])):
        i += 1
    if i == 1 or i >= n or src[i] != 0x2E:
        raise _rfc_fail("invalid_ipv_future", "IPvFuture is invalid")
    var version = String(inner[byte=1:i])
    var rest = String(inner[byte = i + 1 : n])
    if rest.byte_length() == 0 or not _is_ipv_future_rest(rest):
        raise _rfc_fail("invalid_ipv_future", "IPvFuture remainder is invalid")
    return RfcHost.ipv_future(version^, rest^)


def _parse_rfc_ipv6(input: String) raises ParseError -> Ipv6Pieces:
    var compress = input.find("::")
    if compress >= 0:
        if input.find("::", compress + 2) >= 0:
            raise _rfc_fail("invalid_ipv6", "IPv6address has multiple ::")
        var left = String(input[byte=0:compress])
        var right = String(input[byte = compress + 2 : input.byte_length()])
        var lp = _parse_rfc_ipv6_half(left, False)
        var rp = _parse_rfc_ipv6_half(right, True)
        var total = len(lp) + len(rp)
        if total >= 8:
            raise _rfc_fail("invalid_ipv6", "IPv6address has too many pieces")
        var pieces = Ipv6Pieces.zero()
        var i = 0
        while i < len(lp):
            pieces.set(i, UInt16(lp[i]))
            i += 1
        var j = 0
        while j < len(rp):
            pieces.set(8 - len(rp) + j, UInt16(rp[j]))
            j += 1
        return pieces
    var parts = _parse_rfc_ipv6_half(input, True)
    if len(parts) != 8:
        raise _rfc_fail("invalid_ipv6", "IPv6address has the wrong piece count")
    var out = Ipv6Pieces.zero()
    var k = 0
    while k < 8:
        out.set(k, UInt16(parts[k]))
        k += 1
    return out


def _parse_rfc_ipv6_half(
    input: String, allow_ipv4: Bool
) raises ParseError -> List[Int]:
    var out = List[Int]()
    if input.byte_length() == 0:
        return out^
    var parts = _split_byte(input, 0x3A)
    var i = 0
    while i < len(parts):
        if parts[i].byte_length() == 0:
            raise _rfc_fail("invalid_ipv6", "IPv6address has an empty piece")
        if allow_ipv4 and i == len(parts) - 1 and parts[i].find(".") >= 0:
            var v = _try_rfc_ipv4(parts[i])
            if not v.ok:
                raise _rfc_fail(
                    "invalid_ipv6", "IPv6address IPv4 tail is not IPv4address"
                )
            var addr = v.value
            out.append((addr >> 16) & 0xFFFF)
            out.append(addr & 0xFFFF)
        else:
            out.append(_parse_h16(parts[i]))
        i += 1
    return out^


def _parse_h16(piece: String) raises ParseError -> Int:
    var n = piece.byte_length()
    if n < 1 or n > 4:
        raise _rfc_fail("invalid_ipv6", "h16 is not 1–4 HEXDIG")
    var src = piece.as_bytes()
    var v = 0
    var i = 0
    while i < n:
        var d = _hex_value(Int(src[i]))
        if d < 0:
            raise _rfc_fail("invalid_ipv6", "h16 contains a non-hex digit")
        v = v * 16 + d
        i += 1
    return v


@fieldwise_init
struct _RfcIpv4(Copyable, ImplicitlyCopyable, Movable):
    var value: Int
    var ok: Bool

    @staticmethod
    def fail() -> Self:
        return _RfcIpv4(0, False)

    @staticmethod
    def from_addr(addr: Int) -> Self:
        return _RfcIpv4(addr, True)


# RFC 3986 IPv4address: exactly four decimal dec-octets.
def _try_rfc_ipv4(input: String) -> _RfcIpv4:
    var parts = _split_byte(input, 0x2E)
    if len(parts) != 4:
        return _RfcIpv4.fail()
    var addr = 0
    var i = 0
    while i < 4:
        var oct = _parse_dec_octet(parts[i])
        if oct < 0:
            return _RfcIpv4.fail()
        addr = (addr << 8) + oct
        i += 1
    return _RfcIpv4.from_addr(addr)


def _parse_dec_octet(part: String) -> Int:
    var n = part.byte_length()
    if n < 1 or n > 3:
        return -1
    var src = part.as_bytes()
    var i = 0
    while i < n:
        if src[i] < 0x30 or src[i] > 0x39:
            return -1
        i += 1
    if n > 1 and src[0] == 0x30:
        return -1
    var v = 0
    i = 0
    while i < n:
        v = v * 10 + Int(src[i]) - 0x30
        i += 1
    if v > 255:
        return -1
    return v


def _is_reg_name(input: String) -> Bool:
    var src = input.as_bytes()
    var n = len(src)
    var i = 0
    while i < n:
        var b = Int(src[i])
        if _is_unreserved(b) or _is_sub_delim(b):
            i += 1
        elif (
            b == 0x25
            and i + 2 < n
            and _is_ascii_hex(Int(src[i + 1]))
            and _is_ascii_hex(Int(src[i + 2]))
        ):
            i += 3
        else:
            return False
    return True


def _is_zone_id(input: String) -> Bool:
    var src = input.as_bytes()
    var n = len(src)
    if n == 0:
        return False
    var i = 0
    while i < n:
        var b = Int(src[i])
        if _is_unreserved(b):
            i += 1
        elif (
            b == 0x25
            and i + 2 < n
            and _is_ascii_hex(Int(src[i + 1]))
            and _is_ascii_hex(Int(src[i + 2]))
        ):
            i += 3
        else:
            return False
    return True


def _is_ipv_future_rest(input: String) -> Bool:
    var src = input.as_bytes()
    var n = len(src)
    var i = 0
    while i < n:
        var b = Int(src[i])
        if _is_unreserved(b) or _is_sub_delim(b) or b == 0x3A:
            i += 1
        else:
            return False
    return True


def _is_unreserved(b: Int) -> Bool:
    if b >= 0x41 and b <= 0x5A:
        return True
    if b >= 0x61 and b <= 0x7A:
        return True
    if b >= 0x30 and b <= 0x39:
        return True
    return b == 0x2D or b == 0x2E or b == 0x5F or b == 0x7E


def _is_sub_delim(b: Int) -> Bool:
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


def _serialize_ipv4(addr: UInt32) -> String:
    var n = Int(addr)
    var b0 = n % 256
    n = n // 256
    var b1 = n % 256
    n = n // 256
    var b2 = n % 256
    n = n // 256
    var b3 = n % 256
    return String(b3) + "." + String(b2) + "." + String(b1) + "." + String(b0)


def _serialize_ipv6(addr: Ipv6Pieces) -> String:
    var compress = _ipv6_compress_index(addr)
    var out = String("")
    var ignore0 = False
    var i = 0
    while i < 8:
        var piece = Int(addr.get(i))
        if ignore0 and piece == 0:
            i += 1
            continue
        if ignore0:
            ignore0 = False
        if compress >= 0 and i == compress:
            if i == 0:
                out += "::"
            else:
                out += ":"
            ignore0 = True
            i += 1
            continue
        out += _hex_lowest(piece)
        if i != 7:
            out += ":"
        i += 1
    return out^


def _ipv6_compress_index(addr: Ipv6Pieces) -> Int:
    var longest_index = -1
    var longest_size = 1
    var found_index = -1
    var found_size = 0
    var i = 0
    while i < 8:
        if Int(addr.get(i)) != 0:
            if found_size > longest_size:
                longest_index = found_index
                longest_size = found_size
            found_index = -1
            found_size = 0
        else:
            if found_index < 0:
                found_index = i
            found_size += 1
        i += 1
    if found_size > longest_size:
        return found_index
    return longest_index


def _hex_lowest(value: Int) -> String:
    if value == 0:
        return "0"
    var digits = List[UInt8]()
    var v = value
    while v > 0:
        var d = v % 16
        if d < 10:
            digits.append(UInt8(0x30 + d))
        else:
            digits.append(UInt8(0x61 + d - 10))
        v = v // 16
    var out = List[UInt8]()
    var i = len(digits) - 1
    while i >= 0:
        out.append(digits[i])
        i -= 1
    return String(unsafe_from_utf8=out)


def _ipv6_from_list(address: List[Int]) -> Ipv6Pieces:
    var p = Ipv6Pieces.zero()
    var i = 0
    while i < 8:
        p.set(i, UInt16(address[i]))
        i += 1
    return p


def _pow256(exp: Int) -> Int:
    var v = 1
    var i = 0
    while i < exp:
        v *= 256
        i += 1
    return v


def _split_byte(s: String, sep: UInt8) -> List[String]:
    var src = s.as_bytes()
    var n = len(src)
    var parts = List[String]()
    var start = 0
    var i = 0
    while i <= n:
        if i == n or src[i] == sep:
            parts.append(String(s[byte=start:i]))
            start = i + 1
        i += 1
    return parts^


def _codepoints(s: String) -> List[Int]:
    var out = List[Int]()
    for cp in s.codepoints():
        out.append(Int(cp))
    return out^


def _byte_at(s: String, i: Int) -> Int:
    if i < 0 or i >= s.byte_length():
        return -1
    return Int(s.as_bytes()[i])


def _is_ascii(s: String) -> Bool:
    var src = s.as_bytes()
    var i = 0
    while i < len(src):
        if src[i] > 0x7F:
            return False
        i += 1
    return True


def _ascii_lower(s: String) -> String:
    var src = s.as_bytes()
    var out = List[UInt8](capacity=len(src))
    var i = 0
    while i < len(src):
        var b = src[i]
        if b >= 0x41 and b <= 0x5A:
            out.append(b + UInt8(0x20))
        else:
            out.append(b)
        i += 1
    return String(unsafe_from_utf8=out)


def _only_ascii_digits(s: String) -> Bool:
    var src = s.as_bytes()
    if len(src) == 0:
        return False
    var i = 0
    while i < len(src):
        if src[i] < 0x30 or src[i] > 0x39:
            return False
        i += 1
    return True


def _is_ascii_digit(cp: Int) -> Bool:
    return cp >= 0x30 and cp <= 0x39


def _is_ascii_hex(cp: Int) -> Bool:
    if cp >= 0x30 and cp <= 0x39:
        return True
    if cp >= 0x41 and cp <= 0x46:
        return True
    if cp >= 0x61 and cp <= 0x66:
        return True
    return False


def _hex_value(cp: Int) -> Int:
    if cp >= 0x30 and cp <= 0x39:
        return cp - 0x30
    if cp >= 0x41 and cp <= 0x46:
        return cp - 0x41 + 10
    if cp >= 0x61 and cp <= 0x66:
        return cp - 0x61 + 10
    return -1


def _digit_value(cp: Int, radix: Int) -> Int:
    var v = _hex_value(cp)
    if v < 0 or v >= radix:
        return -1
    return v


def _forbidden_host_cp(cp: Int) -> Bool:
    return (
        cp == 0
        or cp == 0x09
        or cp == 0x0A
        or cp == 0x0D
        or cp == 0x20
        or cp == 0x23
        or cp == 0x2F
        or cp == 0x3A
        or cp == 0x3C
        or cp == 0x3E
        or cp == 0x3F
        or cp == 0x40
        or cp == 0x5B
        or cp == 0x5C
        or cp == 0x5D
        or cp == 0x5E
        or cp == 0x7C
    )


def _forbidden_domain_cp(cp: Int) -> Bool:
    if _forbidden_host_cp(cp):
        return True
    if cp <= 0x1F:
        return True
    return cp == 0x25 or cp == 0x7F


def _contains_forbidden_host(s: String) -> Bool:
    for cp in s.codepoints():
        if _forbidden_host_cp(Int(cp)):
            return True
    return False


def _contains_forbidden_domain(s: String) -> Bool:
    for cp in s.codepoints():
        if _forbidden_domain_cp(Int(cp)):
            return True
    return False
