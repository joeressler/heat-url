# ehsanmok/json (vendored)

Pinned **v0.3.0** (`9b53936`) from [github.com/ehsanmok/json](https://github.com/ehsanmok/json).

Tests import the **CPU** parser only:

```mojo
from json.cpu import parse_cpu_native_tape
```

That is `loads[target="cpu"]` (pure Mojo two-pass tape parser). The published pixi git package also pulls MAX, simdjson FFI, and GPU backends; `from json import load` does not compile in this Mojo-only environment (`json.gpu` needs `max.gpu.host`). GPU sources are omitted from this tree for that reason.

License: MIT (see `LICENSE`).
