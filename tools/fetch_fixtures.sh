#!/usr/bin/env bash
# Re-download phase 09 golden files. Recorded URLs must stay in test/data/README.md.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

WPT_SHA="181476aa16e8b28a07698bef3a0275fa53dd22e5"
WPT="https://raw.githubusercontent.com/web-platform-tests/wpt/${WPT_SHA}/url/resources"
UNICODE_IDNA="https://www.unicode.org/Public/17.0.0/idna/IdnaTestV2.txt"

mkdir -p test/data
curl -fsSL "${WPT}/urltestdata.json" -o test/data/urltestdata.json
curl -fsSL "${WPT}/percent-encoding.json" -o test/data/percent-encoding.json
curl -fsSL "${UNICODE_IDNA}" -o test/data/IDNATestV2.txt

echo "updated test/data fixtures from WPT ${WPT_SHA} and Unicode 17.0.0"
