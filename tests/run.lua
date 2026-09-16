-- Host-contract tests; intentionally compatible with stock Lua 5.4 and Luau.
local testDir = arg[0]:match("^(.*[/\\])") or "./"
local root = testDir .. "../github-repos/"
local count = 0
local function check(value, message)
	assert(value, message)
	count = count + 1
end

local function host(entry, pluginRoot, files)
	local root = pluginRoot or root
	local h = { requests = {}, now = 1000, exists = true, accepted = true, files = files or {}, writes = 0 }
	local env = setmetatable({}, { __index = _G })
	env.os = {
		time = function()
			return h.now
		end,
	}
	env.launcher = {
		setResults = function(query, results)
			h.query, h.results = query, results
		end,
	}
	env.noctalia = {
		pluginDataDir = function() return "/plugin-data" end,
		readFile = function(path) return h.files[path] end,
		writeFile = function(path, value)
			if h.writeFailure then return false end
			h.files[path] = value
			h.writes = h.writes + 1
			return true
		end,
		renameFile = function(from, to)
			if h.renameFailure then return false end
			h.files[to], h.files[from] = h.files[from], nil
			return true
		end,
		commandExists = function()
			return h.exists
		end,
		runAsync = function(argv, callback)
			if not h.accepted then
				return false
			end
			table.insert(h.requests, { argv = argv, callback = callback })
			return true
		end,
		json = {
			-- Snapshot the history array so later mutations cannot change a saved file.
			encode = function(value)
				local copy = {}
				for i, item in ipairs(value) do copy[i] = item end
				return copy
			end,
			decode = function(value)
				return value
			end,
		},
		string = {
			trim = function(value)
				return value:match("^%s*(.-)%s*$")
			end,
		},
		-- Deterministic fake matcher: verify integration, not Noctalia's algorithm.
		fuzzyScore = function(query, name)
			if name:lower():find(query:lower(), 1, true) then
				return 100 - #name
			end
			return nil
		end,
		notifyError = function(title, body)
			h.error = { title, body }
		end,
	}
	local modules = {}
	env.require = function(path)
		if not modules[path] then
			modules[path] = assert(loadfile(root .. path:gsub("^%./", ""), "t", env))()
		end
		return modules[path]
	end
	assert(loadfile(root .. entry, "t", env))()
	h.env = env
	function h:queryText(text)
		env.onQuery(text)
	end

	function h:reply(data, options)
		local request = table.remove(self.requests, 1)
		assert(request, "Expected an outstanding request")
		options = options or {}
		options.stdout = data
		options.exitCode = options.exitCode or 0
		request.callback(options)
	end

	return h
end

local function repo(name, private)
	return { id = name, full_name = name, description = "Description", private = private or false }
end

local h = host("repo.luau")
h:queryText("")
check(#h.requests == 1, "initial query fetches repositories")
local args = table.concat(h.requests[1].argv, " ")
check(not args:find("affiliation=", 1, true) and not args:find("sort=", 1, true)
    and not args:find("direction=", 1, true), "use Alfred's default repository parameters")
check(args:find("--hostname github.com", 1, true), "force github.com")
h:queryText("special")
check(#h.requests == 1, "typing must not duplicate the listing request")
local page = {}
for i = 1, 100 do
	page[i] = repo("me/project" .. i)
end
h:reply(page)
check(#h.requests == 1, "fetch the next full page")
check(table.concat(h.requests[1].argv, " "):find("page=2", 1, true), "advance pagination")
h:reply({ repo("me/special", true) })
check(h.requests[1].argv[7] == "user/subscriptions", "include watched repositories")
local duplicate = repo("renamed/special")
duplicate.id = "me/special"
h:reply({ duplicate, repo("watched/special") })
check(h.requests[1].argv[7] == "user/orgs", "discover organizations")
local organizations = {}
for i = 1, 100 do organizations[i] = { login = "org" .. i } end
h:reply(organizations)
check(table.concat(h.requests[1].argv, " "):find("page=2", 1, true), "paginate organization discovery")
h:reply({ { login = "last-org" } })
check(h.requests[1].argv[7] == "orgs/org1/repos", "fetch discovered organization's repositories")
h:reply(page)
check(table.concat(h.requests[1].argv, " "):find("page=2", 1, true), "paginate organization repositories")
h:reply({ repo("org1/special") })
for i = 2, 100 do h:reply({}) end
check(h.requests[1].argv[7] == "orgs/last-org/repos", "include organizations from later pages")
h:reply({ repo("last-org/special") })
check(h.query == "special" and #h.results == 4, "merge all sources and deduplicate by repository ID")
h:queryText("me/special")
check(h.query == "me/special" and #h.results == 1, "filter all pages with latest query")
check(h.results[1].title == "me/special" and h.results[1].glyph == "lock", "private repository result")
h:queryText("")
check(#h.requests == 0 and #h.results == 50, "cached list and result limit")
h.now = 1000 + 24 * 60 * 60 - 1
h:queryText("me/special")
check(#h.requests == 0, "repository cache stays fresh for 24 hours")
h.now = 1000 + 24 * 60 * 60
h:queryText("me/special")
check(#h.requests == 1 and h.results[1].title == "me/special", "serve stale list during refresh")
h:reply({ repo("new/partial") })
h:reply(nil, { exitCode = 1, stderr = "offline" })
check(h.results[1].title == "me/special" and #h.results == 2, "retain complete cache when a later source fails")
h:queryText("me/special")
check(#h.requests == 0, "refresh failure has retry cooldown")
h.now = h.now + 16
h:queryText("me/special")
check(#h.requests == 1, "retry after cooldown")
h:reply({})
h:reply({})
h:reply({})
check(h.results[1].title == "No matching repositories", "successful empty refresh replaces old cache")

-- Equal-length names receive equal mocked fuzzy scores, making source ties observable.
h = host("repo.luau")
h:queryText("match")
local fork = repo("a/match")
fork.fork = true
h:reply({ fork, repo("z/match") })
h:reply({ repo("b/match"), repo("d/match") })
h:reply({ { login = "org" } })
h:reply({ repo("e/match"), repo("z/match") })
local expected = { "z/match", "b/match", "d/match", "e/match", "a/match" }
for index, title in ipairs(expected) do
	check(h.results[index].title == title, "secondary ranking position " .. index)
	if index > 1 then
		check(h.results[index - 1].score > h.results[index].score, "launcher scores preserve secondary ordering")
	end
end
check(#h.results == 5, "overlapping sources do not duplicate repositories")
h:queryText("")
check(h.results[1].title == "z/match" and h.results[5].title == "a/match", "empty query uses secondary priorities")
h.env.noctalia.fuzzyScore = function(_, name)
	return name == "a/match" and 101 or 100
end
h:queryText("mat")
check(h.results[5].title == "a/match", "non-fork priority beats a better fuzzy score")
h.env.noctalia.fuzzyScore = function(_, name)
	return name == "d/match" and 101 or 100
end
h:queryText("mat")
check(h.results[1].title == "z/match", "source priority beats a better fuzzy score")
check(h.results[2].title == "d/match", "fuzzy score sorts within the same priority")

h = host("repo.luau")
h:queryText("docs.rs")
local docsFork = repo("syphar/docs.rs")
docsFork.fork = true
h:reply({ docsFork, repo("me/docs.rs-tools") })
h:reply({ repo("rust-lang/docs.rs") })
h:reply({})
check(h.results[1].title == "me/docs.rs-tools", "source priority takes precedence over exact name matches")
check(h.results[2].title == "rust-lang/docs.rs" and h.results[3].title == "syphar/docs.rs", "original precedes fork regardless of fuzzy score")
check(h.results[2].score > h.results[3].score, "launcher preserves original-before-fork ordering")
h:queryText("DOCS.RS")
check(h.results[2].title == "rust-lang/docs.rs", "priority ordering also applies to uppercase queries")
h:queryText("syphar/docs.rs")
check(#h.results == 1 and h.results[1].title == "syphar/docs.rs", "explicit owner query can still target a fork")

h = host("search.luau")
h:queryText("")
check(#h.requests == 0, "empty global search does not call GitHub")
local query = "foo $(touch /tmp/never) ' language:rust"
h:queryText(query)
local found = false
for _, arg in ipairs(h.requests[1].argv) do
	if arg == "q=" .. query then
		found = true
	end
end
check(found, "user query stays one literal argv field")
h:queryText("second")
h:queryText("third")
check(#h.requests == 1, "coalesce rapid queries")
h:reply({ items = { repo("old/result") } })
check(h.results[1].title == "Searching GitHub…", "stale result is not displayed")
check(table.concat(h.requests[1].argv, " "):find("q=third", 1, true), "fetch only latest query")
h:reply({ items = { repo("third/z"), repo("third/a") } })
check(h.query == "third" and h.results[1].title == "third/z", "preserve GitHub relevance order")
h:queryText(" third ")
check(#h.requests == 0 and h.query == " third ", "cached query echoes original text")
h.env.onActivate(h.results[1].id)
check(h.requests[1].argv[1] == "xdg-open", "open repository via argv")
h:reply("", { exitCode = 1 })
check(h.error ~= nil, "browser failure notification")
h.env.onActivate("status")
h.env.onActivate("https://evil.example/repo")
check(#h.requests == 0, "status and foreign URL cannot be activated")
h:queryText("fourth")
h:queryText("")
h:reply({ items = { repo("fourth/result") } })
check(#h.requests == 0 and h.query == "", "clearing search ignores pending results")
h:queryText("bad")
h:reply("invalid JSON")
check(h.results[1].title == "Could not search GitHub", "malformed response handled")
h:queryText("rate")
h:reply(nil, { exitCode = 1, stderr = "API rate limit exceeded" })
check(h.results[1].subtitle:find("rate limit", 1, true), "rate limit guidance")
h:queryText("timeout")
h:reply(nil, { timedOut = true })
check(h.results[1].subtitle:find("timed out", 1, true), "timeout handled")
h:queryText("truncated")
h:reply({}, { stdoutTruncated = true })
check(h.results[1].subtitle:find("too large", 1, true), "truncated output rejected")
h:queryText("partial")
h:reply({ incomplete_results = true, items = { repo("me/partial") } })
check(#h.results == 2, "partial search results labeled")
h.exists = false
h:queryText("missing")
check(#h.requests == 0 and h.results[1].subtitle:find("Install", 1, true), "missing gh guidance")
h.exists, h.accepted = true, false
h:queryText("rejected")
check(h.results[1].subtitle:find("Could not start", 1, true), "launch rejection handled")

local urlRoot = testDir .. "../url-opener/"
local url = host("provider.luau", urlRoot).env.require("./url.luau")
local validUrls = {
	{ string.rep("a", 64) .. ".com", "https://" .. string.rep("a", 64) .. ".com" },
	{ "https://example.com:99999", "https://example.com:99999" },
	{ "https://-example.com", "https://-example.com" },
	{ "example.com/%2", "https://example.com/%2" },
	{ "example.com/%zz", "https://example.com/%zz" },
	{ "example.com:65536", "https://example.com:65536" },
	{ "example.com:0", "https://example.com:0" },
	{ "example-.com", "https://example-.com" },
	{ "-example.com", "https://-example.com" },
	{ "ftp://example.com", "ftp://example.com" },
	{ "example.com", "https://example.com" },
	{ "  example.com/path?q=a&b=c#part  ", "https://example.com/path?q=a&b=c#part" },
	{ "HTTP://EXAMPLE.COM:8080/a%20b", "HTTP://EXAMPLE.COM:8080/a%20b" },
	{ "https://example.com", "https://example.com" },
	{ "localhost:3000", "https://localhost:3000" },
	{ "http://intranet/", "http://intranet/" },
	{ "http://192.168.1.1:80", "http://192.168.1.1:80" },
	{ "https://192.168.1.1", "https://192.168.1.1" },
	{ "https://[::1]:8080", "https://[::1]:8080" },
	{ "http://[2001:db8::1]/", "http://[2001:db8::1]/" },
	{ "https://[1:2:3:4:5:6:7:8]", "https://[1:2:3:4:5:6:7:8]" },
	{ "http://[::ffff:192.0.2.1]", "http://[::ffff:192.0.2.1]" },
	{ "xn--bcher-kva.de", "https://xn--bcher-kva.de" },
	{ "https://EXAMPLE.com:00443/a%2fb?z=1&a=2&a=3&x=hello+world#part", "https://EXAMPLE.com:00443/a%2fb?z=1&a=2&a=3&x=hello+world#part" },
}
for _, pair in ipairs(validUrls) do
	check(url.normalize(pair[1]) == pair[2], "normalize URL: " .. pair[1])
end
local invalidUrls = {
	"", "  ", "hello", "search for example.com", "/example.com", "//example.com",
	"/url example.com", "~/example.com", "https://", "https:///example.com",
	"javascript:alert(1)", "file:///tmp/example.com",
	"me@example.com", "https://user:pass@example.com", "example..com", ".example.com", "example.com..",
	"ex_ample.com", "example.123", "999.1.1.1",
	"1.2.3", "example.com:abc", "example.com:",
	"example.com:80:90", "example.com/a b",
	"example.com\\path", "example.com/\npath", "[:::1]", "[1:2:3]", "[::1::2]",
	"[1:2:3:4:5:6:7:8::]", "[12345::]", "[::ffff:999.0.0.1]", "::1", "[::1]junk",
	"192.168.1.1", "192.168.1.1:80", "127.0.0.1/path", "[::1]", "[::1]:8080", "[2001:db8::1]/path",
	"example.com.", "example.com.:8080",
}
for _, value in ipairs(invalidUrls) do
	check(url.normalize(value) == nil, "reject malformed/search input: " .. value)
end

h = host("provider.luau", urlRoot)
h:queryText(" example.com ")
check(h.query == " example.com " and #h.results == 1, "URL result echoes exact query")
check(h.results[1].id == "https://example.com" and h.results[1].score > 0, "normalized URL is prioritized")
check(#h.requests == 0, "typing does not open the browser")
h.env.onActivate(h.results[1].id)
check(h.requests[1].argv[1] == "xdg-open" and h.requests[1].argv[2] == "https://example.com", "activate URL with argv")
h:reply("")
check(h.error == nil, "successful browser opening has no error")
h:queryText("ordinary search")
check(#h.results == 0, "invalid input clears previous result")
h.env.onActivate("https://example.com")
check(#h.requests == 0, "stale URL cannot be activated")
local literalUrl = "https://example.com/?q=$(id)&name='quoted'"
h:queryText(literalUrl)
h.env.onActivate(h.results[1].id)
check(#h.requests[1].argv == 2 and h.requests[1].argv[2] == literalUrl, "shell metacharacters remain literal URL data")
h:reply("", { exitCode = 1 })
check(h.error ~= nil, "browser failure is reported")
h.error = nil
h.env.onActivate(h.results[1].id)
h:reply("", { timedOut = true })
check(h.error ~= nil, "browser timeout is reported")
h.error, h.accepted = nil, false
h.env.onActivate(h.results[1].id)
check(h.error ~= nil, "browser launch rejection is reported")
h:queryText("")
check(#h.results == 1 and h.results[1].id == "https://example.com", "empty query shows successful opens only")

local files = h.files
h = host("provider.luau", urlRoot, files)
h:queryText("EXAM")
check(#h.results == 1 and h.results[1].id == "https://example.com", "partial history search survives reload and ignores case")
check(h.writes == 0, "searching history does not write it")
h:queryText("example.com")
check(#h.results == 1 and h.results[1].title == "Open in browser", "direct URL deduplicates history")
h:queryText("example.com/docs")
local opened = h.results[1].id
h.env.onActivate(opened)
h:queryText("other search")
h:reply("")
h:queryText("")
check(h.results[1].id == opened and h.results[2].id == "https://example.com", "callback saves activated URL even after query changes")
h.env.onActivate(h.results[2].id)
check(h.requests[1].argv[2] == "https://example.com", "history result can be opened")
h:reply("")
h:queryText("")
check(#h.results == 2 and h.results[1].id == "https://example.com", "reopening moves exact duplicate to front")
h:queryText("example.com")
check(#h.results == 2 and h.results[1].score > h.results[2].score, "direct URL ranks above history")
h:queryText("/example")
check(#h.results == 0, "slash command does not match history")
h.env.onActivate(opened)
check(#h.requests == 0, "hidden history result cannot be activated")

for i = 1, 101 do
	h:queryText("https://example.com/" .. i)
	h.env.onActivate(h.results[1].id)
	h:reply("")
end
h = host("provider.luau", urlRoot, files)
h:queryText("")
check(#h.results == 100 and h.results[1].id == "https://example.com/101"
	and h.results[100].id == "https://example.com/2", "persist only 100 most recently opened distinct URLs")
h.writeFailure = true
h:queryText("https://example.com/write-failure")
h.env.onActivate(h.results[1].id)
h:reply("")
check(h.error ~= nil and files["/plugin-data/history.json"][1] == "https://example.com/101", "failed save reports error and preserves old file")
h:queryText("")
check(h.results[1].id == "https://example.com/write-failure", "history remains available in memory after save failure")
h.writeFailure, h.renameFailure, h.error = false, true, nil
h.env.onActivate(h.results[1].id)
h:reply("")
check(h.error ~= nil and files["/plugin-data/history.json"][1] == "https://example.com/101", "failed rename preserves previous history")

h = host("provider.luau", urlRoot, { ["/plugin-data/history.json"] = "malformed JSON" })
h:queryText("")
check(#h.results == 0, "corrupt history does not break queries")
h = host("provider.luau", urlRoot, { ["/plugin-data/history.json"] = {
	"https://example.com", "https://example.com", false, {}, "not a URL", "example.com", "https://other.example",
} })
h:queryText("")
check(#h.results == 2 and h.results[2].id == "https://other.example", "loaded history skips duplicates and invalid entries")

print(string.format("Passed %d checks", count))
