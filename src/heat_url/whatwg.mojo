from heat_url.error import (
    ParseError,
    ValidationError,
    check_input_length,
    redact_userinfo,
)
from heat_url.host import (
    WhatwgHost,
    parse_host_whatwg_with_errors,
    serialize_host,
)
from heat_url.limits import DEFAULT_MAX_PATH_SEGMENTS
from heat_url.options import ParseOptions
from heat_url.percent import EncodeSet, encode
from heat_url.query import QueryList


comptime _ST_SCHEME_START: Int = 0
comptime _ST_SCHEME: Int = 1
comptime _ST_NO_SCHEME: Int = 2
comptime _ST_SPECIAL_REL_OR_AUTH: Int = 3
comptime _ST_PATH_OR_AUTH: Int = 4
comptime _ST_RELATIVE: Int = 5
comptime _ST_RELATIVE_SLASH: Int = 6
comptime _ST_SPECIAL_AUTH_SLASHES: Int = 7
comptime _ST_SPECIAL_AUTH_IGNORE: Int = 8
comptime _ST_AUTHORITY: Int = 9
comptime _ST_HOST: Int = 10
comptime _ST_PORT: Int = 11
comptime _ST_FILE: Int = 12
comptime _ST_FILE_SLASH: Int = 13
comptime _ST_FILE_HOST: Int = 14
comptime _ST_PATH_START: Int = 15
comptime _ST_PATH: Int = 16
comptime _ST_OPAQUE_PATH: Int = 17
comptime _ST_QUERY: Int = 18
comptime _ST_FRAGMENT: Int = 19


# WHATWG URL record (specs/02-data-model.md). Blob URL entry is always null.
@fieldwise_init
struct Url(Copyable, Movable, Writable):
    var scheme: String
    var username: String
    var password: String
    var _host: WhatwgHost
    var _has_host: Bool
    var port: Optional[UInt16]
    var _path_opaque: Bool
    var _opaque_path: String
    var _path: List[String]
    var query: Optional[String]
    var fragment: Optional[String]

    @staticmethod
    def empty() -> Self:
        return Url(
            String(""),
            String(""),
            String(""),
            WhatwgHost.empty(),
            False,
            Optional[UInt16](None),
            False,
            String(""),
            List[String](),
            Optional[String](None),
            Optional[String](None),
        )

    # WHATWG basic URL parser (§4.4). Relative refs use parser states, not RFC 3986 §5.
    @staticmethod
    def parse(
        input: String, options: ParseOptions
    ) raises ParseError -> UrlParseResult:
        check_input_length(input, options)
        var cps = _codepoints(input)
        var errors = List[ValidationError]()
        if _has_leading_or_trailing_c0_space(cps):
            _record(errors, "invalid-URL-unit")
        cps = _trim_c0_space(cps)
        if _has_ascii_tab_or_newline(cps):
            _record(errors, "invalid-URL-unit")
        cps = _remove_ascii_tab_newline(cps)

        var has_base = False
        var base = Url.empty()
        if options.base is not None:
            var base_opts = options.copy()
            base_opts.base = Optional[String](None)
            base_opts.strict_whatwg = False
            var base_result = Url.parse(options.base.value(), base_opts)
            base = base_result.url.copy()
            has_base = True

        var url = _basic_parse(
            cps^, errors, has_base, base, DEFAULT_MAX_PATH_SEGMENTS
        )
        if options.strict_whatwg and len(errors) > 0:
            var name = errors[0].name.copy()
            var message = "WHATWG validation error: " + name
            raise ParseError.whatwg_failure(
                "validation_error", name^, redact_userinfo(message)
            )
        return UrlParseResult(url^, errors^)

    def host(self) -> Optional[WhatwgHost]:
        if not self._has_host:
            return Optional[WhatwgHost](None)
        return Optional(self._host.copy())

    def is_special(self) -> Bool:
        return _is_special_scheme(self.scheme)

    def has_opaque_path(self) -> Bool:
        return self._path_opaque

    def includes_credentials(self) -> Bool:
        return (
            self.username.byte_length() > 0 or self.password.byte_length() > 0
        )

    def path_segments(self) -> List[String]:
        return _clone_strings(self._path)

    def opaque_path(self) -> String:
        return self._opaque_path.copy()

    # WHATWG URL Standard §4.5 serializer.
    def serialize(self, exclude_fragment: Bool = False) -> String:
        var out = self.scheme + ":"
        if self._has_host:
            out += "//"
            if self.includes_credentials():
                out += self.username
                if self.password.byte_length() > 0:
                    out += ":"
                    out += self.password
                out += "@"
            out += serialize_host(self._host.copy())
            if self.port is not None:
                out += ":"
                out += String(Int(self.port.value()))
        if (
            (not self._has_host)
            and (not self._path_opaque)
            and len(self._path) > 1
            and self._path[0].byte_length() == 0
        ):
            out += "/."
        out += self._serialize_path()
        if self.query is not None:
            out += "?"
            out += self.query.value()
        if (not exclude_fragment) and self.fragment is not None:
            out += "#"
            out += self.fragment.value()
        return out^

    def _serialize_path(self) -> String:
        if self._path_opaque:
            return self._opaque_path.copy()
        var out = String("")
        var i = 0
        while i < len(self._path):
            out += "/"
            out += self._path[i]
            i += 1
        return out^

    # WHATWG §4.6; library default excludes fragment (specs/02).
    def equals(self, other: Self, *, include_fragment: Bool = False) -> Bool:
        return self.serialize(
            exclude_fragment=not include_fragment
        ) == other.serialize(exclude_fragment=not include_fragment)

    # Form-urlencoded view of the opaque query (specs/05, specs/09).
    def query_list(self) raises ParseError -> QueryList:
        if self.query is None:
            return QueryList.parse("")
        return QueryList.parse(self.query.value())

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.serialize())


@fieldwise_init
struct UrlParseResult(Movable):
    var url: Url
    var validation_errors: List[ValidationError]

    def has_error(self, name: String) -> Bool:
        var i = 0
        while i < len(self.validation_errors):
            if self.validation_errors[i].name == name:
                return True
            i += 1
        return False


def _basic_parse(
    cps: List[Int],
    mut errors: List[ValidationError],
    has_base: Bool,
    base: Url,
    max_path_segments: Int,
) raises ParseError -> Url:
    var url = Url.empty()
    var pointer = 0
    var state = _ST_SCHEME_START
    var buffer = String("")
    var at_sign_seen = False
    var inside_brackets = False
    var password_token_seen = False
    var n = len(cps)

    while True:
        var c = _code_at(cps, pointer, n)
        if state == _ST_SCHEME_START:
            if _is_ascii_alpha(c):
                buffer += _string_from_cp(_ascii_lower_cp(c))
                state = _ST_SCHEME
            else:
                state = _ST_NO_SCHEME
                pointer -= 1
        elif state == _ST_SCHEME:
            if _is_ascii_alphanumeric(c) or c == 0x2B or c == 0x2D or c == 0x2E:
                buffer += _string_from_cp(_ascii_lower_cp(c))
            elif c == 0x3A:
                url.scheme = buffer.copy()
                buffer = String("")
                if url.scheme == "file":
                    if not _rest_starts_with_2(cps, pointer, n, 0x2F, 0x2F):
                        _record(
                            errors, "special-scheme-missing-following-solidus"
                        )
                    state = _ST_FILE
                elif (
                    url.is_special() and has_base and base.scheme == url.scheme
                ):
                    state = _ST_SPECIAL_REL_OR_AUTH
                elif url.is_special():
                    state = _ST_SPECIAL_AUTH_SLASHES
                elif _rest_starts_with_1(cps, pointer, n, 0x2F):
                    state = _ST_PATH_OR_AUTH
                    pointer += 1
                else:
                    url._path_opaque = True
                    url._opaque_path = String("")
                    url._path = List[String]()
                    state = _ST_OPAQUE_PATH
            else:
                buffer = String("")
                state = _ST_NO_SCHEME
                pointer = -1
        elif state == _ST_NO_SCHEME:
            if (not has_base) or (base.has_opaque_path() and c != 0x23):
                raise ParseError.whatwg_failure(
                    "missing_scheme_non_relative_url",
                    "missing-scheme-non-relative-URL",
                    "input is missing a scheme and cannot use the base URL",
                )
            elif base.has_opaque_path() and c == 0x23:
                url.scheme = base.scheme.copy()
                url._path_opaque = True
                url._opaque_path = base._opaque_path.copy()
                url._path = List[String]()
                url.query = _clone_optional(base.query)
                url.fragment = Optional(String(""))
                state = _ST_FRAGMENT
            elif base.scheme != "file":
                state = _ST_RELATIVE
                pointer -= 1
            else:
                state = _ST_FILE
                pointer -= 1
        elif state == _ST_SPECIAL_REL_OR_AUTH:
            if c == 0x2F and _rest_starts_with_1(cps, pointer, n, 0x2F):
                state = _ST_SPECIAL_AUTH_IGNORE
                pointer += 1
            else:
                _record(errors, "special-scheme-missing-following-solidus")
                state = _ST_RELATIVE
                pointer -= 1
        elif state == _ST_PATH_OR_AUTH:
            if c == 0x2F:
                state = _ST_AUTHORITY
            else:
                state = _ST_PATH
                pointer -= 1
        elif state == _ST_RELATIVE:
            url.scheme = base.scheme.copy()
            if c == 0x2F:
                state = _ST_RELATIVE_SLASH
            elif url.is_special() and c == 0x5C:
                _record(errors, "invalid-reverse-solidus")
                state = _ST_RELATIVE_SLASH
            else:
                _copy_from_base_relative(url, base)
                if c == 0x3F:
                    url.query = Optional(String(""))
                    state = _ST_QUERY
                elif c == 0x23:
                    url.fragment = Optional(String(""))
                    state = _ST_FRAGMENT
                elif c >= 0:
                    url.query = Optional[String](None)
                    _shorten_path(url)
                    state = _ST_PATH
                    pointer -= 1
        elif state == _ST_RELATIVE_SLASH:
            if url.is_special() and (c == 0x2F or c == 0x5C):
                if c == 0x5C:
                    _record(errors, "invalid-reverse-solidus")
                state = _ST_SPECIAL_AUTH_IGNORE
            elif c == 0x2F:
                state = _ST_AUTHORITY
            else:
                url.username = base.username.copy()
                url.password = base.password.copy()
                url._host = base._host.copy()
                url._has_host = base._has_host
                url.port = base.port
                state = _ST_PATH
                pointer -= 1
        elif state == _ST_SPECIAL_AUTH_SLASHES:
            if c == 0x2F and _rest_starts_with_1(cps, pointer, n, 0x2F):
                state = _ST_SPECIAL_AUTH_IGNORE
                pointer += 1
            else:
                _record(errors, "special-scheme-missing-following-solidus")
                state = _ST_SPECIAL_AUTH_IGNORE
                pointer -= 1
        elif state == _ST_SPECIAL_AUTH_IGNORE:
            if c != 0x2F and c != 0x5C:
                state = _ST_AUTHORITY
                pointer -= 1
            else:
                _record(errors, "special-scheme-missing-following-solidus")
        elif state == _ST_AUTHORITY:
            if c == 0x40:
                _record(errors, "invalid-credentials")
                if at_sign_seen:
                    buffer = "%40" + buffer
                at_sign_seen = True
                password_token_seen = _apply_userinfo(
                    url, buffer, password_token_seen
                )
                buffer = String("")
            elif (
                c < 0
                or c == 0x2F
                or c == 0x3F
                or c == 0x23
                or (url.is_special() and c == 0x5C)
            ):
                if at_sign_seen and buffer.byte_length() == 0:
                    raise ParseError.whatwg_failure(
                        "host_missing",
                        "host-missing",
                        "special URL is missing a host",
                    )
                pointer -= buffer.count_codepoints() + 1
                buffer = String("")
                state = _ST_HOST
            else:
                buffer += _string_from_cp(c)
        elif state == _ST_HOST:
            if c == 0x3A and not inside_brackets:
                if buffer.byte_length() == 0:
                    raise ParseError.whatwg_failure(
                        "host_missing",
                        "host-missing",
                        "host is empty before port",
                    )
                _set_host(url, buffer, errors)
                buffer = String("")
                state = _ST_PORT
            elif (
                c < 0
                or c == 0x2F
                or c == 0x3F
                or c == 0x23
                or (url.is_special() and c == 0x5C)
            ):
                pointer -= 1
                if url.is_special() and buffer.byte_length() == 0:
                    raise ParseError.whatwg_failure(
                        "host_missing",
                        "host-missing",
                        "special URL is missing a host",
                    )
                _set_host(url, buffer, errors)
                buffer = String("")
                state = _ST_PATH_START
            else:
                if c == 0x5B:
                    inside_brackets = True
                if c == 0x5D:
                    inside_brackets = False
                buffer += _string_from_cp(c)
        elif state == _ST_PORT:
            if _is_ascii_digit(c):
                buffer += _string_from_cp(c)
            elif (
                c < 0
                or c == 0x2F
                or c == 0x3F
                or c == 0x23
                or (url.is_special() and c == 0x5C)
            ):
                if buffer.byte_length() > 0:
                    _set_port(url, buffer)
                    buffer = String("")
                state = _ST_PATH_START
                pointer -= 1
            else:
                raise ParseError.whatwg_failure(
                    "port_invalid",
                    "port-invalid",
                    "port is not a valid decimal number",
                )
        elif state == _ST_FILE:
            url.scheme = String("file")
            url._host = WhatwgHost.empty()
            url._has_host = True
            if c == 0x2F or c == 0x5C:
                if c == 0x5C:
                    _record(errors, "invalid-reverse-solidus")
                state = _ST_FILE_SLASH
            elif has_base and base.scheme == "file":
                url._host = base._host.copy()
                url._has_host = base._has_host
                url._path = _clone_strings(base._path)
                url._path_opaque = False
                url._opaque_path = String("")
                url.query = _clone_optional(base.query)
                if c == 0x3F:
                    url.query = Optional(String(""))
                    state = _ST_QUERY
                elif c == 0x23:
                    url.fragment = Optional(String(""))
                    state = _ST_FRAGMENT
                elif c >= 0:
                    url.query = Optional[String](None)
                    if not _starts_with_windows_drive_letter(cps, pointer):
                        _shorten_path(url)
                    else:
                        _record(errors, "file-invalid-Windows-drive-letter")
                        url._path = List[String]()
                    state = _ST_PATH
                    pointer -= 1
            else:
                state = _ST_PATH
                pointer -= 1
        elif state == _ST_FILE_SLASH:
            if c == 0x2F or c == 0x5C:
                if c == 0x5C:
                    _record(errors, "invalid-reverse-solidus")
                state = _ST_FILE_HOST
            else:
                if has_base and base.scheme == "file":
                    url._host = base._host.copy()
                    url._has_host = base._has_host
                    if (
                        not _starts_with_windows_drive_letter(cps, pointer)
                        and len(base._path) > 0
                        and _is_normalized_windows_drive_letter(base._path[0])
                    ):
                        url._path.append(base._path[0].copy())
                state = _ST_PATH
                pointer -= 1
        elif state == _ST_FILE_HOST:
            if c < 0 or c == 0x2F or c == 0x5C or c == 0x3F or c == 0x23:
                pointer -= 1
                if _is_windows_drive_letter(buffer):
                    _record(errors, "file-invalid-Windows-drive-letter-host")
                    state = _ST_PATH
                elif buffer.byte_length() == 0:
                    url._host = WhatwgHost.empty()
                    url._has_host = True
                    state = _ST_PATH_START
                else:
                    _set_host(url, buffer, errors)
                    if (
                        url._has_host
                        and url._host.is_domain()
                        and url._host.serialize() == "localhost"
                    ):
                        url._host = WhatwgHost.empty()
                    buffer = String("")
                    state = _ST_PATH_START
            else:
                buffer += _string_from_cp(c)
        elif state == _ST_PATH_START:
            if url.is_special():
                if c == 0x5C:
                    _record(errors, "invalid-reverse-solidus")
                state = _ST_PATH
                if c != 0x2F and c != 0x5C:
                    pointer -= 1
            elif c == 0x3F:
                url.query = Optional(String(""))
                state = _ST_QUERY
            elif c == 0x23:
                url.fragment = Optional(String(""))
                state = _ST_FRAGMENT
            elif c >= 0:
                state = _ST_PATH
                if c != 0x2F:
                    pointer -= 1
        elif state == _ST_PATH:
            if (
                c < 0
                or c == 0x2F
                or (url.is_special() and c == 0x5C)
                or c == 0x3F
                or c == 0x23
            ):
                if url.is_special() and c == 0x5C:
                    _record(errors, "invalid-reverse-solidus")
                if _is_double_dot_segment(buffer):
                    _shorten_path(url)
                    if not (c == 0x2F or (url.is_special() and c == 0x5C)):
                        _append_segment(url, "", max_path_segments)
                elif _is_single_dot_segment(buffer):
                    if not (c == 0x2F or (url.is_special() and c == 0x5C)):
                        _append_segment(url, "", max_path_segments)
                else:
                    if (
                        url.scheme == "file"
                        and len(url._path) == 0
                        and _is_windows_drive_letter(buffer)
                    ):
                        buffer = _normalize_drive_letter(buffer)
                    _append_segment(url, buffer, max_path_segments)
                buffer = String("")
                if c == 0x3F:
                    url.query = Optional(String(""))
                    state = _ST_QUERY
                elif c == 0x23:
                    url.fragment = Optional(String(""))
                    state = _ST_FRAGMENT
            else:
                if c != 0x25 and not _is_url_code_point(c):
                    _record(errors, "invalid-URL-unit")
                if c == 0x25 and not _rest_hex_pair(cps, pointer, n):
                    _record(errors, "invalid-URL-unit")
                buffer += encode(_string_from_cp(c), EncodeSet.Path)
        elif state == _ST_OPAQUE_PATH:
            if c == 0x3F:
                url.query = Optional(String(""))
                state = _ST_QUERY
            elif c == 0x23:
                url.fragment = Optional(String(""))
                state = _ST_FRAGMENT
            elif c == 0x20:
                _record(errors, "invalid-URL-unit")
                if _rest_starts_with_1(
                    cps, pointer, n, 0x3F
                ) or _rest_starts_with_1(cps, pointer, n, 0x23):
                    url._opaque_path += "%20"
                else:
                    url._opaque_path += " "
            elif c >= 0:
                if c != 0x25 and not _is_url_code_point(c):
                    _record(errors, "invalid-URL-unit")
                if c == 0x25 and not _rest_hex_pair(cps, pointer, n):
                    _record(errors, "invalid-URL-unit")
                url._opaque_path += encode(
                    _string_from_cp(c), EncodeSet.C0Control
                )
        elif state == _ST_QUERY:
            if c == 0x23 or c < 0:
                var qset = EncodeSet.Query
                if url.is_special():
                    qset = EncodeSet.SpecialQuery
                var encoded = encode(buffer, qset)
                var q = url.query.value()
                q += encoded
                url.query = Optional(q^)
                buffer = String("")
                if c == 0x23:
                    url.fragment = Optional(String(""))
                    state = _ST_FRAGMENT
            elif c >= 0:
                if c != 0x25 and not _is_url_code_point(c):
                    _record(errors, "invalid-URL-unit")
                if c == 0x25 and not _rest_hex_pair(cps, pointer, n):
                    _record(errors, "invalid-URL-unit")
                buffer += _string_from_cp(c)
        else:
            if c >= 0:
                if c != 0x25 and not _is_url_code_point(c):
                    _record(errors, "invalid-URL-unit")
                if c == 0x25 and not _rest_hex_pair(cps, pointer, n):
                    _record(errors, "invalid-URL-unit")
                var frag = url.fragment.value()
                frag += encode(_string_from_cp(c), EncodeSet.Fragment)
                url.fragment = Optional(frag^)

        if pointer >= n:
            break
        pointer += 1

    return url^


def _copy_from_base_relative(mut url: Url, base: Url):
    url.username = base.username.copy()
    url.password = base.password.copy()
    url._host = base._host.copy()
    url._has_host = base._has_host
    url.port = base.port
    url._path_opaque = base._path_opaque
    url._opaque_path = base._opaque_path.copy()
    url._path = _clone_strings(base._path)
    url.query = _clone_optional(base.query)


def _apply_userinfo(
    mut url: Url, buffer: String, password_token_seen_start: Bool
) -> Bool:
    var password_token_seen = password_token_seen_start
    for cp in buffer.codepoints():
        var code = Int(cp)
        if code == 0x3A and not password_token_seen:
            password_token_seen = True
            continue
        var encoded = encode(_string_from_cp(code), EncodeSet.Userinfo)
        if password_token_seen:
            url.password += encoded
        else:
            url.username += encoded
    return password_token_seen


def _set_host(
    mut url: Url, buffer: String, mut errors: List[ValidationError]
) raises ParseError:
    var is_opaque = not url.is_special()
    var host = parse_host_whatwg_with_errors(
        buffer.copy(), errors, is_opaque=is_opaque
    )
    url._host = host^
    url._has_host = True


def _set_port(mut url: Url, buffer: String) raises ParseError:
    var port_val = 0
    var src = buffer.as_bytes()
    var i = 0
    while i < len(src):
        var d = Int(src[i]) - 0x30
        if port_val > (65535 - d) // 10:
            raise ParseError.whatwg_failure(
                "port_out_of_range",
                "port-out-of-range",
                "port is greater than 65535",
            )
        port_val = port_val * 10 + d
        i += 1
    if port_val > 65535:
        raise ParseError.whatwg_failure(
            "port_out_of_range",
            "port-out-of-range",
            "port is greater than 65535",
        )
    var def_port = _default_port(url.scheme)
    if def_port is not None and Int(def_port.value()) == port_val:
        url.port = Optional[UInt16](None)
    else:
        url.port = Optional(UInt16(port_val))


def _append_segment(
    mut url: Url, segment: String, max_path_segments: Int
) raises ParseError:
    if len(url._path) >= max_path_segments:
        raise ParseError.too_many_path_segments(
            len(url._path) + 1, max_path_segments
        )
    url._path.append(segment.copy())


def _shorten_path(mut url: Url):
    if url._path_opaque:
        return
    if (
        url.scheme == "file"
        and len(url._path) == 1
        and _is_normalized_windows_drive_letter(url._path[0])
    ):
        return
    if len(url._path) > 0:
        _ = url._path.pop()


def _is_special_scheme(scheme: String) -> Bool:
    return (
        scheme == "ftp"
        or scheme == "file"
        or scheme == "http"
        or scheme == "https"
        or scheme == "ws"
        or scheme == "wss"
    )


def _default_port(scheme: String) -> Optional[UInt16]:
    if scheme == "ftp":
        return Optional(UInt16(21))
    if scheme == "http" or scheme == "ws":
        return Optional(UInt16(80))
    if scheme == "https" or scheme == "wss":
        return Optional(UInt16(443))
    return Optional[UInt16](None)


def _is_single_dot_segment(s: String) -> Bool:
    var x = _ascii_lower(s)
    return x == "." or x == "%2e"


def _is_double_dot_segment(s: String) -> Bool:
    var x = _ascii_lower(s)
    return x == ".." or x == ".%2e" or x == "%2e." or x == "%2e%2e"


def _is_windows_drive_letter(s: String) -> Bool:
    var cps = _codepoints(s)
    if len(cps) != 2:
        return False
    return _is_ascii_alpha(cps[0]) and (cps[1] == 0x3A or cps[1] == 0x7C)


def _is_normalized_windows_drive_letter(s: String) -> Bool:
    var cps = _codepoints(s)
    if len(cps) != 2:
        return False
    return _is_ascii_alpha(cps[0]) and cps[1] == 0x3A


def _normalize_drive_letter(s: String) -> String:
    return String(s[byte=0:1]) + ":"


def _starts_with_windows_drive_letter(cps: List[Int], pointer: Int) -> Bool:
    var n = len(cps) - pointer
    if n < 2:
        return False
    if not _is_ascii_alpha(cps[pointer]):
        return False
    if cps[pointer + 1] != 0x3A and cps[pointer + 1] != 0x7C:
        return False
    if n == 2:
        return True
    var c3 = cps[pointer + 2]
    return c3 == 0x2F or c3 == 0x5C or c3 == 0x3F or c3 == 0x23


def _record(mut errors: List[ValidationError], name: String):
    errors.append(ValidationError(name.copy(), Optional[Int]()))


def _code_at(cps: List[Int], pointer: Int, n: Int) -> Int:
    if pointer < 0 or pointer >= n:
        return -1
    return cps[pointer]


def _rest_starts_with_1(cps: List[Int], pointer: Int, n: Int, a: Int) -> Bool:
    return pointer + 1 < n and cps[pointer + 1] == a


def _rest_starts_with_2(
    cps: List[Int], pointer: Int, n: Int, a: Int, b: Int
) -> Bool:
    return (
        pointer + 1 < n
        and cps[pointer + 1] == a
        and pointer + 2 < n
        and cps[pointer + 2] == b
    )


def _rest_hex_pair(cps: List[Int], pointer: Int, n: Int) -> Bool:
    return (
        pointer + 2 < n
        and _is_ascii_hex(cps[pointer + 1])
        and _is_ascii_hex(cps[pointer + 2])
    )


def _has_leading_or_trailing_c0_space(cps: List[Int]) -> Bool:
    var n = len(cps)
    if n == 0:
        return False
    return _is_c0_or_space(cps[0]) or _is_c0_or_space(cps[n - 1])


def _trim_c0_space(cps: List[Int]) -> List[Int]:
    var n = len(cps)
    var start = 0
    var end = n
    while start < end and _is_c0_or_space(cps[start]):
        start += 1
    while end > start and _is_c0_or_space(cps[end - 1]):
        end -= 1
    var out = List[Int]()
    var i = start
    while i < end:
        out.append(cps[i])
        i += 1
    return out^


def _has_ascii_tab_or_newline(cps: List[Int]) -> Bool:
    var i = 0
    while i < len(cps):
        if _is_ascii_tab_or_newline(cps[i]):
            return True
        i += 1
    return False


def _remove_ascii_tab_newline(cps: List[Int]) -> List[Int]:
    var out = List[Int]()
    var i = 0
    while i < len(cps):
        if not _is_ascii_tab_or_newline(cps[i]):
            out.append(cps[i])
        i += 1
    return out^


def _is_c0_or_space(cp: Int) -> Bool:
    return cp >= 0 and cp <= 0x20


def _is_ascii_tab_or_newline(cp: Int) -> Bool:
    return cp == 0x09 or cp == 0x0A or cp == 0x0D


def _is_ascii_alpha(cp: Int) -> Bool:
    return (cp >= 0x41 and cp <= 0x5A) or (cp >= 0x61 and cp <= 0x7A)


def _is_ascii_digit(cp: Int) -> Bool:
    return cp >= 0x30 and cp <= 0x39


def _is_ascii_alphanumeric(cp: Int) -> Bool:
    return _is_ascii_alpha(cp) or _is_ascii_digit(cp)


def _is_ascii_hex(cp: Int) -> Bool:
    if _is_ascii_digit(cp):
        return True
    if cp >= 0x41 and cp <= 0x46:
        return True
    return cp >= 0x61 and cp <= 0x66


def _ascii_lower_cp(cp: Int) -> Int:
    if cp >= 0x41 and cp <= 0x5A:
        return cp + 0x20
    return cp


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


def _is_url_code_point(cp: Int) -> Bool:
    if _is_ascii_alphanumeric(cp):
        return True
    if (
        cp == 0x21
        or cp == 0x24
        or cp == 0x26
        or cp == 0x27
        or cp == 0x28
        or cp == 0x29
        or cp == 0x2A
        or cp == 0x2B
        or cp == 0x2C
        or cp == 0x2D
        or cp == 0x2E
        or cp == 0x2F
        or cp == 0x3A
        or cp == 0x3B
        or cp == 0x3D
        or cp == 0x3F
        or cp == 0x40
        or cp == 0x5F
        or cp == 0x7E
    ):
        return True
    if cp < 0xA0 or cp > 0x10FFFD:
        return False
    if cp >= 0xD800 and cp <= 0xDFFF:
        return False
    return not _is_noncharacter(cp)


def _is_noncharacter(cp: Int) -> Bool:
    if cp >= 0xFDD0 and cp <= 0xFDEF:
        return True
    var low = cp & 0xFFFF
    return low == 0xFFFE or low == 0xFFFF


def _codepoints(s: String) -> List[Int]:
    var out = List[Int]()
    for cp in s.codepoints():
        out.append(Int(cp))
    return out^


def _string_from_cp(cp: Int) -> String:
    var out = List[UInt8]()
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
    return String(unsafe_from_utf8=out)


def _clone_strings(segs: List[String]) -> List[String]:
    var out = List[String]()
    var i = 0
    while i < len(segs):
        out.append(segs[i].copy())
        i += 1
    return out^


def _clone_optional(v: Optional[String]) -> Optional[String]:
    if v is None:
        return Optional[String](None)
    return Optional(v.value().copy())
