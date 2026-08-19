# Parse-profile discriminator. Callers pick one; parsers must not mix rules.
@fieldwise_init
struct ParseProfile(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    var _variant: Int

    comptime rfc3986 = Self(_variant=0)
    comptime whatwg = Self(_variant=1)

    def __eq__(self, other: Self) -> Bool:
        return self._variant == other._variant

    def name(self) -> StaticString:
        if self._variant == 0:
            return "rfc3986"
        return "whatwg"

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.name())
