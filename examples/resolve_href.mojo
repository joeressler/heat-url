from heat_url import parse_url


def main() raises:
    # Resolve HTML-style href values against a document URL (WHATWG basic URL parser).
    var base = "https://docs.example.org/guide/start.html"
    var hrefs = [
        "/api",
        "../img/logo.png",
        "?tab=ref",
        "#install",
        "https:cdn.example.org",
    ]
    var i = 0
    while i < len(hrefs):
        var href = hrefs[i]
        var resolved = parse_url(href, base)
        print(href + " -> " + resolved.serialize())
        i += 1

    # Without a base, https:cdn.example.org becomes an https origin.
    print(
        "https:cdn.example.org (no base) -> "
        + parse_url("https:cdn.example.org").serialize()
    )
