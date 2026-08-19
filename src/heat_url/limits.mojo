# Default resource caps from specs/08-error-handling.md (DoS bounds).

comptime DEFAULT_MAX_INPUT_CODEPOINTS: Int = 1 << 20
comptime DEFAULT_MAX_AUTHORITY_LENGTH: Int = 32 * 1024
comptime DEFAULT_MAX_PATH_SEGMENTS: Int = 8192
comptime DEFAULT_MAX_QUERY_TUPLES: Int = 4096
comptime DEFAULT_MAX_IDNA_LABELS: Int = 128
comptime DEFAULT_MAX_PUNYCODE_LABEL_CODEPOINTS: Int = 256
comptime DNS_MAX_LABEL_OCTETS: Int = 63
