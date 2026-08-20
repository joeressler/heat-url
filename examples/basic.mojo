from heat_url import parse_uri, parse_url, to_ascii, try_parse_url


def main() raises:
    var url = parse_url("https:example.org")
    print(url.serialize())

    var resolved = parse_url("/search?q=mojo", "https://example.org/old")
    print(resolved.serialize())

    var uri = parse_uri("https:example.org")
    print(uri.serialize())

    if try_parse_url("https://ex ample.org/") is None:
        print("rejected")

    print(to_ascii("faß.example"))
