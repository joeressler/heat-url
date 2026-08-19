from heat_url.limits import DEFAULT_MAX_INPUT_CODEPOINTS
from heat_url.profile import ParseProfile


# Per-call parser configuration (specs/09-api.md).
@fieldwise_init
struct ParseOptions(Copyable, Movable):
    var profile: ParseProfile
    var iri: Bool
    var allow_ipv6_zone_id: Bool
    var normalize_syntax: Bool
    var idna_host: Bool
    var strict_whatwg: Bool
    var max_input_length: Int

    @staticmethod
    def rfc3986() -> Self:
        return ParseOptions(
            ParseProfile.rfc3986,
            True,
            True,
            False,
            False,
            False,
            DEFAULT_MAX_INPUT_CODEPOINTS,
        )

    @staticmethod
    def whatwg() -> Self:
        return ParseOptions(
            ParseProfile.whatwg,
            True,
            True,
            False,
            False,
            False,
            DEFAULT_MAX_INPUT_CODEPOINTS,
        )
