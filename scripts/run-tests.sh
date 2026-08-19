#!/usr/bin/env bash
# Run every TestSuite file under test/. Invoked via `pixi run test`.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

shopt -s nullglob
files=(test/test_*.mojo)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "no test/test_*.mojo files found" >&2
  exit 1
fi

failed=0
for f in "${files[@]}"; do
  echo "==> ${f}"
  if ! mojo run -I src "${f}"; then
    failed=1
  fi
done

if [[ "${failed}" -ne 0 ]]; then
  echo "test suite failed" >&2
  exit 1
fi
echo "all tests passed"
