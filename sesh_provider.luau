local tinsert = table.insert
local tsort = table.sort

local pendingQuery: string? = nil

local function shellQuote(value: string): string
	return "'" .. value:gsub("'", "'\"'\"'") .. "'"
end

local function seshCommand(): string
	local configured = noctalia.getConfig("sesh_command")
	if type(configured) == "string" then
		configured = noctalia.string.trim(configured)
		if configured ~= "" then
			if configured:sub(1, 1) == "/" or configured:sub(1, 2) == "~/" then
				return noctalia.expandPath(configured)
			end
			return configured
		end
	end
	return "sesh"
end

local function sourceLabel(source: string): string
	local key = "source." .. source
	local translated = noctalia.tr(key)
	return translated ~= key and translated or source
end

local function parseSessions(output: string)
	local decoded, err = noctalia.json.decode(output)
	if type(decoded) ~= "table" then
		noctalia.log("noctalia-tmux-sesh: failed to parse sesh list --json: " .. tostring(err))
		return {}
	end

	local sessions = {}
	for _, session in ipairs(decoded) do
		if type(session) == "table" and type(session.Name) == "string" and session.Name ~= "" then
			tinsert(sessions, session)
		end
	end
	return sessions
end

local function makeResults(query: string, sessions)
	local results = {}
	local seenNames = {}
	for _, session in ipairs(sessions) do
		local name = session.Name
		if seenNames[name] then
			continue
		end
		seenNames[name] = true
		local path = type(session.Path) == "string" and session.Path or ""
		local source = type(session.Src) == "string" and session.Src or "sesh"
		local score: number?

		if query == "" then
			score = 0
		else
			score = noctalia.fuzzyScore(query, name)
			if score == nil and path ~= "" then
				score = noctalia.fuzzyScore(query, path)
			end
		end

		if score ~= nil then
			local subtitle = sourceLabel(source)
			if path ~= "" then
				subtitle = subtitle .. "  ·  " .. path
			end
			if session.Attached and session.Attached > 0 then
				subtitle = subtitle .. "  ·  attached"
			end

			tinsert(results, {
				-- Sesh resolves the name against its own sources, retaining support for
				-- tmux, sesh.toml, tmuxinator, and zoxide entries.
				id = name,
				title = name,
				subtitle = subtitle,
				glyph = source == "tmux" and "terminal-2" or "folder",
				score = score,
			})
		end
	end

	tsort(results, function(a, b)
		return (a.score or 0) > (b.score or 0)
	end)
	return results
end

local function setMessage(query: string, titleKey: string, subtitleKey: string, glyph: string)
	launcher.setResults(query, {
		{
			id = "",
			title = noctalia.tr(titleKey),
			subtitle = noctalia.tr(subtitleKey),
			glyph = glyph,
		},
	})
end

function onQuery(query: string)
	query = noctalia.string.trim(query)
	pendingQuery = query
	local command = seshCommand()

	-- commandExists only searches PATH. An explicitly configured absolute path
	-- (for example a Mise shim) is executed directly below.
	if command == "sesh" and not noctalia.commandExists(command) then
		setMessage(query, "sesh_not_found", "sesh_not_found_subtitle", "alert-triangle")
		return
	end

	setMessage(query, "loading", "loading_subtitle", "loader")
	noctalia.runAsync(shellQuote(command) .. " list --hide-duplicates --json", function(result)
		if pendingQuery ~= query then
			return
		end

		if result.exitCode ~= 0 then
			noctalia.log("noctalia-tmux-sesh: sesh list failed: " .. tostring(result.stderr or result.stdout))
			setMessage(query, "sesh_list_failed", "sesh_list_failed_subtitle", "alert-triangle")
			return
		end

		local results = makeResults(query, parseSessions(result.stdout or ""))
		if #results == 0 then
			setMessage(query, "no_sessions_found", "no_sessions_subtitle", "terminal")
		else
			launcher.setResults(query, results)
		end
	end)
end

function onActivate(id: string)
	if id == "" then
		return
	end

	noctalia.runInTerminal(shellQuote(seshCommand()) .. " connect " .. shellQuote(id))
end
