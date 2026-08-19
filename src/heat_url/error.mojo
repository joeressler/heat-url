from heat_url.options import ParseOptions
from heat_url.profile import ParseProfile


# Fatal parse failure for the active profile (specs/08-error-handling.md).
@fieldwise_init
struct ParseError(Copyable, Movable, Writable):
    var profile: ParseProfile
    var kind: String
    var message: String
    var index: Optional[Int]
    var whatwg_name: Optional[String]

    @staticmethod
    def input_too_long(
        profile: ParseProfile, length: Int, max_length: Int
    ) -> Self:
        var message = (
            "input length "
            + String(length)
            + " exceeds max_input_length "
            + String(max_length)
        )
        return ParseError(
            profile,
            "input_too_long",
            message^,
            Optional[Int](),
            Optional[String](),
        )

    @staticmethod
    def invalid_percent_encoding(index: Int) -> Self:
        return ParseError(
            ParseProfile.rfc3986,
            "invalid_percent_encoding",
            "percent-encoding is not two hex digits",
            Optional(index),
            Optional[String](),
        )

    @staticmethod
    def invalid_utf8(profile: ParseProfile) -> Self:
        return ParseError(
            profile,
            "invalid_utf8",
            "percent-decoded bytes are not valid UTF-8",
            Optional[Int](),
            Optional[String](),
        )

    @staticmethod
    def too_many_query_tuples(
        profile: ParseProfile, count: Int, max_tuples: Int
    ) -> Self:
        var message = (
            "query tuple count "
            + String(count)
            + " exceeds max_tuples "
            + String(max_tuples)
        )
        return ParseError(
            profile,
            "too_many_query_tuples",
            message^,
            Optional[Int](),
            Optional[String](),
        )

    @staticmethod
    def authority_too_long(
        profile: ParseProfile, length: Int, max_length: Int
    ) -> Self:
        var message = (
            "host length "
            + String(length)
            + " exceeds max_authority_length "
            + String(max_length)
        )
        return ParseError(
            profile,
            "authority_too_long",
            message^,
            Optional[Int](),
            Optional[String](),
        )

    @staticmethod
    def host_failure(
        profile: ParseProfile,
        kind: String,
        message: String,
        whatwg_name: Optional[String],
    ) -> Self:
        return ParseError(
            profile,
            kind.copy(),
            message.copy(),
            Optional[Int](),
            whatwg_name,
        )

    @staticmethod
    def rfc_failure(kind: String, message: String) -> Self:
        return ParseError(
            ParseProfile.rfc3986,
            kind.copy(),
            message.copy(),
            Optional[Int](),
            Optional[String](),
        )

    @staticmethod
    def rfc_failure_at(kind: String, message: String, index: Int) -> Self:
        return ParseError(
            ParseProfile.rfc3986,
            kind.copy(),
            message.copy(),
            Optional(index),
            Optional[String](),
        )

    def write_to(self, mut writer: Some[Writer]):
        writer.write("ParseError(", self.profile, ", ", self.kind, ")")
        if self.message.byte_length() > 0:
            writer.write(": ", self.message)


def check_input_length(input: String, options: ParseOptions) raises ParseError:
    var n = input.count_codepoints()
    if n > options.max_input_length:
        raise ParseError.input_too_long(
            options.profile, n, options.max_input_length
        )


# WHATWG non-fatal mismatch; parse still succeeds (specs/08).
@fieldwise_init
struct ValidationError(Copyable, Movable, Writable):
    var name: String
    var index: Optional[Int]
    comptime fatal: Bool = False

    def write_to(self, mut writer: Some[Writer]):
        writer.write("ValidationError(", self.name, ")")


# UTS #46 / Punycode failure (specs/08, specs/06).
@fieldwise_init
struct IdnaError(Copyable, Movable, Writable):
    var code: String
    var message: String

    @staticmethod
    def punycode_bad_input(message: String) -> Self:
        return IdnaError("punycode_bad_input", message.copy())

    @staticmethod
    def punycode_overflow() -> Self:
        return IdnaError("punycode_overflow", "punycode arithmetic overflow")

    @staticmethod
    def punycode_too_long(length: Int, max_length: Int) -> Self:
        var message = (
            "punycode label length "
            + String(length)
            + " exceeds "
            + String(max_length)
        )
        return IdnaError("punycode_too_long", message^)

    @staticmethod
    def input_too_long(length: Int, max_length: Int) -> Self:
        var message = (
            "input length " + String(length) + " exceeds " + String(max_length)
        )
        return IdnaError("input_too_long", message^)

    @staticmethod
    def too_many_labels(count: Int, max_labels: Int) -> Self:
        var message = (
            "IDNA label count "
            + String(count)
            + " exceeds "
            + String(max_labels)
        )
        return IdnaError("too_many_labels", message^)

    @staticmethod
    def disallowed() -> Self:
        return IdnaError("disallowed", "disallowed IDNA code point")

    @staticmethod
    def not_nfc() -> Self:
        return IdnaError("not_nfc", "label is not Unicode NFC")

    @staticmethod
    def check_hyphens() -> Self:
        return IdnaError("check_hyphens", "label has forbidden hyphens")

    @staticmethod
    def leading_combining_mark() -> Self:
        return IdnaError(
            "leading_combining_mark", "label begins with a combining mark"
        )

    @staticmethod
    def std3() -> Self:
        return IdnaError("std3", "label violates STD3 ASCII rules")

    @staticmethod
    def check_bidi() -> Self:
        return IdnaError("check_bidi", "label violates IDNA Bidi Rule")

    @staticmethod
    def check_joiners() -> Self:
        return IdnaError("check_joiners", "label violates CONTEXTJ")

    @staticmethod
    def invalid_ace() -> Self:
        return IdnaError("invalid_ace", "invalid xn-- / Punycode label")

    @staticmethod
    def dns_length() -> Self:
        return IdnaError("dns_length", "domain or label DNS length invalid")

    def write_to(self, mut writer: Some[Writer]):
        writer.write("IdnaError(", self.code, ")")
        if self.message.byte_length() > 0:
            writer.write(": ", self.message)


# Strip userinfo so error text cannot leak passwords (specs/08 security).
def redact_userinfo(text: String) -> String:
    var scheme = text.find("://")
    if scheme < 0:
        return text.copy()
    var host_start = scheme + 3
    var authority_end = _authority_end(text, host_start)
    var at = text.find("@", host_start)
    if at < 0 or at >= authority_end:
        return text.copy()
    return String(text[byte=0:host_start]) + "REDACTED" + String(text[byte=at:])


def _authority_end(text: String, host_start: Int) -> Int:
    var end = text.byte_length()
    end = _min_positive(end, text.find("/", host_start))
    end = _min_positive(end, text.find("?", host_start))
    end = _min_positive(end, text.find("#", host_start))
    return end


def _min_positive(current: Int, candidate: Int) -> Int:
    if candidate >= 0 and candidate < current:
        return candidate
    return current
