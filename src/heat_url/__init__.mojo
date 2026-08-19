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
    DNS_MAX_LABEL_OCTETS,
)
from heat_url.options import ParseOptions
from heat_url.profile import ParseProfile

comptime VERSION: StaticString = "0.1.0"
