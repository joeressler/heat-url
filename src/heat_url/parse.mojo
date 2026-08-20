from heat_url.error import ParseError
from heat_url.host import RfcHost
from heat_url.options import ParseOptions
from heat_url.profile import ParseProfile
from heat_url.rfc3986 import PathKind, Uri, parse_uri as _parse_uri_rfc
from heat_url.whatwg import Url, UrlParseResult


# Url | Uri matching ParseOptions.profile (specs/09-api.md).
@fieldwise_init
struct Parsed(Copyable, Movable, Writable):
    var _variant: Int
    var _url: Url
    var _uri: Uri

    comptime _KIND_URL: Int = 0
    comptime _KIND_URI: Int = 1

    @staticmethod
    def from_url(url: Url) -> Self:
        return Parsed(Self._KIND_URL, url.copy(), _dummy_uri())

    @staticmethod
    def from_uri(uri: Uri) -> Self:
        return Parsed(Self._KIND_URI, Url.empty(), uri.copy())

    def is_url(self) -> Bool:
        return self._variant == Self._KIND_URL

    def is_uri(self) -> Bool:
        return self._variant == Self._KIND_URI

    def url(self) -> Optional[Url]:
        if not self.is_url():
            return Optional[Url](None)
        return Optional(self._url.copy())

    def uri(self) -> Optional[Uri]:
        if not self.is_uri():
            return Optional[Uri](None)
        return Optional(self._uri.copy())

    def serialize(self, exclude_fragment: Bool = False) -> String:
        if self.is_url():
            return self._url.serialize(exclude_fragment)
        return self._uri.serialize(exclude_fragment)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.serialize())


# WHATWG basic URL parser (URL Standard §4.4). Raises ParseError on failure.
def parse_url(
    input: String, base: Optional[String] = None
) raises ParseError -> Url:
    var result = parse_url_detailed(input, base)
    return result.url.copy()


# WHATWG basic URL parser; empty Optional on failure (analogue of URL.parse).
def try_parse_url(
    input: String, base: Optional[String] = None
) -> Optional[Url]:
    try:
        return Optional(parse_url(input, base))
    except _:
        return Optional[Url](None)


# WHATWG basic URL parser plus validation-error list (specs/08, specs/09).
def parse_url_detailed(
    input: String, base: Optional[String] = None
) raises ParseError -> UrlParseResult:
    var options = ParseOptions.whatwg()
    options.base = base
    return Url.parse(input, options)


# RFC 3986 URI-reference parser; `base` selects §5.2 when input is relative-ref.
def parse_uri(
    input: String, base: Optional[String] = None
) raises ParseError -> Uri:
    return _parse_uri_rfc(input, base)


# RFC 3986 URI-reference parser; empty Optional on failure.
def try_parse_uri(
    input: String, base: Optional[String] = None
) -> Optional[Uri]:
    try:
        return Optional(parse_uri(input, base))
    except _:
        return Optional[Uri](None)


# Dispatch on options.profile only; never guess (specs/00, specs/09).
def parse(input: String, options: ParseOptions) raises ParseError -> Parsed:
    if options.profile == ParseProfile.whatwg:
        var result = Url.parse(input, options.copy())
        return Parsed.from_url(result.url.copy())
    var uri = Uri.parse(input, options.copy())
    return Parsed.from_uri(uri^)


def _dummy_uri() -> Uri:
    return Uri(
        Optional[String](None),
        Optional[String](None),
        RfcHost.reg_name(""),
        Optional[String](None),
        Optional[UInt16](None),
        String(""),
        Optional[String](None),
        Optional[String](None),
        False,
        True,
        PathKind.empty,
    )
