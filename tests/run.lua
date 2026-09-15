-- Host-contract tests; intentionally compatible with stock Lua 5.4 and Luau.
local testDir = arg[0]:match("^(.*[/\\])") or "./"
local root = testDir .. "../github-repos/"
local count = 0
local function check(value, message)
	assert(value, message)
	count = count + 1
end

local function host(entry)
	local h = { requests = {}, now = 1000, exists = true, accepted = true }
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

print(string.format("Passed %d checks", count))
