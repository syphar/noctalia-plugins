# URL Opener

Type a web address directly in the launcher and activate **Open in browser**
with Enter. No slash prefix is needed. The result opens in your default browser
through `xdg-open`; typing alone never opens a browser.

The last 100 successfully opened URLs are remembered, with exact duplicates moved
to the front. An empty query shows recent URLs; typing filters history with fuzzy
matching. A directly entered address appears above history matches. This also works
behind `/url`. Failed opens and text you only type are not saved.

For example, after opening `https://github.com/noctalia-dev`, type `github` to find
it again, or enter `/url` with no query to browse recent URLs. Select a history
result and press Enter to reopen it. A successful open means `xdg-open` reported
success; the plugin does not check whether the page loaded.

History is stored as plain JSON in `history.json` under Noctalia's persistent data
directory for `syphar/url-opener`, surviving restarts and plugin updates. It contains
the full URLs, including query strings and fragments, opened through this provider.
Browser history is not imported. If saving fails, the plugin reports the failure
and keeps recent URLs in memory for the current session.

| Plugin | Value |
| --- | --- |
| ID | `syphar/url-opener` |
| Launcher entry | `url` |
| Optional prefix | `/url` |
| Plugin API | 24 |
| Dependency | `xdg-open` |

Examples: `example.com`, `example.com/docs?q=noctalia#install`,
`https://example.com`, `http://localhost:3000`, `http://192.168.1.1`, and `http://[::1]:8080`.
Addresses without a scheme get `https://`; specify `http://` for HTTP-only servers.
Explicit URLs are preserved, including scheme casing, paths, queries, fragments,
and ports. Other `scheme://host` URLs are also accepted and opened through their
default `xdg-open` handler.

The provider accepts addresses with hosts recognized by neturl, including DNS
hostnames, IPv4 addresses, and bracketed IPv6 addresses. IP addresses require an explicit
scheme; bare IP addresses are ignored. Bare hostnames need a dotted domain or `localhost`;
single-label intranet names need an explicit scheme. Use Punycode for international
domain names and percent-encode spaces. Credentials in URLs, local paths, and slash
commands are not offered as new URLs. Ordinary search text can match saved history.
URLs must have a host; schemes without a host, such as `mailto:`, are not supported.
Host parsing is left to neturl, without additional hostname/IP validation,
port-range checks, or percent-escape validation. Trailing-dot hosts are not
recognized by neturl. The plugin does not check whether a host exists or is reachable.
Parsing uses a [vendored copy of neturl](vendor/README.md), with no LuaRocks or
additional runtime dependencies.

Install this directory following the [repository instructions](../README.md),
then enable **URL Opener** in Noctalia's plugin settings. It participates in global
search automatically; `/url example.com` also works. There are no plugin settings.
