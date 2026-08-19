from heat_url.error import ParseError
from heat_url.limits import (
    DEFAULT_MAX_INPUT_CODEPOINTS,
    DEFAULT_MAX_QUERY_TUPLES,
)
from heat_url.percent import EncodeSet, decode_utf8_lenient, encode
from heat_url.profile import ParseProfile


@fieldwise_init
struct QueryTuple(Copyable, Movable):
    var name: String
    var value: String


# Ordered name/value tuples (WHATWG URLSearchParams list; specs/05, §6.2).
@fieldwise_init
struct QueryList(Copyable, Movable, Sized):
    var _tuples: List[QueryTuple]

    # WHATWG §5.1 string parser, or RFC-style split when form=False (no plus-decoding).
    @staticmethod
    def parse(
        input: String,
        form: Bool = True,
        max_tuples: Int = DEFAULT_MAX_QUERY_TUPLES,
    ) raises ParseError -> Self:
        var profile: ParseProfile
        if form:
            profile = ParseProfile.whatwg
        else:
            profile = ParseProfile.rfc3986
        var n_cp = input.count_codepoints()
        if n_cp > DEFAULT_MAX_INPUT_CODEPOINTS:
            raise ParseError.input_too_long(
                profile, n_cp, DEFAULT_MAX_INPUT_CODEPOINTS
            )

        var src = input.as_bytes()
        var n = len(src)
        var tuples = List[QueryTuple]()
        var start = 0
        var i = 0
        while i <= n:
            if i == n or src[i] == 0x26:
                if i > start:
                    if len(tuples) >= max_tuples:
                        raise ParseError.too_many_query_tuples(
                            profile, len(tuples) + 1, max_tuples
                        )
                    var segment = String(input[byte=start:i])
                    tuples.append(_parse_segment(segment^, form))
                start = i + 1
            i += 1
        return QueryList(tuples^)

    # WHATWG §5.2 form-urlencoded serializer (spaces as `+`).
    def serialize(self) -> String:
        var out = String()
        var i = 0
        while i < len(self._tuples):
            if i > 0:
                out += "&"
            out += encode(
                self._tuples[i].name,
                EncodeSet.FormUrlencoded,
                space_as_plus=True,
            )
            out += "="
            out += encode(
                self._tuples[i].value,
                EncodeSet.FormUrlencoded,
                space_as_plus=True,
            )
            i += 1
        return out^

    # WHATWG §6.2 get: first matching name, exact scalar equality.
    def get(self, name: String) -> Optional[String]:
        var i = 0
        while i < len(self._tuples):
            if self._tuples[i].name == name:
                return Optional(self._tuples[i].value.copy())
            i += 1
        return Optional[String](None)

    # WHATWG §6.2 getAll: matching values in list order.
    def get_all(self, name: String) -> List[String]:
        var out = List[String]()
        var i = 0
        while i < len(self._tuples):
            if self._tuples[i].name == name:
                out.append(self._tuples[i].value.copy())
            i += 1
        return out^

    # WHATWG §6.2 has; value filters name+value when present (specs/05).
    def has(self, name: String, value: Optional[String] = None) -> Bool:
        var i = 0
        while i < len(self._tuples):
            if self._tuples[i].name == name:
                if value is None:
                    return True
                if self._tuples[i].value == value.value():
                    return True
            i += 1
        return False

    # WHATWG §6.2 append.
    def append(mut self, name: String, value: String):
        self._tuples.append(QueryTuple(name.copy(), value.copy()))

    # WHATWG §6.2 set: replace first match, drop later matches, else append.
    def set(mut self, name: String, value: String):
        var out = List[QueryTuple]()
        var found = False
        var i = 0
        while i < len(self._tuples):
            if self._tuples[i].name == name:
                if not found:
                    out.append(QueryTuple(name.copy(), value.copy()))
                    found = True
            else:
                out.append(self._tuples[i].copy())
            i += 1
        if not found:
            out.append(QueryTuple(name.copy(), value.copy()))
        self._tuples = out^

    # WHATWG §6.2 delete; value filters name+value when present (specs/05).
    def delete(mut self, name: String, value: Optional[String] = None):
        var out = List[QueryTuple]()
        var i = 0
        while i < len(self._tuples):
            var drop = False
            if self._tuples[i].name == name:
                if value is None:
                    drop = True
                elif self._tuples[i].value == value.value():
                    drop = True
            if not drop:
                out.append(self._tuples[i].copy())
            i += 1
        self._tuples = out^

    # WHATWG §6.2 sort: stable, UTF-16 code unit order of names.
    def sort(mut self):
        var n = len(self._tuples)
        var i = 1
        while i < n:
            var key = self._tuples[i].copy()
            var j = i
            while j > 0 and _utf16_name_less(
                key.name, self._tuples[j - 1].name
            ):
                self._tuples[j] = self._tuples[j - 1].copy()
                j -= 1
            self._tuples[j] = key^
            i += 1

    def __len__(self) -> Int:
        return len(self._tuples)


def _parse_segment(segment: String, form: Bool) raises ParseError -> QueryTuple:
    var eq = segment.find("=")
    var name_raw: String
    var value_raw: String
    if eq < 0:
        name_raw = segment.copy()
        value_raw = String("")
    else:
        name_raw = String(segment[byte=0:eq])
        value_raw = String(segment[byte = eq + 1 : segment.byte_length()])
    return QueryTuple(
        _decode_field(name_raw^, form), _decode_field(value_raw^, form)
    )


def _decode_field(raw: String, form: Bool) raises ParseError -> String:
    if form:
        return decode_utf8_lenient(raw.replace("+", " "))
    return decode_utf8_lenient(raw)


def _utf16_name_less(a: String, b: String) -> Bool:
    var ua = _utf16_units(a)
    var ub = _utf16_units(b)
    var n = len(ua)
    if len(ub) < n:
        n = len(ub)
    var i = 0
    while i < n:
        if ua[i] < ub[i]:
            return True
        if ua[i] > ub[i]:
            return False
        i += 1
    return len(ua) < len(ub)


def _utf16_units(s: String) -> List[Int]:
    var units = List[Int]()
    for cp in s.codepoints():
        var c = Int(cp)
        if c < 0x10000:
            units.append(c)
        else:
            var u = c - 0x10000
            units.append(0xD800 + (u >> 10))
            units.append(0xDC00 + (u & 0x3FF))
    return units^
