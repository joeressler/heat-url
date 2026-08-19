# Test fixtures

Phase 00 does not vendor external suites. Starting in **phase 09**, put golden files here and record:

- Source URL
- Revision / date
- License

Until then this directory may stay empty aside from this README.

Expected later:

| File | Source |
| --- | --- |
| `urltestdata.json` | web-platform-tests `url/resources/urltestdata.json` |
| `percent-encoding.json` | WPT `url/resources/percent-encoding.json` |
| `IDNATestV2.txt` | Unicode IDNA test data |
| `WHATWG_SKIP.md` | Skip list with reasons |

Do not treat Python `urllib.parse` as an oracle.
