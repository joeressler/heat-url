# WPT `urltestdata.json` skips

Unexplained failures are bugs: fix `src/heat_url`, do not delete assertions.

Each skip is one JSON object on its own line (`input` and `base` must match the fixture; `base` is `null` or a string). `test/test_wpt_url.mojo` loads lines that start with `{`.

Currently **no cases are skipped**. `blob:` / `data:` / `javascript:` run as generic parse/serialize (no blob store). `origin` is not compared. WPT `relativeTo` extra bases are not synthesized.

Empty query/fragment: `href` may still end in `?` or `#`, but the URL Standard **search**/**hash** getters return `""` when the component is null or empty.

```skips
```
