# 09 — Public API

This is the **required** v1 surface. Names use Mojo style. Until implementation exists, this document is the contract.

## Package

```text
import heat_url
from heat_url import parse_url, parse_uri, percent, query, host, idna
```

`src/heat_url/__init__.mojo` re-exports the functions below. Submodules may be imported directly.

## Profiles

```text
enum ParseProfile:
    Rfc3986
    Whatwg
```

## Parse and serialize

```text
struct ParseOptions:
    var profile: ParseProfile
    var base: Optional[String]          # or Optional[Url]/Uri matching profile
    var iri: Bool                       # rfc3986; default True
    var allow_ipv6_zone_id: Bool        # rfc3986; default True
    var normalize_syntax: Bool          # rfc3986; default False
    var idna_host: Bool                 # rfc3986; default False
    var strict_whatwg: Bool             # whatwg; default False
    var max_input_length: Int           # default 2^20

def parse_url(input: String, base: Optional[String] = None) raises -> Url
def try_parse_url(input: String, base: Optional[String] = None) -> Optional[Url]
def parse_url_detailed(input: String, base: Optional[String] = None) raises -> UrlParseResult

def parse_uri(input: String, base: Optional[String] = None) raises -> Uri
def try_parse_uri(input: String, base: Optional[String] = None) -> Optional[Uri]

def parse(input: String, options: ParseOptions) raises -> Parsed
```

`parse_url` / `parse_uri` raise `ParseError` on failure. `try_parse_url` / `try_parse_uri` return an empty `Optional` and **MUST NOT** raise on parse failure.

`parse_url` returns the WHATWG `Url` record only. Validation errors are **not** stored on `Url`. Callers that need the list use `parse_url_detailed`, which returns:

```text
struct UrlParseResult:
    var url: Url
    var validation_errors: List[ValidationError]
```

`try_parse_url` is success/failure only (no validation-error channel).

`Parsed` is a variant of `Url` | `Uri` matching `options.profile` (no profile guessing):

```text
struct Parsed:
    def is_url(self) -> Bool
    def is_uri(self) -> Bool
    def url(self) -> Optional[Url]
    def uri(self) -> Optional[Uri]
    def serialize(exclude_fragment: Bool = False) -> String
```

`Url` / `Uri` **MUST** provide:

- Component getters (and setters that re-validate for WHATWG, matching URL standard setter algorithms where implemented).
- `serialize(exclude_fragment: Bool = False) -> String`
- `query_list() -> QueryList` (parses form-urlencoded from the opaque query; empty list if query absent)
- `origin()` optional helper (WHATWG)

WHATWG setters (`protocol`, `username`, `password`, `host`, `hostname`, `port`, `pathname`, `search`, `hash`) and `Url.origin()` are **deferred to v1.1**. Parse/serialize/query/IDNA remain mandatory for v1. If setters are added later, they **MUST** follow URL Standard setter algorithms.

## Percent module (`heat_url.percent`)

```text
enum EncodeSet:
    C0Control, Fragment, Query, SpecialQuery, Path, Userinfo, Component
    FormUrlencoded
    RfcUnreserved, RfcUserinfo, RfcRegName, RfcPath, RfcQuery, RfcFragment

def encode(input: String, set: EncodeSet, space_as_plus: Bool = False) -> String
def decode_lenient(input: String) -> List[UInt8]
def decode_strict(input: String) raises -> List[UInt8]
def decode_utf8_lenient(input: String) raises -> String
def decode_utf8_strict(input: String) raises -> String
```

## Query module (`heat_url.query`)

```text
struct QueryList:
    def parse(
        input: String,
        *,
        form: Bool = True,
        max_tuples: Int = DEFAULT_MAX_QUERY_TUPLES,
    ) raises -> Self
    def serialize(self) -> String
    def get(self, name: String) -> Optional[String]
    def get_all(self, name: String) -> List[String]
    def has(self, name: String, value: Optional[String] = None) -> Bool
    def append(mut self, name: String, value: String)
    def set(mut self, name: String, value: String)
    def delete(mut self, name: String, value: Optional[String] = None)
    def sort(mut self)
    def __len__(self) -> Int
```

`form=True` means WHATWG form-urlencoded (`+` as space, split on `&`). `form=False` means split on `&` / first `=` without plus-decoding. `has` / `delete` take an optional `value` matching WHATWG `URLSearchParams` (specs/05). `max_tuples` defaults to 4096; exceeding it fails with `too_many_query_tuples`.

## Host and IDNA (`heat_url.host`, `heat_url.idna`)

```text
def parse_host_whatwg(input: String, *, is_opaque: Bool) raises -> WhatwgHost
def parse_host_rfc3986(input: String, *, allow_zone_id: Bool = True, iri: Bool = False) raises -> RfcHost
def serialize_host(host: WhatwgHost | RfcHost) -> String

def to_ascii(domain: String, *, be_strict: Bool = False) raises -> String
def to_unicode(domain: String) raises -> String
def punycode_encode(label: String) raises -> String
def punycode_decode(label: String) raises -> String
```

`iri=true` allows RFC 3987 `ireg-name` (Unicode `ucschar` in the host). Default `false` keeps RFC 3986 `reg-name` (ASCII / percent-encoded only).

`to_ascii` / `to_unicode` **MUST** implement UTS #46 as used by WHATWG, not a homemade “strip accents” mapping.

## Errors

```text
struct ParseError(Error):   # or a dedicated Error type if Mojo Error wrapping requires it
    var profile: ParseProfile
    var kind: String
    var index: Optional[Int]
    var whatwg_name: Optional[String]

struct IdnaError(Error):
    var code: String
```

User-facing `Error` messages **MUST NOT** contain passwords.

## What v1 must not expose

- Python interop helpers as the *only* IDNA path.
- A `parse_magic` / `guess_profile` function.
- Mutable global IDNA “transitional=true” switch (transitional processing is **always false**).
- Hidden network I/O.

## Documentation comments

Every public function **MUST** state its profile and the clause it implements (e.g. “WHATWG basic URL parser”, “RFC 3986 §5.2.2”).
