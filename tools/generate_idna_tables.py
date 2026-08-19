#!/usr/bin/env python3
"""Generate src/heat_url/idna_data.mojo from Unicode 17.0.0 UCD / IDNA files.

Runtime stays Mojo. Re-run after bumping UNICODE_VERSION:

    python3 tools/generate_idna_tables.py
"""

from __future__ import annotations

import pathlib
import re
import sys
import urllib.request

UNICODE_VERSION = "17.0.0"
PUBLIC = f"https://www.unicode.org/Public/{UNICODE_VERSION}"
FILES = [
    "idna/IdnaMappingTable.txt",
    "ucd/UnicodeData.txt",
    "ucd/DerivedNormalizationProps.txt",
    "ucd/extracted/DerivedGeneralCategory.txt",
    "ucd/extracted/DerivedBidiClass.txt",
    "ucd/extracted/DerivedJoiningType.txt",
]

STATUS = {"valid": 0, "ignored": 1, "mapped": 2, "deviation": 3, "disallowed": 4}

BIDI = {
    "L": 0,
    "Left_To_Right": 0,
    "R": 1,
    "Right_To_Left": 1,
    "AL": 2,
    "Arabic_Letter": 2,
    "AN": 3,
    "Arabic_Number": 3,
    "EN": 4,
    "European_Number": 4,
    "ES": 5,
    "European_Separator": 5,
    "CS": 6,
    "Common_Separator": 6,
    "ET": 7,
    "European_Terminator": 7,
    "ON": 8,
    "Other_Neutral": 8,
    "BN": 9,
    "Boundary_Neutral": 9,
    "NSM": 10,
    "Nonspacing_Mark": 10,
}
# Remaining classes share one "other" bucket (B, S, WS, embeddings, ...).
BIDI_OTHER = 11

# C (Join_Causing) is stored as D for RFC 5892 CONTEXTJ.
JOIN = {"U": 0, "Non_Joining": 0, "L": 1, "Left_Joining": 1, "D": 2, "Dual_Joining": 2,
        "R": 3, "Right_Joining": 3, "T": 4, "Transparent": 4, "C": 2, "Join_Causing": 2}

SBASE, LBASE, VBASE, TBASE = 0xAC00, 0x1100, 0x1161, 0x11A7
LCOUNT, VCOUNT, TCOUNT = 19, 21, 28
NCOUNT = VCOUNT * TCOUNT
SCOUNT = LCOUNT * NCOUNT
MAX_CP = 0x10FFFF


def repo_root() -> pathlib.Path:
    return pathlib.Path(__file__).resolve().parents[1]


def cache_dir() -> pathlib.Path:
    env = pathlib.Path("/tmp") / f"unicode-{UNICODE_VERSION}"
    if env.exists():
        return env
    d = repo_root() / "tools" / ".unicode-cache" / UNICODE_VERSION
    d.mkdir(parents=True, exist_ok=True)
    return d


def fetch(rel: str) -> pathlib.Path:
    dest = cache_dir() / rel
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 0:
        return dest
    url = f"{PUBLIC}/{rel}"
    print(f"downloading {url}", file=sys.stderr)
    urllib.request.urlretrieve(url, dest)
    return dest


def parse_cp_range(field: str) -> tuple[int, int]:
    field = field.strip()
    if ".." in field:
        a, b = field.split("..")
        return int(a, 16), int(b, 16)
    v = int(field, 16)
    return v, v


def iter_ucd_rows(path: pathlib.Path, *, include_missing: bool = False):
    missing_re = re.compile(r"^#\s*@missing:\s*([0-9A-Fa-f.]+)\s*;\s*(\S+)")
    with path.open(encoding="utf-8") as fh:
        for raw in fh:
            m = missing_re.match(raw) if include_missing else None
            if m:
                yield (*parse_cp_range(m.group(1)), m.group(2))
                continue
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            start, end = parse_cp_range(parts[0])
            yield start, end, parts[1] if len(parts) > 1 else ""


def apply_ranges(table: list[int], rows, mapping, default=None):
    if default is not None:
        for i in range(len(table)):
            table[i] = default
    for start, end, name in rows:
        val = mapping(name)
        for cp in range(start, end + 1):
            table[cp] = val


def coalesce(values: list[int]) -> list[tuple[int, int, int]]:
    out: list[tuple[int, int, int]] = []
    start = 0
    cur = values[0]
    for cp in range(1, len(values)):
        if values[cp] != cur:
            out.append((start, cp - 1, cur))
            start = cp
            cur = values[cp]
    out.append((start, len(values) - 1, cur))
    return out


def hangul_decompose(cp: int) -> list[int] | None:
    sindex = cp - SBASE
    if sindex < 0 or sindex >= SCOUNT:
        return None
    l = LBASE + sindex // NCOUNT
    v = VBASE + (sindex % NCOUNT) // TCOUNT
    t = TBASE + sindex % TCOUNT
    if t == TBASE:
        return [l, v]
    return [l, v, t]


def full_nfd(cp: int, canon: dict[int, list[int]]) -> list[int]:
    hangul = hangul_decompose(cp)
    if hangul is not None:
        return hangul
    parts = canon.get(cp)
    if not parts:
        return [cp]
    out: list[int] = []
    for p in parts:
        out.extend(full_nfd(p, canon))
    return out


def load_mapping(path: pathlib.Path):
    repl_pool: list[int] = []
    rows = []
    with path.open(encoding="utf-8") as fh:
        for raw in fh:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            start, end = parse_cp_range(parts[0])
            status = parts[1]
            mapping = parts[2] if len(parts) > 2 else ""
            repl = [int(x, 16) for x in mapping.split()] if mapping else []
            if status not in STATUS:
                raise SystemExit(f"unknown IDNA status {status!r}")
            rows.append((start, end, STATUS[status], repl))
    packed_ranges: list[int] = []
    for start, end, status, repl in rows:
        off = 0
        ln = len(repl)
        if ln:
            off = len(repl_pool)
            repl_pool.extend(repl)
        packed = status | (ln << 8) | (off << 16)
        packed_ranges.extend((start, end, packed))
    return packed_ranges, repl_pool


def load_unicode_data(path: pathlib.Path):
    ccc = [0] * (MAX_CP + 1)
    canon: dict[int, list[int]] = {}
    with path.open(encoding="utf-8") as fh:
        for raw in fh:
            fields = raw.rstrip("\n").split(";")
            cp = int(fields[0], 16)
            ccc[cp] = int(fields[3] or "0")
            decomp = fields[5]
            if decomp and not decomp.startswith("<"):
                canon[cp] = [int(x, 16) for x in decomp.split()]
    return ccc, canon


def load_full_exclusions(path: pathlib.Path) -> set[int]:
    out: set[int] = set()
    in_section = False
    with path.open(encoding="utf-8") as fh:
        for raw in fh:
            if raw.startswith("# Property:") and "Full_Composition_Exclusion" in raw:
                in_section = True
                continue
            if in_section and raw.startswith("# Property:"):
                break
            if not in_section:
                continue
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            start, end = parse_cp_range(line.split(";")[0])
            out.update(range(start, end + 1))
    return out


def load_gc_mark(path: pathlib.Path) -> list[int]:
    mark = [0] * (MAX_CP + 1)
    with path.open(encoding="utf-8") as fh:
        for raw in fh:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if parts[1] not in ("Mn", "Mc", "Me"):
                continue
            start, end = parse_cp_range(parts[0])
            for cp in range(start, end + 1):
                mark[cp] = 1
    return mark


def load_bidi(path: pathlib.Path) -> list[int]:
    table = [BIDI["L"]] * (MAX_CP + 1)

    def map_name(name: str) -> int:
        name = name.strip()
        if name in BIDI:
            return BIDI[name]
        return BIDI_OTHER

    apply_ranges(table, iter_ucd_rows(path, include_missing=True), map_name)
    return table


def load_join(path: pathlib.Path) -> list[int]:
    table = [JOIN["U"]] * (MAX_CP + 1)

    def map_name(name: str) -> int:
        name = name.strip()
        if name not in JOIN:
            raise SystemExit(f"unknown joining type {name!r}")
        return JOIN[name]

    apply_ranges(table, iter_ucd_rows(path, include_missing=True), map_name)
    return table


def emit_hex(values: list[int]) -> str:
    return "".join(f"{v & 0xFFFFFFFF:08x}" for v in values)


def emit_string_const(name: str, hexdata: str) -> str:
    if not hexdata:
        return f'comptime {name}: String = ""\n'
    return f'comptime {name}: String = "{hexdata}"\n'


def pack_ranges(triples: list[tuple[int, int, int]]) -> list[int]:
    out: list[int] = []
    for start, end, val in triples:
        out.extend((start, end, val))
    return out


def pack_pairs(pairs: list[tuple[int, int]]) -> list[int]:
    out: list[int] = []
    for a, b in pairs:
        out.extend((a, b))
    return out


def build() -> str:
    mapping_path = fetch("idna/IdnaMappingTable.txt")
    unicode_data = fetch("ucd/UnicodeData.txt")
    norm_props = fetch("ucd/DerivedNormalizationProps.txt")
    gc_path = fetch("ucd/extracted/DerivedGeneralCategory.txt")
    bidi_path = fetch("ucd/extracted/DerivedBidiClass.txt")
    join_path = fetch("ucd/extracted/DerivedJoiningType.txt")

    map_ranges, map_repl = load_mapping(mapping_path)
    ccc, canon = load_unicode_data(unicode_data)
    exclusions = load_full_exclusions(norm_props)
    mark = load_gc_mark(gc_path)
    bidi = load_bidi(bidi_path)
    join = load_join(join_path)

    decomp_cps: list[int] = []
    decomp_seq: list[int] = []
    for cp in range(MAX_CP + 1):
        if hangul_decompose(cp) is not None:
            continue
        nfd = full_nfd(cp, canon)
        if nfd == [cp]:
            continue
        packed = (len(nfd) << 16) | len(decomp_seq)
        decomp_cps.extend((cp, packed))
        decomp_seq.extend(nfd)

    compose: list[int] = []
    for cp, parts in canon.items():
        if cp in exclusions:
            continue
        if hangul_decompose(cp) is not None:
            continue
        if len(parts) != 2:
            continue
        a, b = parts
        if ccc[a] != 0:
            continue
        compose.append((a, b, cp))
    compose.sort()
    compose_flat: list[int] = []
    for a, b, c in compose:
        compose_flat.extend((a, b, c))

    ccc_ranges = [(s, e, v) for s, e, v in coalesce(ccc) if v != 0]
    mark_pairs = [(s, e) for s, e, v in coalesce(mark) if v == 1]
    bidi_ranges = coalesce(bidi)
    join_ranges = coalesce(join)

    chunks = [
        "# Generated from Unicode 17.0.0. Do not edit by hand.",
        "# https://www.unicode.org/Public/17.0.0/",
        "# Regenerated by: python3 tools/generate_idna_tables.py",
        "",
        'comptime UNICODE_VERSION: StaticString = "17.0.0"',
        "",
        emit_string_const("MAP_RANGES_HEX", emit_hex(map_ranges)).rstrip(),
        emit_string_const("MAP_REPL_HEX", emit_hex(map_repl)).rstrip(),
        emit_string_const("DECOMP_HEX", emit_hex(decomp_cps)).rstrip(),
        emit_string_const("DECOMP_SEQ_HEX", emit_hex(decomp_seq)).rstrip(),
        emit_string_const("COMPOSE_HEX", emit_hex(compose_flat)).rstrip(),
        emit_string_const("CCC_RANGES_HEX", emit_hex(pack_ranges(ccc_ranges))).rstrip(),
        emit_string_const("MARK_RANGES_HEX", emit_hex(pack_pairs(mark_pairs))).rstrip(),
        emit_string_const("BIDI_RANGES_HEX", emit_hex(pack_ranges(bidi_ranges))).rstrip(),
        emit_string_const("JOIN_RANGES_HEX", emit_hex(pack_ranges(join_ranges))).rstrip(),
        "",
    ]
    print(
        f"map_ranges={len(map_ranges)//3} repl={len(map_repl)} "
        f"decomp={len(decomp_cps)//2} compose={len(compose)} "
        f"ccc={len(ccc_ranges)} mark={len(mark_pairs)} "
        f"bidi={len(bidi_ranges)} join={len(join_ranges)}",
        file=sys.stderr,
    )
    return "\n".join(chunks) + "\n"


def main() -> None:
    text = build()
    dest = repo_root() / "src" / "heat_url" / "idna_data.mojo"
    dest.write_text(text, encoding="utf-8")
    print(f"wrote {dest} ({dest.stat().st_size} bytes)", file=sys.stderr)


if __name__ == "__main__":
    main()
