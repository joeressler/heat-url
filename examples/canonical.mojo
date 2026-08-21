from heat_url import parse_url, to_ascii


def main() raises:
    # Compare parsed URLs for cache keys; fragments excluded by default.
    var a = parse_url("HTTPS://Example.COM:443/a/../b?x=1#section")
    var b = parse_url("https://example.com/b?x=1#other")
    print("equals (no fragment):", a.equals(b))
    print("equals (with fragment):", a.equals(b, include_fragment=True))
    print("cache key:", a.serialize(exclude_fragment=True))

    # Classify host kinds after WHATWG parse.
    var domain = parse_url("https://example.com/")
    var host = domain.host()
    if host is not None:
        print("example.com is domain:", host.value().is_domain())

    var ipv4 = parse_url("https://127.0.0.1/")
    var v4_host = ipv4.host()
    if v4_host is not None:
        print("127.0.0.1 is ipv4:", v4_host.value().is_ipv4())

    var ipv6 = parse_url("https://[::1]/")
    var v6_host = ipv6.host()
    if v6_host is not None:
        print("[::1] is ipv6:", v6_host.value().is_ipv6())

    # DNS-ready host label (UTS #46 ToASCII).
    print("to_ascii(faß.example):", to_ascii("faß.example"))
