# neturl

`neturl.luau` is an unchanged copy of `lib/net/url.lua` from
[golgote/neturl](https://github.com/golgote/neturl), pinned to commit
[`fd0df85f44b545d91c2840dc4339abb3656d031d`](https://github.com/golgote/neturl/tree/fd0df85f44b545d91c2840dc4339abb3656d031d).
Only the filename extension differs. The upstream MIT license is included in
`neturl.LICENSE.txt`. No LuaRocks installation or external Lua modules are needed.

The wrapper in `../url.luau` uses neturl to parse components and applies launcher
matching rules. IP literals require an explicit scheme. Host parsing is left to
neturl without extra hostname/IP validation or trailing-dot exceptions. The wrapper
does not restrict schemes, port ranges, or percent escapes. It never rebuilds the
URL from neturl's parsed query table, preserving the entered scheme casing, path,
query, fragment, and port spelling.
