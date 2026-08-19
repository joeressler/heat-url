# heat_url: standardized URI/URL parsing. Implement against specs/; see phases/.
from heat_url.error import (
    IdnaError,
    ParseError,
    ValidationError,
    check_input_length,
    redact_userinfo,
)
from heat_url.limits import (
    DEFAULT_MAX_AUTHORITY_LENGTH,
    DEFAULT_MAX_IDNA_LABELS,
    DEFAULT_MAX_INPUT_CODEPOINTS,
    DEFAULT_MAX_PATH_SEGMENTS,
    DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS,
    DEFAULT_MAX_QUERY_TUPLES,
    DNS_MAX_DOMAIN_OCTETS,
    DNS_MAX_LABEL_OCTETS,
)
from heat_url.host import (
    Ipv6Pieces,
    RfcHost,
    WhatwgHost,
    parse_host_rfc3986,
    parse_host_whatwg,
    serialize_host,
)
from heat_url.idna import to_ascii, to_unicode
from heat_url.idna_data import UNICODE_VERSION
from heat_url.options import ParseOptions
from heat_url.percent import (
    EncodeSet,
    decode_lenient,
    decode_strict,
    decode_utf8_lenient,
    decode_utf8_strict,
    encode,
)
from heat_url.profile import ParseProfile
from heat_url.punycode import punycode_decode, punycode_encode
from heat_url.query import QueryList
from heat_url.rfc3986 import PathKind, Uri, parse_uri

comptime VERSION: StaticString = "0.1.0"
