from heat_url.error import ParseError, check_input_length
from heat_url.host import RfcHost, parse_host_rfc3986, serialize_host
from heat_url.idna import to_ascii
from heat_url.limits import DEFAULT_MAX_AUTHORITY_LENGTH
from heat_url.options import ParseOptions
from heat_url.percent import decode_utf8_strict
from heat_url.query import QueryList


# RFC 3986 path type (Appendix A); recoverable after parse.
@fieldwise_init
struct PathKind(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    var _variant: Int

    comptime abempty = Self(_variant=0)
    comptime absolute = Self(_variant=1)
    comptime noscheme = Self(_variant=2)
    comptime rootless = Self(_variant=3)
    comptime empty = Self(_variant=4)

    def __eq__(self, other: Self) -> Bool:
        return self._variant == other._variant

    def name(self) -> StaticString:
        if self._variant == 0:
            return "abempty"
        if self._variant == 1:
            return "absolute"
        if self._variant == 2:
            return "noscheme"
        if self._variant == 3:
            return "rootless"
        return "empty"

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.name())


# RFC 3986 URI-reference record (specs/02-data-model.md).
@fieldwise_init
struct Uri(Copyable, Movable, Writable):
    var scheme: Optional[String]
    var userinfo: Optional[String]
    var _host: RfcHost
    var _port_text: Optional[String]
    var _port_u16: Optional[UInt16]
    var path: String
    var query: Optional[String]
    var fragment: Optional[String]
    var has_authority: Bool
    var is_relative: Bool
    var path_kind: PathKind

    # RFC 3986 Appendix B split, Appendix A validation, optional §5.2 resolve.
    @staticmethod
    def parse(input: String, options: ParseOptions) raises ParseError -> Self:
        check_input_length(input, options)
        var split = _split_appendix_b(input)
        var scheme = Optional[String](None)
        if split.has_scheme:
            if not _is_scheme(split.scheme):
                raise ParseError.rfc_failure(
                    "invalid_scheme", "scheme does not match ABNF"
                )
            scheme = Optional(_ascii_lower(split.scheme))

        var userinfo = Optional[String](None)
        var host = RfcHost.reg_name("")
        var port_text = Optional[String](None)
        var port_u16 = Optional[UInt16](None)
        if split.has_authority:
            if split.authority.byte_length() > DEFAULT_MAX_AUTHORITY_LENGTH:
                raise ParseError.authority_too_long(
                    options.profile,
                    split.authority.byte_length(),
                    DEFAULT_MAX_AUTHORITY_LENGTH,
                )
            var auth = _parse_authority(split.authority, options)
            userinfo = auth.userinfo
            host = auth.host.copy()
            port_text = auth.port_text
            port_u16 = auth.port_u16

        var iri = options.iri
        if userinfo is not None:
            _validate_chars(
                userinfo.value(),
                iri,
                True,
                False,
                False,
                False,
                False,
                "invalid_userinfo",
            )
        _validate_chars(
            split.path, iri, True, True, True, False, False, "invalid_path"
        )
        if split.query is not None:
            _validate_chars(
                split.query.value(),
                iri,
                True,
                True,
                True,
                True,
                True,
                "invalid_query",
            )
        if split.fragment is not None:
            _validate_chars(
                split.fragment.value(),
                iri,
                True,
                True,
                True,
                True,
                False,
                "invalid_fragment",
            )

        var has_scheme = scheme is not None
        var path_kind = _classify_path(
            has_scheme, split.has_authority, split.path
        )
        _validate_path_structure(path_kind, split.path)
        if (
            split.has_authority
            and split.path.byte_length() > 0
            and _byte_at(split.path, 0) != 0x2F
        ):
            raise ParseError.rfc_failure(
                "invalid_path", "path after authority must be empty or absolute"
            )

        if options.idna_host and split.has_authority and host.is_reg_name():
            host = _idna_reg_name(host^)

        var uri = Uri(
            scheme,
            userinfo,
            host^,
            port_text,
            port_u16,
            split.path.copy(),
            split.query,
            split.fragment,
            split.has_authority,
            not has_scheme,
            path_kind,
        )
        if uri.is_relative and options.base is not None:
            var base_options = options.copy()
            base_options.base = Optional[String](None)
            base_options.normalize_syntax = False
            var base_uri = Uri.parse(options.base.value(), base_options)
            if base_uri.is_relative:
                raise ParseError.rfc_failure(
                    "invalid_base", "base URI-reference has no scheme"
                )
            uri = _resolve(uri^, base_uri^)
        if options.normalize_syntax:
            uri = _normalize_syntax(uri^)
        return uri^

    def host(self) -> Optional[RfcHost]:
        if not self.has_authority:
            return Optional[RfcHost](None)
        return Optional(self._host.copy())

    def port_text(self) -> Optional[String]:
        return self._port_text

    # Fails when port is absent, empty, or outside 0–65535 (specs/02).
    def port_as_u16(self) raises ParseError -> UInt16:
        if self._port_u16 is not None:
            return self._port_u16.value()
        raise ParseError.rfc_failure(
            "invalid_port", "port cannot be coerced to UInt16"
        )

    # RFC 3986 §5.3 component recomposition.
    def serialize(self, exclude_fragment: Bool = False) -> String:
        var out = String("")
        if self.scheme is not None:
            out += self.scheme.value()
            out += ":"
        if self.has_authority:
            out += "//"
            if self.userinfo is not None:
                out += self.userinfo.value()
                out += "@"
            out += serialize_host(self._host.copy())
            if self._port_text is not None:
                out += ":"
                out += self._port_text.value()
        out += self.path
        if self.query is not None:
            out += "?"
            out += self.query.value()
        if (not exclude_fragment) and self.fragment is not None:
            out += "#"
            out += self.fragment.value()
        return out^

    # Application-layer form-urlencoded view of query (specs/02, specs/09).
    def query_list(self) raises ParseError -> QueryList:
        if self.query is None:
            return QueryList.parse("")
        return QueryList.parse(self.query.value())

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.serialize())


# RFC 3986 URI-reference parser; `base` selects §5.2 when the input is relative-ref.
def parse_uri(
    input: String, base: Optional[String] = None
) raises ParseError -> Uri:
    var options = ParseOptions.rfc3986()
    options.base = base
    return Uri.parse(input, options)


@fieldwise_init
struct _Split(Copyable, Movable):
    var scheme: String
    var has_scheme: Bool
    var has_authority: Bool
    var authority: String
    var path: String
    var query: Optional[String]
    var fragment: Optional[String]


@fieldwise_init
struct _Auth(Copyable, Movable):
    var userinfo: Optional[String]
    var host: RfcHost
    var port_text: Optional[String]
    var port_u16: Optional[UInt16]


# RFC 3986 Appendix B five-component pointer scan (not a regex engine).
def _split_appendix_b(input: String) -> _Split:
    var scheme = String("")
    var has_scheme = False
    var i = 0
    var n = input.byte_length()
    var src = input.as_bytes()
    var delim = -1
    var d = 0
    while d < n:
        var b = src[d]
        if b == 0x3A or b == 0x2F or b == 0x3F or b == 0x23:
            delim = d
            break
        d += 1
    if delim >= 0 and src[delim] == 0x3A and delim > 0:
        scheme = String(input[byte=0:delim])
        has_scheme = True
        i = delim + 1
    var has_authority = False
    var authority = String("")
    if i + 1 < n and src[i] == 0x2F and src[i + 1] == 0x2F:
        has_authority = True
        i += 2
        var auth_start = i
        while i < n and src[i] != 0x2F and src[i] != 0x3F and src[i] != 0x23:
            i += 1
        authority = String(input[byte=auth_start:i])
    var path_start = i
    while i < n and src[i] != 0x3F and src[i] != 0x23:
        i += 1
    var path = String(input[byte=path_start:i])
    var query = Optional[String](None)
    if i < n and src[i] == 0x3F:
        i += 1
        var qstart = i
        while i < n and src[i] != 0x23:
            i += 1
        query = Optional(String(input[byte=qstart:i]))
    var fragment = Optional[String](None)
    if i < n and src[i] == 0x23:
        i += 1
        fragment = Optional(String(input[byte=i:n]))
    return _Split(
        scheme^,
        has_scheme,
        has_authority,
        authority^,
        path^,
        query,
        fragment,
    )


def _parse_authority(
    auth: String, options: ParseOptions
) raises ParseError -> _Auth:
    var userinfo = Optional[String](None)
    var rest = auth
    var at = auth.find("@")
    if at >= 0:
        userinfo = Optional(String(auth[byte=0:at]))
        rest = String(auth[byte = at + 1 :])
    var host_str: String
    var port_text = Optional[String](None)
    if rest.byte_length() > 0 and _byte_at(rest, 0) == 0x5B:
        var close = rest.find("]")
        if close < 0:
            raise ParseError.rfc_failure(
                "invalid_authority", "IP-literal is not closed"
            )
        host_str = String(rest[byte = 0 : close + 1])
        var after = String(rest[byte = close + 1 :])
        if after.byte_length() == 0:
            pass
        elif _byte_at(after, 0) == 0x3A:
            port_text = Optional(String(after[byte=1:]))
        else:
            raise ParseError.rfc_failure(
                "invalid_authority", "unexpected data after IP-literal"
            )
    else:
        var colon = rest.find(":")
        if colon >= 0:
            host_str = String(rest[byte=0:colon])
            port_text = Optional(String(rest[byte = colon + 1 :]))
        else:
            host_str = rest.copy()
    var host = parse_host_rfc3986(
        host_str,
        allow_zone_id=options.allow_ipv6_zone_id,
        iri=options.iri,
    )
    var port_u16 = Optional[UInt16](None)
    if port_text is not None:
        var pt = port_text.value()
        if not _is_all_digits(pt):
            raise ParseError.rfc_failure("invalid_port", "port is not *DIGIT")
        port_u16 = _try_port_u16(pt)
    return _Auth(userinfo, host^, port_text, port_u16)


def _try_to_ascii(domain: String) -> Optional[String]:
    try:
        var ascii = to_ascii(domain, be_strict=True)
        return Optional(ascii^)
    except _:
        return Optional[String](None)


def _idna_reg_name(host: RfcHost) raises ParseError -> RfcHost:
    var name = host.serialize()
    if name.byte_length() == 0:
        return host.copy()
    var decoded: String
    try:
        decoded = decode_utf8_strict(name)
    except _:
        raise ParseError.rfc_failure("idna_host", "IDNA ToASCII failed")
    var ascii = _try_to_ascii(decoded^)
    if ascii is None:
        raise ParseError.rfc_failure("idna_host", "IDNA ToASCII failed")
    return RfcHost.reg_name(ascii.value())


# RFC 3986 §5.2.2 transform references (strict; no same-scheme loophole).
def _resolve(reference: Uri, base: Uri) -> Uri:
    var scheme: Optional[String]
    var userinfo: Optional[String]
    var host: RfcHost
    var has_authority: Bool
    var port_text: Optional[String]
    var port_u16: Optional[UInt16]
    var path: String
    var query: Optional[String]
    if reference.scheme is not None:
        scheme = reference.scheme
        userinfo = reference.userinfo
        host = reference._host.copy()
        has_authority = reference.has_authority
        port_text = reference._port_text
        port_u16 = reference._port_u16
        path = _remove_dot_segments(reference.path)
        query = reference.query
    else:
        scheme = base.scheme
        if reference.has_authority:
            userinfo = reference.userinfo
            host = reference._host.copy()
            has_authority = True
            port_text = reference._port_text
            port_u16 = reference._port_u16
            path = _remove_dot_segments(reference.path)
            query = reference.query
        else:
            userinfo = base.userinfo
            host = base._host.copy()
            has_authority = base.has_authority
            port_text = base._port_text
            port_u16 = base._port_u16
            if reference.path.byte_length() == 0:
                path = base.path.copy()
                if reference.query is not None:
                    query = reference.query
                else:
                    query = base.query
            else:
                if _byte_at(reference.path, 0) == 0x2F:
                    path = _remove_dot_segments(reference.path)
                else:
                    path = _remove_dot_segments(
                        _merge_paths(base, reference.path)
                    )
                query = reference.query
    var fragment = reference.fragment
    var is_relative = scheme is None
    var path_kind = _classify_path(scheme is not None, has_authority, path)
    return Uri(
        scheme,
        userinfo,
        host^,
        port_text,
        port_u16,
        path^,
        query,
        fragment,
        has_authority,
        is_relative,
        path_kind,
    )


# RFC 3986 §5.2.3 merge paths.
def _merge_paths(base: Uri, rel_path: String) -> String:
    if base.has_authority and base.path.byte_length() == 0:
        return "/" + rel_path
    var p = base.path
    var last_slash = -1
    var i = 0
    while i < p.byte_length():
        if _byte_at(p, i) == 0x2F:
            last_slash = i
        i += 1
    if last_slash < 0:
        return rel_path.copy()
    return String(p[byte = 0 : last_slash + 1]) + rel_path


# RFC 3986 §5.2.4 remove_dot_segments (two-buffer algorithm).
def _remove_dot_segments(path: String) -> String:
    var inp = path.copy()
    var output = String("")
    while inp.byte_length() > 0:
        if _starts_with(inp, "../"):
            var rest = _slice_from(inp, 3)
            inp = rest^
        elif _starts_with(inp, "./"):
            var rest2 = _slice_from(inp, 2)
            inp = rest2^
        elif _starts_with(inp, "/./"):
            var rest3 = _slice_from(inp, 3)
            inp = "/" + rest3
        elif inp == "/.":
            inp = String("/")
        elif _starts_with(inp, "/../"):
            var rest4 = _slice_from(inp, 4)
            inp = "/" + rest4
            output = _drop_last_segment(output)
        elif inp == "/..":
            inp = String("/")
            output = _drop_last_segment(output)
        elif inp == "." or inp == "..":
            inp = String("")
        else:
            var i = 0
            if _byte_at(inp, 0) == 0x2F:
                i = 1
            while i < inp.byte_length() and _byte_at(inp, i) != 0x2F:
                i += 1
            output = output + String(inp[byte=0:i])
            var rest5 = _slice_from(inp, i)
            inp = rest5^
    return output^


def _slice_from(s: String, start: Int) -> String:
    return String(s[byte=start:])


def _drop_last_segment(output: String) -> String:
    var n = output.byte_length()
    var i = n - 1
    while i >= 0:
        if _byte_at(output, i) == 0x2F:
            return String(output[byte=0:i])
        i -= 1
    return String("")


# RFC 3986 §6.2.2 syntax-based normalization (not §6.2.3).
def _normalize_syntax(uri: Uri) -> Uri:
    var userinfo = uri.userinfo
    if userinfo is not None:
        userinfo = Optional(_normalize_percent(userinfo.value()))
    var host = uri._host.copy()
    if uri.has_authority and host.is_reg_name():
        var t = _ascii_lower(_normalize_percent(host.serialize()))
        host = RfcHost.reg_name(t^)
    var path = _remove_dot_segments(_normalize_percent(uri.path))
    var query = uri.query
    if query is not None:
        query = Optional(_normalize_percent(query.value()))
    var fragment = uri.fragment
    if fragment is not None:
        fragment = Optional(_normalize_percent(fragment.value()))
    var path_kind = _classify_path(
        uri.scheme is not None, uri.has_authority, path
    )
    return Uri(
        uri.scheme,
        userinfo,
        host^,
        uri._port_text,
        uri._port_u16,
        path^,
        query,
        fragment,
        uri.has_authority,
        uri.is_relative,
        path_kind,
    )


def _normalize_percent(s: String) -> String:
    var src = s.as_bytes()
    var n = len(src)
    var out = List[UInt8](capacity=n)
    var i = 0
    while i < n:
        if (
            src[i] == 0x25
            and i + 2 < n
            and _is_hex_byte(src[i + 1])
            and _is_hex_byte(src[i + 2])
        ):
            var hi = _hex_val(src[i + 1])
            var lo = _hex_val(src[i + 2])
            var b = UInt8((hi << 4) | lo)
            if _is_unreserved_byte(b):
                out.append(b)
            else:
                out.append(UInt8(0x25))
                out.append(_hex_upper(hi))
                out.append(_hex_upper(lo))
            i += 3
        else:
            out.append(src[i])
            i += 1
    return String(unsafe_from_utf8=out)


def _classify_path(
    has_scheme: Bool, has_authority: Bool, path: String
) -> PathKind:
    if has_authority:
        return PathKind.abempty
    if path.byte_length() == 0:
        return PathKind.empty
    if _byte_at(path, 0) == 0x2F:
        return PathKind.absolute
    if has_scheme:
        return PathKind.rootless
    return PathKind.noscheme


def _validate_path_structure(kind: PathKind, path: String) raises ParseError:
    if kind == PathKind.absolute:
        if path.byte_length() == 0 or _byte_at(path, 0) != 0x2F:
            raise ParseError.rfc_failure(
                "invalid_path", "path-absolute is invalid"
            )
        if path.byte_length() > 1 and _byte_at(path, 1) == 0x2F:
            raise ParseError.rfc_failure(
                "invalid_path", "path-absolute has an empty first segment"
            )
    elif kind == PathKind.rootless:
        if path.byte_length() == 0 or _byte_at(path, 0) == 0x2F:
            raise ParseError.rfc_failure(
                "invalid_path", "path-rootless is invalid"
            )
    elif kind == PathKind.noscheme:
        if path.byte_length() == 0 or _byte_at(path, 0) == 0x2F:
            raise ParseError.rfc_failure(
                "invalid_path", "path-noscheme is invalid"
            )
        var i = 0
        while i < path.byte_length() and _byte_at(path, i) != 0x2F:
            if _byte_at(path, i) == 0x3A:
                raise ParseError.rfc_failure(
                    "invalid_path",
                    "path-noscheme first segment contains a colon",
                )
            i += 1
    elif kind == PathKind.abempty:
        if path.byte_length() > 0 and _byte_at(path, 0) != 0x2F:
            raise ParseError.rfc_failure(
                "invalid_path", "path-abempty is invalid"
            )


def _validate_chars(
    s: String,
    iri: Bool,
    allow_colon: Bool,
    allow_at: Bool,
    allow_slash: Bool,
    allow_question: Bool,
    allow_iprivate: Bool,
    err_kind: String,
) raises ParseError:
    var cps = List[Int]()
    for cp in s.codepoints():
        cps.append(Int(cp))
    var n = len(cps)
    var i = 0
    while i < n:
        var cp = cps[i]
        if cp == 0x25:
            if (
                i + 2 >= n
                or not _is_ascii_hex(cps[i + 1])
                or not _is_ascii_hex(cps[i + 2])
            ):
                raise ParseError.rfc_failure_at(
                    "invalid_percent_encoding",
                    "percent-encoding is not two hex digits",
                    i,
                )
            i += 3
            continue
        if cp <= 0x7F:
            if _is_unreserved(cp) or _is_sub_delim(cp):
                i += 1
                continue
            if allow_colon and cp == 0x3A:
                i += 1
                continue
            if allow_at and cp == 0x40:
                i += 1
                continue
            if allow_slash and cp == 0x2F:
                i += 1
                continue
            if allow_question and cp == 0x3F:
                i += 1
                continue
            raise ParseError.rfc_failure(
                err_kind, "component contains a disallowed ASCII code point"
            )
        if not iri:
            raise ParseError.rfc_failure(
                err_kind, "non-ASCII is not allowed when iri is false"
            )
        if _is_ucschar(cp):
            i += 1
            continue
        if allow_iprivate and _is_iprivate(cp):
            i += 1
            continue
        raise ParseError.rfc_failure(
            err_kind, "component contains a disallowed IRI code point"
        )


def _is_scheme(s: String) -> Bool:
    var src = s.as_bytes()
    var n = len(src)
    if n == 0:
        return False
    if not _is_alpha_byte(src[0]):
        return False
    var i = 1
    while i < n:
        var b = src[i]
        if not (
            _is_alpha_byte(b)
            or _is_digit_byte(b)
            or b == 0x2B
            or b == 0x2D
            or b == 0x2E
        ):
            return False
        i += 1
    return True


def _is_all_digits(s: String) -> Bool:
    var src = s.as_bytes()
    var i = 0
    while i < len(src):
        if src[i] < 0x30 or src[i] > 0x39:
            return False
        i += 1
    return True


def _try_port_u16(s: String) -> Optional[UInt16]:
    if s.byte_length() == 0:
        return Optional[UInt16](None)
    var src = s.as_bytes()
    var v = 0
    var i = 0
    while i < len(src):
        var d = Int(src[i]) - 0x30
        if v > (65535 - d) // 10:
            return Optional[UInt16](None)
        v = v * 10 + d
        i += 1
    return Optional(UInt16(v))


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


def _starts_with(s: String, prefix: String) -> Bool:
    var pn = prefix.byte_length()
    if pn > s.byte_length():
        return False
    return String(s[byte=0:pn]) == prefix


def _byte_at(s: String, i: Int) -> Int:
    if i < 0 or i >= s.byte_length():
        return -1
    return Int(s.as_bytes()[i])


def _is_alpha_byte(b: UInt8) -> Bool:
    return (b >= 0x41 and b <= 0x5A) or (b >= 0x61 and b <= 0x7A)


def _is_digit_byte(b: UInt8) -> Bool:
    return b >= 0x30 and b <= 0x39


def _is_unreserved(cp: Int) -> Bool:
    if cp >= 0x41 and cp <= 0x5A:
        return True
    if cp >= 0x61 and cp <= 0x7A:
        return True
    if cp >= 0x30 and cp <= 0x39:
        return True
    return cp == 0x2D or cp == 0x2E or cp == 0x5F or cp == 0x7E


def _is_unreserved_byte(b: UInt8) -> Bool:
    return _is_unreserved(Int(b))


def _is_sub_delim(cp: Int) -> Bool:
    return (
        cp == 0x21
        or cp == 0x24
        or cp == 0x26
        or cp == 0x27
        or cp == 0x28
        or cp == 0x29
        or cp == 0x2A
        or cp == 0x2B
        or cp == 0x2C
        or cp == 0x3B
        or cp == 0x3D
    )


def _is_ascii_hex(cp: Int) -> Bool:
    if cp >= 0x30 and cp <= 0x39:
        return True
    if cp >= 0x41 and cp <= 0x46:
        return True
    if cp >= 0x61 and cp <= 0x66:
        return True
    return False


def _is_hex_byte(b: UInt8) -> Bool:
    return _is_ascii_hex(Int(b))


def _hex_val(b: UInt8) -> Int:
    if b >= 0x30 and b <= 0x39:
        return Int(b) - 0x30
    if b >= 0x41 and b <= 0x46:
        return Int(b) - 0x41 + 10
    return Int(b) - 0x61 + 10


def _hex_upper(nibble: Int) -> UInt8:
    if nibble < 10:
        return UInt8(0x30 + nibble)
    return UInt8(0x41 + nibble - 10)


# RFC 3987 ucschar.
def _is_ucschar(cp: Int) -> Bool:
    if cp >= 0xA0 and cp <= 0xD7FF:
        return True
    if cp >= 0xF900 and cp <= 0xFDCF:
        return True
    if cp >= 0xFDF0 and cp <= 0xFFEF:
        return True
    if cp >= 0x10000 and cp <= 0x1FFFD:
        return True
    if cp >= 0x20000 and cp <= 0x2FFFD:
        return True
    if cp >= 0x30000 and cp <= 0x3FFFD:
        return True
    if cp >= 0x40000 and cp <= 0x4FFFD:
        return True
    if cp >= 0x50000 and cp <= 0x5FFFD:
        return True
    if cp >= 0x60000 and cp <= 0x6FFFD:
        return True
    if cp >= 0x70000 and cp <= 0x7FFFD:
        return True
    if cp >= 0x80000 and cp <= 0x8FFFD:
        return True
    if cp >= 0x90000 and cp <= 0x9FFFD:
        return True
    if cp >= 0xA0000 and cp <= 0xAFFFD:
        return True
    if cp >= 0xB0000 and cp <= 0xBFFFD:
        return True
    if cp >= 0xC0000 and cp <= 0xCFFFD:
        return True
    if cp >= 0xD0000 and cp <= 0xDFFFD:
        return True
    return cp >= 0xE1000 and cp <= 0xEFFFD


# RFC 3987 iprivate (iquery only).
def _is_iprivate(cp: Int) -> Bool:
    if cp >= 0xE000 and cp <= 0xF8FF:
        return True
    if cp >= 0xF0000 and cp <= 0xFFFFD:
        return True
    return cp >= 0x100000 and cp <= 0x10FFFD
