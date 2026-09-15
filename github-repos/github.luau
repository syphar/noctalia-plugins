local M = {}

function M.message(text, title, subtitle)
    launcher.setResults(text, {{ id = "status", title = title, subtitle = subtitle }})
end

function M.api(endpoint, fields, filter, callback)
    if not noctalia.commandExists("gh") then
        callback(nil, "Install GitHub CLI (gh), then run gh auth login --hostname github.com.")
        return
    end
    local argv = { "gh", "api", "--hostname", "github.com", "--method", "GET", endpoint,
        "--jq", filter }
    for _, field in ipairs(fields) do
        table.insert(argv, "--raw-field")
        table.insert(argv, field)
    end
    local accepted = noctalia.runAsync(argv, function(result)
        if result.timedOut or result.stdoutTruncated then
            callback(nil, "GitHub response timed out or was too large. Try again.")
        elseif result.exitCode ~= 0 then
            local detail = result.stderr or ""
            if string.find(detail, "401", 1, true) or string.find(detail, "auth login", 1, true) then
                callback(nil, "Run gh auth login --hostname github.com in a terminal, then retry.")
            elseif string.find(string.lower(detail), "rate limit", 1, true) then
                callback(nil, "GitHub rate limit reached. Wait a minute before retrying.")
            else
                callback(nil, "GitHub request failed. Check your connection and gh auth status --hostname github.com.")
            end
        else
            local data = noctalia.json.decode(result.stdout)
            if type(data) ~= "table" then
                callback(nil, "GitHub returned an invalid response. Try again.")
            else
                callback(data, nil)
            end
        end
    end)
    if not accepted then
        callback(nil, "Could not start GitHub CLI. Try again.")
    end
end

M.fields = "{id, full_name, description, private, fork, stargazers_count}"

function M.results(repos, query, fuzzy)
    local results = {}
    for index, repo in ipairs(repos) do
        local name = repo.full_name
        if type(name) == "string" and string.match(name, "^[%w_.%-]+/[%w_.%-]+$") then
            local score = fuzzy and 0 or -index
            if fuzzy and query ~= "" then
                score = noctalia.fuzzyScore(query, name)
            end
            if score ~= nil then
                local details = repo.private and "Private" or "Public"
                if type(repo.description) == "string" and repo.description ~= "" then
                    details = details .. " · " .. repo.description
                end
                table.insert(results, {
                    id = "https://github.com/" .. name,
                    title = name,
                    subtitle = details,
                    glyph = repo.private and "lock" or "brand-github",
                    score = score,
                    priority = fuzzy and ((repo.fork and 0 or 10) + (repo.sourcePriority or 0)) or 0,
                    index = index,
                })
            end
        end
    end
    table.sort(results, function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end
        if a.score ~= b.score then return a.score > b.score end
        if query == "" then return a.index < b.index end
        return a.title < b.title
    end)
    while #results > 50 do table.remove(results) end
    for index, result in ipairs(results) do
        -- Noctalia sorts by score too: publish the complete ordering, including ties.
        result.score = -index
        result.priority = nil
        result.index = nil
    end
    return results
end

function M.activate(id)
    if not string.match(id, "^https://github%.com/[%w_.%-]+/[%w_.%-]+$") then return end
    if not noctalia.runAsync({ "xdg-open", id }, function(result)
        if result.exitCode ~= 0 or result.timedOut then
            noctalia.notifyError("GitHub Repositories", "Could not open the repository in your browser.")
        end
    end) then
        noctalia.notifyError("GitHub Repositories", "Could not start xdg-open.")
    end
end

return M
